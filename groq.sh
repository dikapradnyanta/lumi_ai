#!/bin/bash
# groq.sh — streaming + hardened version

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
SETTINGS="$HOME/.config/hypr/settings.json"
REQ_FILE="${1:-/tmp/lumi_req.json}"
AUTO_SPEAK="${2:-false}"

if [[ -f "$ENV_FILE" ]]; then
    set -a; source "$ENV_FILE"; set +a
fi

KEY="${GROQ_API_KEY:-}"
if [ -z "$KEY" ]; then
    KEY=$(jq -r '.lumi.apiKey // empty' "$SETTINGS" 2>/dev/null)
fi

if [ -z "$KEY" ]; then
    quickshell ipc call lumi groqError "API key tidak ditemukan di settings.json"
    exit 1
fi

IFS=',' read -ra KEYS <<< "$KEY"

# Validasi file request
if [ ! -f "$REQ_FILE" ] || ! jq empty "$REQ_FILE" 2>/dev/null; then
    quickshell ipc call lumi groqError "File request invalid"
    exit 1
fi

# Dapatkan model (jika kosong fallback ke llama-3)
MODEL=$(jq -r '.lumi.model // "llama-3.1-8b-instant"' "$SETTINGS" 2>/dev/null)

# Build payload (bungkus array dari REQ_FILE ke field messages)
PAYLOAD=$(jq --arg model "$MODEL" '{messages: ., stream: true, model: $model, max_tokens: 1024}' "$REQ_FILE")

SUCCESS=false
for CURRENT_KEY in "${KEYS[@]}"; do
    CURRENT_KEY=$(echo "$CURRENT_KEY" | xargs)
    [ -z "$CURRENT_KEY" ] && continue

    if [ "$AUTO_SPEAK" = "true" ]; then
        # Beri tahu UI bahwa streaming dimulai
        quickshell ipc call lumi streamStart
        
        FULL_TEXT=$(curl -s --no-buffer \
            -X POST "https://api.groq.com/openai/v1/chat/completions" \
            -H "Authorization: Bearer $CURRENT_KEY" \
            -H "Content-Type: application/json" \
            -H "Accept: text/event-stream" \
            --max-time 30 \
            -d "$PAYLOAD" \
        | python3 "$SCRIPT_DIR/stream_tts.py" 2>/tmp/lumi_tts_err.log)

        EXIT_CODE=$?
        if [ $EXIT_CODE -ne 0 ]; then
            cat /tmp/lumi_tts_err.log >&2
            continue
        fi

        if [ -n "$FULL_TEXT" ]; then
            quickshell ipc call lumi groqComplete "$FULL_TEXT"
            quickshell ipc call lumi ttsComplete
            SUCCESS=true
            break
        fi
    else
        # Non-streaming fallback
        HTTP_RESPONSE=$(curl -s -w "\n__HTTP_STATUS__%{http_code}" \
            --max-time 25 \
            --retry 1 \
            --retry-delay 1 \
            -X POST "https://api.groq.com/openai/v1/chat/completions" \
            -H "Authorization: Bearer $CURRENT_KEY" \
            -H "Content-Type: application/json" \
            -d "$(echo "$PAYLOAD" | jq 'del(.stream)')" 2>/tmp/lumi_curl_err.log)

        HTTP_STATUS=$(echo "$HTTP_RESPONSE" | grep "__HTTP_STATUS__" | sed 's/__HTTP_STATUS__//')
        BODY=$(echo "$HTTP_RESPONSE" | grep -v "__HTTP_STATUS__")

        if [ "$HTTP_STATUS" = "200" ]; then
            CONTENT=$(echo "$BODY" | jq -r '.choices[0].message.content // empty')
            if [ -n "$CONTENT" ]; then
                quickshell ipc call lumi groqComplete "$CONTENT"
                SUCCESS=true
                break
            fi
        fi
    fi
done

if [ "$SUCCESS" = "false" ]; then
    quickshell ipc call lumi groqError "Semua API key gagal atau rate limited"
    exit 1
fi
