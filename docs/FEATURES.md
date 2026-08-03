# Lumi AI v2 — Features Overview

Lumi AI v2 provides a rich set of features tailored for linux desktop automation and voice interaction on Hyprland.

---

## Key Features

### 1. Vector SVG Branding & Dual Mode UI
- **Official SVG Logo**: Elegant cat-on-planet vector logo (`assets/lumi_logo.svg`) supporting dynamic theme color inheritance (`currentColor`).
- **Seamless Mode Switcher**: Easily switch between a minimalist **Voice Panel** (with animated visualizer) and a rich **Chat View**.
- **Hands-free Voice Loop**: In Voice Mode, Lumi listens, responds via TTS, and automatically re-opens the microphone after speaking for continuous conversation.

### 2. Intelligent Local Speech-to-Text (STT) & Hybrid VAD
- **Faster-Whisper (`base` / `small` / `tiny`)**: Local, low-latency CPU speech recognition with configurable model size.
- **Indonesian Language Lock & Prompting**: Locked to `language="id"` with desktop context prompt (`Lumi, Hyprland, Linux, Halo`) for high accuracy.
- **Peak Audio Normalization**: Automatically normalizes soft input speech before passing to Whisper decoder.
- **Silero VAD ONNX**: Neural Voice Activity Detection filtering out background noise, fan hum, and static while accurately tracking speech boundaries.
- **Instant Auto-Cutoff**: Automatically finalizes speech recognition after a user-configured silence period (e.g. 0.8s).
- **Live Partial Preview**: Streams partial speech transcripts in real-time as you speak.

### 3. Offline & High-Quality Neural TTS (Text-to-Speech)
- **Piper AudioChunk API**: Offline, native Indonesian neural voice (`id_ID-news_tts-medium.onnx`) streaming PCM audio directly into `aplay`.
- **Karaoke Word Highlighting**: Emits `WORD:idx` events during speech synthesis for live subtitle highlighting in `VoicePanel.qml`.
- **Edge-TTS Fallback**: Online Microsoft Azure neural TTS fallback supporting customized voices (`id-ID-GadisNeural`, `en-GB-SoniaNeural`).
- **Markdown Sanitizer**: Strips code snippets, asterisks, hashtags, and URLs before vocal synthesis for natural reading.
- **Instant Interrupt**: Stop speech playback at any time by pressing Escape or starting a new query.

### 4. Real-time 7-Band FFT Audio Visualizer (`mic_level.py`)
- **PipeWire Audio Reader**: Uses `pw-record` to capture live microphone stream.
- **7 Frequency Bands**: Computes FFT magnitude across voice frequency range.
- **Exponential Moving Average (EMA)**: Smooths bar transitions for fluid animation in `Waveform.qml`.

### 5. Automated 2-Stage Microphone Calibration
- **Stage 1 (Background Noise)**: Records 5 seconds of ambient room noise to establish exact RMS noise floor.
- **Stage 2 (User Speech)**: Records 4 seconds of normal speaking voice to calculate Signal-to-Noise Ratio (SNR).
- **Unbiased Threshold Calculation**: Automatically computes optimal `silenceThreshold` and `speechThreshold` without clipping.

### 6. Hyprland Context Awareness
- Automatically extracts active window titles, current workspace, and media player state.
- Injects desktop context into Gemini API system prompt, allowing questions like *"What code am I editing?"* or *"Summarize my open window"*.

---

## Supported Models & APIs

| Service | Engine / Model | Details |
|---|---|---|
| **Primary LLM** | Google Gemini API (`gemini-2.5-flash`, `gemini-3.6-flash`) | Cloud AI reasoning & task execution |
| **Local STT** | Faster-Whisper (`base`, `small`, `tiny`) | Local INT8 quantized CTranslate2 engine |
| **Local VAD** | Silero VAD ONNX | 16kHz neural voice filter |
| **Local TTS** | Piper TTS (AudioChunk API) | ONNX neural voice synthesizer + `aplay` PCM stream |
| **Audio Visualizer** | `mic_level.py` (FFT) | 7-band live frequency analyzer |
