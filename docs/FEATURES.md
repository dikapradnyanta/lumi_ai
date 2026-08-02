# Lumi AI v2 — Features Overview

Lumi AI v2 provides a set of features tailored for linux desktop automation and voice interaction on Hyprland.

---

## Key Features

### 🎙️ 1. Voice & Chat Dual Interface
- **Seamless Mode Switcher**: Easily switch between a minimalist **Voice Panel** (with animated orb & visualizer) and a rich **Chat View**.
- **Hands-free Voice Loop**: In Voice Mode, Lumi listens, responds via TTS, and automatically re-opens the microphone after speaking for continuous conversation.

### 🧠 2. Intelligent Speech-to-Text (STT) & Hybrid VAD
- **Faster-Whisper (`tiny`)**: Local, low-latency CPU speech recognition requiring no cloud API for voice input.
- **Silero VAD ONNX**: AI-driven Voice Activity Detection filtering out background noise, fan hum, and static while accurately tracking speech boundaries.
- **Instant Auto-Cutoff**: Automatically finalizes speech recognition after a user-configured silence period (e.g. 0.8s).
- **Live Partial Preview**: Streams partial speech transcripts in real-time as you speak.

### 🔊 3. Offline & High-Quality TTS (Text-to-Speech)
- **Piper TTS Engine**: Offline, native Indonesian neural voice (`id_ID-news_tts-medium.onnx`) with zero network latency.
- **Edge-TTS Fallback**: Online Microsoft Azure neural TTS fallback supporting customized voices (`id-ID-GadisNeural`, `en-GB-SoniaNeural`).
- **Markdown Sanitizer**: Strips code snippets, asterisks, hashtags, and URLs before vocal synthesis for natural reading.
- **Instant Interrupt**: Stop speech playback at any time by pressing Escape or starting a new query.

### ⚙️ 4. Automated 2-Stage Microphone Calibration
- **Stage 1 (Background Noise)**: Records 5 seconds of ambient room noise to establish exact RMS noise floor.
- **Stage 2 (User Speech)**: Records 4 seconds of normal speaking voice to calculate Signal-to-Noise Ratio (SNR).
- **Unbiased Threshold Calculation**: Automatically computes optimal `silenceThreshold` and `speechThreshold` without clipping.
- **Responsive UI Card**: Formatted status card with automatic text wrapping and visual indicators.

### 💻 5. Hyprland Context Awareness
- Automatically extracts active window titles, current workspace, and media player state.
- Injects desktop context into Gemini API system prompt, allowing questions like *"What code am I editing?"* or *"Summarize my open window"*.

---

## Supported Models & APIs

| Service | Engine / Model | Details |
|---|---|---|
| **Primary LLM** | Google Gemini API (`gemini-2.5-flash`, `gemini-3.1-flash-lite`) | Cloud AI reasoning & task execution |
| **Local STT** | Faster-Whisper (`tiny.en` / `tiny`) | Local INT8 quantized CTranslate2 engine |
| **Local VAD** | Silero VAD ONNX | 16kHz neural voice filter |
| **Local TTS** | Piper TTS | ONNX neural voice synthesizer |
