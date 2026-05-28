import QtQuick

Item {
    id: root
    width: implicitWidth
    height: implicitHeight

    property string speechState: "idle"
    property color textColor: "white"

    readonly property var stateTexts: ({
        "idle": "lumi",
        "listening": "mendengarkan...",
        "thinking": "memproses...",
        "speaking": "berbicara..."
    })

    Text {
        id: label
        text: stateTexts[root.speechState] || "lumi"
        color: root.textColor
        opacity: root.speechState === "idle" ? 0.5 : 0.9
        font.family: "Outfit" // Use Outfit or fallback
        font.pixelSize: 13
        font.weight: Font.Light
        font.letterSpacing: 2

        Behavior on opacity { NumberAnimation { duration: 300 } }

        // Fade saat teks berganti
        Behavior on text {
            SequentialAnimation {
                NumberAnimation { target: label; property: "opacity"; to: 0; duration: 150 }
                PropertyAction {}
                NumberAnimation { target: label; property: "opacity"; to: label.opacity; duration: 150 }
            }
        }
    }

    // Loading dots untuk state thinking
    Row {
        id: thinkingDots
        anchors.top: label.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 5
        visible: root.speechState === "thinking"

        Repeater {
            model: 3
            Rectangle {
                width: 4; height: 4
                radius: 2
                color: root.textColor

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: thinkingDots.visible
                    PauseAnimation { duration: index * 200 }
                    NumberAnimation { from: 0.2; to: 1.0; duration: 400; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.0; to: 0.2; duration: 400; easing.type: Easing.InOutSine }
                    PauseAnimation { duration: 600 - (index * 200) }
                }
            }
        }
    }
}
