# Lumi AI v2 — Setup & Installation Guide

This guide walks you through setting up Lumi AI v2 on **Hyprland** using **Quickshell**.

---

## Prerequisites

Ensure the following packages are installed on your Linux system:

```bash
# Arch Linux Dependencies
sudo pacman -S pipewire wireplumber pactl jq python python-pip mpv alsa-utils potrace
```

### Python Dependencies

Install the required Python packages for STT, VAD, and TTS:

```bash
pip install numpy faster-whisper onnxruntime piper-tts edge-tts
```

---

## Installation & Setup

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/dikapradnyanta/lumi_ai.git ~/.config/hypr/scripts/quickshell/lumi2
   ```

2. **Download Piper TTS Model (Indonesian)**:
   ```bash
   mkdir -p ~/.local/share/piper/models
   cd ~/.local/share/piper/models
   wget https://huggingface.co/rhasspy/piper-voices/resolve/main/id/id_ID/news_tts/medium/id_ID-news_tts-medium.onnx
   wget https://huggingface.co/rhasspy/piper-voices/resolve/main/id/id_ID/news_tts/medium/id_ID-news_tts-medium.onnx.json
   ```

3. **Configure API Key & Model Settings**:
   Set your Google Gemini API key and preferred STT settings in `~/.config/hypr/settings.json`:
   ```json
   {
     "lumi": {
       "apiKey": "YOUR_GEMINI_API_KEY",
       "model": "gemini-2.5-flash",
       "sttModel": "base",
       "sttLanguage": "id",
       "autoSpeak": true,
       "silenceDuration": 0.8
     }
   }
   ```

4. **Launch Lumi AI via Quickshell**:
   ```bash
   qs -p ~/.config/hypr/scripts/quickshell/lumi2/Lumi.qml
   ```

---

## Microphone Calibration

To calibrate your microphone for optimal Voice Activity Detection:

1. Open the **Quickshell Settings** tab (`LumiConfigTab.qml`).
2. Click **Run 2-Stage Calibration**.
3. **Stage 1**: Stay completely silent for 5 seconds while background noise floor is measured.
4. **Stage 2**: Speak normally for 4 seconds when prompted.
5. The optimal `speechThreshold` will be computed and saved automatically.
