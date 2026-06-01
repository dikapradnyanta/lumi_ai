#!/usr/bin/env python3
"""
stream_tts.py — SSE stream parser + TTS per kalimat.
Dual-engine: edge-tts (online) / piper-tts (offline).

Usage: curl --no-buffer ... | python3 stream_tts.py
Output (stdout): full teks response setelah selesai
"""

import sys
import re
import json
import subprocess
import os
import asyncio
import tempfile
import threading
import queue
import socket
import time
import datetime

def log_time(msg):
    now = datetime.datetime.now().strftime('%H:%M:%S.%f')[:-3]
    with open('/tmp/lumi_timing_debug.log', 'a') as f:
        f.write(f"{now} - [TTS] {msg}\n")

# ── Konfigurasi ────────────────────────────────────────────────
EDGE_VOICE    = "id-ID-GadisNeural"
PIPER_MODEL   = os.path.expanduser(
    "~/.local/share/piper/models/id_ID-news_tts-medium.onnx"
)
PIPER_BIN     = os.path.expanduser("~/.local/bin/piper")
MAX_CHUNK_LEN = 140
SENTENCE_ENDS = re.compile(r'(?<=[.!?,;])\s+')
MARKDOWN_RE   = re.compile(r'```[\s\S]*?```|`[^`]+`|[*_#>~\[\]()]')
URL_RE        = re.compile(r'https?://\S+')
MPV_PID_FILE  = "/tmp/lumi_mpv.pid"


# ── Cek koneksi internet ───────────────────────────────────────
def is_online(host="api.groq.com", port=443, timeout=2) -> bool:
    try:
        socket.setdefaulttimeout(timeout)
        socket.socket(socket.AF_INET, socket.SOCK_STREAM).connect((host, port))
        return True
    except Exception:
        return False


# ── Audio Queue ────────────────────────────────────────────────
audio_queue   = queue.Queue()
playback_done = threading.Event()


def audio_worker():
    """Thread sequential playback dari queue."""
    while True:
        item = audio_queue.get()
        if item is None:
            playback_done.set()
            break
        log_time(f"Starting playback for: {item}")
        _play_audio_file(item)
        log_time(f"Finished playback for: {item}")
        audio_queue.task_done()


def _play_audio_file(path: str):
    try:
        proc = subprocess.Popen(
            ["mpv", "--no-video", "--vo=null", "--ao=pipewire", "--really-quiet", "--", path]
        )
        with open(MPV_PID_FILE, "w") as f:
            f.write(str(proc.pid))
        proc.wait()
    except FileNotFoundError:
        print("[stream_tts] ERROR: mpv tidak ditemukan. Install: sudo pacman -S mpv", file=sys.stderr)
    except Exception as e:
        print(f"[stream_tts] mpv error: {e}", file=sys.stderr)
    finally:
        try:
            os.unlink(path)
        except Exception:
            pass
        try:
            os.unlink(MPV_PID_FILE)
        except Exception:
            pass


# ── Synthesize: edge-tts ───────────────────────────────────────
async def _edge_synth(text: str, output_path: str) -> bool:
    try:
        import edge_tts
        communicate = edge_tts.Communicate(text, EDGE_VOICE)
        await communicate.save(output_path)
        return True
    except ImportError:
        print("[stream_tts] ERROR: edge-tts tidak terinstall. Jalankan: pip install edge-tts --break-system-packages", file=sys.stderr)
        return False
    except Exception as e:
        print(f"[stream_tts] edge-tts error: {e}", file=sys.stderr)
        return False


# ── Synthesize: piper-tts ──────────────────────────────────────
def _piper_synth(text: str, output_path: str) -> bool:
    if not os.path.exists(PIPER_BIN) or not os.path.exists(PIPER_MODEL):
        return False
    try:
        result = subprocess.run(
            [PIPER_BIN, "--model", PIPER_MODEL, "--output_file", output_path],
            input=text.encode("utf-8"),
            capture_output=True,
            timeout=15
        )
        return result.returncode == 0 and os.path.getsize(output_path) > 0
    except Exception as e:
        print(f"[stream_tts] piper error: {e}", file=sys.stderr)
        return False


def enqueue_tts(text: str, online: bool):
    """Synthesize dan masukkan ke audio queue (non-blocking)."""
    text = text.strip()
    if not text:
        return

    ext = ".mp3" if online else ".wav"
    tmp_path = None
    try:
        with tempfile.NamedTemporaryFile(suffix=ext, delete=False) as f:
            tmp_path = f.name

        if online:
            ok = asyncio.run(_edge_synth(text, tmp_path))
            if not ok:
                tmp_wav = tmp_path.replace(".mp3", ".wav")
                ok = _piper_synth(text, tmp_wav)
                if ok:
                    os.unlink(tmp_path)
                    tmp_path = tmp_wav
        else:
            ok = _piper_synth(text, tmp_path)

        if ok:
            log_time(f"Queued TTS chunk (len={len(text)})")
            audio_queue.put(tmp_path)
            print(f"[stream_tts] Queued TTS: {text[:40]}...", file=sys.stderr)
        else:
            print(f"[stream_tts] WARN: Gagal synthesize chunk, skip.", file=sys.stderr)
            if tmp_path and os.path.exists(tmp_path):
                os.unlink(tmp_path)
    except Exception as e:
        print(f"[stream_tts] enqueue error: {e}", file=sys.stderr)
        if tmp_path and os.path.exists(tmp_path):
            try:
                os.unlink(tmp_path)
            except Exception:
                pass


