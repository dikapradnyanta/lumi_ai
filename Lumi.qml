import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../"          // MatugenColors, Config
import "components"   // ChatView, InputBar, VoicePanel, Waveform

// ============================================================
// Lumi v2 — Lumi.qml (M7: Integrated Voice & Chat Modes)
// ============================================================
Item {
    id: root

    MatugenColors { id: _theme }

    // ── Size untuk Main.qml morph system ────────────────────
    property int targetMasterWidth:  680
    property int targetMasterHeight: 720

    // ── API Key dari Config.qml ──────────────────────────────
    readonly property string apiKey: Config.lumiApiKey
    readonly property bool hasApiKey: apiKey.trim().length > 0

    // ── Mode: "chat" | "voice" ───────────────────────────────
    property string activeMode: "chat"

    // ── Voice state: "idle" | "listening" | "thinking" | "speaking" | "error" ──
    property string voiceState: "idle"
    property string voiceSubtitle: ""
    property string userTranscript: ""
    property int spokenWordIndex: -1

    // ── State dari LumiService ───────────────────────────────
    readonly property bool isThinking: lumiSvc.isThinking

    // ── LumiService inline ───────────────────────────────────
    QtObject {
        id: lumiSvc

        property bool isThinking: false
        property bool isSpeaking: false
        property bool isRecording: false
        property string systemContext: ""
        property var apiHistory: []

        readonly property string backendDir: Quickshell.env("HOME") +
            "/.config/hypr/scripts/quickshell/lumi2/backend"
        readonly property string historyFile: "/tmp/lumi2_history.json"

        function sendMessage(userText) {
            let clean = userText.trim().substring(0, 4000)
            if (clean.length === 0 || lumiSvc.isThinking) return

            // Append user message ke UI
            let ts = _timestamp()
            chatModel.append({ role: "user", content: clean, timestamp: ts })

            // Append ke history
            lumiSvc.apiHistory = lumiSvc.apiHistory.concat([
                { role: "user", content: clean }
            ])

            lumiSvc.isThinking = true
            root.voiceState = "thinking"

            // Jalankan get_context.py
            ctxProcess.running = false
            ctxProcess.running = true
        }

        function startSTT() {
            root.voiceState = "listening"
            root.userTranscript = ""
            root.voiceSubtitle = ""
            sttLocalProc.running = false
            sttLocalProc.running = true
        }

        function stopSTT() {
            // Signal stt_local.py to finalize via stop flag
            Config.sh("touch /tmp/lumi_stt_stop")
        }

        function _buildAndSend() {
            let messages = []
            if (lumiSvc.systemContext.length > 0) {
                messages.push({ role: "system", content: lumiSvc.systemContext })
            }
            let hist = lumiSvc.apiHistory
            if (hist.length > 20) hist = hist.slice(hist.length - 20)
            messages = messages.concat(hist)

            let jsonStr = JSON.stringify(messages)
            writeHistoryProc.pendingJson = jsonStr
            writeHistoryProc.running = false
            writeHistoryProc.running = true
        }

        function clearHistory() {
            lumiSvc.apiHistory = []
            chatModel.clear()
            Config.sh("rm -f " + lumiSvc.historyFile)
        }

        function speak(text) {
            root.voiceState = "speaking"
            root.voiceSubtitle = text
            root.spokenWordIndex = 0
            Config.sh("touch /tmp/lumi_tts_stop 2>/dev/null; sleep 0.05")
            ttsProcess.textToSpeak = text
            ttsProcess.running = false
            ttsProcess.running = true
            lumiSvc.isSpeaking = true
        }

        function stopSpeaking() {
            Config.sh("touch /tmp/lumi_tts_stop")
            ttsProcess.running = false
            lumiSvc.isSpeaking = false
            root.spokenWordIndex = -1
            root.voiceState = "idle"
        }

        function _timestamp() {
            let d = new Date()
            return d.getHours().toString().padStart(2,"0") + ":" +
                   d.getMinutes().toString().padStart(2,"0")
        }
    }

    // ── Conversation history model ───────────────────────────
    ListModel { id: chatModel }

    // ── Processes ───────────────────────────────────────────
    Process {
        id: ctxProcess
        command: ["python3", lumiSvc.backendDir + "/get_context.py"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let ctx = this.text.trim()
                if (ctx.length > 0) lumiSvc.systemContext = ctx
                lumiSvc._buildAndSend()
            }
        }
    }

    // ── Local STT: faster-whisper + Silero VAD ────────────────
    // Single streaming process — emits PARTIAL: and FINAL: to stdout
    Process {
        id: sttLocalProc
        command: ["python3", lumiSvc.backendDir + "/stt_local.py"]
        running: false
        stdout: SplitParser {
            onRead: (line) => {
                let trimmed = line.trim()
                if (trimmed.startsWith("PARTIAL:")) {
                    // Live preview while user is speaking
                    let text = trimmed.substring(8)
                    if (text.length > 0 && root.voiceState === "listening") {
                        root.userTranscript = text
                    }
                } else if (trimmed.startsWith("FINAL:")) {
                    // End of speech — send to AI
                    let result = trimmed.substring(6).trim()
                    sttLocalProc.running = false
                    if (result === "SILENCE" || result.length === 0) {
                        root.voiceState = "idle"
                        root.voiceSubtitle = "Tidak ada suara terdeteksi."
                        return
                    }
                    if (result.startsWith("ERROR:")) {
                        root.voiceState = "error"
                        root.voiceSubtitle = result
                        return
                    }
                    root.userTranscript = result
                    root.voiceState = "thinking"
                    lumiSvc.sendMessage(result)
                } else if (trimmed.startsWith("ERROR:")) {
                    sttLocalProc.running = false
                    root.voiceState = "error"
                    root.voiceSubtitle = trimmed
                }
            }
        }
    }

    Process {
        id: ttsProcess
        property string textToSpeak: ""
        command: ["python3", lumiSvc.backendDir + "/tts.py", "--text", textToSpeak]
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                let trimmed = data.trim()
                if (trimmed.startsWith("WORD:")) {
                    root.spokenWordIndex = parseInt(trimmed.substring(5)) || 0
                }
            }
        }
        onExited: {
            lumiSvc.isSpeaking = false
            root.spokenWordIndex = -1
            if (root.voiceState === "speaking") {
                root.voiceState = "idle"
                if (root.activeMode === "voice") {
                    lumiSvc.startSTT()
                }
            }
        }
    }

    Process {
        id: writeHistoryProc
        property string pendingJson: ""
        command: ["bash", "-c", "printf '%s' \"$1\" > /tmp/lumi2_history.json", "--", pendingJson]
        running: false
        onExited: {
            geminiProcess.running = false
            geminiProcess.running = true
        }
    }

    Process {
        id: geminiProcess
        command: ["bash", lumiSvc.backendDir + "/gemini.sh", lumiSvc.historyFile, "false"]
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                lumiSvc.isThinking = false
                let response = this.text.trim()

                if (response.startsWith("ERROR:")) {
                    let msg = response.replace(/^ERROR:[a-z_]*:?/i, "").trim()
                    chatModel.append({
                        role: "error",
                        content: "⚠ " + (msg || "Terjadi kesalahan."),
                        timestamp: lumiSvc._timestamp()
                    })
                    root.voiceState = "error"
                    root.voiceSubtitle = msg
                    return
                }

                lumiSvc.apiHistory = lumiSvc.apiHistory.concat([
                    { role: "assistant", content: response }
                ])
                chatModel.append({
                    role: "assistant",
                    content: response,
                    timestamp: lumiSvc._timestamp()
                })

                if (root.activeMode === "voice" || Config.lumiAutoSpeak) {
                    lumiSvc.speak(response)
                } else {
                    root.voiceState = "idle"
                }
            }
        }
    }

    // ============================================================
    // UI LAYOUT
    // ============================================================

    // Background
    Rectangle {
        anchors.fill: parent
        radius: 24
        color: _theme.base
        border.color: _theme.surface0
        border.width: 1

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor:   Qt.rgba(0, 0, 0, 0.5)
            shadowBlur:    0.3
            shadowVerticalOffset: 6
        }
    }

    // Header
    Rectangle {
        id: header
        anchors.top:   parent.top
        anchors.left:  parent.left
        anchors.right: parent.right
        height: 52
        radius: 24
        color: _theme.mantle
        border.color: _theme.surface0
        border.width: 1

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left:   parent.left
            anchors.right:  parent.right
            height: parent.radius
            color:  parent.color
        }

        RowLayout {
            anchors.fill:        parent
            anchors.leftMargin:  16
            anchors.rightMargin: 12
            spacing: 10

            Image {
                width: 28; height: 28
                source: "./assets/lumi_logo.svg"
                sourceSize: Qt.size(28, 28)
                fillMode: Image.PreserveAspectFit
            }

            Column {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: "Lumi"
                    font.pixelSize: 15
                    font.bold: true
                    color: _theme.text
                }
                Text {
                    text: !root.hasApiKey  ? "⚠ API Key tidak ditemukan" :
                          root.voiceState === "listening" ? "Listening..." :
                          root.voiceState === "thinking"  ? "Thinking..." :
                          root.voiceState === "speaking"  ? "Speaking..." : "Ready"
                    font.pixelSize: 11
                    color: !root.hasApiKey ? _theme.red     :
                           root.voiceState === "listening" ? _theme.green :
                           root.voiceState === "thinking"  ? _theme.blue :
                           root.voiceState === "speaking"  ? _theme.teal : _theme.subtext0
                }
            }

            // Mode Toggle
            Rectangle {
                width: 68; height: 26
                radius: 13
                color: _theme.surface0
                border.color: _theme.surface1
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 2

                    Repeater {
                        model: [
                            { icon: "󰭻", mode: "chat"  },
                            { icon: "󰍬", mode: "voice" }
                        ]
                        Rectangle {
                            width: 30; height: 22
                            radius: 11
                            color: root.activeMode === modelData.mode ?
                                   _theme.mauve : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.icon
                                font.pixelSize: 13
                                color: root.activeMode === modelData.mode ?
                                       _theme.crust : _theme.subtext0
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape:  Qt.PointingHandCursor
                                onClicked: {
                                    root.activeMode = modelData.mode
                                    if (root.activeMode === "voice" && root.voiceState === "idle") {
                                        lumiSvc.startSTT()
                                    } else if (root.activeMode === "chat") {
                                        lumiSvc.stopSpeaking()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Close button
            Rectangle {
                width: 28; height: 28
                radius: 8
                color: xHover.containsMouse ? _theme.red : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 11
                    color: xHover.containsMouse ? _theme.crust : _theme.subtext1
                }
                MouseArea {
                    id: xHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    Config.sh("echo 'close' > /tmp/qs_widget_state")
                }
            }
        }
    }

    // ── Content Area: Switch ChatView vs VoicePanel ───────────
    Item {
        anchors.top:    header.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottom: parent.bottom

        // Mode CHAT
        Item {
            anchors.fill: parent
            visible: root.activeMode === "chat"

            // Explicit dark background — prevents Qt default white
            Rectangle {
                anchors.fill: parent
                color: _theme.base
                z: -1
            }

            ChatView {
                id: chatArea
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: inputArea.top
                anchors.bottomMargin: 4
                chatModel:  chatModel
                isThinking: root.isThinking
            }

            Item {
                id: inputArea
                anchors.bottom: parent.bottom
                anchors.left:   parent.left
                anchors.right:  parent.right
                anchors.bottomMargin: 8
                anchors.leftMargin:   12
                anchors.rightMargin:  12
                height: 60

                InputBar {
                    id: inputBar
                    anchors.fill: parent
                    isThinking: root.isThinking
                    hasApiKey:  root.hasApiKey

                    onSendMessage: (text) => lumiSvc.sendMessage(text)
                    onVoiceModeRequested: {
                        root.activeMode = "voice"
                        lumiSvc.startSTT()
                    }
                }
            }
        }

        // Mode VOICE
        VoicePanel {
            anchors.fill: parent
            visible: root.activeMode === "voice"
            voiceState: root.voiceState
            subtitleText: root.voiceSubtitle
            userTranscript: root.userTranscript
            spokenWordIndex: root.spokenWordIndex

            onStartListening: lumiSvc.startSTT()
            onStopListening:  lumiSvc.stopSTT()
            onAnswerNow:      lumiSvc.stopSTT()
            onCancelSession: {
                lumiSvc.stopSpeaking()
                silenceMonitorProc.running = false
                sttStartProc.running = false
                sttStopProc.running = false
                root.voiceState = "idle"
                root.activeMode = "chat"
            }
        }
    }

    // Keyboard Shortcuts
    Keys.onEscapePressed: {
        Config.sh("echo 'close' > /tmp/qs_widget_state")
        event.accepted = true
    }

    Component.onCompleted: {
        console.log("[Lumi v2] M7 Voice Mode UI loaded.")
    }
}
