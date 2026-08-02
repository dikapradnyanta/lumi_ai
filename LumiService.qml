pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ============================================================
// LumiService.qml — Process manager & conversation brain
// Singleton: satu instance untuk seluruh sesi Lumi v2.
// Kelola: history, gemini calls, tts, stt, context injection.
// ============================================================
QtObject {
    id: service

    // ── Publik signals ───────────────────────────────────────
    signal responseReady(string text)
    signal errorOccurred(string message)
    signal thinkingChanged(bool thinking)
    signal sttTranscriptReady(string text)
    signal ttsDone()

    // ── State ────────────────────────────────────────────────
    property bool isThinking: false
    property bool isSpeaking: false
    property bool isRecording: false

    // ── Paths ────────────────────────────────────────────────
    readonly property string backendDir: Quickshell.env("HOME") +
        "/.config/hypr/scripts/quickshell/lumi2/backend"
    readonly property string historyFile: "/tmp/lumi2_history.json"
    readonly property string contextFile: "/tmp/lumi2_context.txt"

    // ── Conversation history (untuk API) ─────────────────────
    // Array of {role: "user"|"assistant", content: string}
    property var apiHistory: []

    // ── Chat model untuk UI (ListModel dikelola dari Lumi.qml) ─
    // Service tidak memiliki ListModel sendiri — UI yang pegang.
    // Service hanya emit signal → UI append bubble.

    // ── System context (cache, refresh tiap send) ─────────────
    property string systemContext: ""

    // ============================================================
    // PROCESS: get_context.py
    // ============================================================
    property Process contextProcess: Process {
        id: _ctxProc
        command: ["python3", service.backendDir + "/get_context.py"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let ctx = this.text.trim()
                if (ctx.length > 0) {
                    service.systemContext = ctx
                }
                // Setelah context siap, lanjut kirim ke Gemini
                service._buildAndSend()
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim().length > 0) {
                    console.log("[LumiService] context stderr:", this.text.trim())
                }
            }
        }
    }

    // ============================================================
    // PROCESS: gemini.sh (non-streaming untuk reliability M6)
    // ============================================================
    property Process geminiProcess: Process {
        id: _geminiProc
        command: ["bash", service.backendDir + "/gemini.sh",
                  service.historyFile, "false"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                let response = this.text.trim()

                service.isThinking = false
                service.thinkingChanged(false)

                if (response.startsWith("ERROR:")) {
                    let errMsg = response.replace(/^ERROR:[^:]*:?/, "").trim() || "Terjadi kesalahan."
                    service.errorOccurred(errMsg)
                    return
                }

                if (response.length === 0) {
                    service.errorOccurred("Response kosong dari Gemini.")
                    return
                }

                // Tambah ke history
                service.apiHistory = service.apiHistory.concat([
                    { role: "assistant", content: response }
                ])

                service.responseReady(response)
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                // Hanya log, bukan error (stderr dari gemini.sh adalah log)
                let txt = this.text.trim()
                if (txt.length > 0) console.log("[gemini.sh]", txt)
            }
        }
    }

    // ============================================================
    // PROCESS: stt.sh start
    // ============================================================
    property Process sttStartProcess: Process {
        id: _sttStartProc
        command: ["bash", service.backendDir + "/stt.sh", "start"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text.trim()
                if (out.startsWith("RECORDING:")) {
                    service.isRecording = true
                    console.log("[LumiService] STT recording started")
                } else {
                    service.errorOccurred("Gagal memulai rekaman: " + out)
                }
            }
        }
    }

    // ============================================================
    // PROCESS: stt.sh stop (rekam + transkrip)
    // ============================================================
    property Process sttStopProcess: Process {
        id: _sttStopProc
        command: ["bash", service.backendDir + "/stt.sh", "stop"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                service.isRecording = false
                let result = this.text.trim()

                if (result === "SILENCE") {
                    console.log("[LumiService] STT: no speech detected")
                    return
                }
                if (result.startsWith("ERROR:")) {
                    service.errorOccurred("STT gagal: " + result)
                    return
                }
                if (result.length > 0) {
                    service.sttTranscriptReady(result)
                }
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                let txt = this.text.trim()
                if (txt.length > 0) console.log("[stt.sh]", txt)
            }
        }
    }

    // ============================================================
    // PROCESS: tts.py
    // ============================================================
    property Process ttsProcess: Process {
        id: _ttsProc
        command: ["python3", service.backendDir + "/tts.py"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                service.isSpeaking = false
                service.ttsDone()
            }
        }
    }

    // ============================================================
    // FUNGSI PUBLIK
    // ============================================================

    // Kirim pesan user → context → gemini
    function sendMessage(userText: string) {
        if (service.isThinking) return

        // Sanitasi dasar
        let clean = userText.trim()
        if (clean.length === 0) return
        if (clean.length > 4000) {
            clean = clean.substring(0, 4000)
        }

        // Tambah user message ke history
        service.apiHistory = service.apiHistory.concat([
            { role: "user", content: clean }
        ])

        service.isThinking = true
        service.thinkingChanged(true)

        // Refresh context → lanjut ke _buildAndSend
        _ctxProc.running = false
        _ctxProc.running = true
    }

    // Dipanggil setelah context siap
    function _buildAndSend() {
        // Build messages array: system + history
        let messages = []

        if (service.systemContext.length > 0) {
            messages.push({ role: "system", content: service.systemContext })
        }

        // Batasi history (max 20 pesan terakhir untuk hemat token)
        let hist = service.apiHistory
        if (hist.length > 20) {
            hist = hist.slice(hist.length - 20)
        }
        messages = messages.concat(hist)

        // Tulis ke file history
        let jsonStr = JSON.stringify(messages)
        Quickshell.execDetached([
            "bash", "-c",
            "printf '%s' " + "'" + jsonStr.replace(/'/g, "'\\''") + "'" +
            " > " + service.historyFile
        ])

        // Delay kecil supaya file tertulis
        _writeTimer.restart()
    }

    property Timer _writeTimer: Timer {
        interval: 80
        repeat: false
        onTriggered: {
            _geminiProc.running = false
            _geminiProc.running = true
        }
    }

    // Mulai rekaman STT
    function startSTT() {
        if (service.isRecording) return
        _sttStartProc.running = false
        _sttStartProc.running = true
    }

    // Hentikan rekaman STT + transkrip
    function stopSTT() {
        if (!service.isRecording) return
        _sttStopProc.running = false
        _sttStopProc.running = true
    }

    // Putarkan teks via TTS
    function speak(text: string) {
        if (service.isSpeaking) stopSpeaking()
        // Tulis teks ke stdin via env
        Quickshell.execDetached([
            "bash", "-c",
            "echo " + "'" + text.substring(0, 2000).replace(/'/g, "'\\''") + "'" +
            " | python3 " + service.backendDir + "/tts.py"
        ])
        service.isSpeaking = true
    }

    // Hentikan TTS
    function stopSpeaking() {
        Quickshell.execDetached(["bash", "-c", "touch /tmp/lumi_tts_stop"])
        service.isSpeaking = false
    }

    // Bersihkan history
    function clearHistory() {
        service.apiHistory = []
        Quickshell.execDetached(["bash", "-c", "rm -f " + service.historyFile])
    }

    // Timestamp helper
    function nowTimestamp(): string {
        let d = new Date()
        return d.getHours().toString().padStart(2,"0") + ":" +
               d.getMinutes().toString().padStart(2,"0")
    }
}
