import QtQuick

Item {
    id: root
    width: 340; height: 340
    anchors.centerIn: parent

    property color ringColor: "white"
    property int delay: 0
    property bool active: false

    Rectangle {
        id: ring
        anchors.centerIn: parent
        width: 140; height: 140
        radius: width / 2
        color: "transparent"
        border.color: root.ringColor
        border.width: 1.5
        opacity: 0
        antialiasing: true
    }

    SequentialAnimation {
        id: rippleAnim
        running: root.active
        loops: Animation.Infinite

        PauseAnimation { duration: root.delay }

        ParallelAnimation {
            NumberAnimation {
                target: ring; property: "width"
                from: 140; to: 340
                duration: 1600; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: ring; property: "height"
                from: 140; to: 340
                duration: 1600; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: ring; property: "opacity"
                from: 0.6; to: 0.0
                duration: 1600; easing.type: Easing.OutCubic
            }
        }

        PauseAnimation { duration: 1600 - root.delay }
    }

    onActiveChanged: {
        if (!active) {
            rippleAnim.stop()
            ring.width = 140; ring.height = 140; ring.opacity = 0
        }
    }
}
