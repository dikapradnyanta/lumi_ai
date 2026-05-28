import QtQuick

Item {
    id: root
    anchors.fill: parent

    property color ringColor: "white"
    property string speechState: "idle"

    // Config rings statis
    readonly property var ringConfigs: [
        { diameter: 170, strokeWidth: 1.5, baseOpacity: 0.35 },
        { diameter: 210, strokeWidth: 1.0, baseOpacity: 0.25 },
        { diameter: 255, strokeWidth: 1.0, baseOpacity: 0.15 },
        { diameter: 305, strokeWidth: 0.5, baseOpacity: 0.08 }
    ]

    // Rings statis
    Repeater {
        model: root.ringConfigs

        Rectangle {
            anchors.centerIn: parent
            width: modelData.diameter
            height: width
            radius: width / 2
            color: "transparent"
            antialiasing: true
            border.color: root.ringColor
            border.width: modelData.strokeWidth
            opacity: root.speechState === "listening" ? modelData.baseOpacity * 0.5
                   : modelData.baseOpacity

            Behavior on opacity { NumberAnimation { duration: 400 } }
        }
    }

    // Ripple emitter — aktif saat listening
    Item {
        id: rippleEmitter
        anchors.centerIn: parent
        visible: root.speechState === "listening"

        // 3 ripple objects, di-stagger
        Repeater {
            model: 3
            delegate: RippleRing {
                anchors.centerIn: parent
                ringColor: root.ringColor
                delay: index * 533  // 1600ms / 3
                active: root.speechState === "listening"
            }
        }
    }
}
