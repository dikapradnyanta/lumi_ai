<p align="center">
  <img src="assets/lumi_logo.svg" alt="Lumi AI Logo" width="140" height="140" />
</p>

<h1 align="center">Lumi AI</h1>

<p align="center">
  <b>A Voice-First, Low-Latency Desktop AI Assistant for Hyprland & Quickshell</b>
</p>

<p align="center">
  <a href="https://github.com/dikapradnyanta/lumi_ai/blob/main/LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
  <a href="https://hyprland.org"><img src="https://img.shields.io/badge/Hyprland-Supported-00b4d8.svg" alt="Hyprland"></a>
  <a href="https://github.com/outfoxxed/quickshell"><img src="https://img.shields.io/badge/UI-Quickshell%20QML-cba6f7.svg" alt="Quickshell"></a>
  <a href="https://deepmind.google/technologies/gemini/"><img src="https://img.shields.io/badge/AI-Google%20Gemini-8e44ad.svg" alt="Gemini AI"></a>
  <a href="https://github.com/SYSTRAN/faster-whisper"><img src="https://img.shields.io/badge/STT-Faster--Whisper-green.svg" alt="Faster-Whisper"></a>
</p>

<p align="center">
  <a href="#overview">Overview</a> •
  <a href="#key-features">Key Features</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#architecture">Architecture</a> •
  <a href="#configuration">Configuration</a> •
  <a href="#documentation">Documentation</a> •
  <a href="#license">License</a>
</p>

---

## Overview

**Lumi AI** is an intelligent, privacy-respecting desktop virtual assistant built natively for the **Hyprland** window manager using **Quickshell**. Designed with a voice-first philosophy, Lumi combines local real-time Speech-to-Text (STT), neural Text-to-Speech (TTS), and **Google Gemini AI** with live Hyprland window & system context.

Whether you need hands-free voice automation, quick desktop queries, or dynamic context-aware assistance, Lumi delivers sub-second response times with a modern, glassmorphic UI.

---

## Key Features

| Feature | Description |
|---|---|
| **Dual Interface (Voice & Chat)** | Morph smoothly between an ambient Voice Panel with animated visualizers and a rich Chat View. |
| **Hands-Free Voice Loop** | Continuous voice conversation loop (Listen -> Think -> Speak -> Auto-Listen). |
| **Local STT + Hybrid VAD** | Powered by Faster-Whisper (base / tiny) and Silero VAD ONNX for instant silence detection and zero-cloud voice recording privacy. |
| **Local Neural TTS** | Offline Indonesian neural voice synthesis via Piper AudioChunk API streaming directly to aplay PCM buffers with live karaoke word highlighting. |
| **7-Band Audio Visualizer** | Live PipeWire FFT frequency analyzer (mic_level.py) powering responsive 7-bar waveform animations. |
| **2-Stage Mic Calibration** | Automated background noise measurement & Signal-to-Noise Ratio (SNR) calculation to eliminate VAD false triggers. |
| **Hyprland Context Injection** | Automatically reads active window titles, current workspace, and system metrics for contextual AI reasoning. |

---

## Quick Start

### 1. Prerequisites

Install system dependencies on **Arch Linux**:

```bash
sudo pacman -S pipewire wireplumber pactl jq python python-pip mpv alsa-utils potrace
```

Install required Python libraries:

```bash
pip install numpy faster-whisper onnxruntime piper-tts edge-tts
```

### 2. Installation

Clone the repository to your Quickshell scripts directory:

```bash
git clone https://github.com/dikapradnyanta/lumi_ai.git ~/.config/hypr/scripts/quickshell/lumi2
```

### 3. Download Local Neural Voice Model

Download the Piper Indonesian voice model (`id_ID-news_tts-medium`):

```bash
mkdir -p ~/.local/share/piper/models
cd ~/.local/share/piper/models
wget https://huggingface.co/rhasspy/piper-voices/resolve/main/id/id_ID/news_tts/medium/id_ID-news_tts-medium.onnx
wget https://huggingface.co/rhasspy/piper-voices/resolve/main/id/id_ID/news_tts/medium/id_ID-news_tts-medium.onnx.json
```

### 4. Configure API Key

Add your Google Gemini API Key to `~/.config/hypr/settings.json`:

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

### 5. Launch

Run Lumi AI with Quickshell:

```bash
qs -p ~/.config/hypr/scripts/quickshell/lumi2/Lumi.qml
```

---

## Architecture

```
+------------------------------------------------------------------------+
|                          Quickshell QML Frontend                       |
| +----------------------+  +--------------------+  +------------------+ |
| |       Lumi.qml       |  |   VoicePanel.qml   |  |   ChatView.qml   | |
| +----------+-----------+  +---------+----------+  +--------+---------+ |
+------------|------------------------|----------------------|-----------+
             |                        |                      |
             v                        v                      v
+------------------------+  +------------------+  +---------------------+
|  stt_local.py (STT)    |  |  mic_level.py    |  |  gemini.sh (LLM)    |
|  Faster-Whisper (base) |  |  7-Band PipeWire |  |  Google Gemini API  |
|  + Silero VAD ONNX     |  |  FFT Visualizer  |  |  + Context Injection|
+------------+-----------+  +------------------+  +----------+----------+
             |                                               |
             +----------------───────+----------------───────+
                                     |
                                     v
                        +------------------------+
                        |   tts.py (Piper TTS)   |
                        |   AudioChunk PCM Stream|
                        |   --> aplay stdout     |
                        +------------------------+
```

---

## Configuration Reference

All user preferences are managed cleanly via `~/.config/hypr/settings.json` or the **Quickshell Settings Tab**:

| Key | Type | Default | Description |
|---|---|---|---|
| `apiKey` | `string` | `""` | Google Gemini API Key |
| `model` | `string` | `"gemini-2.5-flash"` | Gemini model selection (`gemini-2.5-flash`, `gemini-3.6-flash`, etc.) |
| `sttModel` | `string` | `"base"` | Faster-Whisper model size (`base`, `small`, `tiny`) |
| `sttLanguage` | `string` | `"id"` | STT language code (`id`, `en`, `auto`) |
| `speechThreshold` | `float` | `0.02` | Calibrated VAD speech energy threshold |
| `silenceDuration` | `float` | `0.8` | Silence cutoff duration in seconds before auto-answering |
| `autoSpeak` | `boolean` | `true` | Automatically speak responses via TTS |

---

## Documentation

Detailed documentation is available in the [`docs/`](./docs) directory:

- **[Architecture Overview](./docs/ARCHITECTURE.md)** — Detailed IPC pipelines, data flow & component contracts.
- **[Design System](./docs/DESIGN_SYSTEM.md)** — UI philosophy, color tokens, and SVG asset specifications.
- **[Features Breakdown](./docs/FEATURES.md)** — In-depth breakdown of STT, VAD, TTS, and desktop integration.
- **[Setup & Troubleshooting](./docs/SETUP_GUIDE.md)** — Advanced configuration & audio device tuning.

---

## License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

<p align="right">(<a href="#top">back to top</a>)</p>
