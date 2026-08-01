#!/usr/bin/env python3
"""
tts.py — Standalone TTS player dengan dual-engine:
  - Online  → edge-tts (Microsoft Neural, id-ID-GadisNeural)
  - Offline → piper-tts (lokal, id_ID-news_tts-medium)

Deteksi otomatis berdasarkan koneksi internet.
Usage: python3 tts.py "teks yang ingin diucapkan"
"""

import sys
import re
import os
import signal
import subprocess
import tempfile
import asyncio
import time
import socket

# ── Config ─────────────────────────────────────────────────────
EDGE_VOICE    = "id-ID-GadisNeural"   # edge-tts: suara Indonesia perempuan
PIPER_MODEL   = os.path.expanduser(
    "~/.local/share/piper/models/id_ID-news_tts-medium.onnx"
)
PIPER_BIN     = os.path.expanduser("~/.local/bin/piper")
MAX_CHUNK     = 140
MAX_RETRIES   = 3
RETRY_DELAY   = 0.8
MPV_PID_FILE  = "/tmp/lumi_mpv.pid"

# ── Cek koneksi internet ───────────────────────────────────────
def is_online(host="generativelanguage.googleapis.com", port=443, timeout=2) -> bool:
    """Cek apakah ada koneksi internet (coba reach Groq server)."""
    try:
        socket.setdefaulttimeout(timeout)
        socket.socket(socket.AF_INET, socket.SOCK_STREAM).connect((host, port))
        return True
    except Exception:
        return False


# ── Graceful shutdown pada SIGTERM / SIGINT ────────────────────
current_mpv = None

def handle_signal(signum, frame):
    global current_mpv
    if current_mpv and current_mpv.poll() is None:
        current_mpv.terminate()
    try:
        os.unlink(MPV_PID_FILE)
    except FileNotFoundError:
        pass
    sys.exit(0)

signal.signal(signal.SIGTERM, handle_signal)
signal.signal(signal.SIGINT, handle_signal)


# ── Text Cleaning ──────────────────────────────────────────────
def clean_text(text: str) -> str:
    text = re.sub(r'```[\s\S]*?```', '', text)       # hapus code blocks
    text = re.sub(r'`[^`]+`', '', text)               # hapus inline code
    text = re.sub(r'[*_#>~\[\]()]', '', text)         # hapus markdown
    text = re.sub(r'https?://\S+', 'tautan', text)    # ganti URL
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def chunk_text(text: str) -> list:
    sentences = re.split(r'(?<=[.!?,;])\s+', text)
    chunks = []
    current = ""
    for s in sentences:
        if len(current) + len(s) <= MAX_CHUNK:
            current += s + " "
        else:
            if current.strip():
                chunks.append(current.strip())
            current = s + " "
    if current.strip():
        chunks.append(current.strip())
    return chunks if chunks else [text[:MAX_CHUNK]]


# ── Engine: edge-tts (online) ──────────────────────────────────
async def _edge_synthesize(text: str, output_path: str) -> bool:
    try:
        import edge_tts
        communicate = edge_tts.Communicate(text, EDGE_VOICE)
        await communicate.save(output_path)
        return True
    except Exception as e:
        print(f"[tts] edge-tts error: {e}", file=sys.stderr)
        return False


# ── Engine: piper-tts (offline) ───────────────────────────────
def _piper_synthesize(text: str, output_path: str) -> bool:
    if not os.path.exists(PIPER_BIN):
        print(f"[tts] piper binary tidak ditemukan: {PIPER_BIN}", file=sys.stderr)
        return False
    if not os.path.exists(PIPER_MODEL):
        print(f"[tts] piper model tidak ditemukan: {PIPER_MODEL}", file=sys.stderr)
        return False
    try:
        result = subprocess.run(
            [PIPER_BIN, "--model", PIPER_MODEL, "--output_file", output_path],
            input=text.encode("utf-8"),
            capture_output=True,
            timeout=15
        )
        if result.returncode != 0:
            print(f"[tts] piper error: {result.stderr.decode()}", file=sys.stderr)
            return False
        return os.path.exists(output_path) and os.path.getsize(output_path) > 0
    except subprocess.TimeoutExpired:
        print("[tts] piper timeout", file=sys.stderr)
        return False
    except Exception as e:
        print(f"[tts] piper exception: {e}", file=sys.stderr)
        return False


def _play_file(path: str):
    """Putar audio file dengan mpv, simpan PID."""
    global current_mpv
    current_mpv = subprocess.Popen(
        ["mpv", "--no-video", "--really-quiet", "--", path]
    )
    with open(MPV_PID_FILE, "w") as f:
        f.write(str(current_mpv.pid))
    current_mpv.wait()
    try:
        os.unlink(MPV_PID_FILE)
    except FileNotFoundError:
        pass


# ── speak_chunk: coba edge → fallback piper ───────────────────
def speak_chunk(text: str, online: bool) -> bool:
    text = text.strip()
    if not text:
        return True

    # Tentukan ekstensi file berdasarkan engine
    ext = ".mp3" if online else ".wav"
    tmp_path = None

    for attempt in range(MAX_RETRIES):
        try:
            with tempfile.NamedTemporaryFile(suffix=ext, delete=False) as f:
                tmp_path = f.name

            if online:
                ok = asyncio.run(_edge_synthesize(text, tmp_path))
                if not ok:
                    # Fallback ke piper jika edge-tts gagal
                    print("[tts] edge-tts gagal, fallback ke piper...", file=sys.stderr)
                    tmp_path_wav = tmp_path.replace(".mp3", ".wav")
                    ok = _piper_synthesize(text, tmp_path_wav)
                    if ok:
                        os.unlink(tmp_path)
                        tmp_path = tmp_path_wav
            else:
                ok = _piper_synthesize(text, tmp_path)

            if not ok:
                if attempt < MAX_RETRIES - 1:
                    time.sleep(RETRY_DELAY)
                    continue
                return True  # skip chunk

            _play_file(tmp_path)
            return True

        except Exception as e:
            print(f"[tts] Error (attempt {attempt+1}): {e}", file=sys.stderr)
            if attempt < MAX_RETRIES - 1:
                time.sleep(RETRY_DELAY)
        finally:
            if tmp_path and os.path.exists(tmp_path):
                try:
                    os.unlink(tmp_path)
                except OSError:
                    pass

    print(f"[tts] Gagal setelah {MAX_RETRIES} percobaan, skip chunk", file=sys.stderr)
    return True


def main():
    if len(sys.argv) < 2:
        print("[tts] Usage: tts.py <text>", file=sys.stderr)
        sys.exit(1)

    raw_text = " ".join(sys.argv[1:])
    text = clean_text(raw_text)

    if not text:
        print("[tts] Tidak ada teks yang bisa diucapkan", file=sys.stderr)
        sys.exit(0)

    # Deteksi koneksi internet sekali di awal
    online = is_online()
    engine = "edge-tts (online)" if online else "piper-tts (offline)"
    print(f"[tts] Engine: {engine}", file=sys.stderr)

    chunks = chunk_text(text)
    print(f"[tts] {len(chunks)} chunk(s) akan diputar", file=sys.stderr)

    for i, chunk in enumerate(chunks):
        print(f"[tts] Chunk {i+1}/{len(chunks)}: {chunk[:50]}...", file=sys.stderr)
        speak_chunk(chunk, online)


if __name__ == "__main__":
    main()
