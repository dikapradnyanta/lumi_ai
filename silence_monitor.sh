#!/bin/bash
# silence_monitor.sh — v2 with adaptive ambient noise calibration

AUDIO_FILE="${1:-/tmp/stewart_mic.wav}"
SETTINGS="$HOME/.config/hypr/settings.json"
MONITOR_PID_FILE="/tmp/stewart_silence.pid"

# ── Konfigurasi (bisa di-override dari settings.json) ─────────────────────────
SILENCE_THRESHOLD=$(jq -r '.lumi.silenceThreshold // "-38dB"' "$SETTINGS" 2>/dev/null || echo "-38dB")
SILENCE_DURATION=$(jq -r '.lumi.silenceDuration // 1.2' "$SETTINGS" 2>/dev/null || echo "1.2")
MAX_RECORD_TIME=$(jq -r '.lumi.maxRecordTime // 45' "$SETTINGS" 2>/dev/null || echo "45")

echo $$ > "$MONITOR_PID_FILE"

# ── Tunggu file audio muncul ──────────────────────────────────────────────────
WAIT=0
while [ ! -f "$AUDIO_FILE" ] || [ $(stat -c %s "$AUDIO_FILE" 2>/dev/null || echo 0) -lt 44 ]; do
    sleep 0.1
    WAIT=$((WAIT + 1))
    if [ $WAIT -gt 40 ]; then
        echo "[silence_monitor] Timeout menunggu file audio" >&2
        exit 1
    fi
done

# ── Adaptive calibration: ukur noise lantai selama 0.5 detik pertama ─────────
# Jika ambient noise tinggi (ruangan bising), naikan threshold secara otomatis
sleep 0.4 # Tunggu sebentar agar file wav terisi cukup data
AMBIENT_LEVEL=$(ffmpeg -loglevel error \
    -t 0.5 -i "$AUDIO_FILE" \
    -af "volumedetect" -f null - 2>&1 | \
    grep mean_volume | grep -oP '[-]?\d+\.?\d+' | head -1)

if [ -n "$AMBIENT_LEVEL" ] && [ "$AMBIENT_LEVEL" != "" ]; then
    AMBIENT_INT=$(echo "$AMBIENT_LEVEL" | cut -d'.' -f1)
    if [ "$AMBIENT_INT" -gt -50 ] 2>/dev/null; then
        NEW_THRESHOLD=$((AMBIENT_INT + 12))
        if [ $NEW_THRESHOLD -lt -45 ]; then NEW_THRESHOLD=-45; fi
        if [ $NEW_THRESHOLD -gt -25 ]; then NEW_THRESHOLD=-25; fi
        SILENCE_THRESHOLD="${NEW_THRESHOLD}dB"
        echo "[silence_monitor] Ambient: ${AMBIENT_LEVEL}dB → adaptive threshold: $SILENCE_THRESHOLD" >&2
    fi
fi

# ── Safety net: paksa stop setelah MAX_RECORD_TIME ───────────────────────────
(
    sleep "$MAX_RECORD_TIME"
    if [ -f "$MONITOR_PID_FILE" ] && [ "$(cat $MONITOR_PID_FILE)" = "$$" ]; then
        echo "[silence_monitor] Max record time (${MAX_RECORD_TIME}s) tercapai, stop..." >&2
        bash "$(dirname "$0")/stt.sh" stop
    fi
) &
SAFETY_PID=$!

echo "[silence_monitor] Threshold: $SILENCE_THRESHOLD, Max silence: ${SILENCE_DURATION}s" >&2

SPEECH_STARTED=false
START_TIME=$(date +%s)

# ── Monitor loop dengan silencedetect ────────────────────────────────────────
# Gunakan tail -f agar ffmpeg tidak langsung exit saat mencapai EOF sementara dari arecord
tail -c +0 -f "$AUDIO_FILE" 2>/dev/null | ffmpeg -loglevel info \
    -i pipe:0 \
    -af "highpass=f=200,lowpass=f=3000,silencedetect=noise=${SILENCE_THRESHOLD}:d=${SILENCE_DURATION}" \
    -f null - 2>&1 | \
while IFS= read -r line; do
    if echo "$line" | grep -q "silence_end"; then
        echo "[silence_monitor] Suara aktif (speech detected)" >&2
        SPEECH_STARTED=true
    elif echo "$line" | grep -q "silence_start"; then
        SILENCE_TS=$(echo "$line" | grep -oP '(?<=silence_start: )[\d.]+')
        echo "[silence_monitor] Hening sejak ${SILENCE_TS}s" >&2
    elif echo "$line" | grep -q "silence_duration"; then
        DUR=$(echo "$line" | grep -oP '(?<=silence_duration: )[\d.]+')
        NOW=$(date +%s)
        ELAPSED=$((NOW - START_TIME))
        if [ "$SPEECH_STARTED" = "true" ]; then
            echo "[silence_monitor] Suara selesai, hening ${DUR}s → stop rekaman" >&2
            kill $SAFETY_PID 2>/dev/null || true
            bash "$(dirname "$0")/stt.sh" stop
            exit 0
        elif [ "$ELAPSED" -ge 6 ]; then
            echo "[silence_monitor] Tidak ada suara terdeteksi setelah ${ELAPSED}s → stop..." >&2
            kill $SAFETY_PID 2>/dev/null || true
            bash "$(dirname "$0")/stt.sh" stop
            exit 0
        else
            echo "[silence_monitor] Initial silence ${DUR}s diabaikan (${ELAPSED}s < 6s), menunggu pengguna bicara..." >&2
        fi
    fi
done

kill $SAFETY_PID 2>/dev/null || true
