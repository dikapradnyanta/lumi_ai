#!/usr/bin/env bash
# stt.sh — Speech to Text Backend (v2 - finetuned)
# Groq Whisper large-v3-turbo + language hint + prompt konteks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PID_FILE="/tmp/stewart_stt.pid"
AUDIO_FILE="/tmp/stewart_mic.wav"
SETTINGS="$HOME/.config/hypr/settings.json"

if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env"
fi

log_time() {
    echo "$(date +'%H:%M:%S.%3N') - [STT] $1" >> /tmp/lumi_timing_debug.log
}

ACTION="$1"

# ── Baca config ───────────────────────────────────────────────────────────────
STT_LANGUAGE=$(jq -r '.lumi.sttLanguage // "id"' "$SETTINGS" 2>/dev/null)
STT_PROMPT=$(jq -r '.lumi.sttPrompt // "Percakapan dengan asisten AI bernama Lumi tentang Linux, teknologi, dan kehidupan sehari-hari."' "$SETTINGS" 2>/dev/null)
MIC_DEVICE=$(jq -r '.lumi.micDevice // "default"' "$SETTINGS" 2>/dev/null)

get_effective_mic_device() {
    local dev="$MIC_DEVICE"
    if [ "$dev" = "null" ] || [ "$dev" = "default" ] || [ -z "$dev" ]; then
        local def_src=$(pactl get-default-source 2>/dev/null || echo "")
        if [[ "$def_src" == *".monitor"* ]] || [[ "$def_src" == *"snd_aloop"* ]] || [ -z "$def_src" ]; then
            def_src=$(pactl list sources short 2>/dev/null | awk '{print $2}' | grep "^alsa_input" | grep -v "snd_aloop" | head -n 1)
        fi
        dev="${def_src:-pulse}"
    fi
    echo "$dev"
}

if [[ "$ACTION" == "start" ]]; then
    # Hentikan silence monitor sebelumnya
    if [ -f "/tmp/stewart_silence.pid" ]; then
        kill -9 $(cat "/tmp/stewart_silence.pid") 2>/dev/null || true
        rm -f "/tmp/stewart_silence.pid"
    fi

    TARGET_MIC=$(get_effective_mic_device)
    log_time "Recording starting on device: $TARGET_MIC"

    # Rekam audio: 16kHz mono 16-bit (optimal untuk Whisper)
    if [[ "$TARGET_MIC" == hw:* ]] || [[ "$TARGET_MIC" == sysdefault* ]]; then
        arecord -D "$TARGET_MIC" -f S16_LE -c 1 -r 16000 -t wav "$AUDIO_FILE" >/dev/null 2>&1 &
    else
        PULSE_SOURCE="$TARGET_MIC" arecord -D pulse -f S16_LE -c 1 -r 16000 -t wav "$AUDIO_FILE" >/dev/null 2>&1 &
    fi
    echo $! > "$PID_FILE"

    # Jalankan silence monitor di background
    bash "$SCRIPT_DIR/silence_monitor.sh" &
    echo $! > "/tmp/stewart_silence.pid"

    log_time "Recording started"
    echo "Recording started"

elif [[ "$ACTION" == "abort" ]]; then
    # Hentikan silence monitor
    if [ -f "/tmp/stewart_silence.pid" ]; then
        kill -9 $(cat "/tmp/stewart_silence.pid") 2>/dev/null || true
        rm -f "/tmp/stewart_silence.pid"
    fi

    # Hentikan rekaman tapi langsung keluar (tidak dikirim ke API)
    if [ -f "$PID_FILE" ]; then
        kill -2 $(cat "$PID_FILE") 2>/dev/null || true
        sleep 0.3
        rm -f "$PID_FILE"
    fi
    
    log_time "Recording aborted by user"
    echo "Aborted"
    exit 0

