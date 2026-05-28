#!/usr/bin/env bash

# Stewart AI - Speech to Text Backend
# Uses arecord for recording and Groq's whisper-large-v3-turbo for transcription

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="/tmp/stewart_stt.pid"
AUDIO_FILE="/tmp/stewart_mic.wav"

if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env"
fi

ACTION="$1"

if [[ "$ACTION" == "start" ]]; then
    # Stop existing silence monitor
    if [ -f "/tmp/stewart_silence.pid" ]; then
        kill -9 $(cat "/tmp/stewart_silence.pid") 2>/dev/null
        rm -f "/tmp/stewart_silence.pid"
    fi

    # Record audio at 16kHz, mono, 16-bit (ideal for Whisper)
    arecord -f S16_LE -c 1 -r 16000 -t wav "$AUDIO_FILE" >/dev/null 2>&1 &
    echo $! > "$PID_FILE"
    
    # Start silence monitor in background
    bash "$SCRIPT_DIR/silence_monitor.sh" &
    echo $! > "/tmp/stewart_silence.pid"
    
    echo "Recording started"

elif [[ "$ACTION" == "stop" ]]; then
    if [ -f "/tmp/stewart_silence.pid" ]; then
        kill -9 $(cat "/tmp/stewart_silence.pid") 2>/dev/null
        rm -f "/tmp/stewart_silence.pid"
    fi

    if [ -f "$PID_FILE" ]; then
        kill -2 $(cat "$PID_FILE") 2>/dev/null
        rm -f "$PID_FILE"
    fi
    
    if [ ! -f "$AUDIO_FILE" ]; then
        echo "Error: Audio file not found."
        exit 1
    fi

    # Noise Reduction: Apply highpass filter and afftdn (noise reduction) ~50%
    CLEANED_AUDIO="/tmp/stewart_mic_clean.wav"
    ffmpeg -y -i "$AUDIO_FILE" -af "highpass=f=200,afftdn=nf=-25" "$CLEANED_AUDIO" >/dev/null 2>&1

    if [ ! -f "$CLEANED_AUDIO" ]; then
        CLEANED_AUDIO="$AUDIO_FILE" # Fallback if ffmpeg fails
    fi
    
    if [ -z "$GROQ_API_KEY" ]; then
        GROQ_API_KEY=$(jq -r '.lumi.apiKey // empty' ~/.config/hypr/settings.json 2>/dev/null)
    fi

    IFS=',' read -ra KEYS <<< "$GROQ_API_KEY"
    if [ ${#KEYS[@]} -eq 0 ]; then
        echo "Error: GROQ_API_KEY is not set."
        exit 1
    fi

    SUCCESS=false
    for CURRENT_KEY in "${KEYS[@]}"; do
        CURRENT_KEY=$(echo "$CURRENT_KEY" | xargs)
        if [ -z "$CURRENT_KEY" ]; then continue; fi

        # Transcribe using Groq Whisper API
        RESPONSE=$(curl -s --request POST \
          --url https://api.groq.com/openai/v1/audio/transcriptions \
          --header "Authorization: Bearer $CURRENT_KEY" \
          --header "Content-Type: multipart/form-data" \
          --form file="@$CLEANED_AUDIO" \
          --form model="whisper-large-v3-turbo")
          
        ERR=$(echo "$RESPONSE" | jq -r '.error.message // empty')
        if [ -n "$ERR" ]; then
            continue
        fi

        TEXT=$(echo "$RESPONSE" | jq -r '.text // empty')
        if [ -n "$TEXT" ] && [ "$TEXT" != "null" ]; then
            SUCCESS=true
            break
        fi
    done

    if [ "$SUCCESS" = true ]; then
        echo "$TEXT"
    else
        echo ""
    fi
else
    echo "Usage: $0 [start|stop]"
fi
