#!/usr/bin/env python3
"""
Lumi v2 — backend/tts.py
Text-to-Speech engine dengan streaming playback.

Engine priority:
  1. Piper TTS (lokal, offline) — id_ID-news_tts-medium
  2. edge-tts (online, Microsoft) — fallback

Usage:
  echo "Teks yang dibacakan" | python3 tts.py
  python3 tts.py --text "Teks langsung"
  python3 tts.py --stdin            ← baca dari stdin (streaming)

Stop signal:
  touch /tmp/lumi_tts_stop   ← interrupt playback dalam <100ms

Exit codes: 0=sukses, 1=error
"""

import sys
import os
import json
import subprocess
import threading
import argparse
import time
import tempfile
import io

# ── Konstanta ──────────────────────────────────────────────
SETTINGS_FILE   = os.path.expanduser("~/.config/hypr/settings.json")
STOP_FLAG       = "/tmp/lumi_tts_stop"
PID_FILE        = "/tmp/lumi_tts.pid"
MAX_INPUT_CHARS = 2000
PIPER_MODELS_DIR = os.path.expanduser("~/.local/share/piper/models")
PIPER_MODEL     = os.path.join(PIPER_MODELS_DIR, "id_ID-news_tts-medium.onnx")

# ── Kontrol state ──────────────────────────────────────────
_stop_event = threading.Event()
_player_proc = None
_player_lock = threading.Lock()


def log(msg: str):
    print(f"[tts] {msg}", file=sys.stderr, flush=True)


def load_settings() -> dict:
    try:
        with open(SETTINGS_FILE) as f:
            return json.load(f).get("lumi", {})
    except Exception:
        return {}


def sanitize_text(text: str) -> str:
    """Strip karakter kontrol berbahaya, markdown, dan batasi panjang."""
    import re
    # Hapus block kode ```...```
    text = re.sub(r"```[\s\S]*?```", " ", text)
    # Hapus format markdown seperti **, *, __, _, #, >, `, ~
    text = re.sub(r"\*\*|\*|__|_|`|#+|>|~", "", text)
    # Ubah [teks](url) menjadi teks
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    # Hapus ASCII kontrol (0-8, 11-12, 14-31) kecuali tab & newline
    cleaned = "".join(
        c for c in text
        if ord(c) >= 32 or c in ("\t", "\n")
    )
    # Batasi panjang
    if len(cleaned) > MAX_INPUT_CHARS:
        log(f"WARN: Teks dipotong dari {len(cleaned)} ke {MAX_INPUT_CHARS} karakter")
        cleaned = cleaned[:MAX_INPUT_CHARS]
    return cleaned.strip()


def watch_stop_flag():
    """Thread: pantau /tmp/lumi_tts_stop, set event jika muncul."""
    # Hapus flag lama dulu
    try:
        os.remove(STOP_FLAG)
    except FileNotFoundError:
        pass

    while not _stop_event.is_set():
        if os.path.exists(STOP_FLAG):
            log("Stop flag terdeteksi — interrupt playback")
            _stop_event.set()
            stop_player()
            try:
                os.remove(STOP_FLAG)
            except Exception:
                pass
            break
        time.sleep(0.05)  # polling 50ms → max ~50ms latency


def stop_player():
    """Hentikan proses audio player dengan segera."""
    global _player_proc
    with _player_lock:
        if _player_proc and _player_proc.poll() is None:
            try:
                _player_proc.terminate()
                _player_proc.wait(timeout=0.5)
            except Exception:
                try:
                    _player_proc.kill()
                except Exception:
                    pass
            _player_proc = None


# ============================================================
# ENGINE 1: PIPER TTS (lokal, offline)
# ============================================================
def speak_piper(text: str) -> bool:
    """Gunakan piper Python API untuk TTS + streaming ke aplay."""
    global _player_proc

    if not os.path.exists(PIPER_MODEL):
        log(f"Piper model tidak ditemukan: {PIPER_MODEL}")
        return False

    try:
        from piper import PiperVoice  # type: ignore

        log(f"Piper: loading model {os.path.basename(PIPER_MODEL)}")
        voice = PiperVoice.load(PIPER_MODEL)

        # Jalankan aplay untuk streaming PCM
        with _player_lock:
            _player_proc = subprocess.Popen(
                ["aplay", "-q", "-f", "S16_LE", "-r", "22050", "-c", "1", "-"],
                stdin=subprocess.PIPE,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )

        log("Piper: synthesizing per kalimat...")
        import wave

        # Bagi teks ke kalimat agar streaming lebih responsif
        sentences = [s.strip() for s in text.replace("\n", ". ").split(".") if s.strip()]
        if not sentences:
            sentences = [text]

        total_words = text.split()
        curr_word_idx = 0

        for sentence in sentences:
            if _stop_event.is_set():
                break
            sent_words = sentence.split()
            buf = io.BytesIO()
            with wave.open(buf, "wb") as wav_file:
                wav_file.setnchannels(1)
                wav_file.setsampwidth(2)  # S16_LE = 2 bytes
                wav_file.setframerate(voice.config.sample_rate)
                voice.synthesize(sentence, wav_file)
            buf.seek(44)  # skip WAV header
            pcm_data = buf.read()
            duration = len(pcm_data) / (voice.config.sample_rate * 2.0)

            try:
                with _player_lock:
                    if _player_proc and _player_proc.stdin and not _stop_event.is_set():
                        _player_proc.stdin.write(pcm_data)
                        _player_proc.stdin.flush()
            except BrokenPipeError:
                break

            if sent_words and duration > 0:
                time_per_word = duration / float(len(sent_words))
                for w in sent_words:
                    if _stop_event.is_set():
                        break
                    print(f"WORD:{curr_word_idx}", flush=True)
                    curr_word_idx += 1
                    time.sleep(time_per_word)

        # Tutup stdin untuk sinyal EOF ke aplay
        with _player_lock:
            if _player_proc and _player_proc.stdin:
                try:
                    _player_proc.stdin.close()
                except Exception:
                    pass

        # Tunggu aplay selesai (kecuali di-interrupt)
        if _player_proc:
            _player_proc.wait()

        log("Piper: selesai")
        return True

    except ImportError:
        log("Piper module tidak tersedia")
        return False
    except Exception as e:
        log(f"Piper error: {e}")
        stop_player()
        return False