elif [[ "$ACTION" == "stop" ]]; then
    # Hentikan silence monitor
    if [ -f "/tmp/stewart_silence.pid" ]; then
        kill -9 $(cat "/tmp/stewart_silence.pid") 2>/dev/null || true
        rm -f "/tmp/stewart_silence.pid"
    fi

    # Hentikan rekaman
    if [ -f "$PID_FILE" ]; then
        kill -2 $(cat "$PID_FILE") 2>/dev/null || true
        sleep 0.3
        rm -f "$PID_FILE"
    fi

    if [ ! -f "$AUDIO_FILE" ] || [ $(stat -c %s "$AUDIO_FILE" 2>/dev/null || echo 0) -lt 4096 ]; then
        log_time "Recording too short/empty, exiting"
        echo ""
        exit 0
    fi

    log_time "Recording stopped, starting noise reduction"

    # ── Noise Reduction ────────────────────────────────────────────────────────
    # highpass: hapus frekuensi rendah (AC hum, kipas)
    # afftdn: noise reduction berbasis FFT
    # loudnorm: auto audio gain, memastikan suara pelan tetap terdengar jelas
    # agate: noise gate, hapus sinyal di bawah threshold
    CLEANED_AUDIO="/tmp/stewart_mic_clean.wav"
    ffmpeg -y -i "$AUDIO_FILE" \
        -af "highpass=f=200,lowpass=f=3000,afftdn=nf=-25" \
        "$CLEANED_AUDIO" >/dev/null 2>&1
    
    log_time "Noise reduction finished, preparing API call"

    if [ ! -f "$CLEANED_AUDIO" ] || [ $(stat -c %s "$CLEANED_AUDIO") -lt 44 ]; then
        CLEANED_AUDIO="$AUDIO_FILE"
    fi

    API_KEYS="${GEMINI_API_KEY:-${GROQ_API_KEY:-}}"
    if [ -z "$API_KEYS" ]; then
        API_KEYS=$(jq -r '.lumi.apiKey // .lumi.geminiApiKey // empty' "$SETTINGS" 2>/dev/null)
    fi

    IFS=',' read -ra KEYS <<< "$API_KEYS"
    if [ ${#KEYS[@]} -eq 0 ]; then
        echo ""
        exit 1
    fi

    SUCCESS=false
    for CURRENT_KEY in "${KEYS[@]}"; do
        CURRENT_KEY=$(echo "$CURRENT_KEY" | xargs)
        if [ -z "$CURRENT_KEY" ]; then continue; fi

        if [[ "$CURRENT_KEY" == AIzaSy* ]]; then
            log_time "Sending request to Gemini 2.5 Flash Audio API"
            AUDIO_B64=$(base64 -w 0 "$CLEANED_AUDIO")
            RESPONSE=$(curl -s --max-time 25 \
              -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$CURRENT_KEY" \
              -H "Content-Type: application/json" \
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
                continue
            fi
            TEXT=$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text // empty' | tr -d '\n' | xargs)
        else
            # ── Panggil Groq Whisper dengan language hint + prompt konteks ──────────
            log_time "Sending request to Groq Whisper API"
            RESPONSE=$(curl -s --request POST \
              --url https://api.groq.com/openai/v1/audio/transcriptions \
              --header "Authorization: Bearer $CURRENT_KEY" \
              --header "Content-Type: multipart/form-data" \
              --form file="@$CLEANED_AUDIO" \
              --form model="whisper-large-v3-turbo" \
              --form language="$STT_LANGUAGE" \
              --form prompt="$STT_PROMPT" \
              --form response_format="json")
            log_time "Received response from Groq Whisper API"

            ERR=$(echo "$RESPONSE" | jq -r '.error.message // empty')
            if [ -n "$ERR" ]; then
                continue
            fi
            TEXT=$(echo "$RESPONSE" | jq -r '.text // empty' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
        fi

        # Filter halusinasi umum Whisper (muncul saat rekaman terlalu hening)
        if [ -n "$TEXT" ] && [ "$TEXT" != "null" ] && [ ${#TEXT} -gt 2 ]; then
            if [[ "$TEXT" =~ ^[[:space:]]*([Tt]hank[s]?[[:space:]]for[[:space:]]watching[.!]?|[Ss]ubscribe[.!]?|[Mm]usic[[:space:]]playing|[Tt]erima[[:space:]]kasih[.!]?|[Tt]erima[[:space:]]kasih[[:space:]](sudah|telah)[[:space:]]menonton[.!]?)[[:space:]]*$ ]]; then
                echo ""
            else
                SUCCESS=true
                break
            fi
        fi
    done

    if [ "$SUCCESS" = true ]; then
        log_time "STT Success, sending IPC to quickshell"
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
