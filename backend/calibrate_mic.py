#!/usr/bin/env python3
"""
Lumi v2 — backend/calibrate_mic.py
2-Stage Microphone Calibration:
  Phase 1 (bg, 5s): User DIAM — ukur background noise
  Phase 2 (speech, 4s): User BICARA — ukur intensitas suara

Output ke settings.json:
  silenceThreshold: dB string untuk referensi UI (contoh: "-32dB")
  speechThreshold:  float normalized (0.0–1.0) untuk mic_level.py VAD fallback
  noiseFloor:       float dB background noise peak
  speechFloor:      float dB speech level mean

Usage:
  python3 calibrate_mic.py bg      → rekam 5s background, simpan hasil ke /tmp/lumi_calib_bg.json
  python3 calibrate_mic.py speech  → rekam 4s suara, baca bg hasil, output threshold ke stdout + settings

Output format (stdout):
  JSON { status, phase, ... }
"""

import sys
import os
import json
import subprocess
import struct
import math
import time
import wave
import numpy as np

SETTINGS_FILE  = os.path.expanduser("~/.config/hypr/settings.json")
BG_WAV         = "/tmp/lumi_calib_bg.wav"
SPEECH_WAV     = "/tmp/lumi_calib_speech.wav"
BG_RESULT      = "/tmp/lumi_calib_bg.json"
SAMPLE_RATE    = 16000


def read_mic_device() -> str:
    try:
        with open(SETTINGS_FILE) as f:
            cfg = json.load(f)
        device = cfg.get("lumi", {}).get("micDevice", "default")
        if device and device != "default":
            return device
    except Exception:
        pass

    try:
        res = subprocess.run(
            ["pactl", "get-default-source"],
            capture_output=True, text=True, timeout=2
        )
        src = res.stdout.strip()
        if src and ".monitor" not in src and "snd_aloop" not in src:
            return src
    except Exception:
        pass
    return "default"


def record_wav(output_path: str, duration_sec: int, mic_device: str):
    """Record audio using pw-record."""
    env = os.environ.copy()
    cmd = [
        "pw-record",
        "--format", "s16",
        "--rate", str(SAMPLE_RATE),
        "--channels", "1",
    ]
    if mic_device and mic_device != "default":
        cmd.extend(["--target", mic_device])
        env["PULSE_SOURCE"] = mic_device
    cmd.append(output_path)
    proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
    time.sleep(duration_sec)
    proc.terminate()
    try:
        proc.wait(timeout=1)
    except Exception:
        proc.kill()


def analyze_wav(wav_path: str) -> dict:
    """
    Analyze WAV file and return audio stats.
    Returns: { peak_db, rms_db, peak_norm, rms_norm, percentile95_norm }
    """
    if not os.path.exists(wav_path):
        return {"peak_db": -60.0, "rms_db": -60.0,
                "peak_norm": 0.0, "rms_norm": 0.0, "percentile95_norm": 0.0}
    try:
        with wave.open(wav_path, "rb") as wf:
            frames = wf.readframes(wf.getnframes())
        samples = np.frombuffer(frames, dtype=np.int16).astype(np.float32) / 32768.0
        if len(samples) == 0:
            return {"peak_db": -60.0, "rms_db": -60.0,
                    "peak_norm": 0.0, "rms_norm": 0.0, "percentile95_norm": 0.0}

        # Skip initial 0.3s warmup to ignore startup transient clicks/pops
        warmup = int(SAMPLE_RATE * 0.3)
        if len(samples) > warmup + 1600:
            samples = samples[warmup:]

        peak_norm         = float(np.max(np.abs(samples)))
        rms_norm          = float(np.sqrt(np.mean(samples ** 2)))
        percentile95_norm = float(np.percentile(np.abs(samples), 95))

        peak_db = 20 * math.log10(max(peak_norm, 1e-7))
        rms_db  = 20 * math.log10(max(rms_norm, 1e-7))

        return {
            "peak_db":           round(peak_db, 2),
            "rms_db":            round(rms_db, 2),
            "peak_norm":         round(peak_norm, 5),
            "rms_norm":          round(rms_norm, 5),
            "percentile95_norm": round(percentile95_norm, 5),
        }
    except Exception as e:
        return {"peak_db": -60.0, "rms_db": -60.0,
                "peak_norm": 0.0, "rms_norm": 0.0, "percentile95_norm": 0.0,
                "error": str(e)}


def update_settings(key_values: dict):
    """Update settings.json lumi section safely."""
    try:
        cfg = {}
        if os.path.exists(SETTINGS_FILE):
            with open(SETTINGS_FILE) as f:
                cfg = json.load(f)
        lumi = cfg.get("lumi", {})
        lumi.update(key_values)
        cfg["lumi"] = lumi
        # Write atomically
        tmp = SETTINGS_FILE + ".tmp"
        with open(tmp, "w") as f:
            json.dump(cfg, f, indent=4)
        os.replace(tmp, SETTINGS_FILE)
    except Exception as e:
        print(f"[calibrate] Warning: could not update settings.json: {e}", file=sys.stderr)


