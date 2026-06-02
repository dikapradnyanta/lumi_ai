#!/usr/bin/env bash

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#  ◈ LUMI AI INSTALLER SCRIPT
#  Checks dependencies and prepares the environment for Lumi AI.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

set -euo pipefail

echo "========================================"
echo "    ✨  Lumi AI Setup & Installer  ✨   "
echo "========================================"
echo ""

# 1. Dependency check function
check_dep() {
    local cmd="$1"
    local pkg="${2:-$1}"
    if ! command -v "$cmd" &> /dev/null; then
        echo "❌ Missing dependency: $cmd"
        echo "   Please install it (e.g., sudo pacman -S $pkg)"
        return 1
    else
        echo "✅ Found dependency: $cmd"
        return 0
    fi
}

MISSING=0
echo "🔍 Checking System Dependencies..."
check_dep "curl" || MISSING=1
check_dep "jq" || MISSING=1
check_dep "bc" || MISSING=1
check_dep "ffmpeg" || MISSING=1
check_dep "arecord" "alsa-utils" || MISSING=1
check_dep "python3" "python" || MISSING=1

if [ "$MISSING" -eq 1 ]; then
    echo ""
    echo "⚠️  Please install the missing dependencies above and re-run this script."
    exit 1
fi

echo ""
echo "🔍 Checking Python Dependencies..."
# Check for OpenAI python package used by TTS
if ! python3 -c "import openai" &> /dev/null; then
    echo "❌ Missing Python package: openai"
    echo "   Installing via pip..."
    pip install openai --break-system-packages || {
        echo "   Failed to install via pip. Try: sudo pacman -S python-openai"
        exit 1
    }
else
    echo "✅ Found python package: openai"
fi

echo ""
echo "📁 Setting up Lumi Directory..."

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QS_DIR="$HOME/.config/hypr/scripts/quickshell"
TARGET_DIR="$QS_DIR/lumi"

if [ "$SOURCE_DIR" != "$TARGET_DIR" ]; then
    echo "   Copying Lumi files to $TARGET_DIR..."
    mkdir -p "$TARGET_DIR"
    cp -r "$SOURCE_DIR"/* "$TARGET_DIR"/
    echo "✅ Files copied."
else
    echo "✅ Lumi is already in the correct Quickshell directory."
fi

# Ensure scripts are executable
chmod +x "$TARGET_DIR"/*.sh

echo ""
echo "========================================"
echo "🎉 Lumi AI is ready!"
echo "========================================"
echo "Next steps:"
echo "1. Ensure Quickshell is running."
echo "2. Open Quickshell Settings, go to the Lumi Tab."
echo "3. Enter your Groq API Key."
echo "4. Press the 'Run Calibration' button to set your silence threshold."
echo ""
