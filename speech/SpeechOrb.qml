import QtQuick
import QtQuick.Effects
import "."
import "../../"


Rectangle {
    id: root
    width: 420; height: 560
    color: "#000000"

    property string speechState: "idle"
    property string responseText: ""
    property string sttTranscript: ""

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

        // Wave icon (Hanya visualizer input mic)
        WaveIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            speechState: root.speechState
            primaryColor: root.primaryColor
            speakingColor: root.tertiaryColor
            // onClicked dihapus karena ini hanya indikator
        }

        Item { width: 1; height: 14 }

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
            root.sttTranscript = text
            root.speechState = "thinking"
        }
        function onStreamStart() { root.speechState = "speaking" }
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
