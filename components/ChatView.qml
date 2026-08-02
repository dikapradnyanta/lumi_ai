import QtQuick
import QtQuick.Controls
import "../"  // MatugenColors (unused)

// ============================================================
// ChatView.qml — scrollable list of message bubbles
// Receives model dari LumiService via `chatModel`
// ============================================================
Item {
    id: root

    property var    chatModel:  null   // ListModel dari LumiService
    property bool   isThinking: false

    // ── Scroll area ─────────────────────────────────────────
    ScrollView {
        id: scrollView
        anchors.fill: parent
        contentWidth:  availableWidth
        clip: true

        // Custom scrollbar styling
        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded
            width: 4
            contentItem: Rectangle {
                radius: 2
                color:  "#292a2f"
                opacity: parent.active ? 0.9 : 0.4
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }
            background: Rectangle { color: "transparent" }
        }

        // ── Message list ─────────────────────────────────
        Column {
            id: messageColumn
            width: scrollView.availableWidth
            spacing: 4
            padding:  16
            bottomPadding: 8

            // ── Empty state ──────────────────────────────
            Item {
                visible: (chatModel ? chatModel.count === 0 : true) && !root.isThinking
                width:  parent.width - 32
                height: 200
                anchors.horizontalCenter: parent.horizontalCenter

                Column {
                    anchors.centerIn: parent
                    spacing: 12

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "✦"
                        font.pixelSize: 32
                        color: "#b4c5ff"
                        opacity: 0.6
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Tanya apa saja..."
                        font.pixelSize: 15
                        font.family: "Inter, sans-serif"
                        color: "#8f909a"
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Lumi siap membantu"
                        font.pixelSize: 12
                        font.family: "Inter, sans-serif"
                        color: "#8f909a"
                        opacity: 0.7
                    }
                }
            }

            // ── Message bubbles ──────────────────────────
            Repeater {
                model: root.chatModel

                MessageBubble {
                    width:   messageColumn.width - messageColumn.padding * 2
                    role:    model.role
                    content: model.content
                    timestamp: model.timestamp || ""
                }
            }

            // ── Thinking indicator ───────────────────────
            Item {
                visible: root.isThinking
                width:   messageColumn.width - messageColumn.padding * 2
                height:  56

                Rectangle {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: thinkRow.implicitWidth + 24
                    height: 44
                    radius: 16
                    color:  "#1a1b21"
                    border.color: "#292a2f"
                    border.width: 1

                    Row {
                        id: thinkRow
                        anchors.left:           parent.left
                        anchors.leftMargin:     12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        ThinkingIndicator { }
                    }
                }

                // Enter animation
                Behavior on opacity { NumberAnimation { duration: 200 } }
                opacity: root.isThinking ? 1 : 0
            }
        }
    }

    // ── Auto-scroll ke bawah ─────────────────────────────────
    function scrollToBottom() {
        Qt.callLater(() => {
            scrollView.ScrollBar.vertical.position =
                Math.max(0, 1.0 - scrollView.ScrollBar.vertical.size)
        })
    }

    Connections {
        target: root.chatModel
        function onCountChanged() { root.scrollToBottom() }
    }

    onIsThinkingChanged: {
        if (isThinking) scrollToBottom()
    }
}
