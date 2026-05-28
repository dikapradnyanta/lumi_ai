#!/usr/bin/env bash
# calibrate_silence.sh — Auto-kalibrasi threshold silence monitor
# Merekam ambient noise dan menghitung nilai threshold optimal.
#
# Usage: bash calibrate_silence.sh [--apply]
#   --apply   : langsung tulis threshold ke silence_monitor.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SILENCE_MONITOR="$SCRIPT_DIR/silence_monitor.sh"
TMP_NOISE="/tmp/lumi_calibrate_noise.wav"
RECORD_DURATION=5   # Detik rekaman noise

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║     Lumi — Auto Kalibrasi Silence Threshold         ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "📢  INSTRUKSI:"
echo "    Diam selama $RECORD_DURATION detik (jangan bicara)."
echo "    Script akan merekam ambient noise ruanganmu."
echo ""
read -rp "    Tekan ENTER untuk mulai merekam..." _

echo ""
echo "🎙️  Merekam ambient noise ($RECORD_DURATION detik)..."

# Coba cari device microphone yang tersedia
MIC_DEVICE=$(arecord -l 2>/dev/null | grep "card" | head -1 | grep -oP 'card \K\d+')
if [ -z "$MIC_DEVICE" ]; then
    MIC_DEVICE="0"
fi

# Rekam noise dengan arecord
arecord -f S16_LE -c 1 -r 16000 -d "$RECORD_DURATION" "$TMP_NOISE" 2>/dev/null
echo "✅  Rekaman selesai."
echo ""

# Analisis mean volume dengan ffmpeg
echo "📊  Menganalisis level noise..."
FFMPEG_OUTPUT=$(ffmpeg -i "$TMP_NOISE" -af "volumedetect" -f null - 2>&1)

MEAN_VOLUME=$(echo "$FFMPEG_OUTPUT" | grep -oP '(?<=mean_volume: )-?\d+\.\d+' || echo "")
MAX_VOLUME=$(echo "$FFMPEG_OUTPUT" | grep -oP '(?<=max_volume: )-?\d+\.\d+' || echo "")

if [ -z "$MEAN_VOLUME" ]; then
    echo "❌  Gagal menganalisis audio. Pastikan mikrofon terhubung."
    rm -f "$TMP_NOISE"
    exit 1
fi

echo "    Mean volume  : ${MEAN_VOLUME} dB"
echo "    Max volume   : ${MAX_VOLUME} dB"
echo ""

# Hitung threshold optimal: mean + 15dB (standar rekomendasi)
THRESHOLD=$(echo "$MEAN_VOLUME + 15" | bc)

# Clamp: jangan terlalu sensitif (-30) atau terlalu longgar (-50)
THRESHOLD_INT=${THRESHOLD%.*}
if [ "$THRESHOLD_INT" -gt -30 ]; then
    THRESHOLD="-30"
    echo "⚠️   Threshold diklamp ke -30dB (noise ruangan terlalu tinggi)"
elif [ "$THRESHOLD_INT" -lt -50 ]; then
    THRESHOLD="-50"
    echo "⚠️   Threshold diklamp ke -50dB (ruangan sangat senyap)"
fi

echo "╔══════════════════════════════════════════════════════╗"
echo "║  Hasil Kalibrasi                                    ║"
echo "╠══════════════════════════════════════════════════════╣"
printf "║  Ambient noise level  : %-26s ║\n" "${MEAN_VOLUME} dB"
printf "║  Threshold optimal    : %-26s ║\n" "${THRESHOLD} dB"
printf "║  (rumus: mean + 15dB)                               ║\n"
echo "╚══════════════════════════════════════════════════════╝"
echo ""

# Terapkan ke silence_monitor.sh jika flag --apply
APPLY="${1:---dry-run}"
if [ "$APPLY" = "--apply" ]; then
    if [ ! -f "$SILENCE_MONITOR" ]; then
        echo "❌  File $SILENCE_MONITOR tidak ditemukan!"
        exit 1
    fi

    # Backup dulu
    cp "$SILENCE_MONITOR" "${SILENCE_MONITOR}.calibrate.bak"

    # Update SILENCE_THRESHOLD di silence_monitor.sh
    sed -i "s|SILENCE_THRESHOLD=\"[^\"]*\"|SILENCE_THRESHOLD=\"${THRESHOLD}dB\"|g" "$SILENCE_MONITOR"

    echo "✅  Threshold berhasil diupdate ke ${THRESHOLD}dB di silence_monitor.sh"
    echo "    Backup: ${SILENCE_MONITOR}.calibrate.bak"
else
    echo "ℹ️   Dry-run mode. Untuk menerapkan, jalankan:"
    echo "    bash calibrate_silence.sh --apply"
fi

# Cleanup
rm -f "$TMP_NOISE"
echo ""
