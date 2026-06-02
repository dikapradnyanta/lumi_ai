import QtQuick
import QtQuick.Effects

Item {
    id: root
    width: 260
    height: 260

    // ── Public API ────────
    property real glowRadius: 50
    property real orbScale: 1.0
    property color primaryColor: "#4DB6AC"
    property color containerColor: "#00695C"
    property color glowColor: "#26A69A"
    property real audioLevel: 0.0   
    property var micLevels: [0.08, 0.08, 0.08, 0.08, 0.08]
    property string speechState: "idle"

    property var _animMicLevels: [0.08, 0.08, 0.08, 0.08, 0.08]

    // AI voice animation array
    property var aiLevels: [0.1, 0.1, 0.1, 0.1, 0.1]
    Timer {
        interval: 120
        running: root.speechState === "speaking"
        repeat: true
        onTriggered: {
            root.aiLevels = [
                0.2 + Math.random() * 0.6,
                0.3 + Math.random() * 0.7,
                0.4 + Math.random() * 0.6,
                0.3 + Math.random() * 0.7,
                0.2 + Math.random() * 0.6
            ]
        }
    }

    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: {
            // Smoothly interpolate micLevels for fluid rendering
            var targetLevels = root.speechState === "listening" ? root.micLevels : 
                               root.speechState === "speaking" ? root.aiLevels : 
                               [0.08, 0.08, 0.08, 0.08, 0.08];

            var newAnim = []
            for (var i = 0; i < 5; i++) {
                // simple low pass filter for smoothness
                newAnim.push(root._animMicLevels[i] + (targetLevels[i] - root._animMicLevels[i]) * 0.35)
            }
            root._animMicLevels = newAnim

            orbCanvas.requestPaint()
            glowCanvas.requestPaint()
        }
    }

    property real _t: 0.0
    NumberAnimation on _t {
        from: 0.0
        to: 6283.185
        duration: 60000
        loops: Animation.Infinite
        running: true
    }

    // ── 1. Ambient glow halo ───────────────────
    Canvas {
        id: glowCanvas
        anchors.centerIn: parent
        width: parent.width + root.glowRadius * 2 + root.audioLevel * 60
        height: width

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var cx = width / 2, cy = height / 2
            var r  = Math.min(width, height) / 2
            var al = root.audioLevel

            var grad = ctx.createRadialGradient(cx, cy, r * 0.2, cx, cy, r)
            grad.addColorStop(0.0,  Qt.rgba(root.glowColor.r, root.glowColor.g, root.glowColor.b, 0.25 + al * 0.4).toString())
            grad.addColorStop(0.4,  Qt.rgba(root.glowColor.r, root.glowColor.g, root.glowColor.b, 0.08).toString())
            grad.addColorStop(1.0,  "rgba(0,0,0,0)")

            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.fillStyle = grad
            ctx.fill()
        }
    }

    // ── 2. The Plasma Waves (Siri-style) ─────────────────────────
    Canvas {
        id: orbCanvas
        anchors.centerIn: parent
        width: parent.width * root.orbScale
        height: width
        antialiasing: true
        renderStrategy: Canvas.Threaded

        // Siri-like neon colors
        readonly property var waveColors: [
            root.primaryColor,
            "#3399FF", // Blueish
            "#CC33FF", // Purpleish
            "#FF3399", // Pinkish
            root.tertiaryColor
        ]

        onPaint: {
            var ctx = getContext("2d")
            var w  = width, h = height
            var cx = w / 2, cy = h / 2
            var baseR = Math.min(w, h) / 2 * 0.55 // Base radius of the inner sphere
            var t  = root._t * 0.002

            ctx.clearRect(0, 0, w, h)
            ctx.globalCompositeOperation = "lighter" // Additive blending for neon glow

            // Base glowing core sphere
            ctx.beginPath()
            ctx.arc(cx, cy, baseR * 0.85, 0, Math.PI * 2)
            var coreGrad = ctx.createRadialGradient(cx, cy, 0, cx, cy, baseR * 0.85)
            coreGrad.addColorStop(0, Qt.rgba(1,1,1, 0.7).toString())
            coreGrad.addColorStop(0.5, Qt.rgba(root.primaryColor.r, root.primaryColor.g, root.primaryColor.b, 0.4).toString())
            coreGrad.addColorStop(1, "rgba(0,0,0,0)")
            ctx.fillStyle = coreGrad
            ctx.fill()

            // Draw 5 overlapping plasma waves
            for (var i = 0; i < 5; i++) {
                var level = root._animMicLevels[i]
                var waveAmpli = baseR * 1.1 * level // Amplitude driven by frequency band
                
                ctx.beginPath()
                // Use many segments for smooth curves
                for (var angle = 0; angle <= Math.PI * 2 + 0.1; angle += 0.05) {
                    // Complex trig noise to create swirling waves
                    var noise = Math.sin(angle * (2 + i % 3) + t * (3.0 + i)) * waveAmpli
                    var noise2 = Math.cos(angle * 3 - t * (2.0 + i*0.5)) * (waveAmpli * 0.5)
                    
                    var currentR = baseR + noise + noise2
                    
                    // Add slight 3D rotation wobble
                    var wobbleX = Math.cos(t * 1.5 + i) * 15 * level
                    var wobbleY = Math.sin(t * 1.5 - i) * 15 * level

                    var x = cx + wobbleX + currentR * Math.cos(angle)
                    var y = cy + wobbleY + currentR * Math.sin(angle)
                    
                    if (angle === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.closePath()

                // Stroke styling
                ctx.lineWidth = 3.0 + level * 6.0
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                
                // Add stroke glow via shadow
                ctx.shadowColor = orbCanvas.waveColors[i]
                ctx.shadowBlur = 12 + level * 15
                
                ctx.globalAlpha = 0.65 + level * 0.35
                ctx.strokeStyle = orbCanvas.waveColors[i]
                
                ctx.stroke()
            }
            
            // Reset global alpha and shadow for next frame to be safe
            ctx.globalAlpha = 1.0
            ctx.shadowColor = "transparent"
            ctx.shadowBlur = 0
        }
    }
}