# ============================================================
# ENGINE 2: EDGE-TTS (online, Microsoft)
# ============================================================
def speak_edge_tts(text: str) -> bool:
    """Gunakan edge-tts untuk TTS + streaming via mpv, dengan karaoke emit."""
    global _player_proc

    try:
        import asyncio
        import edge_tts  # type: ignore

        settings = load_settings()
        VOICE = settings.get("ttsVoice", "id-ID-GadisNeural")

        log(f"edge-tts: voice={VOICE}, generating audio...")

        async def run_tts():
            communicate = edge_tts.Communicate(text, VOICE)

            # Tulis ke temp file dulu (edge-tts tidak support streaming pipe langsung)
            with tempfile.NamedTemporaryFile(suffix=".mp3", delete=False) as tmp:
                tmp_path = tmp.name

            try:
                await communicate.save(tmp_path)

                if _stop_event.is_set():
                    os.remove(tmp_path)
                    return

                # Putar dengan mpv (atau ffplay sebagai fallback)
                global _player_proc
                with _player_lock:
                    player_cmd = ["mpv", "--no-terminal", "--really-quiet", tmp_path]
                    _player_proc = subprocess.Popen(
                        player_cmd,
                        stdout=subprocess.DEVNULL,
                        stderr=subprocess.DEVNULL
                    )

                log("edge-tts: playing...")
                _player_proc.wait()

            finally:
                try:
                    os.remove(tmp_path)
                except Exception:
                    pass

        asyncio.run(run_tts())
        log("edge-tts: selesai")
        return True

    except ImportError:
        log("edge-tts module tidak tersedia")
        return False
    except Exception as e:
        log(f"edge-tts error: {e}")
        stop_player()
        return False


# ============================================================
# MAIN
# ============================================================
def main():
    parser = argparse.ArgumentParser(description="Lumi v2 TTS Engine")
    parser.add_argument("--text", type=str, help="Teks yang dibacakan langsung")
    parser.add_argument("--stdin", action="store_true", help="Baca dari stdin")
    parser.add_argument("--engine", choices=["piper", "edge-tts", "auto"],
                        default="auto", help="Pilih engine TTS")
    args = parser.parse_args()

    # ── Ambil teks input ──────────────────────────────────────
    if args.text:
        raw_text = args.text
    elif args.stdin or not sys.stdin.isatty():
        raw_text = sys.stdin.read()
    else:
        print("Usage: tts.py --text 'Teks' | atau pipe dari stdin", file=sys.stderr)
        sys.exit(1)

    # ── Sanitasi ──────────────────────────────────────────────
    text = sanitize_text(raw_text)
    if not text:
        log("Teks kosong setelah sanitasi, skip.")
        sys.exit(0)

    log(f"Input: {len(text)} chars | Preview: {text[:50]}...")

    # ── Simpan PID ────────────────────────────────────────────
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

    # ── Jalankan stop-flag watcher di thread terpisah ─────────
    watcher = threading.Thread(target=watch_stop_flag, daemon=True)
    watcher.start()

    # ── Tentukan engine ───────────────────────────────────────
    settings = load_settings()
    engine_cfg = settings.get("ttsEngine", "auto") if args.engine == "auto" else args.engine

    success = False

    try:
        if engine_cfg == "piper" or engine_cfg == "auto":
            success = speak_piper(text)

        if not success and engine_cfg in ("edge-tts", "auto"):
            log("Fallback ke edge-tts...")
            success = speak_edge_tts(text)

        if not success:
            log("ERROR: Semua engine TTS gagal")
            sys.exit(1)

    finally:
        _stop_event.set()   # hentikan watcher thread
        stop_player()       # pastikan player bersih
        try:
            os.remove(PID_FILE)
        except FileNotFoundError:
            pass
        try:
            os.remove(STOP_FLAG)
        except FileNotFoundError:
            pass

    log("TTS selesai.")


if __name__ == "__main__":
    main()
