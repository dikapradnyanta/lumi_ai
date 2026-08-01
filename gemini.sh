#!/bin/bash
# gemini.sh — Streaming & Non-streaming Google Gemini API client for Lumi AI

set -euo pipefail

log_time() {
    echo "$(date +'%H:%M:%S.%3N') - [GEMINI] $1" >> /tmp/lumi_timing_debug.log
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
SETTINGS="$HOME/.config/hypr/settings.json"
REQ_FILE="${1:-/tmp/lumi_req.json}"
AUTO_SPEAK="${2:-false}"

if [[ -f "$ENV_FILE" ]]; then
    set -a; source "$ENV_FILE"; set +a
fi

KEY="${GEMINI_API_KEY:-}"
if [ -z "$KEY" ]; then
    KEY=$(jq -r '.lumi.apiKey // .lumi.geminiApiKey // empty' "$SETTINGS" 2>/dev/null)
fi

if [ -z "$KEY" ]; then
    echo "ERROR: Gemini API key tidak ditemukan di settings.json. Dapatkan di https://aistudio.google.com"
    exit 1
fi

IFS=',' read -ra KEYS <<< "$KEY"

# Validasi file request
if [ ! -f "$REQ_FILE" ] || ! jq empty "$REQ_FILE" 2>/dev/null; then
    echo "ERROR: File request invalid"
    exit 1
fi

# ── Baca konfigurasi dari settings.json ───────────────────────────────────────
TEMPERATURE=$(jq -r '.lumi.temperature // 0.7' "$SETTINGS" 2>/dev/null)
TOP_P=$(jq -r '.lumi.topP // 0.9' "$SETTINGS" 2>/dev/null)
MAX_TOKENS=$(jq -r '.lumi.maxTokens // 1024' "$SETTINGS" 2>/dev/null)

# ── DYNAMIC MODEL ROUTING ─────────────────────────────────────────────────────
SMALL_MODEL=$(jq -r '.lumi.smallModel // "gemini-3.6-flash"' "$SETTINGS" 2>/dev/null)
LARGE_MODEL=$(jq -r '.lumi.model // "gemini-3.6-flash"' "$SETTINGS" 2>/dev/null)
THRESHOLD=$(jq -r '.lumi.routingThreshold // 1500' "$SETTINGS" 2>/dev/null)

CONTEXT_LENGTH=$(jq -r 'map(.content // "") | join("") | length' "$REQ_FILE" 2>/dev/null || echo "0")

if [ "$CONTEXT_LENGTH" -lt "$THRESHOLD" ]; then
    MODEL="$SMALL_MODEL"
    echo "[Lumi Routing] ${CONTEXT_LENGTH} char < ${THRESHOLD} → $SMALL_MODEL" > /tmp/lumi_routing.log
else
    MODEL="$LARGE_MODEL"
    echo "[Lumi Routing] ${CONTEXT_LENGTH} char >= ${THRESHOLD} → $LARGE_MODEL" > /tmp/lumi_routing.log
fi

# Sanitize legacy model names if present
if [[ "$MODEL" == llama* ]] || [[ "$MODEL" == mixtral* ]] || [[ "$MODEL" == gemma* ]] || [[ "$MODEL" == gemini-2.5* ]] || [[ "$MODEL" == gemini-1.5* ]]; then
    MODEL="gemini-3.6-flash"
fi

log_time "Model decided: $MODEL"

# ── Build payload dengan parameter finetuning ──────────────────────────────────
DYNAMIC_CONTEXT=$(python3 "$HOME/.config/hypr/scripts/quickshell/lumi/get_context.py" 2>/dev/null)

API_URL="https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"

PAYLOAD=$(jq \
    --arg model "$MODEL" \
    --argjson temperature "$TEMPERATURE" \
    --argjson top_p "$TOP_P" \
    --argjson max_tokens "$MAX_TOKENS" \
    --arg dyn_ctx "$DYNAMIC_CONTEXT" \
    '{
        messages: (if .[0].role == "system" then (.[0].content += "\n\n" + $dyn_ctx | .) else ([{role: "system", content: $dyn_ctx}] + .) end),
        stream: true,
        model: $model,
        max_tokens: $max_tokens,
        temperature: $temperature,
        top_p: $top_p
    }' "$REQ_FILE")

SUCCESS=false
for CURRENT_KEY in "${KEYS[@]}"; do
    CURRENT_KEY=$(echo "$CURRENT_KEY" | xargs)
    [ -z "$CURRENT_KEY" ] && continue

    log_time "Calling Gemini API ($MODEL)"

    if [ "$AUTO_SPEAK" = "true" ]; then
        log_time "Sending streamStart IPC"
        quickshell -p "$HOME/.config/hypr/scripts/quickshell/Main.qml" ipc call lumi streamStart 2>/dev/null || true

        log_time "Starting curl to Gemini API (streaming)"
        FULL_TEXT=$(curl -s --no-buffer \
            -X POST "$API_URL" \
            -H "Authorization: Bearer $CURRENT_KEY" \
            -H "Content-Type: application/json" \
            -H "Accept: text/event-stream" \
            --max-time 30 \
            -d "$PAYLOAD" \
        | python3 "$SCRIPT_DIR/stream_tts.py" 2>/tmp/lumi_tts_err.log)
        
        log_time "curl and stream_tts.py finished"

        EXIT_CODE=$?
        if [ $EXIT_CODE -ne 0 ]; then
            log_time "stream_tts.py exited with error $EXIT_CODE"
            cat /tmp/lumi_tts_err.log >&2
            continue
        fi

        if [ -n "$FULL_TEXT" ]; then
            log_time "Sending groqComplete and ttsComplete IPC"
            echo "$FULL_TEXT"
            quickshell -p "$HOME/.config/hypr/scripts/quickshell/Main.qml" ipc call lumi groqComplete "$FULL_TEXT" 2>/dev/null || true
            quickshell -p "$HOME/.config/hypr/scripts/quickshell/Main.qml" ipc call lumi ttsComplete 2>/dev/null || true
            SUCCESS=true
            break
        fi
    else
        HTTP_RESPONSE=$(curl -s -w "\n__HTTP_STATUS__%{http_code}" \
            --max-time 25 \
            --retry 1 \
            --retry-delay 1 \
            -X POST "$API_URL" \
            -H "Authorization: Bearer $CURRENT_KEY" \
            -H "Content-Type: application/json" \
            -d "$(echo "$PAYLOAD" | jq 'del(.stream)')" 2>/tmp/lumi_curl_err.log)

        HTTP_STATUS=$(echo "$HTTP_RESPONSE" | grep "__HTTP_STATUS__" | sed 's/__HTTP_STATUS__//')
        BODY=$(echo "$HTTP_RESPONSE" | grep -v "__HTTP_STATUS__")

        if [ "$HTTP_STATUS" = "429" ]; then
            echo "ERROR: Gemini API Rate Limit, mencoba key berikutnya..." >&2
            continue
        fi

        if [ "$HTTP_STATUS" = "200" ]; then
            CONTENT=$(echo "$BODY" | jq -r '.choices[0].message.content // empty')
            if [ -n "$CONTENT" ]; then
                echo "$CONTENT"
                SUCCESS=true
                break
            fi
        else
            echo "ERROR HTTP $HTTP_STATUS dari Gemini API: $BODY" >&2
        fi
    fi
done

if [ "$SUCCESS" = "false" ]; then
    echo "ERROR: Gemini API key gagal atau rate limited. Pastikan API key valid dari https://aistudio.google.com"
    exit 1
fi
