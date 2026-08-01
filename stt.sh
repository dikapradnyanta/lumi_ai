#!/bin/bash
# stt.sh — Google Gemini Native Multimodal Speech-to-Text for Lumi AI

set -euo pipefail

log_time() {
    echo "$(date +'%H:%M:%S.%3N') - [GEMINI STT] $1" >> /tmp/lumi_timing_debug.log
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
SETTINGS="$HOME/.config/hypr/settings.json"
AUDIO_FILE="/tmp/lumi_speech.wav"
CLEANED_AUDIO="/tmp/lumi_speech_clean.wav"
PID_FILE="/tmp/lumi_stt.pid"

if [[ -f "$ENV_FILE" ]]; then
    set -a; source "$ENV_FILE"; set +a
fi

ACTION="${1:-}"

if [ "$ACTION" = "start" ]; then
    log_time "Start recording requested"
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID" 2>/dev/null || true
        fi
        rm -f "$PID_FILE"
    fi

    rm -f "$AUDIO_FILE" "$CLEANED_AUDIO"

    MIC_DEVICE=$(jq -r '.lumi.micDevice // empty' "$SETTINGS" 2>/dev/null)
    if [ -z "$MIC_DEVICE" ] || [ "$MIC_DEVICE" = "null" ] || [ "$MIC_DEVICE" = "default" ]; then
        MIC_DEVICE=""
    fi

    log_time "Starting arecord"
    if [ -n "$MIC_DEVICE" ]; then
        PULSE_SOURCE="$MIC_DEVICE" arecord -D pulse -f S16_LE -r 16000 -c 1 "$AUDIO_FILE" >/dev/null 2>&1 &
    else
        arecord -f S16_LE -r 16000 -c 1 "$AUDIO_FILE" >/dev/null 2>&1 &
    fi

    echo $! > "$PID_FILE"
    log_time "arecord started with PID $(cat "$PID_FILE")"

elif [ "$ACTION" = "stop" ]; then
    log_time "Stop recording requested"
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID" 2>/dev/null || true
            log_time "Killed arecord PID $PID"
        fi
        rm -f "$PID_FILE"
    fi

    sleep 0.2

    if [ ! -f "$AUDIO_FILE" ] || [ $(stat -c %s "$AUDIO_FILE") -lt 1000 ]; then
        log_time "Audio file too small or missing"
        quickshell -p "$HOME/.config/hypr/scripts/quickshell/Main.qml" ipc call lumi sttComplete "" 2>/dev/null || true
        exit 0
    fi

    log_time "Starting noise reduction & audio normalization with ffmpeg"
    ffmpeg -y -i "$AUDIO_FILE" \
        -af "highpass=f=60, lowpass=f=8000, dynaudnorm=g=11:f=150:m=10.0" \
        -ar 16000 -ac 1 \
        "$CLEANED_AUDIO" >/dev/null 2>&1 || true

    if [ ! -f "$CLEANED_AUDIO" ] || [ $(stat -c %s "$CLEANED_AUDIO") -lt 44 ]; then
        CLEANED_AUDIO="$AUDIO_FILE"
    fi

    API_KEYS="${GEMINI_API_KEY:-}"
    if [ -z "$API_KEYS" ]; then
        API_KEYS=$(jq -r '.lumi.apiKey // .lumi.geminiApiKey // empty' "$SETTINGS" 2>/dev/null)
    fi

    IFS=',' read -ra KEYS <<< "$API_KEYS"
    if [ ${#KEYS[@]} -eq 0 ]; then
        echo "ERROR: Gemini API key tidak ditemukan" >&2
        quickshell -p "$HOME/.config/hypr/scripts/quickshell/Main.qml" ipc call lumi sttComplete "" 2>/dev/null || true
        exit 1
    fi

    SUCCESS=false
    TEXT=""
    for CURRENT_KEY in "${KEYS[@]}"; do
        CURRENT_KEY=$(echo "$CURRENT_KEY" | xargs)
        if [ -z "$CURRENT_KEY" ]; then continue; fi

        log_time "Sending request to Google Gemini Audio API"
        AUDIO_B64=$(base64 -w 0 "$CLEANED_AUDIO")
        RESPONSE=$(curl -s --max-time 25 \
          -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent" \
          -H "Content-Type: application/json" \
          -H "X-goog-api-key: $CURRENT_KEY" \
          -d '{
            "contents": [{
              "parts": [
                {"text": "Transkripsikan audio percakapan berikut ke dalam teks secara presisi. HANYA kembalikan teks hasil transkripsi tanpa komentar atau penjelasan tambahan."},
                {"inline_data": {"mime_type": "audio/wav", "data": "'"$AUDIO_B64"'"}}
              ]
            }]
          }')
        log_time "Received response from Gemini Audio API"

        ERR=$(echo "$RESPONSE" | jq -r '.error.message // empty')
        if [ -n "$ERR" ]; then
            echo "ERROR Gemini STT: $ERR" >&2
            continue
        fi

        RAW_TEXT=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text // empty' | tr -d '\n' | xargs)

        if [ -n "$RAW_TEXT" ] && [ "$RAW_TEXT" != "null" ]; then
            TEXT="$RAW_TEXT"
            SUCCESS=true
            break
        fi
    done

    if [ "$SUCCESS" = true ]; then
        log_time "STT Success ($TEXT), sending IPC to quickshell"
        echo "$TEXT"
        quickshell -p "$HOME/.config/hypr/scripts/quickshell/Main.qml" ipc call lumi sttComplete "$TEXT" 2>/dev/null || true
    else
        log_time "STT Failed or empty"
        echo ""
        quickshell -p "$HOME/.config/hypr/scripts/quickshell/Main.qml" ipc call lumi sttComplete "" 2>/dev/null || true
    fi
else
    echo "Usage: $0 [start|stop]"
fi
