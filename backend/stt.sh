#!/usr/bin/env bash
# ============================================================
# Lumi v2 — backend/stt.sh
# Speech-to-Text pipeline:
#   start → rekam audio via arecord (PipeWire)
#   stop  → kirim WAV ke Gemini Audio API → output transcript
#
# Usage:
#   stt.sh start   — mulai rekam, simpan PID ke /tmp/lumi_stt.pid
#   stt.sh stop    — hentikan rekam, transkrip, output ke stdout
#   stt.sh status  — cek apakah sedang merekam
#   stt.sh cleanup — bersihkan semua file temp
#
# Exit codes: 0=sukses, 1=error
# ============================================================

set -euo pipefail

readonly SETTINGS_FILE="$HOME/.config/hypr/settings.json"
readonly AUDIO_FILE="/tmp/lumi_audio.wav"
readonly PID_FILE="/tmp/lumi_stt.pid"
readonly STOP_FLAG="/tmp/lumi_stt_stop"
readonly MAX_RECORD_SECONDS=60
readonly MAX_AUDIO_BYTES=10485760   # 10MB
readonly SAMPLE_RATE=16000

log_info()  { echo "[stt] INFO: $*"  >&2; }
log_error() { echo "[stt] ERROR: $*" >&2; }

# ============================================================
# RESOLUSI MIC DEVICE
# ============================================================
resolve_mic() {
    local cfg_device
    cfg_device="$(jq -r '.lumi.micDevice // "default"' "$SETTINGS_FILE" 2>/dev/null || echo "default")"

    if [[ "$cfg_device" != "default" && -n "$cfg_device" ]]; then
        echo "$cfg_device"
        return
    fi

    # Auto-detect: cari mic fisik (bukan loopback/monitor)
    local default_src
    default_src="$(timeout 1 pactl get-default-source 2>/dev/null || echo "")"

    # Jika default bukan loopback/monitor, pakai itu
    if [[ -n "$default_src" ]] && \
       [[ "$default_src" != *".monitor"* ]] && \
       [[ "$default_src" != *"snd_aloop"* ]]; then
        echo "$default_src"
        return
    fi

    # Fallback: cari alsa_input fisik pertama
    local physical_mic
    physical_mic="$(timeout 1 pactl list short sources 2>/dev/null \
        | grep 'alsa_input' \
        | grep -v 'snd_aloop\|monitor' \
        | head -1 \
        | awk '{print $2}')"

    if [[ -n "$physical_mic" ]]; then
        echo "$physical_mic"
    else
        echo "default"
    fi
}

# ============================================================
# CLEANUP
# ============================================================
cleanup() {
    rm -f "$AUDIO_FILE" "$PID_FILE" "$STOP_FLAG"
}

# ============================================================
# START — mulai rekam
# ============================================================
cmd_start() {
    # Hentikan rekaman sebelumnya jika ada
    if [[ -f "$PID_FILE" ]]; then
        local old_pid
        old_pid="$(cat "$PID_FILE" 2>/dev/null || echo "")"
        [[ -n "$old_pid" ]] && kill "$old_pid" 2>/dev/null || true
        rm -f "$PID_FILE"
    fi

    rm -f "$AUDIO_FILE" "$STOP_FLAG"

    local MIC_DEVICE
    MIC_DEVICE="$(resolve_mic)"
    log_info "Menggunakan mic: $MIC_DEVICE"

    # Rekam audio dengan timeout otomatis (keamanan: max 60 detik)
    PULSE_SOURCE="$MIC_DEVICE" arecord \
        -D pulse \
        -f S16_LE \
        -r "$SAMPLE_RATE" \
        -c 1 \
        -d "$MAX_RECORD_SECONDS" \
        "$AUDIO_FILE" \
        2>/dev/null &

    local REC_PID=$!
    echo "$REC_PID" > "$PID_FILE"
    log_info "Rekaman dimulai. PID: $REC_PID"
    echo "RECORDING:$REC_PID"
}