# ── Text utils ─────────────────────────────────────────────────
def clean(text: str) -> str:
    text = MARKDOWN_RE.sub("", text)
    text = URL_RE.sub("tautan", text)
    return re.sub(r'\s+', ' ', text).strip()


def split_sentences(text: str) -> list:
    parts = SENTENCE_ENDS.split(text)
    result = []
    current = ""
    for part in parts:
        if len(current) + len(part) <= MAX_CHUNK_LEN:
            current += part + " "
        else:
            if current.strip():
                result.append(current.strip())
            current = part + " "
    if current.strip():
        result.append(current.strip())
    return result if result else [text]


def main():
    online = is_online()
    engine = "edge-tts" if online else "piper-tts"
    print(f"[stream_tts] Engine: {engine}", file=sys.stderr)

    # Start audio worker thread
    worker = threading.Thread(target=audio_worker, daemon=True)
    worker.start()

    full_text       = []
    sentence_buffer = ""
    line_count      = 0
    sse_count       = 0
    raw_lines_buffer = []  # buffer beberapa baris pertama untuk debug

    for raw_line in sys.stdin:
        if line_count == 0:
            log_time("Received first byte from API")
        line = raw_line.strip()
        line_count += 1

        # Simpan 5 baris pertama untuk debug
        if line_count <= 5 and line:
            raw_lines_buffer.append(line)

        # ── Deteksi response error dari API (bukan SSE) ────────────────
        # Groq error response berupa JSON murni, bukan "data: ..."
        if line_count == 1 and line and not line.startswith("data:"):
            try:
                error_json = json.loads(line)
                if "error" in error_json:
                    err_msg = error_json["error"].get("message", str(error_json["error"]))
                    print(f"[stream_tts] API ERROR: {err_msg}", file=sys.stderr)
                    # Drain stdin
                    for _ in sys.stdin:
                        pass
                    audio_queue.put(None)
                    playback_done.wait(timeout=1)
                    sys.exit(1)
            except (json.JSONDecodeError, ValueError):
                # Bukan JSON, mungkin HTTP header atau response aneh
                print(f"[stream_tts] WARN: Baris pertama bukan SSE atau JSON: {line[:80]}", file=sys.stderr)

        if not line.startswith("data:"):
            continue

        sse_count += 1
        data_str = line[5:].strip()

        if data_str == "[DONE]":
            leftover = clean(sentence_buffer)
            if leftover:
                for chunk in split_sentences(leftover):
                    if chunk:
                        enqueue_tts(chunk, online)
            break

        try:
            data = json.loads(data_str)
        except json.JSONDecodeError:
            continue

        delta = data.get("choices", [{}])[0].get("delta", {})
        token = delta.get("content", "")
        if not token:
            continue

        sentence_buffer += token
        full_text.append(token)

        if re.search(r'[.!?,;]\s', sentence_buffer):
            sentences = split_sentences(clean(sentence_buffer))
            for sentence in sentences[:-1]:
                if sentence:
                    enqueue_tts(sentence, online)
            sentence_buffer = sentences[-1] if sentences else ""

    # ── Debug summary ──────────────────────────────────────────
    print(f"[stream_tts] Selesai. Total baris: {line_count}, SSE lines: {sse_count}", file=sys.stderr)
    if sse_count == 0:
        print(f"[stream_tts] WARNING: Tidak ada SSE data yang diterima!", file=sys.stderr)
        if raw_lines_buffer:
            print(f"[stream_tts] 5 baris pertama dari curl:", file=sys.stderr)
            for l in raw_lines_buffer:
                print(f"  > {l[:120]}", file=sys.stderr)
        print(f"[stream_tts] Cek: apakah AUTO_SPEAK=true? Apakah groq.sh streaming aktif?", file=sys.stderr)

    # Output full text ke stdout (dibaca groq.sh)
    result = "".join(full_text)
    log_time("Sending IPC text directly to QML")
    if result:
        # Kirim IPC secara langsung agar UI langsung update teks (tidak nunggu audio selesai)
        try:
            qs_path = os.path.expanduser("~/.config/hypr/scripts/quickshell/Main.qml")
            subprocess.Popen(["quickshell", "-p", qs_path, "ipc", "call", "lumi", "groqComplete", result])
        except Exception:
            pass
        print(result, end="", flush=True)
    else:
        print("[stream_tts] ERROR: Tidak ada teks yang dihasilkan", file=sys.stderr)
        sys.exit(1)

    # Tunggu semua audio selesai
    audio_queue.join()
    audio_queue.put(None)
    playback_done.wait(timeout=30)


if __name__ == "__main__":
    main()
