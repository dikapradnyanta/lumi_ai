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

    // 60 FPS Smooth Interpolation Loop (16ms)
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
                        targetLevels[k] = Math.min(1.0, (root.micLevels[k] - 0.08) * 2.8)
                    }
                } else {
                    targetLevels = [0.05, 0.05, 0.05, 0.05, 0.05]
                }
            } else if (root.speechState === "speaking") {
                var tSec = root._t * 0.06
                var envelope = 0.35 + 0.5 * Math.abs(Math.sin(tSec * 4.2) * Math.cos(tSec * 1.9) + Math.sin(tSec * 6.8) * 0.25)
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

    // Canvas Renderer — ChatGPT Voice Fluid Blob + Pinterest Liquid Ring
    Canvas {
        id: orbCanvas
        anchors.centerIn: parent
        width: parent.width * root.orbScale * 1.6
        height: width
        antialiasing: true
        renderStrategy: Canvas.Threaded

        readonly property var themeColors: [
            "#00F2FE", // Electric Cyan
            "#7F00FF", // Deep Violet
            "#00FF87", // Neon Mint
            "#FF007F"  // Hot Magenta
        ]

        onPaint: {
            var ctx = getContext("2d")
            var w  = width, h = height
            var cx = w / 2, cy = h / 2
            
            ctx.clearRect(0, 0, w, h)

            var refSize = root.width * root.orbScale
            var state = root.speechState
            var t = root._t * 0.8

            // ─────────────────────────────────────────────────────────
            // 🧠 1. THINKING STATE: Pinterest Fluid Liquid Morphing Ring
            // ─────────────────────────────────────────────────────────
            if (state === "thinking") {
                var tThink = root._t * 2.2
                var ringBaseR = refSize * 0.28

                // Radial Ambient Glow Aura
                var thinkGlow = ctx.createRadialGradient(cx, cy, 10, cx, cy, ringBaseR * 1.8)
                thinkGlow.addColorStop(0, "rgba(0, 242, 254, 0.2)")
                thinkGlow.addColorStop(0.5, "rgba(127, 0, 255, 0.12)")
                thinkGlow.addColorStop(1, "rgba(0, 0, 0, 0)")
                ctx.fillStyle = thinkGlow
                ctx.beginPath()
                ctx.arc(cx, cy, ringBaseR * 1.8, 0, Math.PI * 2)
                ctx.fill()

                ctx.globalCompositeOperation = "lighter"

                // Draw 5 Interlocking Liquid Ribbons
                for (var r = 0; r < 5; r++) {
                    var phase = tThink * (0.8 + r * 0.15)
                    ctx.beginPath()
                    for (var a = 0; a <= Math.PI * 2 + 0.1; a += 0.06) {
                        var ripple = Math.sin(a * 4 + phase) * 8.0 + Math.cos(a * 2 - phase * 0.7) * 5.0
                        var currentR = ringBaseR + ripple + (r - 2) * 4.5

                        var x = cx + currentR * Math.cos(a + phase * 0.2)
                        var y = cy + currentR * Math.sin(a + phase * 0.2)

                        if (a === 0) ctx.moveTo(x, y)
                        else ctx.lineTo(x, y)
                    }
                    ctx.closePath()

                    var cRing = themeColors[r % themeColors.length]
                    ctx.lineWidth = 3.5
                    ctx.shadowColor = cRing
                    ctx.shadowBlur = 20
                    ctx.globalAlpha = 0.8
                    ctx.strokeStyle = cRing
                    ctx.stroke()
                }

                // Inner Fluid Core
                var innerR = 16 + Math.sin(tThink * 1.5) * 4
                ctx.beginPath()
                ctx.arc(cx, cy, innerR, 0, Math.PI * 2)
                ctx.shadowColor = "#00F2FE"
                ctx.shadowBlur = 25
                ctx.fillStyle = "rgba(0, 242, 254, 0.6)"
                ctx.globalAlpha = 0.9
                ctx.fill()

                ctx.globalAlpha = 1.0
                ctx.shadowColor = "transparent"
                ctx.shadowBlur = 0
                return
            }

            // ─────────────────────────────────────────────────────────
            // 🎙️ 2. LISTENING / 🗣️ SPEAKING / 💤 IDLE: ChatGPT Voice Fluid Blob
            // ─────────────────────────────────────────────────────────
            var avgLevel = 0
            for (var k = 0; k < 5; k++) avgLevel += root._animMicLevels[k]
            avgLevel /= 5.0

            var blobBaseR = refSize * (state === "idle" ? 0.26 : 0.3)

            // Ambient Radiant Aura
            var auraR = blobBaseR * (1.3 + avgLevel * 0.6)
            var auraGrad = ctx.createRadialGradient(cx, cy, 5, cx, cy, auraR)
            auraGrad.addColorStop(0, state === "idle" ? "rgba(0, 242, 254, 0.25)" : "rgba(0, 242, 254, 0.5)")
            auraGrad.addColorStop(0.5, state === "idle" ? "rgba(127, 0, 255, 0.1)" : "rgba(127, 0, 255, 0.3)")
            auraGrad.addColorStop(1, "rgba(0, 0, 0, 0)")
            ctx.fillStyle = auraGrad
            ctx.beginPath()
            ctx.arc(cx, cy, auraR, 0, Math.PI * 2)
            ctx.fill()

            ctx.globalCompositeOperation = "lighter"

            // Render 6 Organic Fluid Layer Blobs (ChatGPT Style)
            for (var b = 0; b < 6; b++) {
                var bPhase = t * (1.2 + b * 0.2)
                var bAmp = (state === "idle" ? 4.0 : 12.0 + avgLevel * 32.0)

                ctx.beginPath()
                for (var ang = 0; ang <= Math.PI * 2 + 0.1; ang += 0.08) {
                    var n1 = Math.sin(ang * 3 + bPhase) * bAmp
                    var n2 = Math.cos(ang * 4 - bPhase * 0.8) * (bAmp * 0.6)
                    var n3 = Math.sin(ang * 2 + bPhase * 1.5) * (bAmp * 0.4)

                    var rRadius = blobBaseR + n1 + n2 + n3 + (b - 2.5) * 3.0

                    var bx = cx + rRadius * Math.cos(ang)
                    var by = cy + rRadius * Math.sin(ang)

                    if (ang === 0) ctx.moveTo(bx, by)
                    else ctx.lineTo(bx, by)
                }
                ctx.closePath()

                var cBlob = themeColors[b % themeColors.length]
                ctx.lineWidth = state === "idle" ? 2.0 : 3.2
                ctx.shadowColor = cBlob
                ctx.shadowBlur = state === "idle" ? 8 : (12 + avgLevel * 25)
                ctx.globalAlpha = state === "idle" ? 0.4 : (0.55 + avgLevel * 0.4)
                ctx.strokeStyle = cBlob
                ctx.stroke()
            }

            ctx.globalAlpha = 1.0
            ctx.shadowColor = "transparent"
            ctx.shadowBlur = 0
        }
    }
}
