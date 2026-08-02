import QtQuick
import QtQuick.Effects
import "../"  // MatugenColors (unused)

// ============================================================
// MessageBubble.qml — satu bubble chat
// role: "user" | "assistant" | "error"
// ============================================================
Item {
    id: root

    property string role:    "user"
    property string content: ""
    property string timestamp: ""

    readonly property bool isUser:  role === "user"
    readonly property bool isError: role === "error"

    // Exposed untuk ChatView sizing
    implicitWidth:  parent ? parent.width : 400
    implicitHeight: bubbleRow.implicitHeight + 8

    Row {
        id: bubbleRow
        anchors.top:    parent.top
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.topMargin: 4
        layoutDirection: root.isUser ? Qt.RightToLeft : Qt.LeftToRight
        spacing: 8

        // ── Avatar ──────────────────────────────────────
        Rectangle {
            id: avatar
            width: 28; height: 28
            radius: 14
            color: root.isUser   ? "#b4c5ff" :
                   root.isError  ? "#ffb4ab"   :
                                   "#b4c5ff"
            anchors.top: parent.top
            anchors.topMargin: 2

            Text {
                anchors.centerIn: parent
                text: root.isUser ? "U" : root.isError ? "!" : "L"
                font.pixelSize: 12
                font.bold: true
                color: "#121318"
            }
        }

        // ── Bubble Content ──────────────────────────────
        Item {
            width: parent.width - avatar.width - 8
            implicitHeight: bubble.implicitHeight

            Rectangle {
                id: bubble
                width: Math.min(contentText.implicitWidth + 24, parent.width)
                implicitHeight: contentText.implicitHeight + 20
                anchors.left:  root.isUser ? undefined : parent.left
                anchors.right: root.isUser ? parent.right : undefined

                radius: 16
                color: root.isUser   ? "#b4c5ff"  :
                       root.isError  ? Qt.rgba(1.0,
                                               0.7059,
                                               0.6706, 0.15) :
                                       "#1e1f25"
                border.color: root.isError ? "#ffb4ab" :
                              root.isUser  ? "transparent"       :
                                             "#292a2f"
                border.width: root.isError ? 1 : root.isUser ? 0 : 1

                // ── Teks pesan ──────────────────────────
                Text {
                    id: contentText
                    anchors {
                        top:    parent.top
                        left:   parent.left
                        right:  parent.right
                        bottom: parent.bottom
                        margins: 10
                        leftMargin:  12
                        rightMargin: 12
                    }
                    text: root.content
                    font.pixelSize: 14
                    font.family: "Inter, sans-serif"
                    color: root.isUser  ? "#121318" :
                           root.isError ? "#ffb4ab"   :
                                          "#e3e2e9"
                    wrapMode: Text.WordWrap
                    lineHeight: 1.5
                    textFormat: Text.PlainText
                }
            }

            // ── Timestamp ───────────────────────────────
            Text {
                visible: root.timestamp !== ""
                anchors.top:   bubble.bottom
                anchors.left:  root.isUser ? undefined : bubble.left
                anchors.right: root.isUser ? bubble.right : undefined
                anchors.topMargin: 2
                text: root.timestamp
                font.pixelSize: 10
                color: "#34343a"
            }
        }
    }
}
