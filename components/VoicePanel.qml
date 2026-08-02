import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../"  // MatugenColors (unused)

// ============================================================
// VoicePanel.qml — Full Voice Mode Interface (design.md §2.2)
// State machine: Idle → Listening → Thinking → Speaking → Error
// ============================================================
Item {
    id: root

    // State machine input dari Lumi.qml
    // voiceState: "idle" | "listening" | "thinking" | "speaking" | "error"
    property string voiceState: "idle"
    property string subtitleText: ""
    property string userTranscript: ""
    property int spokenWordIndex: -1

    // Signals
    signal startListening()
    signal stopListening()
    signal cancelSession()
    signal answerNow()

    // ── Mic level analyzer process (python3 mic_level.py) ────
    property var micLevels: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

    readonly property string backendDir: Quickshell.env("HOME") +
        "/.config/hypr/scripts/quickshell/lumi2/backend"

    Process {
        id: micProc
        command: ["python3", root.backendDir + "/mic_level.py"]
        running: root.voiceState === "listening" || root.voiceState === "idle"

        stdout: SplitParser {
            onRead: (data) => {
                let parts = data.trim().split(/\s+/)
                if (parts.length >= 7) {
                    let parsed = []
                    for (let i = 0; i < 7; i++) {
                        parsed.push(parseFloat(parts[i]) || 0.0)
                    }
                    root.micLevels = parsed
                }
            }
        }
    }

    // ── Explicit dark background (prevent Qt transparent/white rendering) ──
    Rectangle {
        anchors.fill: parent
        color: "#0d0e13"
        z: -1
    }

    // ── Layout utama ─────────────────────────────────────────
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 24

        Item { Layout.fillHeight: true } // Spacer atas

        // ============================================================
        // 1. STATUS LABEL (DI ATAS VISUALIZER)
        // ============================================================
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: {
                switch (root.voiceState) {
                    case "listening": return "Listening..."
                    case "thinking":  return "Thinking..."
                    case "speaking":  return "Speaking..."
                    case "error":     return "Error"
                    default:          return "Tap microphone to speak"
                }
            }
            font.pixelSize: 20
            font.bold: true
            font.family: "Inter, sans-serif"
            color: {
                switch (root.voiceState) {
                    case "listening": return "#c1c5dd"
                    case "thinking":  return "#b4c5ff"
                    case "speaking":  return "#c1c5dd"
                    case "error":     return "#ffb4ab"
                    default:          return "#c6c6d0"
                }
            }
            Behavior on color { ColorAnimation { duration: 200 } }
        }

        // ============================================================
        // 2. VISUALIZER CENTER (Waveform atau Thinking Orbs) (DI TENGAH)
        // ============================================================
        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth:  240
            implicitHeight: 140

            // Ambient Aura Glow (ChatGPT 4o / Siri style)
            Rectangle {
                anchors.centerIn: parent
                width: 180; height: 180
                radius: 90
                color: root.voiceState === "listening" ? "#c1c5dd" :
                       root.voiceState === "thinking"  ? "#b4c5ff" :
                       root.voiceState === "speaking"  ? "#e2bbdb" : "#1e1f25"
                opacity: root.voiceState === "idle" ? 0.04 : 0.18

                Behavior on opacity { NumberAnimation { duration: 300 } }
                Behavior on color { ColorAnimation { duration: 300 } }

                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 0.8
                    blurMax: 32
                }
            }

            // ── Mode 1: Listening / Idle / Speaking → Waveform ──────
            Waveform {
                anchors.centerIn: parent
                visible: root.voiceState === "idle" ||
                         root.voiceState === "listening" ||
                         root.voiceState === "speaking"
                levels: root.micLevels
                state:  root.voiceState === "listening" ? "listening" :
                        root.voiceState === "speaking"  ? "speaking"  : "idle"
            }

            // ── Mode 2: Thinking → Glowing Orbs ──────────────────────
            Item {
                anchors.centerIn: parent
                visible: root.voiceState === "thinking"
                implicitWidth:  120
                implicitHeight: 120

                // Central orb
                Rectangle {
                    anchors.centerIn: parent
                    width: 60; height: 60
                    radius: 30
                    color: "#b4c5ff"
                    opacity: 0.8

                    SequentialAnimation on scale {
                        loops: Animation.Infinite
                        running: root.voiceState === "thinking"
                        NumberAnimation { to: 1.25; duration: 600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.95; duration: 600; easing.type: Easing.InOutSine }
                    }

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        blurEnabled: true
                        blur: 0.5
                    }
                }

                // Rotating ring dots
                Item {
                    anchors.fill: parent
                    RotationAnimation on rotation {
                        loops: Animation.Infinite
                        from: 0; to: 360
                        duration: 3000
                        running: root.voiceState === "thinking"
                    }

                    Repeater {
                        model: 3
                        Rectangle {
                            width: 12; height: 12
                            radius: 6
                            color: "#b4c5ff"
                            x: 60 + 40 * Math.cos(index * 2 * Math.PI / 3) - 6
                            y: 60 + 40 * Math.sin(index * 2 * Math.PI / 3) - 6
                        }
                    }
                }
            }

            // ── Mode 3: Error ────────────────────────────────────────
            Rectangle {
                anchors.centerIn: parent
                visible: root.voiceState === "error"
                width: 64; height: 64
                radius: 32
                color: Qt.rgba(1.0, 0.7059, 0.6706, 0.2)
                border.color: "#ffb4ab"
                border.width: 2

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 24
                    color: "#ffb4ab"
                }
            }
        }

        // ============================================================
        // 3. USER STT TRANSCRIPT & SUBTITLE (DI BAWAH VISUALIZER)
        // ============================================================
        // 3. USER STT TRANSCRIPT & SUBTITLE (DI BAWAH VISUALIZER)
        // ============================================================
        // Karaoke flow saat Lumi berbicara (speaking mode)
        Flow {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(parent.width - 32, 520)
            spacing: 6
            visible: root.voiceState === "speaking" && root.subtitleText.length > 0

            Repeater {
                model: root.subtitleText.trim().split(/\s+/)
                Text {
                    required property string modelData
                    required property int index
                    text: modelData
                    font.pixelSize: index === root.spokenWordIndex ? 17 : 15
                    font.bold: index === root.spokenWordIndex
                    font.family: "Inter, sans-serif"
                    color: {
                        if (index === root.spokenWordIndex) return "#c1c5dd"
                        if (index < root.spokenWordIndex) return "#e3e2e9"
                        return Qt.rgba(0.7765, 0.7765, 0.8157, 0.4)
                    }
                    Behavior on color { ColorAnimation { duration: 150 } }
                    Behavior on font.pixelSize { NumberAnimation { duration: 120 } }
                }
            }
        }

        // Teks standar saat listening / thinking / idle / error
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(parent.width - 32, 500)
            text: root.userTranscript !== "" ? root.userTranscript : root.subtitleText
            font.pixelSize: 15
            font.family: "Inter, sans-serif"
            color: "#e3e2e9"
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: root.voiceState !== "speaking" && text.length > 0
            maximumLineCount: 4
            elide: Text.ElideRight
        }

        Item { Layout.fillHeight: true } // Spacer bawah

        // ============================================================
        // CONTROLS BAR (design.md §2.2 - 3 Action Buttons)
        // Stop/Interrupt | Answer Now | Cancel/Close
        // ============================================================
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            // 1. Cancel / Close Button
            Rectangle {
                implicitWidth: 48; implicitHeight: 48
                radius: 24
                color: cancelHover.containsMouse ? "#292a2f" : "#1e1f25"
                border.color: "#292a2f"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "✕"
                    font.pixelSize: 16
                    color: "#c6c6d0"
                }

                MouseArea {
                    id: cancelHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cancelSession()
                }
            }

            // 2. Main Mic / Action Button (ChatGPT 4o ring style)
            Rectangle {
                implicitWidth: 60; implicitHeight: 60
                radius: 30
                color: "transparent"
                border.color: root.voiceState === "listening" ? "#c1c5dd" :
                              root.voiceState === "speaking"  ? "#e2bbdb" : "#b4c5ff"
                border.width: 2.5

                Rectangle {
                    anchors.centerIn: parent
                    width: 46; height: 46
                    radius: 23
                    color: root.voiceState === "listening" ? "#c1c5dd" :
                           root.voiceState === "speaking"  ? "#e2bbdb" :
                           mainBtnHover.containsMouse ? "#b4c5ff" : "#292a2f"

                    Text {
                        anchors.centerIn: parent
                        text: root.voiceState === "listening" ? "■" :
                              root.voiceState === "speaking"  ? "⏸" : "󰍬"
                        font.pixelSize: 20
                        color: (root.voiceState === "listening" || root.voiceState === "speaking") ?
                               "#121318" : "#e3e2e9"
                    }
                }

                MouseArea {
                    id: mainBtnHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (root.voiceState === "listening") {
                            root.stopListening()
                        } else if (root.voiceState === "speaking") {
                            root.cancelSession()
                        } else {
                            root.startListening()
                        }
                    }
                }
            }

            // 3. Answer Now / Force Send Button
            Rectangle {
                implicitWidth: 48; implicitHeight: 48
                radius: 24
                visible: root.voiceState === "listening"
                color: answerHover.containsMouse ? "#c1c5dd" : "#1e1f25"
                border.color: "#c1c5dd"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "✓"
                    font.pixelSize: 16
                    color: answerHover.containsMouse ? "#121318" : "#c1c5dd"
                }

                MouseArea {
                    id: answerHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.answerNow()
                }
            }
        }
    }
}