# ============================================================
# STOP — hentikan rekam + transkrip
# ============================================================
cmd_stop() {
    # 1. Hentikan proses arecord
    if [[ -f "$PID_FILE" ]]; then
        local REC_PID
        REC_PID="$(cat "$PID_FILE")"
        kill "$REC_PID" 2>/dev/null || true
        wait "$REC_PID" 2>/dev/null || true
        rm -f "$PID_FILE"
        log_info "Rekaman dihentikan. PID: $REC_PID"
    else
        log_error "Tidak ada rekaman aktif (PID file tidak ditemukan)"
    fi

    # 2. Cek file audio
    if [[ ! -f "$AUDIO_FILE" ]]; then
        log_error "File audio tidak ditemukan: $AUDIO_FILE"
        echo "ERROR:no_audio_file"
        rm -f "$STOP_FLAG"
        exit 1
    fi

    local AUDIO_SIZE
    AUDIO_SIZE="$(stat -c%s "$AUDIO_FILE" 2>/dev/null || echo "0")"
    log_info "Ukuran audio: $AUDIO_SIZE bytes"

    # Cek minimum size (WAV header = 44 bytes, butuh minimal 0.5 detik audio)
    local MIN_BYTES=$(( SAMPLE_RATE * 2 / 2 ))  # 0.5 detik @ 16kHz S16LE mono
    if [[ "$AUDIO_SIZE" -lt "$MIN_BYTES" ]]; then
        log_error "Audio terlalu pendek atau kosong: $AUDIO_SIZE bytes"
        echo "ERROR:audio_too_short"
        rm -f "$AUDIO_FILE" "$STOP_FLAG"
        exit 1
    fi

    # Cek max size (keamanan)
    if [[ "$AUDIO_SIZE" -gt "$MAX_AUDIO_BYTES" ]]; then
        log_error "Audio terlalu besar: $AUDIO_SIZE bytes (max: $MAX_AUDIO_BYTES)"
        echo "ERROR:audio_too_large"
        rm -f "$AUDIO_FILE" "$STOP_FLAG"
        exit 1
    fi

    # 3. Baca API key
    local API_KEY
    API_KEY="$(jq -r '.lumi.apiKey // empty' "$SETTINGS_FILE" 2>/dev/null | cut -d',' -f1 | tr -d '[:space:]')"
    if [[ -z "$API_KEY" || "$API_KEY" == "null" ]]; then
        log_error "API key tidak ditemukan"
        echo "ERROR:no_api_key"
        rm -f "$AUDIO_FILE" "$STOP_FLAG"
        exit 1
    fi

    # 4. Encode audio ke base64 → tulis ke file temp (hindari "Argument list too long")
    log_info "Encoding audio ke base64..."
    local B64_FILE="/tmp/lumi_audio_b64.txt"
    base64 -w 0 "$AUDIO_FILE" > "$B64_FILE"

    # 5. Baca model STT dari settings
    local STT_MODEL
    STT_MODEL="$(jq -r '.lumi.model // "gemini-3.5-flash"' "$SETTINGS_FILE" 2>/dev/null)"
    log_info "STT Model: $STT_MODEL"

    # 6. Build payload Gemini Audio API menggunakan --rawfile (aman untuk data besar)
    local PAYLOAD_FILE="/tmp/lumi_stt_payload.json"
    jq -n \
        --rawfile b64 "$B64_FILE" \
        --arg model "$STT_MODEL" \
        '{
            contents: [{
                parts: [
                    {
                        inline_data: {
                            mime_type: "audio/wav",
                            data: ($b64 | rtrimstr("\n"))
                        }
                    },
                    {
                        text: "Transkripsi audio ini secara akurat ke dalam teks. Jika ada keheningan atau tidak ada pembicaraan, balas hanya dengan kata: SILENCE. Jangan tambahkan penjelasan lain."
                    }
                ]
            }],
            generationConfig: {
                temperature: 0,
                maxOutputTokens: 1024
            }
        }' > "$PAYLOAD_FILE"
    rm -f "$B64_FILE"

    # 7. Kirim ke Gemini Generative Language API via --data @file (handle large payload)
    log_info "Mengirim ke Gemini Audio API..."
    local RESPONSE
    RESPONSE="$(curl \
        --silent \
        --max-time 30 \
        --connect-timeout 10 \
        -H "Content-Type: application/json" \
        -H "X-goog-api-key: ${API_KEY}" \
        --data "@${PAYLOAD_FILE}" \
        "https://generativelanguage.googleapis.com/v1beta/models/${STT_MODEL}:generateContent" \
        2>/dev/null)"
    rm -f "$PAYLOAD_FILE"

    # 8. Ekstrak transkrip
    local TRANSCRIPT
    TRANSCRIPT="$(echo "$RESPONSE" | jq -r '.candidates[0].content.parts[0].text // empty' 2>/dev/null)"

    # Cek API error
    local API_ERR
    API_ERR="$(echo "$RESPONSE" | jq -r '.error.message // empty' 2>/dev/null)"
    if [[ -n "$API_ERR" ]]; then
        log_error "API error: $API_ERR"
        echo "ERROR:api_error:${API_ERR}"
        rm -f "$AUDIO_FILE" "$STOP_FLAG"
        exit 1
    fi

    if [[ -z "$TRANSCRIPT" ]]; then
        log_error "Transkrip kosong. Raw response: ${RESPONSE:0:200}"
        echo "ERROR:empty_transcript"
        rm -f "$AUDIO_FILE" "$STOP_FLAG"
        exit 1
    fi

    # 9. Cek jika silence
    if [[ "$TRANSCRIPT" == *"SILENCE"* ]]; then
        log_info "Tidak ada pembicaraan terdeteksi"
        echo "SILENCE"
        rm -f "$AUDIO_FILE" "$STOP_FLAG"
        exit 0
    fi

    # 10. Strip karakter kontrol berbahaya & output
    log_info "Transkrip berhasil: ${TRANSCRIPT:0:50}..."
    printf '%s\n' "$TRANSCRIPT" | tr -d '\000-\010\013\014\016-\031'

    # 11. Cleanup
    rm -f "$AUDIO_FILE" "$STOP_FLAG" "/tmp/lumi_audio_b64.txt" "/tmp/lumi_stt_payload.json"
}

# ============================================================
# STATUS
# ============================================================
cmd_status() {
    if [[ -f "$PID_FILE" ]]; then
        local PID
        PID="$(cat "$PID_FILE")"
        if kill -0 "$PID" 2>/dev/null; then
            echo "RECORDING:$PID"
        else
            echo "STOPPED"
            rm -f "$PID_FILE"
        fi
    else
        echo "IDLE"
    fi
}

# ============================================================
# MAIN
# ============================================================
CMD="${1:-help}"
case "$CMD" in
    start)   cmd_start   ;;
    stop)    cmd_stop    ;;
    status)  cmd_status  ;;
    cleanup) cleanup; echo "CLEANED" ;;
    *)
        echo "Usage: stt.sh {start|stop|status|cleanup}"
        exit 1
        ;;
esac
