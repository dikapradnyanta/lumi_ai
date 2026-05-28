import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import Quickshell
import "../"
import "speech"

Item {
    id: root

    MatugenColors { id: _theme }

    // ── Colors ────────────────────────────────────────────────────────────
    readonly property color cBase:     _theme.base
    readonly property color cSurface0: _theme.surface0
    readonly property color cSurface1: _theme.surface1
    readonly property color cText:     _theme.text
    readonly property color cSubtext:  _theme.subtext0
    readonly property color cOverlay:  _theme.overlay0
    readonly property color cMauve:    _theme.mauve
    readonly property color cPink:     _theme.pink
    readonly property color cBlue:     _theme.blue
    readonly property color cSapphire: _theme.sapphire
    readonly property color cGreen:    _theme.green
    readonly property color cRed:      _theme.red
    readonly property color cLavender: _theme.lavender
    readonly property color cCrust:    _theme.crust

    // ── State ─────────────────────────────────────────────────────────────
    property bool isThinking: false
    
    // Bind to Config.qml directly
    property string apiKey: Config.lumiApiKey
    property bool hasApiKey: apiKey.length > 0
    property string groqModel: Config.lumiModel
    property bool autoSpeak: Config.lumiAutoSpeak

    property string pendingKeyInput: ""
    property bool isRecording: false
    property bool isSpeaking: false
    property bool speechMode: true // Default ke mode suara

    readonly property string scriptDir:
        "/home/dikapradnyanta/.config/hypr/scripts/quickshell/lumi"

    // ── Persistent memory ringkasan sesi ──────────────────────────────────
    property string sessionSummary: ""
    property int contextThreshold: Config.getSetting("lumi", {}).contextThreshold !== undefined ? Config.getSetting("lumi", {}).contextThreshold : 4000
    property string summaryPrompt: Config.getSetting("lumi", {}).summaryPrompt !== undefined ? Config.getSetting("lumi", {}).summaryPrompt : "Ringkas konteks obrolan berikut:"

    // ── System Prompt ─────────────────────────────────────────────────────
    function buildSystemPrompt() {
        let now = new Date()
        let dateStr = now.toLocaleDateString("id-ID", {
            weekday: "long", year: "numeric", month: "long", day: "numeric"
        })
        let timeStr = now.toLocaleTimeString("id-ID", {
            hour: "2-digit", minute: "2-digit"
        })
        let hour = now.getHours()
        let sapa = hour < 11 ? "Selamat pagi" : hour < 15 ? "Selamat siang" : hour < 18 ? "Selamat sore" : "Selamat malam"

        let prompt =
            "<identity>\n" +
            "You are Lumi — a personal AI embedded in the user's desktop: Arch Linux, Hyprland WM, Quickshell UI.\n" +
            "Current time: " + dateStr + " " + timeStr + ".\n" +
            "Default greeting if conversation starts: " + sapa + ".\n" +
            "</identity>\n\n" +

            "<expertise>\n" +
            "Linux (Arch, pacman, systemd, Hyprland, dotfiles, ricing), shell scripting (bash/zsh/fish),\n" +
            "programming (Python, JS/TS, C, Rust, QML), AI/ML concepts, daily productivity.\n" +
            "</expertise>\n\n" +

            "<language_rules>\n" +
            "1. Mirror the user's language exactly: Indonesian → respond Indonesian, mixed → match the mix, English → respond English.\n" +
            "2. Recognize tech slang as valid terms: nge-build, nge-push, nge-hang, crash, broken, lag, rice, dotfiles, qs, hyprconf.\n" +
            "3. Input may be STT-transcribed voice: tolerate typos, cut words, phonetic spellings (gimana=bagaimana, benerin=perbaiki, gapunya=tidak punya). Infer intent — never correct the transcription.\n" +
            "4. If intent is unclear: ask ONE short clarifying question. Never assume.\n" +
            "</language_rules>\n\n" +

            "<behavior>\n" +
            "- Be direct. Answer first, explain after if needed.\n" +
            "- Scale depth to complexity: short answer for simple questions, detailed for technical ones.\n" +
            "- Never repeat the user's question verbatim at the start of your reply.\n" +
            "- If unsure: say so, suggest where to look. Never fabricate terminal commands.\n" +
            "- Dangerous/destructive commands: always warn clearly before providing.\n" +
            "</behavior>\n\n" +

            "<output_format>\n" +
            "- Code: always use fenced code blocks with language tag (```bash, ```python, ```js, ```qml).\n" +
            "- Steps: use numbered list, keep each step concise.\n" +
            "- Short answers (<3 sentences): plain prose, no headers or bullets.\n" +
            "- Never output JSON unless explicitly requested.\n" +
            "</output_format>"

        if (root.sessionSummary && root.sessionSummary.length > 0) {
            prompt += "\n\n<memory>\n" + root.sessionSummary + "\n</memory>"
        }

        return prompt
    }

    // ── Messages ──────────────────────────────────────────────────────────
    ListModel { id: messagesModel }

    function estimateTokens(text) {
        // Estimasi lebih akurat: Bahasa Indonesia ~3.5 karakter per token
        return Math.ceil(text.length / 3.5)
    }

    // Buat ringkasan otomatis ketika history terlalu panjang
    function buildSessionSummary(trimmedMessages) {
        if (trimmedMessages.length < 4) return ""
        let topics = []
        for (let i = 0; i < Math.min(trimmedMessages.length, 6); i++) {
            let m = trimmedMessages[i]
            if (m.role === "user" && m.content.length > 10) {
                topics.push(m.content.substring(0, 60).replace(/\n/g, " "))
            }
        }
        if (topics.length === 0) return ""
        return root.summaryPrompt + " " + topics.join("; ") + "."
    }

    function buildApiMessages() {
        let sysPrompt = buildSystemPrompt()
        let sysTokens = estimateTokens(sysPrompt)

        // Budget dari contextThreshold settings.json
        let TOKEN_BUDGET = root.contextThreshold - sysTokens
        if (TOKEN_BUDGET < 1000) TOKEN_BUDGET = 1000 // Failsafe
        
        let usedTokens = 0
        let selectedMessages = []
        let trimmedMessages = []

        // Iterasi dari belakang (pesan terbaru selalu masuk)
        for (let i = messagesModel.count - 1; i >= 0; i--) {
            let m = messagesModel.get(i)
            if (m.role !== "user" && m.role !== "assistant") continue

            let msgTokens = estimateTokens(m.role + m.content)
            if (usedTokens + msgTokens > TOKEN_BUDGET) {
                // Simpan pesan yang terpotong untuk dijadikan summary
                for (let j = i; j >= 0; j--) {
                    let old = messagesModel.get(j)
                    if (old.role === "user" || old.role === "assistant") {
                        trimmedMessages.unshift({ role: old.role, content: old.content })
                    }
                }
                console.log("[lumi] Context trim: " + trimmedMessages.length + " pesan lama → summary")
                break
            }

            selectedMessages.unshift({ role: m.role, content: m.content })
            usedTokens += msgTokens
        }

        // Jika ada pesan yang terpotong, buat ringkasan singkat
        if (trimmedMessages.length > 0) {
            let summary = buildSessionSummary(trimmedMessages)
            if (summary) {
                root.sessionSummary = summary
            }
            selectedMessages.unshift({
                role: "system",
                content: "[" + trimmedMessages.length + " pesan awal dihapus. " +
                         (summary || "Konteks lanjutan dari percakapan sebelumnya.") + "]"
            })
        }

        return [{ role: "system", content: sysPrompt }].concat(selectedMessages)
    }

    function saveChatHistory() {
        let arr = []
        for (let i = 0; i < messagesModel.count; i++) {
            let msg = messagesModel.get(i)
            // Hanya simpan pesan user dan assistant yang bukan log internal
            if ((msg.role === "user" || msg.role === "assistant") &&
                !msg.content.startsWith("🟢") && !msg.content.startsWith("⚠️")) {
                arr.push({ role: msg.role, content: msg.content })
            }
        }
        let jsonStr = JSON.stringify(arr).replace(/'/g, "'\\''")
        saveHistoryProc.contentToSave = jsonStr
        saveHistoryProc.running = true
    }

    function sendMessage(text) {
        if (!text || text.trim() === "" || isThinking || !hasApiKey) return
        let trimmed = text.trim()

        if (trimmed === "/clear") {
            messagesModel.clear()
            saveChatHistory()
            messagesModel.append({ role: "assistant", content: "🟢 Chat history cleared. How can I help you today?" })
            msgInput.text = ""
            return
        }

        messagesModel.append({ role: "user", content: trimmed })
        msgInput.text = ""
        saveChatHistory()
        sendToGroq(buildApiMessages())
    }

    function sendToGroq(msgs) {
        root.isThinking = true
        Qt.callLater(() => { chatFlickable.scrollToBottom() })
        let tmpFile = "/tmp/lumi_req.json"
        Quickshell.execDetached(["bash", "-c", "printf '%s' '" + JSON.stringify(msgs).replace(/'/g, "'\\''") + "' > '" + tmpFile + "'"])
        groqProcess.command = ["bash", scriptDir + "/groq.sh", tmpFile, root.autoSpeak ? "true" : "false"]
        groqProcess.running = true
    }

    function saveApiKey(key) {
        if (!key || key.trim() === "") return
        Config.lumiApiKey = key.trim()
        Config.saveLumiConfig()
        messagesModel.append({ role: "assistant",
            content: "🟢 API key saved via Chat! I'm Lumi — your desktop AI. How can I help?" })
    }

    // React to initial key availability after Config loaded
    Connections {
        target: Config
        function onDataReadyChanged() {
            if (Config.dataReady && Config.lumiApiKey.length > 0) {
                loadHistoryProc.running = true
            }
        }
    }

    // ── Processes ─────────────────────────────────────────────────────────

    Process {
        id: groqProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.isThinking = false
                let reply = (this.text || "").trim()
                if (reply === "NO_KEY") {
                    root.hasApiKey = false
                } else if (reply.startsWith("ERROR:")) {
                    let errMsg = reply.slice(6).trim()
                    messagesModel.append({ role: "assistant", content: "⚠️ " + errMsg })
                    if (typeof LumiService !== "undefined") LumiService.groqError(errMsg)
                } else if (reply !== "") {
                    messagesModel.append({ role: "assistant", content: reply })
                    saveChatHistory()
                    if (typeof LumiService !== "undefined") LumiService._handleGroqComplete(reply)
                }
                Qt.callLater(() => { chatFlickable.scrollToBottom() })
            }
        }
    }

    Process {
        id: sttProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.isRecording = false
                let text = (this.text || "").trim()
                if (text !== "" && text !== "null") {
                    // Tampilkan teks transkripsi di SpeechOrb sebelum kirim ke Groq
                    speechOrb.sttTranscript = text
                    msgInput.text = text
                    msgInput.forceActiveFocus()
                    root.sendMessage(text) // Auto-send for seamless voice
                } else {
                    speechOrb.close()
                }
            }
        }
    }

    Process {
        id: loadHistoryProc
        command: ["cat", scriptDir + "/history.json"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let loaded = false
                try {
                    let text = (this.text || "").trim()
                    if (text !== "") {
                        let arr = JSON.parse(text)
                        if (arr.length > 0) {
                            for (let i = 0; i < arr.length; i++) {
                                messagesModel.append(arr[i])
                            }
                            loaded = true
                            Qt.callLater(() => { chatFlickable.scrollToBottom() })
                        }
                    }
                } catch (e) {
                    console.log("[lumi] Failed to parse history.json: " + e)
                }

                if (!loaded && messagesModel.count === 0) {
                    messagesModel.append({ role: "assistant",
                        content: "🟢 Hello! I'm Lumi. Ask me anything about your system or anything else!" })
                }
            }
        }
    }


    Process {
        id: saveHistoryProc
        property string contentToSave: ""
        command: ["bash", "-c", "printf '%s' '" + contentToSave + "' > '" + scriptDir + "/history.json'"]
        running: false
    }

    // ── Background Visuals ────────────────────────────────────────────────
    Rectangle {
        id: bg
        anchors.fill: parent
        radius: 12
        color: root.cBase
        clip: true

        property real time: 0
        NumberAnimation on time { from: 0; to: Math.PI * 2; duration: 15000; loops: Animation.Infinite; running: true }
        property real breathA: (Math.sin(time * 3) + 1) / 2
        property real orbAngle: 0
        NumberAnimation on orbAngle { from: 0; to: Math.PI * 2; duration: 60000; loops: Animation.Infinite; running: true }
        property color purpleColor: Qt.tint(root.cMauve, Qt.rgba(root.cPink.r, root.cPink.g, root.cPink.b, breathA * 0.3))
        property color blueColor:   Qt.tint(root.cBlue, Qt.rgba(root.cSapphire.r, root.cSapphire.g, root.cSapphire.b, breathA * 0.3))

        Rectangle {
            width: parent.width * 0.7; height: width; radius: width / 2
            x: parent.width/2 - width/2 + Math.cos(bg.orbAngle * 2) * 200
            y: parent.height/2 - height/2 + Math.sin(bg.orbAngle * 2) * 120
            opacity: 0.04; color: bg.purpleColor; antialiasing: true
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 64; blur: 1.0 }
        }
        Rectangle {
            width: parent.width * 0.65; height: width; radius: width / 2
            x: parent.width/2 - width/2 + Math.sin(bg.orbAngle * 1.5) * -180
            y: parent.height/2 - height/2 + Math.cos(bg.orbAngle * 1.5) * -100
            opacity: 0.03; color: bg.blueColor; antialiasing: true
            layer.enabled: true
            layer.effect: MultiEffect { blurEnabled: true; blurMax: 80; blur: 1.0 }
        }
    }

    // ── Main Layout ───────────────────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 0
        spacing: 0

        // ── Header ────────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 56
            color: Qt.rgba(root.cSurface0.r, root.cSurface0.g, root.cSurface0.b, 0.85)
            radius: 12

            Rectangle { // Bottom edge square
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 12
                color: parent.color
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Mini animated orb
                Rectangle {
                    width: 32; height: 32; radius: 16
                    property real pulse: (Math.sin(bg.time * (root.isThinking ? 8 : 3)) + 1) / 2
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.cMauve }
                        GradientStop { position: 1.0; color: root.cSapphire }
                    }
                    border.width: root.isThinking ? 2 : 1
                    border.color: Qt.rgba(1,1,1, 0.2 + parent.pulse * 0.3)
                    scale: root.isThinking ? (0.9 + parent.pulse * 0.15) : 1.0
                    Behavior on scale { NumberAnimation { duration: 100 } }
                }

                Text {
                    text: "LUMI"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 16
                    font.weight: Font.Black
                    font.letterSpacing: 3
                    color: root.cText
                }

                Text {
                    text: root.isThinking ? "thinking..." : (root.groqModel)
                    font.family: "JetBrains Mono"
                    font.pixelSize: 10
                    color: root.isThinking ? root.cMauve : root.cOverlay
                    opacity: 0.8
                    Behavior on color { ColorAnimation { duration: 300 } }
                }

                Item { Layout.fillWidth: true }

                // Mode Toggle (Chat ↔ Speech)
                Rectangle {
                    width: 70; height: 28; radius: 14
                    color: Qt.rgba(root.cSurface1.r, root.cSurface1.g, root.cSurface1.b, 0.5)
                    border.width: 1; border.color: root.cSurface1
                    
                    Rectangle {
                        width: 32; height: 24; radius: 12
                        color: root.speechMode ? root.cPink : root.cBlue
                        y: 2; x: root.speechMode ? 36 : 2
                        Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                    
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 4; spacing: 0
                        Item {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            Text {
                                anchors.centerIn: parent; text: "󰭹" // Chat
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 14
                                color: !root.speechMode ? root.cBase : root.cOverlay
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                        }
                        Item {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            Text {
                                anchors.centerIn: parent; text: "󰍬" // Mic
                                font.family: "Iosevka Nerd Font"; font.pixelSize: 14
                                color: root.speechMode ? root.cBase : root.cOverlay
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.speechMode = !root.speechMode
                            if (root.speechMode) {
                                root.isRecording = true
                                speechOrb.open()
                            } else {
                                root.isRecording = false
                                LumiService.cancelListening()
                                speechOrb.close()
                            }
                        }
                    }
                }

                // Auto-Speak button
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: speakMouse.containsMouse ? Qt.rgba(root.cMauve.r, root.cMauve.g, root.cMauve.b, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Text {
                        anchors.centerIn: parent; text: root.autoSpeak ? "󰕾" : "󰖁"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 18
                        color: root.autoSpeak ? root.cMauve : root.cOverlay
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                    MouseArea {
                        id: speakMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Config.lumiAutoSpeak = !Config.lumiAutoSpeak
                            if (!Config.lumiAutoSpeak) {
                                LumiService.muteTTS()
                            }
                        }
                    }
                }

                // Clear button
                Rectangle {
                    width: 28; height: 28; radius: 6
                    color: clearMouse.containsMouse ? Qt.rgba(root.cRed.r, root.cRed.g, root.cRed.b, 0.15) : "transparent"
                    Behavior on color { ColorAnimation { duration: 200 } }
                    visible: messagesModel.count > 0
                    Text {
                        anchors.centerIn: parent; text: "󰃢"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 16
                        color: clearMouse.containsMouse ? root.cRed : root.cOverlay
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                    MouseArea {
                        id: clearMouse; anchors.fill: parent; hoverEnabled: true
                        onClicked: messagesModel.clear()
                    }
                }
            }
        }

        // ── Setup Screen (no API key) ──────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.hasApiKey && !root.speechMode

            ColumnLayout {
                anchors.centerIn: parent
                width: parent.width * 0.75
                spacing: 16

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "󰚩"
                    font.family: "Iosevka Nerd Font"; font.pixelSize: 48
                    color: root.cMauve; opacity: 0.8
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Connect Lumi to Groq AI"
                    font.family: "JetBrains Mono"; font.pixelSize: 15; font.weight: Font.Bold
                    color: root.cText
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter; Layout.fillWidth: true
                    text: "Enter your key below, or configure it via Settings (Super + S > Lumi AI).\nGet a free API key at console.groq.com"
                    font.family: "JetBrains Mono"; font.pixelSize: 11
                    color: root.cSubtext; wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter
                }
                TextField {
                    id: apiKeyInput
                    Layout.fillWidth: true
                    placeholderText: "gsk_xxxxxxxxxxxxxxxxxxxxxxxx"
                    echoMode: TextInput.Password
                    font.family: "JetBrains Mono"; font.pixelSize: 13
                    color: root.cText
                    placeholderTextColor: root.cOverlay
                    background: Rectangle {
                        radius: 10
                        color: Qt.rgba(root.cSurface1.r, root.cSurface1.g, root.cSurface1.b, 0.8)
                        border.width: apiKeyInput.activeFocus ? 1 : 0
                        border.color: root.cMauve
                    }
                    leftPadding: 12; rightPadding: 12; topPadding: 10; bottomPadding: 10
                    onAccepted: root.saveApiKey(text)
                }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    width: 160; height: 38; radius: 10
                    color: saveMouse.containsMouse
                        ? Qt.rgba(root.cMauve.r, root.cMauve.g, root.cMauve.b, 0.9)
                        : Qt.rgba(root.cMauve.r, root.cMauve.g, root.cMauve.b, 0.7)
                    Behavior on color { ColorAnimation { duration: 200 } }
                    Text {
                        anchors.centerIn: parent
                        text: "Connect"
                        font.family: "JetBrains Mono"; font.pixelSize: 13; font.weight: Font.Bold
                        color: root.cCrust
                    }
                    MouseArea {
                        id: saveMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.saveApiKey(apiKeyInput.text)
                    }
                }
            }
        }

        // ── Chat Screen ───────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.hasApiKey && !root.speechMode
            clip: true

            Flickable {
                id: chatFlickable
                anchors.fill: parent
                contentHeight: Math.max(height, chatColumn.height + 16)
                clip: true

                function scrollToBottom() {
                    if (contentHeight > height)
                        contentY = contentHeight - height
                }

                onContentHeightChanged: scrollToBottom()

                Column {
                    id: chatColumn
                    width: parent.width
                    padding: 12
                    spacing: 10

                    Repeater {
                        model: messagesModel
                        delegate: Item {
                            width: chatColumn.width - 24
                            height: bubble.height + 4
                            property bool isUser: model.role === "user"

                            Rectangle {
                                id: bubble
                                width: Math.min(msgText.implicitWidth + 24, parent.width * 0.78)
                                height: msgText.height + 20
                                radius: 12
                                anchors.right: isUser ? parent.right : undefined
                                anchors.left:  isUser ? undefined : parent.left

                                color: isUser
                                    ? Qt.rgba(root.cMauve.r, root.cMauve.g, root.cMauve.b, 0.85)
                                    : Qt.rgba(root.cSurface1.r, root.cSurface1.g, root.cSurface1.b, 0.7)

                                // Tail indicator
                                Rectangle {
                                    width: 8; height: 8; radius: 2
                                    anchors.bottom: parent.bottom
                                    anchors.right:  isUser ? parent.right : undefined
                                    anchors.left:   isUser ? undefined : parent.left
                                    anchors.margins: 4
                                    color: parent.color
                                }

                                Text {
                                    id: msgText
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.margins: 12
                                    anchors.topMargin: 10
                                    text: model.content
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: 12
                                    color: isUser ? root.cCrust : root.cText
                                    wrapMode: Text.Wrap
                                    lineHeight: 1.4
                                }
                            }
                        }
                    }

                    // Thinking dots
                    Row {
                        visible: root.isThinking
                        spacing: 6
                        anchors.left: parent.left
                        anchors.leftMargin: 12

                        Repeater {
                            model: 3
                            Rectangle {
                                width: 8; height: 8; radius: 4
                                color: root.cMauve
                                opacity: 0.3
                                SequentialAnimation on opacity {
                                    running: root.isThinking
                                    loops: Animation.Infinite
                                    PauseAnimation { duration: index * 200 }
                                    NumberAnimation { to: 1.0; duration: 300 }
                                    NumberAnimation { to: 0.3; duration: 300 }
                                    PauseAnimation { duration: (2 - index) * 200 }
                                }
                            }
                        }
                    }
                }
            }

            // Scroll indicator
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 2
                y: chatFlickable.visibleArea.yPosition * parent.height
                width: 3
                height: chatFlickable.visibleArea.heightRatio * parent.height
                radius: 2
                color: root.cMauve
                opacity: chatFlickable.moving ? 0.6 : 0.0
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }
        }

        // ── Input Area ────────────────────────────────────────────────────
        Rectangle {
            Layout.fillWidth: true
            height: 60
            color: Qt.rgba(root.cSurface0.r, root.cSurface0.g, root.cSurface0.b, 0.85)
            radius: 12
            visible: root.hasApiKey

            Rectangle { // Top edge square
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 12
                color: parent.color
            }

            // Separator line
            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: Qt.rgba(root.cOverlay.r, root.cOverlay.g, root.cOverlay.b, 0.2)
            }

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 8

                // Mic Button (Replaced by WaveIcon)
                WaveIcon {
                    width: 38; height: 38
                    enabled: !root.isThinking
                    speechState: root.isRecording ? "listening" : "idle"
                    primaryColor: root.cOverlay
                    speakingColor: root.cRed
                    onIconClicked: {
                        if (!root.isRecording) {
                            root.isRecording = true
                            root.speechMode = true
                            speechOrb.open()
                            Quickshell.execDetached(["bash", root.scriptDir + "/stt.sh", "start"])
                        } else {
                            sttProcess.command = ["bash", root.scriptDir + "/stt.sh", "stop"]
                            sttProcess.running = true
                        }
                    }
                }

                TextField {
                    id: msgInput
                    Layout.fillWidth: true
                    placeholderText: root.isThinking ? "Waiting for response..." : "Ask Lumi anything..."
                    enabled: !root.isThinking
                    font.family: "JetBrains Mono"; font.pixelSize: 13
                    color: root.cText
                    placeholderTextColor: root.cOverlay
                    background: Rectangle {
                        radius: 8
                        color: Qt.rgba(root.cSurface1.r, root.cSurface1.g, root.cSurface1.b, 0.6)
                        border.width: msgInput.activeFocus ? 1 : 0
                        border.color: root.cMauve
                        Behavior on border.width { NumberAnimation { duration: 150 } }
                    }
                    leftPadding: 12; rightPadding: 12; topPadding: 8; bottomPadding: 8
                    onAccepted: root.sendMessage(text)

                    Component.onCompleted: forceActiveFocus()
                }

                Rectangle {
                    width: 38; height: 38; radius: 10
                    enabled: !root.isThinking && msgInput.text.trim() !== ""
                    opacity: enabled ? 1.0 : 0.4
                    Behavior on opacity { NumberAnimation { duration: 200 } }

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: root.cMauve }
                        GradientStop { position: 1.0; color: root.cSapphire }
                    }

                    scale: sendMouse.containsMouse && !root.isThinking ? 1.08 : 1.0
                    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

                    Text {
                        anchors.centerIn: parent; text: "󰒊"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 18
                        color: root.cCrust
                    }
                    MouseArea {
                        id: sendMouse; anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.sendMessage(msgInput.text)
                    }
                }
            }
        }
    }

    // ── Speech Orb Overlay ────────────────────────────────────────────────
    SpeechOrb {
        id: speechOrb
        anchors.fill: parent
        z: 100
        visible: root.speechMode

        primaryColor: root.cMauve
        primaryContainerColor: root.cSapphire
        secondaryContainerColor: root.cBlue
        tertiaryColor: root.cPink
        onBackgroundColor: root.cText
        surfaceVariantColor: Qt.rgba(root.cSurface1.r, root.cSurface1.g, root.cSurface1.b, 0.8)

    }

    Component.onCompleted: {
        if (root.speechMode) {
            root.isRecording = true
            speechOrb.open()
        }
    }
}
