import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "."
import "../../"

Rectangle {
    id: root
    width: 420; height: 500
    color: "#12131C"
    radius: 20
    border.color: Qt.rgba(1, 1, 1, 0.12)
    border.width: 1

    property string speechState: "idle" // "idle", "listening", "thinking", "speaking"
    property string responseText: ""
    property string sttTranscript: ""
    property bool isAborting: false
    property string greetingName: ""
    property string greetingText: ""

    // Theme colors
    property color primaryColor:            "#4DB6AC"
    property color primaryContainerColor:   "#00695C"
    property color secondaryContainerColor: "#B2DFDB"
    property color tertiaryColor:           "#26A69A"
    property color onBackgroundColor:       "#E0F2F1"
    property color surfaceVariantColor:     "#1E202E"

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

    // Enter & Exit Animations
    opacity: 0; scale: 0.95
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
        root.greetingName = "Halo " + formattedName
        root.greetingText = "Ada yang bisa Lumi bantu?"
        
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
        LumiService.forceStopAll()
        exitAnim.start()
    }

    ParallelAnimation {
        id: enterAnim
        NumberAnimation { target: root; property: "opacity"; from: 0; to: 1; duration: 200; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "scale"; from: 0.95; to: 1; duration: 200; easing.type: Easing.OutCubic }
    }

    // ── Top Bar Header ──────────────────────────────────────────
    RowLayout {
        anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
        anchors.margins: 20
        z: 10

        RowLayout {
            spacing: 8
            Text {
                text: "󰍬"
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 18
                color: root.primaryColor
            }
            Text {
                text: "Lumi Voice Mode"
                font.family: "Outfit"
                font.pixelSize: 15
                font.bold: true
                color: root.onBackgroundColor
            }
        }

        Item { Layout.fillWidth: true }

        // Top Right Force Close (X) Button
        Rectangle {
            width: 32; height: 32; radius: 16
            color: closeMa.containsMouse ? Qt.rgba(1, 0.3, 0.3, 0.3) : Qt.rgba(1, 1, 1, 0.08)
            border.color: closeMa.containsMouse ? "#FF5252" : Qt.rgba(1, 1, 1, 0.15)
            border.width: 1

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
                onClicked: root.close()
            }
        }
    }

    // ── Main Content Column ─────────────────────────────────────
    ColumnLayout {
        anchors.top: parent.top
        anchors.topMargin: 70
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        spacing: 16

        // State Icon Card (Simple & Functional)
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 100; Layout.preferredHeight: 100
            radius: 50
            color: root.speechState === "listening" ? Qt.rgba(0.3, 0.7, 0.6, 0.15) :
                   root.speechState === "thinking"  ? Qt.rgba(0.5, 0.4, 0.9, 0.15) :
                   root.speechState === "speaking"  ? Qt.rgba(0.2, 0.8, 0.4, 0.15) : Qt.rgba(1, 1, 1, 0.05)
            border.color: root.primaryColor
            border.width: 1.5

            Text {
                anchors.centerIn: parent
                font.family: "Iosevka Nerd Font"
                font.pixelSize: 42
                color: root.primaryColor
                text: root.speechState === "listening" ? "󰍬" :
                      root.speechState === "thinking"  ? "󰑮" :
                      root.speechState === "speaking"  ? "󰓃" : "󰍭"
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (root.speechState === "idle" || root.speechState === "speaking") {
                        root.restartListening()
                    }
                }
            }
        }

        // State Text Label
        StateLabel {
            Layout.alignment: Qt.AlignHCenter
            speechState: root.speechState
            textColor: root.onBackgroundColor
        }

        // Greeting
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4
            visible: root.speechState === "listening" && root.sttTranscript === ""
            Text {
                text: root.greetingName
                font.family: "Outfit"
                font.pixelSize: 14
                color: Qt.rgba(root.onBackgroundColor.r, root.onBackgroundColor.g, root.onBackgroundColor.b, 0.7)
                Layout.alignment: Qt.AlignHCenter
            }
            Text {
                text: root.greetingText
                font.family: "Outfit"
                font.pixelSize: 22
                font.bold: true
                color: root.onBackgroundColor
                Layout.alignment: Qt.AlignHCenter
            }
        }

        // Transkripsi Suara (STT Transcript)
        SttTranscript {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 360
            transcript: root.sttTranscript
            speechState: root.speechState
            textColor: root.onBackgroundColor
            cursorColor: root.primaryColor
        }

        // Response Display Box
        ResponseDisplay {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 360
            fullText: root.responseText
            speechState: root.speechState
            textColor: root.onBackgroundColor
            bgColor: root.surfaceVariantColor
            borderColor: root.primaryColor
        }

        Item { Layout.fillHeight: true }

        // Manual Controls (Answer Now Button)
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            visible: root.speechState === "listening"

            Rectangle {
                width: 140; height: 38; radius: 19
                color: answerMa.containsMouse ? root.primaryContainerColor : root.primaryColor

                Row {
                    anchors.centerIn: parent; spacing: 8
                    Text { text: "󰄬"; font.family: "Iosevka Nerd Font"; color: root.onBackgroundColor; font.pixelSize: 15 }
                    Text { text: "Answer Now"; font.family: "Outfit"; font.bold: true; color: root.onBackgroundColor; font.pixelSize: 13 }
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

        Text {
            text: "Tekan Esc atau klik X untuk menutup mode suara"
            font.family: "Outfit"
            font.pixelSize: 11
            color: Qt.rgba(root.onBackgroundColor.r, root.onBackgroundColor.g, root.onBackgroundColor.b, 0.5)
            Layout.alignment: Qt.AlignHCenter
        }
    }

    // Dismiss animation
    ParallelAnimation {
        id: exitAnim
        NumberAnimation { target: root; property: "opacity"; to: 0; duration: 150 }
        NumberAnimation { target: root; property: "scale"; to: 0.95; duration: 150 }
        onFinished: {
            root.visible = false
            root.closeRequested()
        }
    }

    focus: true
    Keys.onEscapePressed: root.close()
}
