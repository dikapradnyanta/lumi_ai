#!/usr/bin/env bash
# ============================================================
# Lumi v2 — backend/silence_monitor.sh
# Voice Activity Detection (VAD) berbasis ffmpeg silencedetect.
# Monitor audio stream dari mic secara real-time.
# Saat user diam selama SILENCE_THRESHOLD detik SETELAH berbicara,
# set flag /tmp/lumi_stt_stop untuk memicu stt.sh stop.
#
# Usage:
#   silence_monitor.sh [mic_device] &
#   — jalankan sebagai background process bersamaan dengan stt.sh start
#
# Stop: kill process ini, atau tunggu hingga flag di-set
# ============================================================

set -euo pipefail

readonly SETTINGS_FILE="$HOME/.config/hypr/settings.json"
readonly STOP_FLAG="/tmp/lumi_stt_stop"
readonly PID_FILE="/tmp/lumi_silence_monitor.pid"

# ── Konfigurasi VAD ──────────────────────────────────────
# Threshold hening setelah bicara (detik, default 1.0s)
SILENCE_AFTER_SPEECH="$(jq -r '.lumi.silenceDuration // 1.0' "$SETTINGS_FILE" 2>/dev/null || echo "1.0")"
# Minimum durasi speech sebelum hitung silence (cegah false trigger)
MIN_SPEECH_DURATION=0.3
# Noise floor threshold (dB) dari hasil kalibrasi
SILENCE_DB="$(jq -r '.lumi.silenceThreshold // "-35dB"' "$SETTINGS_FILE" 2>/dev/null || echo "-35dB")"
if [[ "$SILENCE_DB" != *"dB" ]]; then
    SILENCE_DB="${SILENCE_DB}dB"
fi

log_info()  { echo "[silence_monitor] INFO: $*"  >&2; }
log_error() { echo "[silence_monitor] ERROR: $*" >&2; }

# ── Simpan PID sendiri ───────────────────────────────────
echo "$$" > "$PID_FILE"
log_info "Silence monitor started. PID: $$"
log_info "Silence threshold: ${SILENCE_AFTER_SPEECH}s setelah speech"

# ── Resolve mic device ───────────────────────────────────
MIC_DEVICE="${1:-}"
if [[ -z "$MIC_DEVICE" ]]; then
    MIC_DEVICE="$(jq -r '.lumi.micDevice // "default"' "$SETTINGS_FILE" 2>/dev/null || echo "default")"
    if [[ "$MIC_DEVICE" == "default" ]]; then
        MIC_DEVICE="$(timeout 1 pactl get-default-source 2>/dev/null || echo "default")"
    fi
fi
log_info "Monitor mic: $MIC_DEVICE"

# ── State machine ────────────────────────────────────────
HAS_SPEECH=false         # sudah pernah mendeteksi suara?
SPEECH_START_TIME=""
SILENCE_START_TIME=""

# ── Cleanup on exit ──────────────────────────────────────
trap 'rm -f "$PID_FILE"; log_info "Silence monitor stopped."' EXIT

# ============================================================
# MONITOR LOOP
# Gunakan ffmpeg untuk mendeteksi silence secara real-time
# Output format: "silence_start: X.X" dan "silence_end: X.X | duration: X.X"
# ============================================================
PULSE_SOURCE="$MIC_DEVICE" ffmpeg \
    -hide_banner \
    -loglevel info \
    -f pulse \
    -i "$MIC_DEVICE" \
    -af "silencedetect=noise=${SILENCE_DB}:duration=${SILENCE_AFTER_SPEECH}" \
    -f null - \
    2>&1 | while IFS= read -r line; do

    # Hanya proses baris silencedetect
    [[ "$line" != *"silencedetect"* ]] && continue

    if [[ "$line" == *"silence_start"* ]]; then
        # Hening terdeteksi
        SILENCE_START_TIME="$(echo "$line" | grep -oP 'silence_start: \K[\d.]+')"
        log_info "Hening mulai: ${SILENCE_START_TIME}s"

        # Jika sudah ada speech sebelumnya, set flag stop
        if [[ "$HAS_SPEECH" == "true" ]]; then
            log_info "Speech + Hening ${SILENCE_AFTER_SPEECH}s → trigger stop"
            touch "$STOP_FLAG"
            exit 0
        fi

    elif [[ "$line" == *"silence_end"* ]]; then
        # Suara terdeteksi setelah hening
        SPEECH_START_TIME="$(echo "$line" | grep -oP 'silence_end: \K[\d.]+')"
        HAS_SPEECH=true
        log_info "Speech terdeteksi pada: ${SPEECH_START_TIME}s"
    fi

done

# Cleanup PID file jika loop selesai secara natural
rm -f "$PID_FILE"
