import QtQuick
import QtQuick.Effects

// OrbCore.qml — v2 (voiceorb-inspired)
// Improvements over v1:
//   • Organic blob shape via multi-octave trig noise (mirrors voiceorb's simplex)
//   • Fresnel rim ring — glows brighter with audioLevel
//   • Audio-reactive displacement, shimmer, and ambient glow
//   • Specular highlight + inner edge darkening for depth
//
// New property:
//   audioLevel : real  — 0.0–1.0, bind from WaveIcon's currentLevel
//
// Wiring in SpeechOrb.qml:
//   WaveIcon { id: waveIcon ... }
//   OrbCore  { audioLevel: waveIcon.currentLevel ... }

Item {
    id: root
    width: 140
    height: 140

    // ── Public API (backward-compatible + new audioLevel) ────────
    property real glowRadius: 35
    property real orbScale: 1.0
    property color primaryColor: "#4DB6AC"
    property color containerColor: "#00695C"
    property color glowColor: "#26A69A"
    property real audioLevel: 0.0   // 0.0–1.0 — drives noise intensity & glow
    property string speechState: "idle"

    // ── Animation time ───────────────────────────────────────────
    property real _t: 0.0
    NumberAnimation on _t {
        from: 0.0
        to: 6283.185    // 2π × 1000, wraps cleanly
        duration: 60000
        loops: Animation.Infinite
        running: true
    }

    // ── Repaint at ~30fps ────────────────────────────────────────
    Timer {
        interval: 33
        running: true
        repeat: true
        onTriggered: {
            glowCanvas.requestPaint()
            orbCanvas.requestPaint()
        }
    }

    // ── 1. Ambient glow halo (audio-breathing) ───────────────────
    Canvas {
        id: glowCanvas
        anchors.centerIn: parent
        width: parent.width + root.glowRadius * 2 + root.audioLevel * 28
        height: width

        Behavior on width {
            NumberAnimation { duration: 180; easing.type: Easing.OutSine }
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var cx = width / 2, cy = height / 2
            var r  = Math.min(width, height) / 2
            var al = root.audioLevel

            var grad = ctx.createRadialGradient(cx, cy, r * 0.35, cx, cy, r)
            grad.addColorStop(0.0,  Qt.rgba(root.glowColor.r, root.glowColor.g, root.glowColor.b, 0.16 + al * 0.26).toString())
            grad.addColorStop(0.55, Qt.rgba(root.glowColor.r, root.glowColor.g, root.glowColor.b, 0.05).toString())
            grad.addColorStop(1.0,  "rgba(0,0,0,0)")

            ctx.beginPath()
            ctx.arc(cx, cy, r, 0, Math.PI * 2)
            ctx.fillStyle = grad
            ctx.fill()
        }
    }

    // ── 2. Fresnel rim ring ──────────────────────────────────────
    // Bright edge halo — intensifies with audio (voiceorb's fresnel effect)
    Item {
        id: fresnelRing
        anchors.centerIn: parent
        width: parent.width * root.orbScale + 8 + root.audioLevel * 8
        height: width

        Behavior on width {
            NumberAnimation { duration: 100; easing.type: Easing.OutSine }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.35
            blurMax: 14
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            antialiasing: true
            border.color: Qt.rgba(
                root.glowColor.r,
                root.glowColor.g,
                root.glowColor.b,
                0.28 + root.audioLevel * 0.60
            )
            border.width: 1.5 + root.audioLevel * 3.0

            Behavior on border.width {
                NumberAnimation { duration: 80 }
            }
        }
    }

    // ── 3. Main orb — organic blob + specular + shimmer ─────────
    Canvas {
        id: orbCanvas
        anchors.centerIn: parent
        width: parent.width * root.orbScale
        height: width
        antialiasing: true
        renderStrategy: Canvas.Threaded
        renderTarget: Canvas.FramebufferObject

        onPaint: {
            var ctx = getContext("2d")
            var w  = width, h = height
            var cx = w / 2, cy = h / 2
            var r  = Math.min(w, h) / 2 - 1.5
            var t  = root._t * 0.001   // slow, smooth time
            var al = root.audioLevel

            ctx.clearRect(0, 0, w, h)

            // ── Blob shape helper ─────────────────────────────────
            // Multi-octave trig noise — mirrors voiceorb's simplex displacement
            var N        = 200
            var displace = r * (0.055 + al * 0.16)

            function blobPath() {
                ctx.beginPath()
                for (var i = 0; i <= N; i++) {
                    var angle = (i / N) * Math.PI * 2
                    var ca = Math.cos(angle), sa = Math.sin(angle)

                    // Octave 1 — low-freq form
                    var n1 = Math.sin(ca * 3.1 + t * 1.05) * Math.cos(sa * 2.6 + t * 0.80)
                    // Octave 2 — mid-freq detail
                    var n2 = Math.sin(ca * 7.3 - t * 0.55) * Math.sin(sa * 8.0 + t * 0.42)
                    // Octave 3 — high-freq texture (boosted by audio)
                    var n3 = Math.cos(ca * 13.4 + t * 1.75) * Math.cos(sa * 12.6 - t * 0.95)
                    var n  = n1 * 0.50 + n2 * 0.30 + n3 * (0.20 + al * 0.15)

                    var pr = r + n * displace
                    if (i === 0) ctx.moveTo(cx + pr * ca, cy + pr * sa)
                    else         ctx.lineTo(cx + pr * ca, cy + pr * sa)
                }
                ctx.closePath()
            }

            // ── Pass 1: base gradient fill ────────────────────────
            ctx.save()
            blobPath()
            var baseGrad = ctx.createRadialGradient(
                cx - r * 0.22, cy - r * 0.24, r * 0.04,
                cx + r * 0.08, cy + r * 0.08, r * 1.18
            )
            baseGrad.addColorStop(0.00, Qt.lighter(root.primaryColor, 1.50).toString())
            baseGrad.addColorStop(0.42, root.primaryColor.toString())
            baseGrad.addColorStop(1.00, root.containerColor.toString())
            ctx.fillStyle = baseGrad
            ctx.fill()
            ctx.restore()

            // ── Pass 2: inner layers clipped to blob ──────────────
            ctx.save()
            blobPath()
            ctx.clip()

            // Orbiting shimmer (audio-reactive, invisible when quiet)
            if (al > 0.04) {
                var shimmerGrad = ctx.createRadialGradient(
                    cx + Math.cos(t * 2.1) * r * 0.32,
                    cy + Math.sin(t * 1.65) * r * 0.32,
                    0,
                    cx, cy, r
                )
                shimmerGrad.addColorStop(0.0, Qt.rgba(
                    root.glowColor.r, root.glowColor.g, root.glowColor.b,
                    al * 0.42
                ).toString())
                shimmerGrad.addColorStop(0.7, "rgba(0,0,0,0)")
                ctx.fillStyle = shimmerGrad
                ctx.fillRect(0, 0, w, h)
            }

            // Specular highlight — top-left corner, glass feel
            var specGrad = ctx.createRadialGradient(
                cx - r * 0.28, cy - r * 0.30, 0,
                cx - r * 0.08, cy - r * 0.10, r * 0.60
            )
            specGrad.addColorStop(0.00, "rgba(255,255,255,0.32)")
            specGrad.addColorStop(0.55, "rgba(255,255,255,0.06)")
            specGrad.addColorStop(1.00, "rgba(255,255,255,0.00)")
            ctx.fillStyle = specGrad
            ctx.fillRect(0, 0, w, h)

            // Fresnel inner edge darkening — depth without shaders
            var edgeGrad = ctx.createRadialGradient(cx, cy, r * 0.50, cx, cy, r * 1.05)
            edgeGrad.addColorStop(0.0, "rgba(0,0,0,0.00)")
            edgeGrad.addColorStop(1.0, "rgba(0,0,0,0.28)")
            ctx.fillStyle = edgeGrad
            ctx.fillRect(0, 0, w, h)

            ctx.restore()
        }
    }
}
