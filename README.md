# Lumi AI untuk Hyprland & Quickshell

Lumi AI adalah asisten virtual berbasis suara yang sangat ringan dan cepat, dirancang secara native untuk desktop **Hyprland** menggunakan UI dari **Quickshell**. Lumi memanfaatkan API Groq untuk *Speech-to-Text* (Whisper) dan inferensi AI (Llama 3, Mixtral, dll) secara instan, serta integrasi Text-to-Speech yang cerdas.

## ✨ Fitur Utama

- **🚀 Native & Super Cepat**: Menggunakan arsitektur bash + QML yang sangat ringan. Tidak ada backend server berat (Node/Python daemon) yang berjalan di background.
- **🎤 Kalibrasi Silence Otomatis**: Dilengkapi dengan STT cerdas. Lumi hanya mendengarkan saat Anda berbicara dan otomatis berhenti saat Anda diam. Ambang batas keheningan (Silence Threshold) dapat dikalibrasi otomatis atau diatur manual via UI.
- **🔄 Dynamic Model Routing**: Demi kecepatan maksimal, Lumi akan menggunakan model AI ringan (Fast Model, misal `Llama 3 8B`) untuk pertanyaan singkat, dan otomatis beralih ke model besar (`Llama 3 70B`) jika prompt Anda melebihi panjang karakter yang ditentukan.
- **🔊 Auto-TTS**: Anda bisa menyalakan fitur Auto-Speak di Settings agar Lumi langsung membacakan balasannya kepada Anda.
- **⚙️ Konfigurasi Penuh dari UI**: Ganti API Key, pilih AI Model, atur Temperature, Max Tokens, hingga Threshold semuanya bisa dilakukan langsung dari menu Settings Quickshell.

## 📦 Prasyarat Sistem

Sebelum menginstall Lumi AI, pastikan sistem Anda memiliki paket-paket berikut:

- **Hyprland** (Window Manager)
- **Quickshell** (UI Framework)
- `curl` dan `jq` (Untuk API STT/TTS dan parsing JSON)
- `ffmpeg` dan `alsa-utils` (`arecord` untuk perekaman dan kalibrasi audio)
- `bc` (Kalkulator shell untuk kalibrasi audio)
- `python3` (Untuk kalkulasi mic level visualisasi)

## 🛠️ Cara Install & Setup

Anda dapat dengan mudah menyalin folder `lumi/` ke konfigurasi Quickshell Anda menggunakan skrip instalasi yang disediakan:

1. Unduh dan jalankan skrip installer:
   ```bash
   chmod +x install_lumi.sh
   ./install_lumi.sh
   ```

2. Buka Quickshell Settings (umumnya dengan shortcut `Super + S` atau via App Launcher), lalu navigasi ke tab **Lumi AI (Logo Robot/Mic)**.
3. Masukkan **Groq API Key** Anda (Dapatkan gratis dari `console.groq.com`).
4. (Opsional) Klik tombol **Run Calibration** di menu Microphone Calibration untuk mendeteksi tingkat noise di ruangan Anda secara otomatis, atau ketik manual (contoh: `-35dB`).
5. Selesai! Lumi AI siap digunakan.

## 💡 Arsitektur Singkat

- `lumi.qml`: Front-end utama chat Lumi. Menangani state UI, visualizer mic, dan animasi.
- `LumiConfigTab.qml`: Menu pengaturan Lumi yang terintegrasi di Quickshell Settings.
- `stt.sh`: Menggunakan Whisper via Groq untuk mendeteksi dan mentranskrip suara.
- `silence_monitor.sh`: Memonitor aktivitas mikrofon menggunakan `arecord` dan memotong rekaman otomatis jika terdeteksi keheningan sesuai *threshold*.
- `groq.sh`: Skrip bash untuk mengirim request STT dan chat secara paralel ke API.
