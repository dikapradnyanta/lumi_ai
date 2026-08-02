import QtQuick
import QtQuick.Controls
import "../"  // MatugenColors (unused)

// ============================================================
// InputBar.qml — pill-shaped input box (design.md §2.1)
// Padding: 12px T/B, 16px L/R | Radius: 24px | Border: surface1
// ============================================================
Item {
    id: root

    implicitHeight: 56
    implicitWidth:  400

    // Signals
    signal sendMessage(string text)
    signal voiceModeRequested()

    // State
    property bool isThinking: false
    property bool hasApiKey:  true

    // ── Background — pill shape ──────────────────────────────
    Rectangle {
        id: inputBg
        anchors.fill: parent
        anchors.margins: 4
        radius: 24
        color: "#1a1b21"
        border.color: textInput.activeFocus ?
                      "#b4c5ff" : "#292a2f"
        border.width: 1

        Behavior on border.color { ColorAnimation { duration: 150 } }

        // Subtle glow on focus
        Rectangle {
            anchors.fill: parent
            anchors.margins: -1
            radius: parent.radius + 1
            color: "transparent"
            border.color: Qt.rgba(0.7059,
                                  0.7725,
                                  1.0,
                                  textInput.activeFocus ? 0.25 : 0)
            border.width: 2
            Behavior on border.color { ColorAnimation { duration: 150 } }
        }

        // ── Input row ────────────────────────────────────
        Row {
            anchors.fill: parent
            anchors.leftMargin:  12
            anchors.rightMargin: 8
            anchors.topMargin:   4
            anchors.bottomMargin: 4
            spacing: 4

            // ── Text field ───────────────────────────────
            TextInput {
                id: textInput
                width: parent.width - sendBtn.width - voiceBtn.width - 16
                height: parent.height
                verticalAlignment: TextInput.AlignVCenter
                font.pixelSize: 14
                font.family: "Inter, sans-serif"
                color: "#e3e2e9"
                selectionColor: Qt.rgba(0.7059,
                                        0.7725,
                                        1.0, 0.4)
                clip: true
                enabled: !root.isThinking && root.hasApiKey

                // Placeholder
                Text {
                    visible: textInput.text.length === 0 && !textInput.activeFocus
                    text: root.hasApiKey    ? "Ask the agent..."       :
                          root.isThinking   ? "Lumi sedang berpikir..." :
                                              "Set API Key di Settings"
                    font.pixelSize: 14
                    font.family: "Inter, sans-serif"
                    color: "#8f909a"
                    anchors.verticalCenter: parent.verticalCenter
                }

                // Enter to send
                Keys.onReturnPressed:  doSend()
                Keys.onEnterPressed:   doSend()

                // Escape clear
                Keys.onEscapePressed: {
                    if (text.length > 0) {
                        text = ""
                    } else {
                        event.accepted = false  // propagate ke Lumi.qml
                    }
                }
            }

            // ── Voice button ─────────────────────────────
            Rectangle {
                id: voiceBtn
                width: 36; height: 36
                radius: 12
                anchors.verticalCenter: parent.verticalCenter
                color: voiceHover.containsMouse ?
                       "#1e1f25" : "transparent"
                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰍬"
                    font.pixelSize: 16
                    color: voiceHover.containsMouse ?
                           "#b4c5ff" : "#7f849c"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: voiceHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  Qt.PointingHandCursor
                    onClicked:    root.voiceModeRequested()
                }
            }

            // ── Send button ──────────────────────────────
            Rectangle {
                id: sendBtn
                width: 36; height: 36
                radius: 12
                anchors.verticalCenter: parent.verticalCenter

                readonly property bool canSend: textInput.text.trim().length > 0 &&
                                                !root.isThinking && root.hasApiKey

                color: canSend ?
                       (sendHover.containsMouse ? "#b4c5ff" :
                        Qt.rgba(0.7059,
                                0.7725,
                                1.0, 0.7)) :
                       "#1e1f25"

                Behavior on color { ColorAnimation { duration: 150 } }

                Text {
                    anchors.centerIn: parent
                    text: "󰒊"
                    font.pixelSize: 15
                    color: sendBtn.canSend ? "#121318" :
                                            "#8f909a"
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: sendHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape:  sendBtn.canSend ? Qt.PointingHandCursor :
                                                    Qt.ArrowCursor
                    onClicked:    if (sendBtn.canSend) doSend()
                }
            }
        }
    }

    // ── Helper: trim & send ──────────────────────────────────
    function doSend() {
        let msg = textInput.text.trim()
        if (msg.length === 0 || root.isThinking || !root.hasApiKey) return
        textInput.text = ""
        root.sendMessage(msg)
    }

    // ── Focus helper ─────────────────────────────────────────
    function focusInput() {
        textInput.forceActiveFocus()
    }
}
