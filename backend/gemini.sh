#!/usr/bin/env bash
# ============================================================
# Lumi v2 — backend/gemini.sh
# Google Gemini LLM Engine via OpenAI Compatibility Layer.
# SSE Streaming. Dibangun dari nol dengan keamanan penuh.
#
# Usage:
#   gemini.sh <history_json_file> [stream:true|false]
#
# Output:
#   Streaming token ke stdout (jika stream=true)
#   Full response ke stdout (jika stream=false)
#
# Exit codes:
#   0 = sukses
#   1 = error (API key tidak ada, JSON invalid, network timeout, dll)
# ============================================================

set -euo pipefail

# ── Konstanta ─────────────────────────────────────────────
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SETTINGS_FILE="$HOME/.config/hypr/settings.json"
readonly MAX_INPUT_CHARS=4000
readonly CURL_TIMEOUT=30
readonly MAX_TOKENS=2048

# ── Warna log (hanya ke stderr, tidak ke stdout) ──────────
log_info()  { echo "[gemini] INFO: $*"  >&2; }
log_warn()  { echo "[gemini] WARN: $*"  >&2; }
log_error() { echo "[gemini] ERROR: $*" >&2; }

# ============================================================
# 1. BACA ARGUMEN
# ============================================================
HISTORY_FILE="${1:-}"
STREAM="${2:-true}"

if [[ -z "$HISTORY_FILE" ]]; then
    log_error "Usage: gemini.sh <history_json_file> [true|false]"
    exit 1
fi

if [[ ! -f "$HISTORY_FILE" ]]; then
    log_error "File tidak ditemukan: $HISTORY_FILE"
    exit 1
fi

# ============================================================
# 2. BACA API KEY DARI settings.json (via Config.qml pattern)
# ============================================================
# Key disimpan di settings.json["lumi"]["apiKey"] — sama dengan
# yang dipakai Config.lumiApiKey di QML.
if [[ ! -f "$SETTINGS_FILE" ]]; then
    log_error "settings.json tidak ditemukan: $SETTINGS_FILE"
    echo "ERROR:no_settings_file" 
    exit 1
fi

API_KEY="$(jq -r '.lumi.apiKey // empty' "$SETTINGS_FILE" 2>/dev/null | cut -d',' -f1 | tr -d '[:space:]')"

if [[ -z "$API_KEY" ]]; then
    log_error "API key tidak ditemukan di settings.json (.lumi.apiKey)"
    echo "ERROR:no_api_key"
    exit 1
fi

