import QtQuick

Item {
    id: root

    width: 320
    height: contentCol.implicitHeight

    property string transcript: ""
    property string speechState: "idle"
    property color textColor: "white"
    property color cursorColor: "#4DB6AC"

    // Tampil hanya saat state "thinking" DAN ada teks
    opacity: (speechState === "thinking" && transcript.length > 0) ? 1.0 : 0.0

    visible: true

    Behavior on opacity {
        NumberAnimation { duration: 300; easing.type: Easing.InOutCubic }
    }

    // ── Word-by-word reveal ─────────────────────────────────────────────
    property string displayText: ""
    property var wordList: []
    property int wordIdx: 0

    // Simpan kata-kata saat transcript berubah, TAPI jangan mulai timer dulu
    onTranscriptChanged: {
        displayText = ""
        wordIdx = 0
        wordList = transcript.split(" ").filter(function(w) { return w.length > 0 })
        // Timer akan dimulai di onSpeechStateChanged saat state = "thinking"
    }

    Timer {
        id: wordTimer
        interval: 55
        repeat: true
        onTriggered: {
            if (root.wordIdx < root.wordList.length) {
                root.displayText += (root.wordIdx > 0 ? " " : "") + root.wordList[root.wordIdx]
                root.wordIdx++
            } else {
                wordTimer.stop()
            }
        }
    }

    onSpeechStateChanged: {
        if (speechState === "listening") {
            // Reset saat sesi baru
            wordTimer.stop()
            displayText = ""
            wordIdx = 0
            wordList = []
        } else if (speechState === "thinking") {
            // Mulai reveal kata per kata SEKARANG saat komponen sudah visible
            if (wordList.length > 0 && !wordTimer.running) {
                displayText = ""
                wordIdx = 0
                wordTimer.start()
            }
        }
    }

    Column {
        id: contentCol
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        spacing: 0

        // Garis tipis pemisah
        Rectangle {
            width: 36
            height: 1
            anchors.horizontalCenter: parent.horizontalCenter
            color: root.textColor
            opacity: 0.18
            visible: root.displayText.length > 0
        }

        Item { width: 1; height: 10 }

        // Teks transkripsi
        Text {
            id: transcriptText
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            text: root.displayText
            color: root.textColor
            opacity: 0.75
            font.family: ["Geist", "Outfit", "DM Sans", "Ubuntu"]
            font.pixelSize: 15
            font.weight: Font.Light
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            lineHeight: 1.5

            // Blinking cursor saat masih mengungkap kata
            Rectangle {
                id: cursor
                width: 2
                height: transcriptText.font.pixelSize * 0.85
                color: root.cursorColor
                radius: 1
                visible: wordTimer.running
                anchors {
                    left: transcriptText.right
                    leftMargin: 3
                    verticalCenter: transcriptText.verticalCenter
                }

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: wordTimer.running
                    NumberAnimation { to: 0; duration: 450; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 450; easing.type: Easing.InOutSine }
                }
            }
        }

        Item { width: 1; height: 8 }
    }
}
