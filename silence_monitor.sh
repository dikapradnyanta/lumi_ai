#!/bin/bash
# silence_monitor.sh — tuned version
# Deteksi silence yang lebih robust dengan adaptive threshold

AUDIO_FILE="${1:-/tmp/stewart_mic.wav}"
STT_PID_FILE="/tmp/stewart_stt.pid"
MONITOR_PID_FILE="/tmp/stewart_silence.pid"

# ── Konfigurasi (tunable) ──────────────────────────────────────
SILENCE_THRESHOLD="-38dB"   # -35 terlalu sensitif, -40 terlalu longgar
                             # Rekomendasi: -38 untuk ruangan normal
SILENCE_DURATION="2.2"      # Detik: 2.0 terlalu cepat, 2.5 terlalu lambat
POLL_INTERVAL="0.3"         # Cek setiap 0.3 detik
MAX_RECORD_TIME="30"        # Maksimum 30 detik rekaman (safety net)

# ── Simpan PID monitor ini ────────────────────────────────────
echo $$ > "$MONITOR_PID_FILE"

# ── Tunggu file audio muncul ──────────────────────────────────
WAIT=0
while [ ! -f "$AUDIO_FILE" ] || [ $(stat -c %s "$AUDIO_FILE") -lt 44 ]; do
    sleep 0.1
    WAIT=$((WAIT + 1))
    if [ $WAIT -gt 30 ]; then
        echo "[silence_monitor] Timeout menunggu file audio" >&2
        exit 1
    fi
done

# ── Safety net: paksa stop setelah MAX_RECORD_TIME ───────────
(
    sleep "$MAX_RECORD_TIME"
    if [ -f "$MONITOR_PID_FILE" ]; then
        echo "[silence_monitor] Max record time reached, stopping..." >&2
        bash "$(dirname "$0")/stt.sh" stop
    fi
) &
SAFETY_PID=$!

# ── Monitor loop ──────────────────────────────────────────────
echo "[silence_monitor] Monitoring dimulai (threshold: $SILENCE_THRESHOLD, duration: ${SILENCE_DURATION}s)"

# Gunakan ffmpeg untuk deteksi silence secara real-time
# -t baca maksimum, -af silencedetect output ke stderr
ffmpeg -loglevel info \
    -i "$AUDIO_FILE" \
    -af "silencedetect=noise=${SILENCE_THRESHOLD}:d=${SILENCE_DURATION}" \
    -f null - 2>&1 | \
while IFS= read -r line; do
    if echo "$line" | grep -q "silence_end"; then
        # Silence end berarti suara terdeteksi lagi, reset
        echo "[silence_monitor] Suara terdeteksi, reset timer"
    elif echo "$line" | grep -q "silence_start"; then
        SILENCE_TS=$(echo "$line" | grep -oP '(?<=silence_start: )\d+\.\d+')
        echo "[silence_monitor] Silence dimulai pada ${SILENCE_TS}s"
    elif echo "$line" | grep -q "silence_duration"; then
        DUR=$(echo "$line" | grep -oP '(?<=silence_duration: )\d+\.\d+')
        echo "[silence_monitor] Silence ${DUR}s terdeteksi, menghentikan rekaman..."
        kill $SAFETY_PID 2>/dev/null
        bash "$(dirname "$0")/stt.sh" stop
        exit 0
    fi
done

# Cleanup
kill $SAFETY_PID 2>/dev/null
