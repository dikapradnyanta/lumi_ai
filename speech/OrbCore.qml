import QtQuick
import QtQuick.Effects
import "../../"

Item {
    id: root
    width: 260
    height: 260

    // ── Public API ────────
    property real glowRadius: 50
    property real orbScale: 1.0
    property color primaryColor: "#4DB6AC"
    property color containerColor: "#00695C"
    property color tertiaryColor: "#26A69A"
    property color secondaryContainerColor: "#B2DFDB"
    
    property real audioLevel: 0.0   
    property var micLevels: [0.08, 0.08, 0.08, 0.08, 0.08]
    property string speechState: "idle"

    property var _animMicLevels: [0.05, 0.05, 0.05, 0.05, 0.05]

    // Timer 1: Interpolate animation values at 60 FPS (16ms)
    Timer {
        interval: 16
        running: root.visible
        repeat: true
        onTriggered: {
            var targetLevels = [0.05, 0.05, 0.05, 0.05, 0.05]
            
            if (root.speechState === "listening") {
                // Calculate average mic level
                var sum = 0
                for (var j = 0; j < 5; j++) sum += root.micLevels[j]
                var avg = sum / 5.0

                // Only amplify if speech passes noise floor (> 0.11)
                if (avg > 0.11) {
                    for (var k = 0; k < 5; k++) {
                        targetLevels[k] = Math.min(1.0, (root.micLevels[k] - 0.08) * 2.2)
                    }
                } else {
                    targetLevels = [0.05, 0.05, 0.05, 0.05, 0.05]
                }
            } else if (root.speechState === "speaking") {
                // Smooth AI speech cadence modulation (harmonic sine wave)
                var tSec = root._t * 0.05
                var envelope = 0.25 + 0.45 * Math.abs(Math.sin(tSec * 4.2) * Math.cos(tSec * 1.8) + Math.sin(tSec * 6.5) * 0.25)
                targetLevels = [
                    envelope * 0.7,
                    envelope * 0.9,
                    envelope * 1.0,
                    envelope * 0.8,
                    envelope * 0.6
                ]
            } else if (root.speechState === "thinking") {
                // Thinking uses 0 mic distortion (clean pulse)
                targetLevels = [0.0, 0.0, 0.0, 0.0, 0.0]
            }

            var newAnim = []
            for (var i = 0; i < 5; i++) {
                newAnim.push(root._animMicLevels[i] + (targetLevels[i] - root._animMicLevels[i]) * 0.25)
            }
            root._animMicLevels = newAnim
            orbCanvas.requestPaint()
        }
    }

    property real _t: 0.0
    NumberAnimation on _t {
        from: 0.0
        to: 100000.0
        duration: 1000000
        loops: Animation.Infinite
        running: root.visible
    }

    // Canvas to draw 10 glowing plasma lines
    Canvas {
        id: orbCanvas
        anchors.centerIn: parent
        width: parent.width * root.orbScale * 1.6
        height: width
        antialiasing: true
        renderStrategy: Canvas.Threaded

        readonly property var waveColors: [
            root.primaryColor,
            root.tertiaryColor,
            root.containerColor,
            root.secondaryContainerColor,
            Qt.tint(root.primaryColor, Qt.rgba(1,1,1,0.5))
        ]

        onPaint: {
            var ctx = getContext("2d")
            var w  = width, h = height
            var cx = w / 2, cy = h / 2
            
            ctx.clearRect(0, 0, w, h)
            ctx.globalCompositeOperation = "lighter"

            var refSize = root.width * root.orbScale
            var state = root.speechState

            // ─────────────────────────────────────────────────────────
            // 🧠 DEDICATED THINKING ANIMATION (Smooth Rotating Rings)
            // ─────────────────────────────────────────────────────────
            if (state === "thinking") {
                var tThink = root._t * 3.5
                var baseRThink = refSize / 2 * 0.42

                for (var i = 0; i < 6; i++) {
                    var ringR = baseRThink + (i - 2.5) * 8.0 + Math.sin(tThink * 0.5 + i) * 3.0
                    var rotSpeed = (i % 2 === 0 ? 1.0 : -1.2) * (1.0 + i * 0.15)
                    var rotAngle = tThink * 0.4 * rotSpeed

                    ctx.beginPath()
                    for (var a = 0; a <= Math.PI * 2 + 0.1; a += 0.1) {
                        var rPulse = ringR + Math.sin(a * 3 + rotAngle) * 2.5
                        var x = cx + rPulse * Math.cos(a + rotAngle)
                        var y = cy + rPulse * Math.sin(a + rotAngle)
                        if (a === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                    }
                    ctx.closePath()

                    var cThink = orbCanvas.waveColors[i % 5].toString()
                    ctx.lineWidth = 2.2 * (Config.lumiOrbThickness || 1.0)
                    ctx.shadowColor = cThink
                    ctx.shadowBlur = 15 + Math.sin(tThink * 0.8 + i) * 5
                    ctx.globalAlpha = 0.7 + 0.3 * Math.sin(tThink * 0.6 + i)
                    ctx.strokeStyle = cThink
                    ctx.stroke()
                }

                // Center glowing energy core
                var coreR = 12 + Math.sin(tThink * 1.2) * 4
                ctx.beginPath()
                ctx.arc(cx, cy, coreR, 0, Math.PI * 2)
                ctx.shadowColor = root.primaryColor.toString()
                ctx.shadowBlur = 25
                ctx.fillStyle = root.primaryColor.toString()
                ctx.globalAlpha = 0.85
                ctx.fill()

                ctx.globalAlpha = 1.0
                ctx.shadowColor = "transparent"
                ctx.shadowBlur = 0
                return
            }

            // ─────────────────────────────────────────────────────────
            // 🎙️ LISTENING / 🗣️ SPEAKING / 💤 IDLE ANIMATIONS
            // ─────────────────────────────────────────────────────────
            var stateBaseMod = state === "idle" ? 0.38 : 0.48
            var baseR = refSize / 2 * stateBaseMod
            var timeSpeed = state === "idle" ? 0.4 : (state === "speaking" ? 1.8 : 2.2)
            var t = root._t * timeSpeed

            for (var i = 0; i < 10; i++) {
                var bandIndex = i % 5
                var rawVal = root._animMicLevels[bandIndex]
                var level = rawVal

                var waveAmpli = baseR * 0.7 * level * (Config.lumiOrbWaviness || 1.0)

                ctx.beginPath()
                for (var angle = 0; angle <= Math.PI * 2 + 0.1; angle += 0.08) {
                    var freq = 2.0 + (i % 3)
                    var noise = Math.sin(angle * freq + t * (0.5 + i * 0.1)) * waveAmpli
                    var noise2 = Math.cos(angle * (freq + 1) - t * (0.8 + i * 0.15)) * (waveAmpli * 0.5)

                    var currentR = baseR + noise + noise2

                    var wobbleX = Math.cos(t * 0.4 + i) * 12 * level * (Config.lumiOrbWaviness || 1.0)
                    var wobbleY = Math.sin(t * 0.4 - i) * 12 * level * (Config.lumiOrbWaviness || 1.0)

                    var x = cx + wobbleX + currentR * Math.cos(angle)
                    var y = cy + wobbleY + currentR * Math.sin(angle)

                    if (angle === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.closePath()

                var baseThickness = state === "idle" ? 1.2 : (2.0 + level * 4.5)
                ctx.lineWidth = baseThickness * (Config.lumiOrbThickness || 1.0)
                ctx.lineCap = "round"
                ctx.lineJoin = "round"

                var colorStr = orbCanvas.waveColors[i % 5].toString()
                ctx.shadowColor = colorStr
                ctx.shadowBlur = state === "idle" ? 4 : (8 + level * 16)
                ctx.globalAlpha = state === "idle" ? 0.35 : (0.45 + level * 0.5)
                ctx.strokeStyle = colorStr
                ctx.stroke()
            }

            ctx.globalAlpha = 1.0
            ctx.shadowColor = "transparent"
            ctx.shadowBlur = 0
        }
    }
}
