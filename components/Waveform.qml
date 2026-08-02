import QtQuick
import QtQuick.Effects
import "../"  // MatugenColors (unused)

// ============================================================
// Waveform.qml — 7 bar audio visualizer (design.md §2.2)
// 7-9 rounded bars, lebar 8px, tinggi dinamis 16-64px
// Glow: duplikat bar di belakang dengan blur
// ============================================================
Item {
    id: root

    implicitWidth:  220
    implicitHeight: 120

    // Input: 7 nilai float 0.0–1.0 dari mic_level.py
    property var levels: [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

    // State: "listening" | "speaking" | "idle"
    property string state: "idle"

    readonly property int nBars:    7
    readonly property int barWidth: 12
    readonly property int barGap:   10
    readonly property int minH:     12    // Sama dengan barWidth (12x12) -> Bentuk bulat sempurna!
    readonly property int maxH:     96

    readonly property color barColor: "#e3e2e9"
    readonly property color glowColor: "#b4c5ff"

    // ── Idle animasi: gentle pulsing opacity untuk titik bulat ──
    SequentialAnimation {
        running: root.state === "idle"
        loops: Animation.Infinite
        NumberAnimation {
            target: root
            property: "idleBreath"
            from: 0.4; to: 0.9
            duration: 800; easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root
            property: "idleBreath"
            from: 0.9; to: 0.4
            duration: 800; easing.type: Easing.InOutSine
        }
    }
    property real idleBreath: 0.7

    // ── Glow layer (di belakang) ─────────────────────────────
    Row {
        id: glowRow
        anchors.centerIn: parent
        spacing: root.barGap
        opacity: root.state === "idle" ? 0.2 : 0.5

        Repeater {
            model: root.nBars
            Rectangle {
                id: glowBar
                width:  root.barWidth + 6
                radius: width / 2
                color:  root.glowColor
                opacity: 0.7

                readonly property real targetH: {
                    let rawLv = root.levels[index] || 0
                    let lv = Math.min(1.0, rawLv * 2.5)
                    let h = root.state === "idle" ?
                        root.minH :
                        root.minH + lv * (root.maxH - root.minH)
                    return Math.max(root.minH, h)
                }
                height: targetH
                anchors.verticalCenter: parent.verticalCenter

                Behavior on height {
                    NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                }

                // Blur simulation via layered opacity
                layer.enabled: true
                layer.effect: MultiEffect {
                    blurEnabled: true
                    blur: 0.5
                    blurMax: 10
                }
            }
        }
    }

    // ── Bar utama (Bulat saat diam, naik-turun saat bicara) ────
    Row {
        id: barRow
        anchors.centerIn: parent
        spacing: root.barGap

        Repeater {
            model: root.nBars
            Rectangle {
                id: bar
                width:  root.barWidth
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter

                readonly property real targetH: {
                    let rawLv = root.levels[index] || 0
                    let lv = Math.min(1.0, rawLv * 2.5)
                    let h = root.state === "idle" ?
                        root.minH :
                        root.minH + lv * (root.maxH - root.minH)
                    return Math.max(root.minH, h)
                }

                height: targetH
                Behavior on height {
                    NumberAnimation { duration: 50; easing.type: Easing.OutQuad }
                }

                // Opacity: Saat diam lembut, saat ada suara solid & glowing
                color: root.state === "idle" ?
                    Qt.rgba(1.0, 1.0, 1.0, 0.35 + root.idleBreath * 0.35) :
                    Qt.rgba(1.0, 1.0, 1.0, 0.75 + Math.min(0.25, (root.levels[index] || 0) * 1.5))

                Behavior on color { ColorAnimation { duration: 150 } }

                layer.enabled: root.state !== "idle"
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: root.state === "listening" ? "#c1c5dd" : "#b4c5ff"
                    shadowBlur: 0.4
                }
            }
        }
    }
}

