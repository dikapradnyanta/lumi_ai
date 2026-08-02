#!/usr/bin/env python3
"""
Lumi v2 — backend/get_context.py
System Context Engine: kumpulkan info OS + jadwal + state sistem
dan format sebagai system prompt XML untuk Gemini.

Usage:
    python3 get_context.py           → output system prompt ke stdout
    python3 get_context.py --json    → output JSON mentah
    python3 get_context.py --test    → pretty-print semua context

Output: system prompt siap pakai untuk Gemini API messages[0]
"""

import os
import sys
import json
import subprocess
import time
from datetime import datetime

# ── Path konstanta (tidak di luar direktori ini) ───────────
HOME = os.path.expanduser("~")
SCHEDULE_FILE = os.path.join(
    HOME, ".config/hypr/scripts/quickshell/calendar/schedule/schedule.json"
)
SETTINGS_FILE = os.path.join(HOME, ".config/hypr/settings.json")

# ── Batas keamanan ─────────────────────────────────────────
MAX_CALENDAR_EVENTS  = 10   # max events yang disertakan
MAX_WINDOW_LIST      = 8    # max active windows
MAX_CONTEXT_CHARS    = 3000 # total context tidak melebihi ini


# ============================================================
# HELPER: jalankan command dengan timeout, return stdout
# ============================================================
def run_cmd(cmd: list, timeout: int = 3) -> str:
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout
        )
        return result.stdout.strip()
    except Exception:
        return ""


# ============================================================
# 1. INFORMASI SISTEM DASAR
# ============================================================
def get_os_info() -> dict:
    info = {
        "os": "Unknown",
        "kernel": "Unknown",
        "wm": "Hyprland",
        "shell": "Unknown",
        "hostname": "Unknown",
        "username": os.environ.get("USER", os.environ.get("LOGNAME", "user")),
        "uptime": "Unknown",
    }

    # OS Name dari /etc/os-release
    try:
        with open("/etc/os-release") as f:
            for line in f:
                if line.startswith("NAME="):
                    info["os"] = line.split("=", 1)[1].strip().strip('"')
                    break
    except Exception:
        pass

    # Kernel
    info["kernel"] = run_cmd(["uname", "-r"]) or "Unknown"

    # Shell (ambil nama saja, bukan path)
    shell_path = os.environ.get("SHELL", "")
    info["shell"] = os.path.basename(shell_path) if shell_path else "zsh"

    # Hostname
    info["hostname"] = run_cmd(["hostname"]) or "localhost"

    # Uptime human-readable
    uptime_raw = run_cmd(["uptime", "-p"])
    info["uptime"] = uptime_raw.replace("up ", "") if uptime_raw else "Unknown"

    # Hyprland version (singkat)
    hypr_ver = run_cmd(["hyprctl", "version"], timeout=2)
    if hypr_ver:
        first_line = hypr_ver.splitlines()[0]
        # Ekstrak versi: "Hyprland X.Y.Z ..."
        parts = first_line.split()
        if len(parts) >= 2:
            info["wm"] = f"Hyprland {parts[1]}"

    return info


# ============================================================
# 2. WAKTU & TANGGAL
# ============================================================
def get_datetime_info() -> dict:
    now = datetime.now()
    return {
        "datetime_str": now.strftime("%A, %d %B %Y — %H:%M"),
        "datetime_iso": now.isoformat(),
        "timezone": time.strftime("%Z"),
        "day_of_week": now.strftime("%A"),
        "hour": now.hour,
        "greeting": (
            "Selamat pagi"   if now.hour < 11 else
            "Selamat siang"  if now.hour < 15 else
            "Selamat sore"   if now.hour < 18 else
            "Selamat malam"
        ),
    }


# ============================================================
# 3. BATERAI
# ============================================================
def get_battery_info() -> dict | None:
    battery_dir = "/sys/class/power_supply/BAT0"
    if not os.path.isdir(battery_dir):
        return None

    def read_file(fname: str) -> str:
        try:
            with open(os.path.join(battery_dir, fname)) as f:
                return f.read().strip()
        except Exception:
            return ""

    capacity = read_file("capacity")
    status   = read_file("status")

    if not capacity:
        return None

    return {
        "percent": int(capacity),
        "status": status,  # Charging / Discharging / Full
        "summary": f"{capacity}% ({status})",
    }


# ============================================================
# 4. WINDOW AKTIF (via hyprctl)
# ============================================================
def get_active_windows() -> list[str]:
    raw = run_cmd(["hyprctl", "clients", "-j"], timeout=2)
    if not raw:
        return []
    try:
        clients = json.loads(raw)
        classes = []
        seen = set()
        for c in clients:
            cls = c.get("class", "").strip()
            title = c.get("title", "").strip()
            if cls and cls not in seen:
                seen.add(cls)
                label = cls
                if title and title != cls:
                    label = f"{cls} ({title[:30]})"
                classes.append(label)
        return classes[:MAX_WINDOW_LIST]
    except Exception:
        return []


