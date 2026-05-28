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
        _play_audio_file(item)
        audio_queue.task_done()


def _play_audio_file(path: str):
    try:
        proc = subprocess.Popen(
            ["mpv", "--no-video", "--really-quiet", "--", path]
        )
        with open(MPV_PID_FILE, "w") as f:
            f.write(str(proc.pid))
        proc.wait()
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
                # Fallback ke piper
                tmp_wav = tmp_path.replace(".mp3", ".wav")
                ok = _piper_synth(text, tmp_wav)
                if ok:
                    os.unlink(tmp_path)
                    tmp_path = tmp_wav
        else:
            ok = _piper_synth(text, tmp_path)

        if ok:
            audio_queue.put(tmp_path)
        else:
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
    # Deteksi koneksi sekali di awal
    online = is_online()
    engine = "edge-tts" if online else "piper-tts"
    print(f"[stream_tts] Engine: {engine}", file=sys.stderr)

    # Start audio worker thread
    worker = threading.Thread(target=audio_worker, daemon=True)
    worker.start()

    full_text      = []
    sentence_buffer = ""

    for raw_line in sys.stdin:
        line = raw_line.strip()

        if not line.startswith("data:"):
            continue

        data_str = line[5:].strip()

        if data_str == "[DONE]":
            leftover = clean(sentence_buffer)
            if leftover:
                full_text.append(leftover)
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

        # Deteksi kalimat lengkap
        if re.search(r'[.!?,;]\s', sentence_buffer):
            sentences = split_sentences(clean(sentence_buffer))
            for sentence in sentences[:-1]:
                if sentence:
                    enqueue_tts(sentence, online)
            sentence_buffer = sentences[-1] if sentences else ""

    # Tunggu semua audio selesai
    audio_queue.join()
    audio_queue.put(None)
    playback_done.wait()

    # Output full text ke stdout (dibaca groq.sh)
    print("".join(full_text), end="")


if __name__ == "__main__":
    main()