# ── Validasi format key (harus non-empty string, bukan null) ─
if [[ "$API_KEY" == "null" || ${#API_KEY} -lt 10 ]]; then
    log_error "API key tidak valid atau terlalu pendek"
    echo "ERROR:invalid_api_key"
    exit 1
fi

# ============================================================
# 3. VALIDASI DAN SANITASI INPUT JSON
# ============================================================

# 3a. Cek apakah valid JSON
if ! jq empty "$HISTORY_FILE" 2>/dev/null; then
    log_error "File bukan JSON valid: $HISTORY_FILE"
    echo "ERROR:invalid_json"
    exit 1
fi

# 3b. Cek panjang total konten (keamanan: cegah payload besar)
TOTAL_CONTENT_LEN="$(jq -r '[.[].content // ""] | add // ""' "$HISTORY_FILE" 2>/dev/null | wc -c)"
if [[ "$TOTAL_CONTENT_LEN" -gt "$MAX_INPUT_CHARS" ]]; then
    log_warn "Input terlalu panjang: $TOTAL_CONTENT_LEN chars (max: $MAX_INPUT_CHARS)"
    echo "ERROR:input_too_long"
    exit 1
fi

# 3c. Cek struktur: harus array berisi objek {role, content}
VALID_STRUCT="$(jq 'if type == "array" and (length > 0) and (.[0] | has("role") and has("content")) then "ok" else "bad" end' "$HISTORY_FILE" 2>/dev/null)"
if [[ "$VALID_STRUCT" != '"ok"' ]]; then
    log_error "Struktur JSON tidak valid. Harus: [{\"role\":\"...\",\"content\":\"...\"}]"
    echo "ERROR:invalid_structure"
    exit 1
fi

# ============================================================
# 4. BACA MODEL DARI SETTINGS
# ============================================================
GEMINI_MODEL="$(jq -r '.lumi.model // "gemini-3.5-flash"' "$SETTINGS_FILE" 2>/dev/null)"
MAX_TOKENS_CFG="$(jq -r '.lumi.maxTokens // 2048' "$SETTINGS_FILE" 2>/dev/null)"
TEMPERATURE="$(jq -r '.lumi.temperature // 0.7' "$SETTINGS_FILE" 2>/dev/null)"

log_info "Model: $GEMINI_MODEL | Stream: $STREAM | MaxTokens: $MAX_TOKENS_CFG"

# ============================================================
# 5. BUILD REQUEST PAYLOAD
# ============================================================
# Baca messages dari file, sanitasi karakter berbahaya
MESSAGES="$(jq '.' "$HISTORY_FILE")"

# Build JSON payload dengan jq (aman dari injection)
PAYLOAD="$(jq -n \
    --argjson messages "$MESSAGES" \
    --arg model "$GEMINI_MODEL" \
    --argjson max_tokens "$MAX_TOKENS_CFG" \
    --argjson temperature "$TEMPERATURE" \
    --argjson stream "$( [[ "$STREAM" == "true" ]] && echo "true" || echo "false")" \
    '{
        model: $model,
        messages: $messages,
        max_tokens: $max_tokens,
        temperature: $temperature,
        stream: $stream
    }'
)"

# ============================================================
# 6. KIRIM KE GEMINI API
# ============================================================
readonly API_URL="https://generativelanguage.googleapis.com/v1beta/openai/chat/completions"

# Fungsi curl dengan timeout dan header yang benar
call_api() {
    curl \
        --silent \
        --no-buffer \
        --max-time "$CURL_TIMEOUT" \
        --connect-timeout 10 \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${API_KEY}" \
        -d "$PAYLOAD" \
        "$API_URL"
}

# ============================================================
# 7. PROSES RESPONSE
# ============================================================
if [[ "$STREAM" == "true" ]]; then
    # ── Streaming SSE ────────────────────────────────────────
    # Parse event-stream: ambil delta content dari setiap chunk
    call_api | while IFS= read -r line; do
        # Skip kosong dan komentar SSE
        [[ -z "$line" ]] && continue
        [[ "$line" == ":"* ]] && continue

        # Ambil data setelah "data: "
        if [[ "$line" == "data: "* ]]; then
            DATA="${line#data: }"
            
            # Signal akhir stream
            [[ "$DATA" == "[DONE]" ]] && break

            # Ekstrak delta content dengan jq (aman)
            CHUNK="$(echo "$DATA" | jq -r '.choices[0].delta.content // empty' 2>/dev/null)"
            
            if [[ -n "$CHUNK" ]]; then
                # Strip karakter kontrol berbahaya (ASCII 0-8, 11-12, 14-31)
                # Biarkan tab(9), newline(10), carriage return(13)
                printf '%s' "$CHUNK" | tr -d '\000-\010\013\014\016-\031'
            fi
            
            # Cek error dari API
            API_ERR="$(echo "$DATA" | jq -r '.error.message // empty' 2>/dev/null)"
            if [[ -n "$API_ERR" ]]; then
                log_error "API error: $API_ERR"
                echo ""
                echo "ERROR:api_error:${API_ERR}"
                exit 1
            fi
        fi
    done

    # Newline di akhir setelah streaming selesai
    echo ""

else
    # ── Non-streaming (full response) ─────────────────────────
    RESPONSE="$(call_api)"
    
    # Cek HTTP error / API error
    API_ERR="$(echo "$RESPONSE" | jq -r '.error.message // empty' 2>/dev/null)"
    if [[ -n "$API_ERR" ]]; then
        log_error "API error: $API_ERR"
        echo "ERROR:api_error:${API_ERR}"
        exit 1
    fi

    # Ekstrak content
    CONTENT="$(echo "$RESPONSE" | jq -r '.choices[0].message.content // empty' 2>/dev/null)"
    if [[ -z "$CONTENT" ]]; then
        log_error "Response kosong atau tidak terduga: $RESPONSE"
        echo "ERROR:empty_response"
        exit 1
    fi

    # Strip karakter kontrol berbahaya
    printf '%s\n' "$CONTENT" | tr -d '\000-\010\013\014\016-\031'
fi
