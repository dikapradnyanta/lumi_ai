#!/usr/bin/env python3
"""
Lumi v2 — backend/stt_local.py
Real-time Local STT using faster-whisper (offline) with Hybrid VAD (Silero AI + Adaptive Calibrated Energy).

Pipeline:
  - Records continuous 16kHz mono audio via arecord
  - Per-chunk Silero VAD + Calibrated SNR Energy Check
  - Instant trigger upon silence duration threshold
  - Real-time partial transcript preview
"""

import sys
import os
import json
import time
import subprocess
import struct
import math
import numpy as np

SETTINGS_FILE = os.path.expanduser("~/.config/hypr/settings.json")
MODEL_CACHE   = os.path.expanduser("~/.cache/faster_whisper")
STOP_FLAG     = "/tmp/lumi_stt_stop"
SAMPLE_RATE   = 16000
CHUNK_SECS    = 1.5                              # transcribe preview chunk every 1.5s
CHUNK_BYTES   = int(SAMPLE_RATE * CHUNK_SECS * 2)  # S16_LE bytes


def log(msg):
    print(f"[stt_local] {msg}", file=sys.stderr, flush=True)


def load_settings():
    try:
        with open(SETTINGS_FILE) as f:
            return json.load(f).get("lumi", {})
    except Exception:
        return {}


def resolve_mic() -> str:
    cfg = load_settings().get("micDevice", "default")
    if cfg and cfg != "default":
        return cfg
    try:
        res = subprocess.run(
            ["pactl", "get-default-source"],
            capture_output=True, text=True, timeout=2
        )
        src = res.stdout.strip()
        if src and ".monitor" not in src:
            return src
    except Exception:
        pass
    return "default"


def load_silero_vad():
    """Load Silero VAD ONNX model with context buffer."""
    try:
        import onnxruntime as ort
        model_path = os.path.join(
            os.path.dirname(__file__), "silero_vad.onnx"
        )
        if not os.path.exists(model_path):
            return None, None
        session = ort.InferenceSession(model_path, providers=["CPUExecutionProvider"])
        state = np.zeros((2, 1, 128), dtype=np.float32)
        context = np.zeros((1, 64), dtype=np.float32)
        sr_tensor = np.array(16000, dtype=np.int64)
        return session, (state, context, sr_tensor)
    except Exception as e:
        log(f"Silero VAD not available: {e}")
        return None, None


def vad_is_speech(session, vad_ctx, chunk_512: np.ndarray, energy_threshold: float) -> tuple[bool, tuple]:
    """
    Hybrid VAD:
      1. Noise floor check (0.008)
      2. Silero VAD neural probability (prob >= 0.45 for real human speech)
    """
    state, context, sr_tensor = vad_ctx

    peak_energy = float(np.max(np.abs(chunk_512)))
    if peak_energy < 0.008:
        return False, vad_ctx

    try:
        inp = chunk_512[np.newaxis, :]
        x = np.concatenate([context, inp], axis=1)
        out, new_state = session.run(None, {"input": x, "sr": sr_tensor, "state": state})
        new_context = x[:, -64:]
        prob = float(out[0][0])
        is_speech = prob >= 0.45
        return is_speech, (new_state, new_context, sr_tensor)
    except Exception:
        return peak_energy >= energy_threshold, vad_ctx


def transcribe_chunk(model, audio_bytes: bytes) -> str:
    """Transcribe raw PCM bytes using faster-whisper."""
    if not audio_bytes or len(audio_bytes) < int(SAMPLE_RATE * 2 * 0.3):
        return ""
    try:
        samples = np.frombuffer(audio_bytes, dtype=np.int16).astype(np.float32) / 32768.0
        segments, _ = model.transcribe(
            samples,
            beam_size=1,
            word_timestamps=False,
            condition_on_previous_text=False,
            language=None
        )
        text = " ".join(seg.text.strip() for seg in segments).strip()
        return text
    except Exception as e:
        log(f"Transcribe error: {e}")
        return ""


