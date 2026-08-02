#!/usr/bin/env python3
"""
Lumi v2 — backend/mic_level.py
Real-time FFT mic level analyzer untuk waveform visualizer.

Baca PCM stream dari arecord → FFT 7 band → output ke stdout.
Format output: 7 float angka per baris, dipisah spasi, 25 FPS.
Contoh: 0.12 0.45 0.78 0.34 0.56 0.23 0.67

Usage:
    python3 mic_level.py [mic_device]
    python3 mic_level.py alsa_input.pci-0000_07_00.6.analog-stereo

Stop: Ctrl+C atau kill process
"""

import sys
import os
import subprocess
import struct
import numpy as np
import json
import time

# ── Konfigurasi ──────────────────────────────────────────
SAMPLE_RATE   = 16000
CHANNELS      = 1
CHUNK_SIZE    = 512       # samples per chunk
N_BARS        = 7         # jumlah bar waveform (sesuai design.md: 7-9)
TARGET_FPS    = 25        # frame per detik output
SMOOTHING     = 0.6       # smoothing factor (0=no smooth, 1=full smooth)
MIN_DB        = -55.0     # dB floor
MAX_DB        = -15.0     # dB ceceilingiling (boost sensitivity for speech)

SETTINGS_FILE = os.path.expanduser("~/.config/hypr/settings.json")


def read_mic_device() -> str:
    """Baca mic device dari settings.json dengan fallback."""
    try:
        with open(SETTINGS_FILE) as f:
            cfg = json.load(f)
        device = cfg.get("lumi", {}).get("micDevice", "default")
        if device and device != "default":
            return device
    except Exception:
        pass

    # Fallback: pactl get-default-source
    try:
        result = subprocess.run(
            ["pactl", "get-default-source"],
            capture_output=True, text=True, timeout=3
        )
        device = result.stdout.strip()
        # Hindari loopback/monitor
        if device and ".monitor" not in device and "snd_aloop" not in device:
            return device
    except Exception:
        pass

    # Fallback ke physical mic pertama
    try:
        result = subprocess.run(
            ["pactl", "list", "short", "sources"],
            capture_output=True, text=True, timeout=3
        )
        for line in result.stdout.splitlines():
            parts = line.split()
            if len(parts) >= 2:
                name = parts[1]
                if "alsa_input" in name and "snd_aloop" not in name:
                    return name
    except Exception:
        pass

    return "default"



def read_silence_duration() -> float:
    """Baca silence duration (pause time in seconds before auto-answer) dari settings.json."""
    try:
        with open(SETTINGS_FILE) as f:
            cfg = json.load(f)
        val = cfg.get("lumi", {}).get("silenceDuration", 1.0)
        return max(0.2, min(5.0, float(val)))
    except Exception:
        return 1.0


def read_speech_threshold() -> float:
    """Baca calibrated speech threshold (normalized 0.0-1.0) dari settings.json.
    Digunakan sebagai energy-based VAD fallback jika Silero ONNX tidak tersedia."""
    try:
        with open(SETTINGS_FILE) as f:
            cfg = json.load(f)
        val = cfg.get("lumi", {}).get("speechThreshold", None)
        if val is not None:
            return max(0.005, min(0.5, float(val)))
    except Exception:
        pass
    return 0.03  # Default threshold



def db_to_norm(db: float) -> float:
    """Konversi dB ke nilai normalized 0.0-1.0 dengan responsivitas tinggi."""
    norm = max(0.0, min(1.0, (db - MIN_DB) / (MAX_DB - MIN_DB)))
    # Non-linear gain boost (sqrt/power curve) untuk reaksi visual yang responsive
    return float(norm ** 0.75)


def compute_bands(samples: np.ndarray, n_bands: int) -> list[float]:
    """FFT → split ke N band frekuensi vokal (125Hz - 4200Hz) → return normalized levels."""
    if len(samples) == 0:
        return [0.0] * n_bands

    # Apply Hanning window untuk mengurangi spectral leakage
    windowed = samples * np.hanning(len(samples))

    # FFT — ambil magnitude (half spectrum saja)
    fft_vals = np.fft.rfft(windowed)
    magnitude = np.abs(fft_vals)

    # Focus 7 bands secara spesifik pada rentang frekuensi vokal manusia (125 Hz - 4200 Hz)
    # Bin index = freq / (16000 / 512) = freq / 31.25 Hz per bin
    low_bin = 4     # ~125 Hz
    high_bin = 135  # ~4200 Hz

    log_bins = np.logspace(np.log10(low_bin), np.log10(high_bin), n_bands + 1, dtype=int)
    log_bins = np.clip(log_bins, 0, len(magnitude) - 1)

    levels = []
    for i in range(n_bands):
        start = log_bins[i]
        end   = log_bins[i + 1]
        if start >= end:
            end = start + 1
        end = min(end, len(magnitude))

        band_mag = magnitude[start:end]
        if len(band_mag) == 0:
            levels.append(0.0)
            continue

        # RMS magnitude → dB
        rms = float(np.sqrt(np.mean(band_mag ** 2)))
        if rms > 0:
            db = 20 * np.log10(rms / (CHUNK_SIZE / 2))
        else:
            db = MIN_DB

        levels.append(db_to_norm(db))

    return levels


