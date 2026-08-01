# Lumi AI — Agent & Architecture Specification

Dokumen ini berisi spesifikasi teknis lengkap, arsitektur sistem, alur IPC, serta panduan troubleshoot untuk Lumi AI (Desktop Voice & Chat Assistant) di lingkungan Hyprland + Quickshell.

---

## 📌 1. Ikhtisar Sistem (System Overview)
Lumi AI adalah asisten desktop cerdas berbasis **Quickshell (QML)** dan **Hyprland** yang berjalan 100% menggunakan **Google Gemini API**:
1. **Chat Mode:** Antarmuka obrolan teks tradisional dengan riwayat percakapan, auto-scroll, serta dynamic model routing (`gemini-3.6-flash`).
2. **Speech Mode (Voice Mode):** Antarmuka suara interaktif dengan visualisasi plasma orb 3D (`OrbCore.qml`), pendeteksi suara otomatis (`silence_monitor.sh`), serta integrasi Google Gemini Multimodal Audio API + Text-to-Speech (Piper / Edge-TTS streaming).

---

## 🏗️ 2. Struktur File Utama & Peran

| File | Deskripsi / Tanggung Jawab |
| :--- | :--- |
| `lumi.qml` | Main UI container. Mengelola tampilan Chat, riwayat pesan, input box, toggle mode (Chat ↔ Speech), dan keyboard shortcut global (`Escape`). |
| `speech/SpeechOrb.qml` | Overlay antarmuka mode suara. Mengelola state machine suara (`listening`, `thinking`, `speaking`, `idle`), tombol *Answer Now*, dan penanganan peristiwa keyboard/mouse. |
| `speech/OrbCore.qml` | Renderer Canvas 2D untuk visualisasi plasma orb dengan 10 gelombang dinamis yang merespons 5 band frekuensi audio mic secara real-time. |
| `LumiService.qml` | Central IPC service untuk Quickshell. Mengontrol proses latar belakang (`stt.sh`, `gemini.sh`, `stream_tts.py`) dan memancarkan signal QML (`sttComplete`, `groqComplete`, dll). |
| `stt.sh` | Backend rekaman audio (`arecord`). Memilih source mic PulseAudio/PipeWire dan melakukan transkripsi via **Google Gemini Multimodal Audio API** (`gemini-flash-latest`). |
| `silence_monitor.sh` | Monitor keheningan real-time menggunakan `ffmpeg silencedetect`. Dilengkapi logika perlindungan *initial silence* (menunggu pengguna bicara sebelum menghitung timeout 1.2 detik). |
| `mic_level.py` | Python spectrum analyzer. Membaca stream raw PCM dari `arecord`, menghitung FFT 5 band frekuensi, dan memancarkan level amplitudo via stdout (25 FPS). |
| `gemini.sh` | Google Gemini API LLM Engine. Mendukung OpenAI-compatible SSE streaming (`gemini-3.6-flash`, `gemini-3.1-pro-preview`), menyuntikkan konteks sistem (`get_context.py`), dan mengalirkan response ke TTS. |

---

## 🤖 3. Google Gemini AI Engine

- **Full Gemini API Integration:**
  - **Models:** `gemini-3.6-flash` (Fast & High Rate Limit), `gemini-flash-latest`, `gemini-3.1-pro-preview`.
  - **Audio STT:** Gemini Native Multimodal Audio API via base64 WAV payload ke `generativelanguage.googleapis.com`.
  - **LLM Endpoint:** `https://generativelanguage.googleapis.com/v1beta/openai/chat/completions` (OpenAI Compatibility Layer dengan SSE Streaming).
  - **Authentication:** Header `Authorization: Bearer <API_KEY>` & `X-goog-api-key: <API_KEY>` (didapatkan dari [Google AI Studio](https://aistudio.google.com)).

---

## 🔄 4. Alur Kerja IPC & Mode Switching

### Mode Switching (Chat ↔ Speech)
- **Masuk ke Speech Mode:**
  - Klik tombol mode di header `lumi.qml` atau panggil `speechOrb.open()`.
  - `speechOrb` mengaktifkan process `mic_level.py` untuk visualisasi orb.
  - `LumiService.startListening()` memanggil `stt.sh start` dan `silence_monitor.sh`.
- **Keluar ke Chat Mode:**
  - Tekan **Escape**, klik area luar Orb, atau klik tombol toggle mode.
  - Signal `closeRequested` dipancarkan ke `lumi.qml` → `root.speechMode = false`.
  - Service menghentikan proses `stt.sh` dan mematikan pemutaran TTS (`muteTTS`).

### Speech-to-Text (STT) Pipeline
```
[User Speaking] ──> [arecord (PulseAudio)] ──> [audio.wav]
                         │
                         ├──> [mic_level.py (FFT)] ──> [SpeechOrb Canvas Sync]
                         │
                         └──> [silence_monitor.sh] ──> (Silence 1.2s post-speech) ──> [stt.sh stop]
                                                                                            │
                                                                           [Google Gemini Audio API]
                                                                                            │
                                                                                   [onSttComplete IPC]
```

---

## 🎧 5. Konfigurasi Audio & Microphone

### Resolusi Perangkat Mic (Audio Source Resolution)
- Perangkat dikonfigurasi melalui `~/.config/hypr/settings.json` (`lumi.micDevice`).
- Jika set ke `"default"` atau `null`:
  1. Script mengecek `pactl get-default-source`.
  2. Jika default source mengarah ke `.monitor` atau `snd_aloop`, script otomatis melakukan fallback ke input microphone fisik terdeteksi pertama (`alsa_input.*`).
  3. `arecord` dijalankan dengan flag `-D pulse` dan `PULSE_SOURCE=<device>` untuk menjamin audio ditangkap melalui PipeWire/PulseAudio.

---

## ⌨️ 6. Fitur Utama & Navigasi Pengguna

- **Tombol Answer Now:** Push button bergaya modern dengan ikon centang (`󰄬`) untuk langsung menghentikan rekaman dan memproses transkripsi tanpa menunggu timeout hening.
- **Ketuk Orb Core:** Mengklik Orb saat posisi `idle` atau `speaking` akan langsung memulai rekaman suara baru (`restartListening`).
- **Escape Key:** Tombol Esc di keyboard secara konsisten menutup mode suara dan kembali ke tampilan chat teks.

---

## 🛠️ 7. Petunjuk Pengujian (Testing Instructions)

1. **Uji Coba Rekaman Mic:**
   ```bash
   bash ~/.config/hypr/scripts/quickshell/lumi/stt.sh start
   # Bicara pada mic, lalu jalankan:
   bash ~/.config/hypr/scripts/quickshell/lumi/stt.sh stop
   ```
2. **Uji Coba LLM Engine:**
   ```bash
   echo '[{"role":"user","content":"halo"}]' > /tmp/req.json
   bash ~/.config/hypr/scripts/quickshell/lumi/gemini.sh /tmp/req.json false
   ```
3. **Uji Coba GUI Reload:**
   ```bash
   pkill -f "quickshell -p .*Main.qml"
   nohup quickshell -p ~/.config/hypr/scripts/quickshell/Main.qml >/tmp/qs_lumi.log 2>&1 &
   ```