# ============================================================
# 5. JADWAL KALENDER HARI INI
# ============================================================
def get_calendar_today() -> list[dict]:
    if not os.path.isfile(SCHEDULE_FILE):
        return []

    try:
        with open(SCHEDULE_FILE) as f:
            data = json.load(f)
    except Exception:
        return []

    today = datetime.now().date()
    events = []

    # Cek lessons/events
    for item in data.get("lessons", []) + data.get("events", []):
        try:
            # Support format timestamp atau string
            start = item.get("start")
            if isinstance(start, (int, float)):
                event_date = datetime.fromtimestamp(start).date()
                time_str = datetime.fromtimestamp(start).strftime("%H:%M")
            elif isinstance(start, str) and "T" in start:
                dt = datetime.fromisoformat(start)
                event_date = dt.date()
                time_str = dt.strftime("%H:%M")
            else:
                time_str = item.get("time", "?")
                event_date = today  # fallback assume today

            if event_date != today:
                continue

            events.append({
                "time": time_str,
                "title": item.get("subject", item.get("title", "Event")),
                "type": item.get("type", "event"),
            })
        except Exception:
            continue

    # Sort by time
    events.sort(key=lambda e: e["time"])
    return events[:MAX_CALENDAR_EVENTS]


# ============================================================
# 6. ASSEMBLY: FORMAT SYSTEM PROMPT
# ============================================================
def build_system_prompt(os_info: dict, dt_info: dict,
                         battery: dict | None,
                         windows: list[str],
                         calendar: list[dict]) -> str:

    # Calendar section
    if calendar:
        cal_lines = "\n".join(
            f"  - {e['time']}: {e['title']}" for e in calendar
        )
        cal_block = f"<calendar_today>\n{cal_lines}\n</calendar_today>"
    else:
        cal_block = "<calendar_today>Tidak ada jadwal hari ini.</calendar_today>"

    # Battery section
    bat_line = ""
    if battery:
        bat_line = f"\n    Battery: {battery['summary']}"

    # Active windows
    win_line = ""
    if windows:
        win_line = f"\n    Active apps: {', '.join(windows)}"

    prompt = f"""<system_context>
  <identity>
    Kamu adalah Lumi — asisten AI personal yang tertanam di desktop {os_info['username']} ({os_info['hostname']}).
    OS: {os_info['os']} | WM: {os_info['wm']} | Kernel: {os_info['kernel']} | Shell: {os_info['shell']}.
    Waktu sekarang: {dt_info['datetime_str']} ({dt_info['timezone']}).
    Uptime sistem: {os_info['uptime']}.{bat_line}{win_line}
  </identity>

  <rules>
    - Jawab dalam Bahasa Indonesia kecuali user minta bahasa lain.
    - Jangan mengarang informasi sistem yang tidak kamu ketahui.
    - Untuk mode chat: max 3 paragraf kecuali diminta detail.
    - Untuk mode voice: max 2-3 kalimat pendek, langsung ke inti.
    - Jika diminta jalankan perintah sistem, jelaskan efeknya dulu sebelum konfirmasi.
    - Sapa user dengan "{dt_info['greeting']}" jika percakapan baru dimulai.
  </rules>

  <expertise>
    Linux (BlackArch/Arch, pacman, systemd, Hyprland, dotfiles, ricing),
    shell scripting (bash/zsh), programming (Python, JS/TS, QML, C, Rust),
    keamanan siber (tools BlackArch), AI/ML, produktivitas harian.
  </expertise>

  {cal_block}
</system_context>"""

    # Potong jika terlalu panjang
    if len(prompt) > MAX_CONTEXT_CHARS:
        prompt = prompt[:MAX_CONTEXT_CHARS] + "\n</system_context>"

    return prompt.strip()


# ============================================================
# MAIN
# ============================================================
def collect_all() -> dict:
    os_info  = get_os_info()
    dt_info  = get_datetime_info()
    battery  = get_battery_info()
    windows  = get_active_windows()
    calendar = get_calendar_today()

    return {
        "os_info":  os_info,
        "dt_info":  dt_info,
        "battery":  battery,
        "windows":  windows,
        "calendar": calendar,
    }


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else "prompt"

    data = collect_all()

    if mode == "--json":
        print(json.dumps(data, indent=2, ensure_ascii=False))

    elif mode == "--test":
        print("=" * 60)
        print("OS INFO:", json.dumps(data["os_info"], indent=2, ensure_ascii=False))
        print("DATETIME:", json.dumps(data["dt_info"], indent=2, ensure_ascii=False))
        print("BATTERY:", data["battery"])
        print("WINDOWS:", data["windows"])
        print("CALENDAR:", data["calendar"])
        print("=" * 60)
        print("\nSYSTEM PROMPT:\n")
        prompt = build_system_prompt(**data)
        print(prompt)
        print(f"\n[Total chars: {len(prompt)}]")

    else:
        # Default: output system prompt
        prompt = build_system_prompt(**data)
        print(prompt)


if __name__ == "__main__":
    main()
