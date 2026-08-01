#!/usr/bin/env python3
"""
mic_level.py — Baca level amplitude mic secara real-time.
Output: 5 nilai float 0.0–1.0 per baris, dipisah spasi, tiap ~50ms.
Format: "0.23 0.45 0.67 0.34 0.12\n"

Usage: python3 mic_level.py
Stop:  Kirim SIGTERM atau tutup pipe.

Cara kerja:
- Baca audio mentah dari arecord (16-bit signed, mono, 16kHz)
- Bagi tiap frame menjadi 5 band frekuensi sederhana (sub-bass, bass,
  mid, upper-mid, presence) dengan FFT sederhana menggunakan numpy/array
- Output amplitudo per band yang sudah dinormalisasi
"""

import sys
import os
import signal
import struct
import math
import subprocess
import threading
import time

# ── Config ─────────────────────────────────────────────────────
SAMPLE_RATE   = 16000
CHUNK_SIZE    = 800       # ~50ms per frame (16000 * 0.05)
N_BARS        = 5
SMOOTHING     = 0.55      # 0 = no smoothing, 1 = full hold (rise fast, fall medium)
SMOOTHING_UP  = 0.3       # Smoothing saat naik (lebih responsif)
SMOOTHING_DN  = 0.65      # Smoothing saat turun (lebih smooth)
GAIN          = 30.0      # Amplifikasi sinyal (mic level biasanya rendah)
NOISE_GATE    = 0.003     # Level minimum sebelum dianggap silence
MIN_IDLE      = 0.08      # Level minimum bar saat diam (supaya tidak flat 0)
OUTPUT_FPS    = 25        # Target frames per second

# Band ranges (index dalam FFT output, dari 0 Hz - 8kHz range)
# Chunk 800 samples → FFT 400 bins, tiap bin = 20Hz
# Bar 0: 0-200Hz (sub-bass)
# Bar 1: 200-600Hz (bass)
# Bar 2: 600-1400Hz (mid)
# Bar 3: 1400-3000Hz (upper-mid)
# Bar 4: 3000-8000Hz (presence)
BAND_RANGES = [
    (0,   10),    # sub-bass: 0–200Hz
    (10,  30),    # bass: 200–600Hz
    (30,  70),    # mid: 600–1400Hz
    (70,  150),   # upper-mid: 1400–3000Hz
    (150, 400),   # presence: 3000–8000Hz
]

arecord_proc = None
running = True

def handle_signal(signum, frame):
    global running
    running = False
    if arecord_proc:
        arecord_proc.terminate()
    sys.exit(0)

signal.signal(signal.SIGTERM, handle_signal)
signal.signal(signal.SIGINT, handle_signal)


