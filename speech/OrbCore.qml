import QtQuick
import QtQuick.Effects

Item {
    id: root
    width: 140
    height: 140

    // Dipanggil dari parent untuk drive animasi
    property real glowRadius: 35
    property real orbScale: 1.0
    property color primaryColor: "white"
    property color containerColor: "white"
    property color glowColor: "white"

    // Glow layer (di belakang orb)
    Rectangle {
        id: glowLayer
        anchors.centerIn: parent
        width: parent.width + glowRadius * 2
        height: width
        radius: width / 2
        color: "transparent"

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            colorization: 0.8
            colorizationColor: root.glowColor
        }

        // Soft bloom circle
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: root.glowColor
            opacity: 0.18
        }

        Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.InOutSine } }
    }

    // Orb utama
    Rectangle {
        id: orb
        anchors.centerIn: parent
        width: parent.width * root.orbScale
        height: width
        radius: width / 2
        antialiasing: true

        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.lighter(root.primaryColor, 1.3) }
            GradientStop { position: 0.5; color: root.primaryColor }
            GradientStop { position: 1.0; color: root.containerColor }
        }

        // Spekuler / inner highlight
        Rectangle {
            x: parent.width * 0.2
            y: parent.height * 0.12
            width: parent.width * 0.35
            height: width * 0.5
            radius: width / 2
            color: "white"
            opacity: 0.2
            rotation: -30
        }

        Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.InOutQuart } }
    }
}
