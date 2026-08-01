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

    property var _animMicLevels: [0.08, 0.08, 0.08, 0.08, 0.08]

    // AI voice animation array for simulated speaking
    property var aiLevels: [0.1, 0.1, 0.1, 0.1, 0.1]
    Timer {
        interval: 100
        running: root.speechState === "speaking" && root.visible
        repeat: true
        onTriggered: {
            root.aiLevels = [
                0.2 + Math.random() * 0.7,
                0.3 + Math.random() * 0.6,
                0.4 + Math.random() * 0.6,
                0.3 + Math.random() * 0.7,
                0.2 + Math.random() * 0.5
            ]
        }
    }

    Timer {
        interval: 16
        running: root.visible
        repeat: true
        onTriggered: {
            // Smoothly interpolate micLevels for fluid rendering
            var targetLevels = root.speechState === "listening" ? root.micLevels : 
                               root.speechState === "speaking" ? root.aiLevels : 
                               root.speechState === "thinking" ? [0.4, 0.5, 0.6, 0.5, 0.4] :
                               [0.05, 0.05, 0.05, 0.05, 0.05]; // idle

            var newAnim = []
            for (var i = 0; i < 5; i++) {
                // simple low pass filter for smoothness
                newAnim.push(root._animMicLevels[i] + (targetLevels[i] - root._animMicLevels[i]) * 0.35)
            }
            root._animMicLevels = newAnim
            orbCanvas.requestPaint()
        }
    }

    property real _t: 0.0
    NumberAnimation on _t {
        from: 0.0
        to: 10000.0
        duration: 200000
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

        // Matugen-based color palette for the lines
        readonly property var waveColors: [
            root.primaryColor,
            root.tertiaryColor,
            root.containerColor,
            root.secondaryContainerColor,
            Qt.tint(root.primaryColor, Qt.rgba(1,1,1,0.5)) // Lighter variation
        ]

        onPaint: {
            var ctx = getContext("2d")
            var w  = width, h = height
            var cx = w / 2, cy = h / 2
            
            // Adjust base radius based on state
            var stateBaseMod = root.speechState === "idle" ? 0.4 :
                               root.speechState === "thinking" ? 0.35 : 0.55
            
            // Base the geometry on root.width so enlarging the canvas doesn't scale up the orb
            var refSize = root.width * root.orbScale
            var baseR = refSize / 2 * stateBaseMod
            
            // Thinking state speeds up time to create a fast spinning vortex
            var timeSpeed = root.speechState === "thinking" ? 8.0 :
                            root.speechState === "idle" ? 0.5 : 2.5
            var t  = root._t * timeSpeed

            ctx.clearRect(0, 0, w, h)
            ctx.globalCompositeOperation = "lighter" // Additive blending for neon glow

            // Draw 10 overlapping plasma waves
            for (var i = 0; i < 10; i++) {
                // Map the 10 lines to the 5 frequency bands
                var bandIndex = i % 5
                var rawVal = root._animMicLevels[bandIndex]
                var level = root.speechState === "listening" ? Math.pow(rawVal, 0.6) * 1.5 : rawVal
                
                // Base amplitude response
                var waveAmpli = baseR * 0.8 * level * (Config.lumiOrbWaviness || 1.0)
                
                // Thinking state creates a tight, turbulent knot
                if (root.speechState === "thinking") {
                    waveAmpli = baseR * 0.4 * (1.0 + Math.sin(t + i)) * (Config.lumiOrbWaviness || 1.0)
                }
                
                ctx.beginPath()
                // Iterate through angles to draw the wavy circle
                for (var angle = 0; angle <= Math.PI * 2 + 0.1; angle += 0.08) {
                    
                    // Complex trig noise to create swirling waves
                    // Frequency of the wave pattern
                    var freq = 2.0 + (i % 3)
                    
                    // The distortion logic
                    var noise = Math.sin(angle * freq + t * (0.5 + i * 0.1)) * waveAmpli
                    var noise2 = Math.cos(angle * (freq + 1) - t * (0.8 + i * 0.15)) * (waveAmpli * 0.6)
                    
                    var currentR = baseR + noise + noise2
                    
                    // Add slight 3D rotation wobble offset per line
                    var wobbleX = Math.cos(t * 0.5 + i) * 20 * level * Config.lumiOrbWaviness
                    var wobbleY = Math.sin(t * 0.5 - i) * 20 * level * Config.lumiOrbWaviness

                    var x = cx + wobbleX + currentR * Math.cos(angle)
                    var y = cy + wobbleY + currentR * Math.sin(angle)
                    
                    if (angle === 0) ctx.moveTo(x, y)
                    else ctx.lineTo(x, y)
                }
                ctx.closePath()

                // Stroke styling
                // Thicker lines when speaking or loud, thin during idle
                var baseThickness = root.speechState === "idle" ? 1.5 : (2.0 + level * 5.0)
                ctx.lineWidth = baseThickness * Config.lumiOrbThickness
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                
                var colorStr = orbCanvas.waveColors[i % 5].toString()
                
                // Add stroke glow via shadow
                ctx.shadowColor = colorStr
                ctx.shadowBlur = root.speechState === "idle" ? 5 : (10 + level * 20)
                
                ctx.globalAlpha = root.speechState === "idle" ? 0.4 : (0.5 + level * 0.5)
                ctx.strokeStyle = colorStr
                
                ctx.stroke()
            }
            
            // Reset global alpha and shadow for safety
            ctx.globalAlpha = 1.0
            ctx.shadowColor = "transparent"
            ctx.shadowBlur = 0
        }
    }
}