def simple_fft_magnitude(samples: list) -> list:
    """
    FFT sederhana tanpa numpy — cukup untuk 5 band visualisasi.
    Menggunakan Goertzel-like approach untuk kecepatan.
    Kembalikan list amplitudo per band.
    """
    n = len(samples)
    band_levels = []

    for lo, hi in BAND_RANGES:
        # Hitung RMS untuk rentang bin frekuensi ini
        # Simplified: DFT partial evaluation
        power = 0.0
        count = 0
        for k in range(lo, min(hi, n // 2)):
            real = 0.0
            imag = 0.0
            angle = 2.0 * math.pi * k / n
            for i, s in enumerate(samples):
                c = math.cos(angle * i)
                si = math.sin(angle * i)
                real += s * c
                imag -= s * si
            mag = math.sqrt(real * real + imag * imag) / n
            power += mag
            count += 1
        band_levels.append(power / count if count > 0 else 0.0)

    return band_levels


def fast_band_rms(samples: bytes) -> list:
    """
    Pendekatan cepat: bagi samples menjadi 5 segmen posisi,
    hitung RMS tiap segmen sebagai proxy band.
    
    Ini tidak akurat secara spektral tapi sangat cepat dan cukup
    untuk visualisasi waveform yang responsif.
    """
    # Parse bytes ke signed int16
    n_samples = len(samples) // 2
    if n_samples == 0:
        return [0.0] * N_BARS

    fmt = f"{n_samples}h"
    try:
        ints = struct.unpack(fmt, samples[:n_samples * 2])
    except struct.error:
        return [0.0] * N_BARS

    # Normalisasi ke -1.0 .. 1.0
    floats = [s / 32768.0 for s in ints]
    total = len(floats)

    # Overall RMS untuk scaling
    overall_rms = math.sqrt(sum(x * x for x in floats) / total) if total > 0 else 0.0
    overall_rms = min(overall_rms * GAIN, 1.0)

    # Bagi menjadi 5 segmen untuk variasi antar bar
    # Tambahkan variasi berdasarkan posisi sample (temporal bands)
    seg_size = total // N_BARS
    band_levels = []

    for i in range(N_BARS):
        start = i * seg_size
        end = start + seg_size if i < N_BARS - 1 else total
        seg = floats[start:end]
        if not seg:
            band_levels.append(0.0)
            continue
        rms = math.sqrt(sum(x * x for x in seg) / len(seg))
        # Tambahkan sedikit variasi per band untuk efek cava-like
        variation = 1.0 + 0.3 * math.sin(i * 1.2 + overall_rms * 5)
        level = min(rms * GAIN * variation, 1.0)
        band_levels.append(level)

    # Noise gate: jika overall sangat kecil, kembalikan ke minimum
    if overall_rms < NOISE_GATE:
        return [MIN_IDLE] * N_BARS

    # Smooth agar bar tengah lebih dominan (seperti cava)
    # Bar pattern: rendah, sedang, tinggi, sedang, rendah
    center_boost = [0.75, 0.88, 1.0, 0.88, 0.75]
    band_levels = [max(band_levels[i] * center_boost[i], MIN_IDLE) for i in range(N_BARS)]

    return band_levels


def get_effective_mic_device(configured_dev: str) -> str:
    if not configured_dev or configured_dev in ("default", "null"):
        try:
            res = subprocess.run(["pactl", "get-default-source"], capture_output=True, text=True).stdout.strip()
            if res and ".monitor" not in res and "snd_aloop" not in res:
                return res
        except Exception:
            pass
        try:
            sources = subprocess.run(["pactl", "list", "sources", "short"], capture_output=True, text=True).stdout
            for line in sources.splitlines():
                parts = line.split()
                if len(parts) >= 2:
                    name = parts[1]
                    if name.startswith("alsa_input.") and "snd_aloop" not in name:
                        return name
        except Exception:
            pass
        return "pulse"
    return configured_dev


def main():
    global arecord_proc, running

    # Baca device dari settings.json
    mic_device = "default"
    settings_path = os.path.expanduser("~/.config/hypr/settings.json")
    try:
        import json
        with open(settings_path, "r") as f:
            data = json.load(f)
            dev = data.get("lumi", {}).get("micDevice", "default")
            if dev and dev != "null":
                mic_device = dev
    except Exception:
        pass

    target_mic = get_effective_mic_device(mic_device)

    # Start arecord untuk baca mic
    try:
        env = os.environ.copy()
        if target_mic.startswith("hw:") or target_mic.startswith("sysdefault"):
            cmd = ["arecord", "-D", target_mic, "-f", "S16_LE", "-c", "1", "-r", str(SAMPLE_RATE), "-t", "raw", "--quiet"]
        else:
            cmd = ["arecord", "-D", "pulse", "-f", "S16_LE", "-c", "1", "-r", str(SAMPLE_RATE), "-t", "raw", "--quiet"]
            if target_mic != "pulse":
                env["PULSE_SOURCE"] = target_mic
                
        arecord_proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            env=env
        )
    except FileNotFoundError:
        print("ERROR: arecord tidak ditemukan", file=sys.stderr)
        sys.exit(1)

    # State smoothing
    smoothed = [0.0] * N_BARS
    frame_interval = 1.0 / OUTPUT_FPS

    while running:
        t_start = time.monotonic()

        # Baca satu chunk
        raw = arecord_proc.stdout.read(CHUNK_SIZE * 2)  # 2 bytes per sample (S16_LE)
        if not raw:
            break

        # Hitung level per band
        levels = fast_band_rms(raw)

        # Smooth: naik cepat, turun lebih lambat (seperti VU meter)
        for i in range(N_BARS):
            alpha = SMOOTHING_UP if levels[i] > smoothed[i] else SMOOTHING_DN
            smoothed[i] = smoothed[i] * alpha + levels[i] * (1.0 - alpha)

        # Output: 5 nilai dipisah spasi
        line = " ".join(f"{v:.4f}" for v in smoothed)
        try:
            sys.stdout.write(line + "\n")
            sys.stdout.flush()
        except BrokenPipeError:
            break

        # Rate limiting
        elapsed = time.monotonic() - t_start
        sleep_time = frame_interval - elapsed
        if sleep_time > 0:
            time.sleep(sleep_time)

    if arecord_proc:
        arecord_proc.terminate()


if __name__ == "__main__":
    main()
