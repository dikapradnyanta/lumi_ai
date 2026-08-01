import QtQuick
import QtQuick.Effects

Item {
    id: root
    width: 360
    height: displayText.length > 0 ? container.height : 0
    clip: true

    property string fullText: ""
    property string currentText: ""
    property color textColor: "white"
    property color bgColor: "#1A2E2C"
    property color borderColor: "white"
    property string speechState: "idle"

    Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    opacity: displayText.length > 0 ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: 300 } }

    property string displayText: currentText

    // Typewriter engine
    property int charIdx: 0
    Timer {
        id: typer
        interval: 18
        repeat: true
        running: root.speechState === "speaking" && root.charIdx < root.fullText.length
        onTriggered: {
            root.charIdx++
            root.currentText = root.fullText.substring(0, root.charIdx)
        }
    }

    onFullTextChanged: {
        charIdx = 0
        currentText = ""
        if (speechState === "speaking") typer.restart()
    }

    Rectangle {
        id: container
        width: parent.width
        height: Math.max(textItem.implicitHeight + 32, 56)
        radius: 16
        color: root.bgColor
        opacity: 0.88
        border.color: root.borderColor
        border.width: 1

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true; blur: 0.3; blurMax: 6
        }

        Text {
            id: textItem
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 16 }
            text: root.displayText
            color: root.textColor
            opacity: 0.90
            font.family: ["Geist", "Outfit", "DM Sans", "Ubuntu"]
            font.pixelSize: 14
            font.bold: false
            lineHeight: 1.55
            wrapMode: Text.WordWrap
        }
    }
}
