import QtQuick
import QtQuick.Effects
import "../../"

Item {
    id: root
    width: 280
    height: 280

    // ── Public API ────────
    property real glowRadius: 50
    property real orbScale: 1.0
    property color primaryColor: "#00F2FE"
    property color containerColor: "#00695C"
    property color tertiaryColor: "#7F00FF"
    property color secondaryContainerColor: "#00FF87"
    
    property real audioLevel: 0.0   
    property var micLevels: [0.08, 0.08, 0.08, 0.08, 0.08]
    property string speechState: "idle"

    property var _animMicLevels: [0.05, 0.05, 0.05, 0.05, 0.05]

    // 60 FPS Smooth Interpolation Loop
    Timer {
        interval: 16
        running: root.visible
        repeat: true
        onTriggered: {
            var targetLevels = [0.05, 0.05, 0.05, 0.05, 0.05]
            
            if (root.speechState === "listening") {
                var sum = 0
                for (var j = 0; j < 5; j++) sum += root.micLevels[j]
                var avg = sum / 5.0

                if (avg > 0.11) {
                    for (var k = 0; k < 5; k++) {
                        targetLevels[k] = Math.min(1.0, (root.micLevels[k] - 0.08) * 2.5)
                    }
                } else {
                    targetLevels = [0.05, 0.05, 0.05, 0.05, 0.05]
                }
            } else if (root.speechState === "speaking") {
                var tSec = root._t * 0.06
                var envelope = 0.3 + 0.5 * Math.abs(Math.sin(tSec * 4.5) * Math.cos(tSec * 2.1) + Math.sin(tSec * 7.2) * 0.2)
                targetLevels = [
                    envelope * 0.75,
                    envelope * 0.95,
                    envelope * 1.0,
                    envelope * 0.85,
                    envelope * 0.65
                ]
            } else if (root.speechState === "thinking") {
                targetLevels = [0.0, 0.0, 0.0, 0.0, 0.0]
            }

            var newAnim = []
            for (var i = 0; i < 5; i++) {
                newAnim.push(root._animMicLevels[i] + (targetLevels[i] - root._animMicLevels[i]) * 0.28)
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

    // Canvas Renderer — High Definition 3D Futuristic Energy Orb (JARVIS Style)
    Canvas {
        id: orbCanvas
        anchors.centerIn: parent
        width: parent.width * root.orbScale * 1.6
        height: width
        antialiasing: true
        renderStrategy: Canvas.Threaded

        readonly property var waveColors: [
            "#00F2FE", // Electric Cyan
            "#7F00FF", // Deep Violet
            "#00FF87", // Neon Mint
            "#FF007F", // Hot Pink / Magenta
            "#3A86FF", // Royal Blue
            "#FFD700"  // Gold Spark
        ]

        onPaint: {
            var ctx = getContext("2d")
            var w  = width, h = height
            var cx = w / 2, cy = h / 2
            
            ctx.clearRect(0, 0, w, h)

            var refSize = root.width * root.orbScale
            var state = root.speechState

            // ─────────────────────────────────────────────────────────
            // 🧠 1. THINKING STATE: Glowing Cybernetic Particle Vortex
            // ─────────────────────────────────────────────────────────
            if (state === "thinking") {
                var tThink = root._t * 3.8
                var baseRThink = refSize / 2 * 0.44

                // Background Energy Radial Glow
                var bgGrad = ctx.createRadialGradient(cx, cy, 5, cx, cy, baseRThink * 1.5)
                bgGrad.addColorStop(0, "rgba(0, 242, 254, 0.35)")
                bgGrad.addColorStop(0.5, "rgba(127, 0, 255, 0.15)")
                bgGrad.addColorStop(1, "rgba(0, 0, 0, 0)")
                ctx.fillStyle = bgGrad
                ctx.beginPath()
                ctx.arc(cx, cy, baseRThink * 1.5, 0, Math.PI * 2)
                ctx.fill()

                ctx.globalCompositeOperation = "lighter"

                // 8 Concentric Counter-rotating Orbital Waves
                for (var i = 0; i < 8; i++) {
                    var ringR = baseRThink + (i - 3.5) * 7.5 + Math.sin(tThink * 0.6 + i) * 4.0
                    var dir = (i % 2 === 0 ? 1 : -1)
                    var rotAngle = tThink * 0.45 * dir * (1.0 + i * 0.12)

                    ctx.beginPath()
                    for (var a = 0; a <= Math.PI * 2 + 0.15; a += 0.09) {
                        var rPulse = ringR + Math.sin(a * 4 + rotAngle) * 3.5 + Math.cos(a * 2 - rotAngle) * 2.0
                        var x = cx + rPulse * Math.cos(a + rotAngle)
                        var y = cy + rPulse * Math.sin(a + rotAngle)
                        if (a === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y)
                    }
                    ctx.closePath()

                    var cThink = orbCanvas.waveColors[i % waveColors.length]
                    ctx.lineWidth = 2.4 * (Config.lumiOrbThickness || 1.0)
                    ctx.shadowColor = cThink
                    ctx.shadowBlur = 18 + Math.sin(tThink * 0.8 + i) * 6
                    ctx.globalAlpha = 0.75 + 0.25 * Math.sin(tThink * 0.7 + i)
                    ctx.strokeStyle = cThink
                    ctx.stroke()
                }

                // Inner Core Spark
                var coreR = 14 + Math.sin(tThink * 1.4) * 5
                var coreGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, coreR)
                coreGrad.addColorStop(0, "#FFFFFF")
                coreGrad.addColorStop(0.4, "#00F2FE")
                coreGrad.addColorStop(1, "rgba(127, 0, 255, 0)")

                ctx.beginPath()
                ctx.arc(cx, cy, coreR, 0, Math.PI * 2)
                ctx.shadowColor = "#00F2FE"
                ctx.shadowBlur = 30
                ctx.fillStyle = coreGrad
                ctx.globalAlpha = 0.95
                ctx.fill()

                ctx.globalAlpha = 1.0
                ctx.shadowColor = "transparent"
                ctx.shadowBlur = 0
                return
            }

            // ─────────────────────────────────────────────────────────
            // 🎙️ 2. LISTENING / 🗣️ SPEAKING / 💤 IDLE: Futuristic 3D Plasma Sphere
            // ─────────────────────────────────────────────────────────
            var stateBaseMod = state === "idle" ? 0.38 : 0.48
            var baseR = refSize / 2 * stateBaseMod
            var timeSpeed = state === "idle" ? 0.4 : (state === "speaking" ? 1.8 : 2.4)
            var t = root._t * timeSpeed

            // Inner Core Ambient Glow Gradient
            var coreGlowR = baseR * (1.1 + (state === "idle" ? 0 : root._animMicLevels[0] * 0.4))
            var orbGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, coreGlowR)
            orbGrad.addColorStop(0, state === "idle" ? "rgba(0, 242, 254, 0.25)" : "rgba(0, 242, 254, 0.45)")
            orbGrad.addColorStop(0.6, state === "idle" ? "rgba(127, 0, 255, 0.1)" : "rgba(127, 0, 255, 0.25)")
            orbGrad.addColorStop(1, "rgba(0, 0, 0, 0)")

            ctx.fillStyle = orbGrad
            ctx.beginPath()
            ctx.arc(cx, cy, coreGlowR, 0, Math.PI * 2)
            ctx.fill()

            ctx.globalCompositeOperation = "lighter"

            // 12 Overlapping 3D Plasma Energy Rings
            for (var i = 0; i < 12; i++) {
                var bandIndex = i % 5
                var rawVal = root._animMicLevels[bandIndex]
                var level = rawVal

                var waveAmpli = baseR * 0.75 * level * (Config.lumiOrbWaviness || 1.0)
                if (state === "idle") waveAmpli = baseR * 0.08

                ctx.beginPath()
                for (var angle = 0; angle <= Math.PI * 2 + 0.12; angle += 0.07) {
                    var freq = 2.0 + (i % 4)
                    var noise = Math.sin(angle * freq + t * (0.5 + i * 0.08)) * waveAmpli
                    var noise2 = Math.cos(angle * (freq + 1) - t * (0.7 + i * 0.12)) * (waveAmpli * 0.55)
                    var noise3 = Math.sin(angle * 3 + t * 0.9) * (waveAmpli * 0.3)

                    var currentR = baseR + noise + noise2 + noise3

                    var wobbleX = Math.cos(t * 0.4 + i * 0.7) * 14 * (state === "idle" ? 0.2 : level) * (Config.lumiOrbWaviness || 1.0)
                    var wobbleY = Math.sin(t * 0.4 - i * 0.7) * 14 * (state === "idle" ? 0.2 : level) * (Config.lumiOrbWaviness || 1.0)

                    var x = cx + wobbleX + currentR * Math.cos(angle)
                    var y = cy + wobbleY + currentR * Math.sin(angle)

                    if (angle === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.closePath()

                var baseThickness = state === "idle" ? 1.2 : (2.2 + level * 5.0)
                ctx.lineWidth = baseThickness * (Config.lumiOrbThickness || 1.0)
                ctx.lineCap = "round"
                ctx.lineJoin = "round"

                var colorStr = orbCanvas.waveColors[i % waveColors.length]
                ctx.shadowColor = colorStr
                ctx.shadowBlur = state === "idle" ? 5 : (10 + level * 22)
                ctx.globalAlpha = state === "idle" ? 0.35 : (0.45 + level * 0.55)
                ctx.strokeStyle = colorStr
                ctx.stroke()
            }

            ctx.globalAlpha = 1.0
            ctx.shadowColor = "transparent"
            ctx.shadowBlur = 0
        }
    }
}
