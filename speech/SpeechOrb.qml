import QtQuick
import QtQuick.Effects
import Quickshell.Io
import Quickshell
import "."
import "../../"


Rectangle {
    id: root
    width: 420; height: 560
    color: "#000000"

    property string speechState: "idle"
    property string responseText: ""
    property string sttTranscript: ""
    property bool isAborting: false
    property string greetingName: ""
    property string greetingText: ""

    // Colors — wired to Matugen via parent or defaults
    property color primaryColor:            "#4DB6AC"
    property color primaryContainerColor:   "#00695C"
    property color secondaryContainerColor: "#B2DFDB"
    property color tertiaryColor:           "#26A69A"
    property color onBackgroundColor:       "#E0F2F1"
    property color surfaceVariantColor:     "#1A2E2C"

    property real targetGlowRadius:
        speechState === "listening" ? 50 :
        speechState === "speaking"  ? 50 : 35

    property var micLevels: [0.08, 0.08, 0.08, 0.08, 0.08]

    Process {
        id: micProc
        running: false
        command: ["python3", "/home/dikapradnyanta/.config/hypr/scripts/quickshell/lumi/mic_level.py"]
        stdout: SplitParser {
            onRead: function(line) {
                var parts = line.trim().split(" ")
                if (parts.length === 5) {
                    var levels = []
                    for (var i = 0; i < 5; i++) {
                        var v = parseFloat(parts[i])
                        levels.push(isNaN(v) ? 0.08 : Math.max(0.08, Math.min(1.0, v)))
                    }
                    root.micLevels = levels
                }
            }
        }
    }

    onSpeechStateChanged: {
        if (speechState === "listening") {
            micProc.running = true
        } else {
            micProc.running = false
            root.micLevels = [0.08, 0.08, 0.08, 0.08, 0.08]
        }
    }

    // Enter animation
    opacity: 0; scale: 0.9
    visible: opacity > 0
    
    onVisibleChanged: {
        if (!visible) {
            speechState = "idle"
            micProc.running = false
            LumiService.forceStopAll()
        }
    }

    signal closeRequested()

    function open() {
        visible = true
        enterAnim.start()
        speechState = "listening"
        responseText = ""
        sttTranscript = ""
        
        let uname = Quickshell.env("USER") || "Robin"
        let formattedName = uname.length > 0 ? uname.charAt(0).toUpperCase() + uname.slice(1) : "Robin"
        root.greetingName = "Hello " + formattedName
        root.greetingText = "How can I help you today?"
        
        LumiService.startListening()
    }

    function restartListening() {
        LumiService.muteTTS()
        speechState = "listening"
        sttTranscript = ""
        responseText = ""
        LumiService.startListening()
    }

    function close() {
        exitAnim.start()
    }

    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: 250; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "scale"; from: 0.9; to: 1; duration: 250; easing.type: Easing.OutBack }
    }

    // ── Top Right Force Close Button ──────────────────────────────
    Rectangle {
        width: 32; height: 32; radius: 16
        color: closeMa.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.3) : Qt.rgba(1, 1, 1, 0.08)
        border.color: closeMa.containsMouse ? "#FF5252" : Qt.rgba(1, 1, 1, 0.15)
        border.width: 1
        anchors.top: parent.top; anchors.right: parent.right
        anchors.topMargin: 16; anchors.rightMargin: 16
        z: 10

        Text {
            anchors.centerIn: parent
            text: "󰅖"
            font.family: "Iosevka Nerd Font"
            font.pixelSize: 16
            color: closeMa.containsMouse ? "#FF5252" : root.onBackgroundColor
        }

        MouseArea {
            id: closeMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                LumiService.forceStopAll()
                exitAnim.start()
            }
        }
    }

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 40
        spacing: root.speechState === "speaking" ? -60 : 0
        Behavior on spacing { NumberAnimation { duration: 400; easing.type: Easing.InOutCubic } }

        // Orb + Rings
        Item {
            width: 340; height: 340
            anchors.horizontalCenter: parent.horizontalCenter
            scale: root.speechState === "speaking" ? 0.6 : 1.0
            Behavior on scale { NumberAnimation { duration: 400; easing.type: Easing.InOutCubic } }

            RingSystem {
                anchors.fill: parent
                ringColor: root.secondaryContainerColor
                speechState: root.speechState
            }

            OrbCore {
                id: orbCore
                anchors.centerIn: parent
                primaryColor: root.primaryColor
                containerColor: root.primaryContainerColor
                tertiaryColor: root.tertiaryColor
                glowRadius: root.targetGlowRadius
                speechState: root.speechState

                audioLevel: {
                    if (root.speechState === "listening") {
                        var levels = root.micLevels
                        var sum = 0
                        for (var i = 0; i < levels.length; i++) sum += levels[i]
                        return Math.min(1.0, (sum / levels.length) * 1.5)
                    }
                    return root.speechState === "speaking" ? 0.4 + Math.random() * 0.3 : 0.0
                }

                // Pass the full array to OrbCore to drive plasma rings
                micLevels: root.micLevels

                Behavior on glowRadius { NumberAnimation { duration: 400; easing.type: Easing.InOutSine } }
            }

            MouseArea {
                anchors.centerIn: parent
                width: 220; height: 220
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.speechState === "idle" || root.speechState === "speaking") {
                        root.restartListening()
                    }
                }
            }
        }

        Item { width: 1; height: 12 }

        StateLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            speechState: root.speechState
            textColor: root.onBackgroundColor
        }

        Item { width: 1; height: 16 }
        
        // ── Apple Intelligence Style Greeting ──────────────────
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            visible: root.speechState === "listening" && root.sttTranscript === ""
            opacity: visible ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }

            Text {
                text: root.greetingName
                font.family: "Outfit"
                font.pixelSize: 16
                font.weight: Font.Medium
                color: Qt.rgba(root.onBackgroundColor.r, root.onBackgroundColor.g, root.onBackgroundColor.b, 0.7)
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: root.greetingText
                font.family: "Outfit"
                font.pixelSize: 28
                font.weight: Font.Bold
                color: root.onBackgroundColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }

        // Teks transkripsi STT — tampil setelah user selesai bicara
        SttTranscript {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 320
            transcript: root.sttTranscript
            speechState: root.speechState
            textColor: root.onBackgroundColor
            cursorColor: root.primaryColor
        }

        Item { width: 1; height: 8 }

        // ── Thinking indicator — tiga titik naik turun (gaya Gemini) ──────
        Row {
            id: thinkingDots
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 9
            visible: root.speechState === "thinking"
            opacity: root.speechState === "thinking" ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.InOutCubic } }

            Repeater {
                model: 3
                delegate: Item {
                    width: 9; height: 20
                    required property int index

                    Rectangle {
                        id: dot
                        width: 9; height: 9
                        radius: 4.5
                        color: root.primaryColor
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 6

                        SequentialAnimation on y {
                            loops: Animation.Infinite
                            running: root.speechState === "thinking"
                            PauseAnimation { duration: index * 130 }
                            NumberAnimation { to: 0;  duration: 280; easing.type: Easing.OutQuad }
                            NumberAnimation { to: 6;  duration: 280; easing.type: Easing.InQuad }
                            PauseAnimation { duration: (2 - index) * 130 }
                        }

                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: root.speechState === "thinking"
                            PauseAnimation { duration: index * 130 }
                            NumberAnimation { to: 1.0; duration: 200 }
                            NumberAnimation { to: 0.4; duration: 200 }
                            PauseAnimation { duration: (2 - index) * 130 }
                        }
                    }
                }
            }
            
            Text {
                text: "Menganalisis audio..."
                color: root.primaryColor
                font.family: "Outfit"
                font.pixelSize: 13
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
                
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: root.speechState === "thinking"
                    NumberAnimation { from: 0.3; to: 1.0; duration: 800; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.0; to: 0.3; duration: 800; easing.type: Easing.InOutSine }
                }
            }
        }

        Item { width: 1; height: 10 }

        // Response text
        ResponseDisplay {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 360
            fullText: root.responseText
            speechState: root.speechState
            textColor: root.onBackgroundColor
            bgColor: root.surfaceVariantColor
            borderColor: root.primaryColor
        }
        
        Item { width: 1; height: 24 }

        // ── Manual Control Buttons (Listening State Only) ───────────────
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16
            visible: root.speechState === "listening"
            opacity: root.speechState === "listening" ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 220 } }

            Text {
                text: "Tekan Esc atau klik area luar untuk batal"
                font.family: "Outfit"
                font.pixelSize: 12
                color: Qt.rgba(root.onBackgroundColor.r, root.onBackgroundColor.g, root.onBackgroundColor.b, 0.6)
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Answer Now Push Button
            Rectangle {
                width: 145; height: 38; radius: 19
                color: answerMa.containsMouse ? root.primaryContainerColor : root.primaryColor
                scale: answerMa.pressed ? 0.95 : (answerMa.containsMouse ? 1.04 : 1.0)
                Behavior on scale { NumberAnimation { duration: 120 } }
                Behavior on color { ColorAnimation { duration: 150 } }
                anchors.horizontalCenter: parent.horizontalCenter
                
                Row {
                    anchors.centerIn: parent; spacing: 8
                    Text { text: "󰄬"; font.family: "Iosevka Nerd Font"; color: root.onBackgroundColor; font.pixelSize: 15; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Answer Now"; font.family: "Outfit"; font.weight: Font.SemiBold; color: root.onBackgroundColor; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                    id: answerMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Quickshell.execDetached(["bash", "/home/dikapradnyanta/.config/hypr/scripts/quickshell/lumi/stt.sh", "stop"])
                    }
                }
            }
        }
    }

    // Breathing (idle)
    SequentialAnimation {
        running: root.speechState === "idle"
        loops: Animation.Infinite
        NumberAnimation { target: orbCore; property: "orbScale"; from: 1.0; to: 1.04; duration: 2500; easing.type: Easing.InOutSine }
        NumberAnimation { target: orbCore; property: "orbScale"; from: 1.04; to: 1.0; duration: 2500; easing.type: Easing.InOutSine }
    }

    // Speaking oscillation
    SequentialAnimation {
        running: root.speechState === "speaking"
        loops: Animation.Infinite
        NumberAnimation { target: orbCore; property: "orbScale"; from: 1.0; to: 1.08; duration: 300; easing.type: Easing.InOutSine }
        NumberAnimation { target: orbCore; property: "orbScale"; from: 1.08; to: 1.0; duration: 300; easing.type: Easing.InOutSine }
    }

    // Timeout saat listening
    Timer {
        interval: 8000
        running: root.speechState === "listening"
        onTriggered: { root.speechState = "idle"; LumiService.cancelListening() }
    }

    // IPC Handlers
    Connections {
        target: LumiService
        function onSttComplete(text) {
            if (root.isAborting) {
                root.isAborting = false
                return
            }
            let trimmed = (text || "").trim()
            if (trimmed !== "" && trimmed !== "null") {
                root.sttTranscript = trimmed
                root.speechState = "thinking"
            } else {
                root.sttTranscript = ""
                root.responseText = "Tidak ada suara terdeteksi. Ketuk Orb untuk bicara."
                root.speechState = "idle"
            }
        }
        function onStreamStart() { 
            if (!root.isAborting) root.speechState = "speaking" 
        }
        function onGroqComplete(text) {
            root.responseText = text
            root.speechState = "speaking"
        }
        function onTtsComplete() { root.speechState = "idle" }
        function onGroqError(msg) {
            root.responseText = "Error: " + msg
            root.speechState = "idle"
        }
    }

    // Dismiss
    MouseArea { anchors.fill: parent; z: -1; onClicked: exitAnim.start() }
    ParallelAnimation {
        id: exitAnim
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 200; easing.type: Easing.InCubic }
        NumberAnimation { target: root; property: "scale"; to: 0.95; duration: 200 }
        onFinished: {
            root.visible = false
            root.closeRequested()
        }
    }

    focus: true
    Keys.onEscapePressed: {
        LumiService.forceStopAll()
        exitAnim.start()
    }
}
