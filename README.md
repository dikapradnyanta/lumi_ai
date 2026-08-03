# Lumi AI v2 — Desktop AI Assistant for Hyprland & Quickshell

<p align="center">
  <img src="assets/lumi_logo.svg" alt="Lumi Logo" width="160" height="160" />
</p>

Lumi AI v2 adalah asisten virtual cerdas berbasis suara dan teks yang dirancang secara native untuk desktop **Hyprland** menggunakan **Quickshell**. Lumi mengintegrasikan **Google Gemini API** dengan konteks sistem Hyprland, **Faster-Whisper (Local STT)** dengan Silero VAD, serta **Piper TTS (Local Speech Synthesis)** untuk interaksi suara yang cepat dan natural.

---

## ✨ Fitur Utama

- **🪐 Elegant Branding & UI**: Dilengkapi logo vektor SVG resmi (Cat Sleeping on Planet) dengan tema Catppuccin / Matugen dan animasi mikro yang fluida.
- **🎙️ Dual Mode (Voice & Chat)**:
  - **Voice Mode**: Mode interaksi hands-free dengan *voice-loop* otomatis (Listen → Think → Speak → Loop).
  - **Chat Mode**: Tampilan percakapan multi-bubble dengan dukungan format Markdown & kode.
- **🧠 Local STT Presisi Tinggi (Faster-Whisper + Silero VAD)**:
  - Menggunakan model Whisper `base` (dengan fallback otomatis ke `tiny`).
  - Dilengkapi **Silero VAD ONNX** untuk menyaring kebisingan latar belakang.
  - **Peak Audio Normalization** & Pengunci Bahasa Indonesia (`id`) untuk transkripsi suara yang sangat akurat.
- **🔊 Local Neural TTS (Piper AudioChunk Streaming)**:
  - Sintesis suara lokal Bahasa Indonesia (`id_ID-news_tts-medium.onnx`) yang disalurkan secara streaming ke `aplay`.
  - Dilengkapi **Markdown Sanitizer** dan pembacaan teks bergaya *Karaoke word highlight*.
  - Dukungan fallback online ke **Edge-TTS**.
- **📊 7-Band FFT Visualizer (`mic_level.py`)**:
  - Visualizer audio 7-bar yang reaktif dan fluida berbasis FFT dengan animasi *Exponential Moving Average (EMA)*.
- **⚙️ Automated 2-Stage Microphone Calibration**:
  - Perekaman 2 tahap (Background noise 5s + Voice 4s) untuk menentukan threshold SNR suara secara otomatis tanpa distorsi.
- **💻 Hyprland Desktop Context Awareness**:
  - Membaca judul jendela aktif, workspace Hyprland, dan status media player untuk dimasukkan ke konteks Gemini API.

---

## 📦 Prasyarat Sistem

Pastikan paket-paket berikut terinstall di sistem Linux Anda:

```bash
# Arch Linux Dependencies
sudo pacman -S pipewire wireplumber pactl jq python python-pip mpv alsa-utils potrace
```

### Python Dependencies

```bash
pip install numpy faster-whisper onnxruntime piper-tts edge-tts
```

---

## 🛠️ Cara Install & Running

1. **Clone Repository**:
   ```bash
   git clone https://github.com/dikapradnyanta/lumi_ai.git ~/.config/hypr/scripts/quickshell/lumi2
   ```

2. **Download Model Piper TTS (Bahasa Indonesia)**:
   ```bash
   mkdir -p ~/.local/share/piper/models
   cd ~/.local/share/piper/models
   wget https://huggingface.co/rhasspy/piper-voices/resolve/main/id/id_ID/news_tts/medium/id_ID-news_tts-medium.onnx
   wget https://huggingface.co/rhasspy/piper-voices/resolve/main/id/id_ID/news_tts/medium/id_ID-news_tts-medium.onnx.json
   ```

3. **Konfigurasi Gemini API Key**:
   Buka `~/.config/hypr/settings.json` dan tambahkan API Key Gemini Anda:
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

4. **Jalankan via Quickshell**:
   ```bash
   qs -p ~/.config/hypr/scripts/quickshell/lumi2/Lumi.qml
   ```

---

## 💡 Struktur Arsitektur Singkat

- `Lumi.qml`: Main window container dengan logo SVG dan mode switcher.
- `LumiService.qml`: Core IPC process manager dan handler state.
- `backend/stt_local.py`: Engine local STT (Faster-Whisper + Silero VAD + Normalization).
- `backend/tts.py`: Engine local TTS (Piper AudioChunk + Edge-TTS fallback + `aplay`).
- `backend/mic_level.py`: Real-time 7-band FFT audio analyzer untuk `Waveform.qml`.
- `backend/gemini.sh`: Client Google Gemini API dengan context injection.
- `backend/get_context.py`: Hyprland window & system metrics context generator.
- `backend/calibrate_mic.py`: Automated 2-stage noise & speech calibration pipeline.
- `assets/lumi_logo.svg`: Official Lumi SVG vector logo.