def main():
    phase = sys.argv[1] if len(sys.argv) > 1 else "all"
    mic_device = read_mic_device()

    # ─── PHASE 1: Background Noise (5s, user silent) ───────────────
    if phase == "bg":
        print("[calibrate] Recording 5s background noise... STAY SILENT!", file=sys.stderr)
        record_wav(BG_WAV, 5, mic_device)
        stats = analyze_wav(BG_WAV)

        # Save bg result for speech phase to reference
        with open(BG_RESULT, "w") as f:
            json.dump(stats, f)

        result = {
            "status": "ok",
            "phase": "bg",
            "max_db": stats["peak_db"],
            "mean_db": stats["rms_db"],
            "peak_norm": stats["peak_norm"],
            "rms_norm": stats["rms_norm"],
        }
        print(json.dumps(result), flush=True)
        return

    # ─── PHASE 2: User Speech (4s, user speaks) ────────────────────
    if phase == "speech":
        print("[calibrate] Recording 4s user voice... SPEAK NORMALLY!", file=sys.stderr)
        record_wav(SPEECH_WAV, 4, mic_device)

        speech_stats = analyze_wav(SPEECH_WAV)

        # Load background stats
        bg_stats = {}
        if os.path.exists(BG_RESULT):
            try:
                with open(BG_RESULT) as f:
                    bg_stats = json.load(f)
            except Exception:
                pass

        bg_peak_norm  = bg_stats.get("peak_norm", 0.05)
        bg_rms_norm   = bg_stats.get("rms_norm", 0.02)
        bg_peak_db    = bg_stats.get("peak_db", -30.0)
        bg_rms_db     = bg_stats.get("rms_db", -40.0)

        sp_peak_norm  = speech_stats["peak_norm"]
        sp_rms_norm   = speech_stats["rms_norm"]
        sp_p95_norm   = speech_stats["percentile95_norm"]
        sp_peak_db    = speech_stats["peak_db"]
        sp_rms_db     = speech_stats["rms_db"]

        # ── Validate: speech must be louder than background ──
        snr_db = sp_rms_db - bg_rms_db  # Signal-to-Noise Ratio
        if snr_db < 2.0:
            print(json.dumps({
                "status": "error",
                "phase": "speech",
                "message": f"SNR terlalu rendah ({snr_db:.1f}dB). Bicara lebih keras atau dekatkan mikrofon saat tahap 2.",
                "bg_max_db": bg_peak_db,
                "speech_rms_db": sp_rms_db,
                "snr_db": round(snr_db, 1),
            }), flush=True)
            return

        # ── Calculate unbiased thresholds ─────────────────────────────────────
        # 1. speech_threshold (normalized 0–1): midpoint between bg RMS noise and speech RMS level
        raw_speech_threshold = (bg_rms_norm + sp_rms_norm) / 2.0
        speech_threshold = round(max(0.01, min(0.04, raw_speech_threshold)), 4)

        # 2. silence_threshold (dB string): midpoint between bg RMS noise and speech RMS level
        mid_db = (bg_rms_db + sp_rms_db) / 2.0
        mid_db = max(-50.0, min(-18.0, mid_db))
        silence_threshold_str = f"{int(round(mid_db))}dB"

        # Update settings.json with calibration results
        update_settings({
            "silenceThreshold":  silence_threshold_str,
            "speechThreshold":   speech_threshold,
            "noiseFloor":        round(bg_rms_db, 1),
            "speechLevel":       round(sp_rms_db, 1),
        })

        # Also update mic_level SPEECH_THRESHOLD fallback in memory (via env file)
        with open("/tmp/lumi_calib_result.json", "w") as f:
            json.dump({
                "speech_threshold": speech_threshold,
                "silence_threshold": silence_threshold_str,
            }, f)

        result = {
            "status": "ok",
            "phase": "speech",
            "bg_max_db": round(bg_peak_db, 1),
            "bg_rms_db": round(bg_rms_db, 1),
            "speech_max_db": round(sp_peak_db, 1),
            "speech_mean_db": round(sp_rms_db, 1),
            "speech_p95_norm": sp_p95_norm,
            "bg_peak_norm": bg_peak_norm,
            "speech_threshold_norm": speech_threshold,
            "snr_db": round(snr_db, 1),
            "optimal_threshold": silence_threshold_str,
        }
        print(json.dumps(result), flush=True)

        # Cleanup temp files
        for f in [BG_WAV, SPEECH_WAV, BG_RESULT]:
            try:
                os.remove(f)
            except FileNotFoundError:
                pass
        return

    # ─── FULL (all): Run both phases sequentially ──────────────────
    print("[calibrate] Phase 1/2: Recording 5s background noise (STAY SILENT)...")
    record_wav(BG_WAV, 5, mic_device)
    bg = analyze_wav(BG_WAV)
    print(f"[calibrate] Background: peak={bg['peak_db']:.1f}dB, rms={bg['rms_db']:.1f}dB")

    print("[calibrate] Phase 2/2: Recording 4s user voice (SPEAK NORMALLY)...")
    record_wav(SPEECH_WAV, 4, mic_device)
    sp = analyze_wav(SPEECH_WAV)
    print(f"[calibrate] Speech:     peak={sp['peak_db']:.1f}dB, rms={sp['rms_db']:.1f}dB")

    snr = sp["rms_db"] - bg["rms_db"]
    mid_db = (bg["rms_db"] + sp["rms_db"]) / 2.0
    mid_db = max(-50.0, min(-18.0, mid_db))
    threshold_str = f"{int(round(mid_db))}dB"
    speech_thr = round((bg["rms_norm"] + sp["rms_norm"]) / 2.0, 4)

    print(f"[calibrate] SNR: {snr:.1f}dB")
    print(f"[calibrate] Optimal threshold: {threshold_str} (normalized: {speech_thr})")


if __name__ == "__main__":
    main()