def main():
    # ── Resolve mic ──────────────────────────────────────────
    mic_device = sys.argv[1] if len(sys.argv) > 1 else None
    if not mic_device:
        mic_device = read_mic_device()

    print(f"[mic_level] Mic: {mic_device}", file=sys.stderr, flush=True)

    # ── Jalankan arecord via subprocess ─────────────────────
    env = os.environ.copy()
    env["PULSE_SOURCE"] = mic_device

    proc = subprocess.Popen(
        [
            "pw-record",
            "--format", "s16",
            "--rate", str(SAMPLE_RATE),
            "--channels", str(CHANNELS),
            "-"
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        env=env
    )

    print(f"[mic_level] Started. PID: {proc.pid}", file=sys.stderr, flush=True)

    # ── State untuk smoothing & VAD ───────────────────────────
    prev_levels = [0.0] * N_BARS
    bytes_per_sample = 2  # S16_LE = 2 bytes
    bytes_per_chunk  = CHUNK_SIZE * bytes_per_sample * CHANNELS
    frame_interval   = 1.0 / TARGET_FPS
    last_output_time = 0.0

    # ── Silero VAD AI Neural Model ──────────────────────────────
    silero_session = None
    silero_state   = None
    sr_tensor      = np.array(16000, dtype=np.int64)
    model_path     = os.path.expanduser("~/.config/hypr/scripts/quickshell/lumi2/backend/silero_vad.onnx")
    if os.path.exists(model_path):
        try:
            import onnxruntime as ort
            silero_session = ort.InferenceSession(model_path, providers=['CPUExecutionProvider'])
            silero_state   = np.zeros((2, 1, 128), dtype=np.float32)
            print("[mic_level] Silero VAD AI Neural Model: ACTIVE", file=sys.stderr, flush=True)
        except Exception as e:
            print(f"[mic_level] Silero VAD warning: {e}", file=sys.stderr, flush=True)

    # ── Local zero-cost VAD (Voice Activity Detection) ───────
    SPEECH_THRESHOLD     = read_speech_threshold()          # Calibrated from settings.json
    SILENCE_AFTER_SPEECH = read_silence_duration()  # Read dynamically from settings.json
    has_speech           = False
    last_speech_time     = 0.0
    vad_triggered        = False

    print(f"[mic_level] VAD active: pause trigger after {SILENCE_AFTER_SPEECH}s silence", file=sys.stderr, flush=True)

    try:
        while True:
            # Baca chunk dari arecord
            raw = proc.stdout.read(bytes_per_chunk)
            if not raw or len(raw) < bytes_per_chunk:
                break

            # Parse ke numpy array (int16 → float32 normalized)
            samples = np.frombuffer(raw, dtype=np.int16).astype(np.float32)
            samples /= 32768.0  # normalize ke -1.0 .. 1.0

            # ── Silero AI VAD Inference ─────────────────────────
            is_voice = False
            if silero_session is not None and len(samples) == CHUNK_SIZE:
                try:
                    inp_tensor = samples[np.newaxis, :]
                    out, silero_state = silero_session.run(None, {
                        'input': inp_tensor,
                        'sr': sr_tensor,
                        'state': silero_state
                    })
                    speech_prob = float(out[0][0])
                    is_voice = speech_prob >= 0.45
                except Exception:
                    is_voice = False
            else:
                is_voice = False

            # Throttle output ke TARGET_FPS
            now = time.monotonic()
            if now - last_output_time < frame_interval:
                # Update VAD state even on throttled visual frames
                if is_voice:
                    if not has_speech:
                        has_speech = True
                        vad_triggered = False
                        try:
                            os.remove("/tmp/lumi_stt_stop")
                        except Exception:
                            pass
                    last_speech_time = now
                elif has_speech and not vad_triggered:
                    if (now - last_speech_time) >= SILENCE_AFTER_SPEECH:
                        vad_triggered = True
                        try:
                            open("/tmp/lumi_stt_stop", "w").close()
                            print(f"[mic_level] Silero VAD: {SILENCE_AFTER_SPEECH}s silence detected -> created /tmp/lumi_stt_stop", file=sys.stderr, flush=True)
                        except Exception:
                            pass
                continue

            last_output_time = now

            # FFT → band levels
            levels = compute_bands(samples, N_BARS)

            # Smoothing (exponential moving average)
            smoothed = [
                SMOOTHING * prev + (1 - SMOOTHING) * curr
                for prev, curr in zip(prev_levels, levels)
            ]
            prev_levels = smoothed

            # Energy fallback if AI model wasn't available
            if silero_session is None:
                is_voice = max(smoothed) >= SPEECH_THRESHOLD

            # ── VAD State Update ─────────────────────────────────
            if is_voice:
                if not has_speech:
                    has_speech = True
                    vad_triggered = False
                    try:
                        os.remove("/tmp/lumi_stt_stop")
                    except Exception:
                        pass
                last_speech_time = now
            elif has_speech and not vad_triggered:
                if (now - last_speech_time) >= SILENCE_AFTER_SPEECH:
                    vad_triggered = True
                    try:
                        open("/tmp/lumi_stt_stop", "w").close()
                        print(f"[mic_level] VAD: {SILENCE_AFTER_SPEECH}s silence detected -> created /tmp/lumi_stt_stop", file=sys.stderr, flush=True)
                    except Exception:
                        pass

            # Output ke stdout: 7 float per baris
            line = " ".join(f"{v:.4f}" for v in smoothed)
            print(line, flush=True)

    except (KeyboardInterrupt, BrokenPipeError):
        pass
    finally:
        try:
            proc.terminate()
            proc.wait()
        except Exception:
            pass
        print("[mic_level] Stopped.", file=sys.stderr, flush=True)



if __name__ == "__main__":
    main()
