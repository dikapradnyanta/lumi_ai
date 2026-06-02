import QtQuick
import QtQuick.Effects
import Quickshell.Io
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

    function open() {
        visible = true
        enterAnim.start()
        speechState = "listening"
        responseText = ""
        sttTranscript = ""
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

    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 50
        spacing: 0

        // Orb + Rings
        Item {
            width: 340; height: 340
            anchors.horizontalCenter: parent.horizontalCenter

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
                glowColor: root.tertiaryColor
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
        }

        Item { width: 1; height: 12 }

        StateLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            speechState: root.speechState
            textColor: root.onBackgroundColor
        }

        Item { width: 1; height: 16 }

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
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 20
            visible: root.speechState === "listening"
            opacity: root.speechState === "listening" ? 1.0 : 0.0
            Behavior on opacity { NumberAnimation { duration: 220 } }

            // Cancel Button
            Rectangle {
                width: 120; height: 36; radius: 18
                color: cancelMa.containsMouse ? Qt.rgba(root.tertiaryColor.r, root.tertiaryColor.g, root.tertiaryColor.b, 0.2) : "transparent"
                border.color: Qt.rgba(root.tertiaryColor.r, root.tertiaryColor.g, root.tertiaryColor.b, 0.5)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 150 } }
                
                Row {
                    anchors.centerIn: parent; spacing: 6
                    Text { text: "󰅖"; font.family: "Iosevka Nerd Font"; color: root.tertiaryColor; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Cancel"; font.family: "Outfit"; color: root.tertiaryColor; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
                }

                MouseArea {
                    id: cancelMa; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        root.isAborting = true
                        root.speechState = "idle"
                        Quickshell.execDetached(["bash", "/home/dikapradnyanta/.config/hypr/scripts/quickshell/lumi/stt.sh", "abort"])
                        LumiService.cancelListening()
                        root.close()
                    }
                }
            }

            // Answer Now Button
            Rectangle {
                width: 140; height: 36; radius: 18
                color: answerMa.containsMouse ? root.primaryContainerColor : root.primaryColor
                Behavior on color { ColorAnimation { duration: 150 } }
                
                Row {
                    anchors.centerIn: parent; spacing: 6
                    Text { text: "󰔡"; font.family: "Iosevka Nerd Font"; color: root.onBackgroundColor; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Answer Now"; font.family: "Outfit"; font.weight: Font.Medium; color: root.onBackgroundColor; font.pixelSize: 13; anchors.verticalCenter: parent.verticalCenter }
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
            root.sttTranscript = text
            root.speechState = "thinking"
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
        onFinished: root.visible = false
    }

    focus: true
    Keys.onEscapePressed: exitAnim.start()
}
