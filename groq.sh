#!/bin/bash
# groq.sh — streaming + hardened version (v2 - finetuned)

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

# ── Baca konfigurasi dari settings.json ───────────────────────────────────────
MODEL=$(jq -r '.lumi.model // "llama-3.3-70b-versatile"' "$SETTINGS" 2>/dev/null)
TEMPERATURE=$(jq -r '.lumi.temperature // 0.7' "$SETTINGS" 2>/dev/null)
TOP_P=$(jq -r '.lumi.topP // 0.9' "$SETTINGS" 2>/dev/null)
MAX_TOKENS=$(jq -r '.lumi.maxTokens // 1024' "$SETTINGS" 2>/dev/null)

# ── Build payload dengan parameter finetuning ──────────────────────────────────
PAYLOAD=$(jq \
    --arg model "$MODEL" \
    --argjson temperature "$TEMPERATURE" \ 
    --argjson top_p "$TOP_P" \
    --argjson max_tokens "$MAX_TOKENS" \
    '{
        messages: .,
        stream: true,
        model: $model,
        max_tokens: $max_tokens,
        temperature: $temperature,
        top_p: $top_p,
        stop: null
    }' "$REQ_FILE")

SUCCESS=false
for CURRENT_KEY in "${KEYS[@]}"; do
    CURRENT_KEY=$(echo "$CURRENT_KEY" | xargs)
    [ -z "$CURRENT_KEY" ] && continue

    if [ "$AUTO_SPEAK" = "true" ]; then
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

        # Tangkap error API (rate limit, token limit, dll)
        if [ "$HTTP_STATUS" = "429" ]; then
            quickshell ipc call lumi groqError "Rate limit, coba lagi sebentar..."
            continue
        fi

        if [ "$HTTP_STATUS" = "200" ]; then
            CONTENT=$(echo "$BODY" | jq -r '.choices[0].message.content // empty')
            if [ -n "$CONTENT" ]; then
                # Deteksi JSON Mode (Persiapan Dasar Tool Calling)
                if echo "$CONTENT" | jq -e 'type == "object"' >/dev/null 2>&1; then
                    # Jika response adalah JSON murni, teruskan sebagai struktur data
                    # Ke depannya QML bisa menangkap ini sebagai command (misal: jalankan script)
                    quickshell ipc call lumi groqComplete "$CONTENT"
                else
                    quickshell ipc call lumi groqComplete "$CONTENT"
                fi
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
