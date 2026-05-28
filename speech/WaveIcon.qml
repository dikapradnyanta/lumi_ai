import QtQuick
import Quickshell.Io

Item {
    id: root
    width: 48; height: 48

    property string speechState: "idle"
    property color primaryColor: "white"
    property color speakingColor: "white"
    property var lineScales: [0.3, 0.45, 0.55, 0.45, 0.3]

    // Mic level dari script (hanya aktif saat listening)
    property var micLevels: [0.3, 0.45, 0.55, 0.45, 0.3]

    signal iconClicked()

    readonly property var lineData: [
        { length: 14, ox: -12 },
        { length: 24, ox: -6 },
        { length: 32, ox: 0 },
        { length: 24, ox: 6 },
        { length: 14, ox: 12 }
    ]

    // ── Proses mic_level.py (hanya saat listening) ─────────────
    Process {
        id: micProc
        running: false
        command: ["python3",
                  "/home/dikapradnyanta/.config/hypr/scripts/quickshell/lumi/mic_level.py"]

        stdout: SplitParser {
            onRead: function(line) {
                var parts = line.trim().split(" ")
                if (parts.length === 5) {
                    var levels = []
                    for (var i = 0; i < 5; i++) {
                        var v = parseFloat(parts[i])
                        levels.push(isNaN(v) ? 0.08 : Math.max(0.08, Math.min(1.0, v)))
                    }
                    root.micLevels = levels
                    // Map level ke lineScales: min bar length 0.2, max 1.0
                    // Setiap bar scale = 0.2 + level * 0.8
                    root.lineScales = levels.map(function(v) {
                        return 0.2 + v * 0.8
                    })
                    canvas.requestPaint()
                }
            }
        }
    }

    // ── Start/stop mic_level.py sesuai state ───────────────────
    onSpeechStateChanged: {
        if (speechState === "listening") {
            micProc.running = true
        } else {
            micProc.running = false
            // Reset ke animasi sesuai state
            if (speechState === "idle") {
                lineScales = [0.3, 0.45, 0.55, 0.45, 0.3]
            }
            canvas.requestPaint()
        }
    }

    // ── Canvas ─────────────────────────────────────────────────
    Canvas {
        id: canvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            ctx.lineWidth = 2.5
            ctx.lineCap = "round"

            var cx = width / 2
            var cy = height / 2
            var iscale = width / 48.0

            var isSpeaking = root.speechState === "speaking"
            var isListening = root.speechState === "listening"

            ctx.globalAlpha = root.speechState === "idle" ? 0.55 : 1.0

            for (var i = 0; i < root.lineData.length; i++) {
                var ld = root.lineData[i]
                var sc = root.lineScales[i]

                // Base length dari lineData, scale dengan mic level
                var baseLen = ld.length * iscale
                var half = (baseLen * sc) / 2

                var bx = cx + (ld.ox * iscale)

                // Gradient warna per bar berdasarkan level saat listening
                if (isListening) {
                    var level = root.micLevels[i] || 0.08
                    // Interpolasi dari primaryColor ke speakingColor berdasarkan level
                    var r = root.primaryColor.r + (root.speakingColor.r - root.primaryColor.r) * level
                    var g = root.primaryColor.g + (root.speakingColor.g - root.primaryColor.g) * level
                    var b = root.primaryColor.b + (root.speakingColor.b - root.primaryColor.b) * level
                    ctx.strokeStyle = Qt.rgba(r, g, b, 1.0)
                } else if (isSpeaking) {
                    ctx.strokeStyle = root.speakingColor
                } else {
                    ctx.strokeStyle = root.primaryColor
                }

                ctx.beginPath()
                ctx.moveTo(bx, cy - half)
                ctx.lineTo(bx, cy + half)
                ctx.stroke()
            }
        }
    }

    // ── Speaking: bars berdenyut random setiap 120ms ──────────
    Timer {
        interval: 120
        running: root.speechState === "speaking"
        repeat: true
        onTriggered: {
            root.lineScales = [
                0.2 + Math.random() * 0.8,
                0.3 + Math.random() * 0.7,
                0.35 + Math.random() * 0.65,
                0.3 + Math.random() * 0.7,
                0.2 + Math.random() * 0.8
            ]
            canvas.requestPaint()
        }
    }

    // ── Idle: gentle breathing wave ────────────────────────────
    Timer {
        interval: 80
        running: root.speechState === "idle"
        repeat: true
        property real phase: 0
        onTriggered: {
            phase += 0.15
            root.lineScales = [
                0.25 + 0.12 * Math.sin(phase),
                0.38 + 0.12 * Math.sin(phase + 0.7),
                0.50 + 0.12 * Math.sin(phase + 1.4),
                0.38 + 0.12 * Math.sin(phase + 0.7),
                0.25 + 0.12 * Math.sin(phase)
            ]
            canvas.requestPaint()
        }
    }

    // ── Hover feedback ─────────────────────────────────────────
    Rectangle {
        anchors.fill: parent; radius: width / 2
        color: root.primaryColor
        opacity: ma.containsMouse ? 0.08 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.iconClicked()
        onPressed: canvas.scale = 0.88
        onReleased: canvas.scale = 1.0
        Behavior on scale { NumberAnimation { duration: 100 } }
    }
}
