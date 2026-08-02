import QtQuick
import "../"  // MatugenColors (unused)

// ============================================================
// QuickReply.qml — Action clarification buttons (design.md §2.3)
// Menampilkan opsi aksi seperti "Jalankan Perintah", "Buka Browser",
// atau "Batal" saat AI menyarankan aksi ke OS.
// ============================================================
Item {
    id: root

    implicitWidth:  actionsRow.implicitWidth + 24
    implicitHeight: 40

    // Model: array of string / object { label: string, action: string }
    property var actions: []

    signal actionClicked(string action, string label)

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: "#1a1b21"
        border.color: "#292a2f"
        border.width: 1

        Row {
            id: actionsRow
            anchors.centerIn: parent
            spacing: 8

            Repeater {
                model: root.actions

                Rectangle {
                    implicitWidth:  btnText.implicitWidth + 24
                    implicitHeight: 28
                    radius: 14
                    color: btnHover.containsMouse ? "#b4c5ff" : "#1e1f25"
                    border.color: "#292a2f"
                    border.width: 1

                    Text {
                        id: btnText
                        anchors.centerIn: parent
                        text: modelData.label || modelData
                        font.pixelSize: 12
                        font.bold: true
                        font.family: "Inter, sans-serif"
                        color: btnHover.containsMouse ? "#121318" : "#e3e2e9"
                    }

                    MouseArea {
                        id: btnHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            let act = modelData.action || modelData.label || modelData
                            root.actionClicked(act, btnText.text)
                        }
                    }
                }
            }
        }
    }
}
