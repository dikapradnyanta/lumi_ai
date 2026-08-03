#!/usr/bin/env python3
"""
Lumi v2 — backend/mic_level.py
Reads live audio from PipeWire and emits 7 normalized energy band levels
each frame to stdout, for use by Waveform.qml visualizer.

Output format (one line per frame, 7 space-separated floats 0.0–1.0):
  0.12 0.45 0.67 0.55 0.38 0.22 0.10

Stop: send SIGTERM or SIGINT (process killed when VoicePanel is hidden).
"""

import sys
import os
import json
import time
import signal
import subprocess
import threading
import numpy as np

# ── Constants ─────────────────────────────────────────────────────────────────
SETTINGS_FILE = os.path.expanduser("~/.config/hypr/settings.json")
SAMPLE_RATE   = 16000
CHANNELS      = 1
CHUNK_SAMPLES = 512          # ~32ms per chunk
N_BANDS       = 7
SMOOTHING     = 0.65         # EMA smoothing (higher = slower decay, more fluid)
GAIN          = 4.0          # Amplification multiplier for visualization

_running = True


def log(msg: str):
    print(f"[mic_level] {msg}", file=sys.stderr, flush=True)


def load_mic_device() -> str:
    """Read micDevice from settings.json, fallback to 'default'."""
    try:
        with open(SETTINGS_FILE) as f:
            data = json.load(f)
            return data.get("lumi", {}).get("micDevice", "default")
    except Exception:
        return "default"


def compute_bands(samples: np.ndarray, n_bands: int) -> list[float]:
    """Split samples into N_BANDS frequency bands using FFT magnitude."""
    n = len(samples)
    if n == 0:
        return [0.0] * n_bands

    # Apply Hanning window to reduce spectral leakage
    windowed = samples * np.hanning(n)
    fft_mag = np.abs(np.fft.rfft(windowed))

    # Only use the lower 60% of frequency spectrum (voice range)
    usable = max(1, len(fft_mag) * 6 // 10)
    fft_mag = fft_mag[:usable]

    # Split into N_BANDS equal-ish chunks
    split = np.array_split(fft_mag, n_bands)
    bands = []
    for band in split:
        rms = float(np.sqrt(np.mean(band ** 2))) if len(band) > 0 else 0.0
        bands.append(rms)

    # Normalize to [0, 1] with gain
    peak = max(bands) if max(bands) > 0 else 1.0
    normalized = [min(1.0, (b / peak) * GAIN) for b in bands]
    return normalized


def main():
    global _running

    def _stop(sig, frame):
        global _running
        _running = False

    signal.signal(signal.SIGTERM, _stop)
    signal.signal(signal.SIGINT, _stop)

    mic_device = load_mic_device()
    env = os.environ.copy()
    if mic_device != "default":
        env["PULSE_SOURCE"] = mic_device

    cmd = [
        "pw-record",
        "--format", "s16",
        "--rate", str(SAMPLE_RATE),
        "--channels", str(CHANNELS),
        "-"
    ]

    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            env=env
        )
    except Exception as e:
        log(f"Failed to start pw-record: {e}")
        sys.exit(1)

    log(f"Started. mic={mic_device}, rate={SAMPLE_RATE}, bands={N_BANDS}")

    # EMA smoothed levels
    smoothed = [0.0] * N_BANDS
    bytes_per_chunk = CHUNK_SAMPLES * 2  # 16-bit = 2 bytes/sample

    try:
        while _running:
            raw = proc.stdout.read(bytes_per_chunk)
            if not raw or len(raw) < bytes_per_chunk:
                break

            samples = np.frombuffer(raw, dtype=np.int16).astype(np.float32) / 32768.0
            bands = compute_bands(samples, N_BANDS)

            # EMA smoothing for fluid animation
            for i in range(N_BANDS):
                smoothed[i] = SMOOTHING * smoothed[i] + (1.0 - SMOOTHING) * bands[i]

            # Emit one line: 7 space-separated floats
            line = " ".join(f"{v:.4f}" for v in smoothed)
            print(line, flush=True)

    except (BrokenPipeError, KeyboardInterrupt):
        pass
    finally:
        try:
            proc.terminate()
            proc.wait(timeout=1)
        except Exception:
            pass
        log("Stopped.")


if __name__ == "__main__":
    main()
