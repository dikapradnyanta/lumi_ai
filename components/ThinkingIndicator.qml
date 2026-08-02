import QtQuick
import "../"  // MatugenColors (unused)

// ============================================================
// ThinkingIndicator.qml — animasi "Thinking..." (glowing orbs)
// Sesuai design.md: 2-3 ellipses dengan FastBlur glow
// ============================================================
Item {
    id: root
    implicitWidth:  200
    implicitHeight: 48

    // ── Tiga dot animasi ────────────────────────────────────
    Row {
        anchors.left:       parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Repeater {
            model: 3
            Rectangle {
                id: dot
                width: 10; height: 10
                radius: 5
                color: "#b4c5ff"
                opacity: 0.3

                // Pulse animation — offset per dot
                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    PauseAnimation   { duration: index * 200 }
                    NumberAnimation  { to: 1.0;  duration: 300; easing.type: Easing.OutSine }
                    NumberAnimation  { to: 0.3;  duration: 400; easing.type: Easing.InSine  }
                    PauseAnimation   { duration: Math.max(0, 600 - index * 200) }
                }

                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    PauseAnimation   { duration: index * 200 }
                    NumberAnimation  { to: 1.3;  duration: 300; easing.type: Easing.OutSine }
                    NumberAnimation  { to: 1.0;  duration: 400; easing.type: Easing.InSine  }
                    PauseAnimation   { duration: Math.max(0, 600 - index * 200) }
                }
            }
        }
    }

    // ── Label "Thinking..." ─────────────────────────────────
    Text {
        anchors.left:           parent.left
        anchors.leftMargin:     62
        anchors.verticalCenter: parent.verticalCenter
        text: "Thinking..."
        font.pixelSize: 13
        font.family: "Inter, sans-serif"
        color: "#c6c6d0"

        SequentialAnimation on opacity {
            loops: Animation.Infinite
            NumberAnimation { to: 0.4; duration: 800;  easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 800;  easing.type: Easing.InOutSine }
        }
    }
}