def run():
    settings = load_settings()
    # Dynamic silence duration from settings (min 0.2s)
    silence_dur = max(0.2, float(settings.get("silenceDuration", 0.5)))
    
    # Read calibrated speech threshold (capped at 0.04 for sensitive VAD gate)
    calib_threshold = float(settings.get("speechThreshold", 0.02))
    energy_threshold = min(0.04, max(0.008, calib_threshold))

    mic_device = resolve_mic()

    # Load faster-whisper model
    log("Loading faster-whisper tiny model...")
    try:
        from faster_whisper import WhisperModel  # type: ignore
        model = WhisperModel("tiny", device="cpu", compute_type="int8", download_root=MODEL_CACHE)
        log("faster-whisper tiny: ready")
    except Exception as e:
        print(f"ERROR:whisper_load:{e}", flush=True)
        return

    # Load Silero VAD
    vad_session, vad_ctx = load_silero_vad()
    if vad_session:
        log(f"Hybrid VAD: Silero + Energy (silence_dur={silence_dur}s, energy_thresh={energy_threshold:.4f})")
    else:
        log(f"Energy VAD (silence_dur={silence_dur}s, energy_thresh={energy_threshold:.4f})")

    # Clean stop flag
    try:
        os.remove(STOP_FLAG)
    except FileNotFoundError:
        pass

    # Start arecord (continuous stream)
    env = os.environ.copy()
    if mic_device != "default":
        env["PULSE_SOURCE"] = mic_device
    cmd = ["pw-record", "--format", "s16", "--rate", str(SAMPLE_RATE), "--channels", "1", "-"]
    try:
        proc = subprocess.Popen(cmd, stdout=subprocess.PIPE,
                                stderr=subprocess.DEVNULL, env=env)
    except Exception as e:
        print(f"ERROR:arecord:{e}", flush=True)
        return

    # State tracking
    has_speech       = False
    start_time       = time.monotonic()
    last_speech_time = 0.0
    accumulated_pcm  = b""     # Complete recording buffer for final transcription
    preview_buffer   = b""     # Buffer for live PARTIAL preview
    last_partial     = ""

    log("Listening started...")

    try:
        while True:
            # Check stop flag
            if os.path.exists(STOP_FLAG):
                log("Stop flag detected → finalizing transcript")
                break

            data = proc.stdout.read(512 * 2)  # 512 samples per read (32ms)
            if not data or len(data) < 512 * 2:
                break

            now = time.monotonic()
            accumulated_pcm += data
            preview_buffer += data

            # VAD check
            samples_512 = np.frombuffer(data, dtype=np.int16).astype(np.float32) / 32768.0
            if vad_session:
                is_speech, vad_ctx = vad_is_speech(vad_session, vad_ctx, samples_512, energy_threshold)
            else:
                peak_energy = float(np.max(np.abs(samples_512)))
                is_speech = peak_energy >= energy_threshold

            if is_speech:
                has_speech = True
                last_speech_time = now

            # ── PARTIAL live text preview (every CHUNK_BYTES) ──────────
            if len(preview_buffer) >= CHUNK_BYTES:
                preview_text = transcribe_chunk(model, preview_buffer)
                preview_buffer = preview_buffer[CHUNK_BYTES:]
                if preview_text and preview_text.lower() not in ("", ".", "you", "the", "thank you"):
                    if preview_text != last_partial:
                        last_partial = preview_text
                        print(f"PARTIAL:{preview_text}", flush=True)

            # ── Instant Auto-Answer Trigger ───────────────────────────
            if has_speech and (now - last_speech_time) >= silence_dur:
                log(f"Silence detected ({silence_dur}s) → auto answering!")
                break

            # ── Safety Cutoff: 8s without speech ──────────────────────
            if not has_speech and (now - start_time) >= 8.0:
                log("No speech detected after 8s → stopping recording")
                break

    except KeyboardInterrupt:
        pass
    finally:
        try:
            proc.terminate()
            proc.wait(timeout=1)
        except Exception:
            pass

    # Transcribe entire accumulated speech buffer for accurate FINAL result
    final_text = transcribe_chunk(model, accumulated_pcm)
    if not final_text and last_partial:
        final_text = last_partial

    if final_text and final_text.lower() not in ("", ".", "you", "the", "thank you"):
        print(f"FINAL:{final_text}", flush=True)
        log(f"FINAL: {final_text}")
    else:
        print("FINAL:SILENCE", flush=True)
        log("No speech detected (SILENCE)")

    try:
        os.remove(STOP_FLAG)
    except FileNotFoundError:
        pass


if __name__ == "__main__":
    run()
