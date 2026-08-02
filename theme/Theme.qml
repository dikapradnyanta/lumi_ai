pragma Singleton
import QtQuick

// ============================================================
// Lumi v2 — Theme.qml
// Semua warna di-proxy dari MatugenColors (illyamiro) secara
// reaktif. Tidak ada hardcoded hex. Saat matugen generate warna
// baru dari wallpaper, Lumi otomatis ikut berubah.
// ============================================================
QtObject {
    id: theme

    // ── Proxy ke MatugenColors singleton illyamiro ──────────
    readonly property color bgBase:        MatugenColors.crust        // #11111b
    readonly property color surface:       MatugenColors.mantle       // #181825
    readonly property color surfaceAlt:    MatugenColors.base         // #1e1e2e
    readonly property color surfaceHover:  MatugenColors.surface0     // #313244
    readonly property color surfaceActive: MatugenColors.surface1     // #45475a
    readonly property color surfaceBright: MatugenColors.surface2     // #585b70

    // ── Teks ─────────────────────────────────────────────────
    readonly property color textPrimary:   MatugenColors.text         // #cdd6f4
    readonly property color textSecondary: MatugenColors.subtext0     // #a6adc8
    readonly property color textMuted:     MatugenColors.overlay0     // #6c7086
    readonly property color textHint:      MatugenColors.overlay1     // #7f849c

    // ── Aksen ────────────────────────────────────────────────
    readonly property color accentStop:    MatugenColors.peach        // #fab387 — Stop/Interrupt
    readonly property color accentPrimary: MatugenColors.mauve        // #cba6f7 — Focus/Active
    readonly property color accentSuccess: MatugenColors.green        // #a6e3a1 — Answer Now
    readonly property color accentError:   MatugenColors.red          // #f38ba8 — Error state
    readonly property color accentInfo:    MatugenColors.blue         // #89b4fa — Thinking orb
    readonly property color accentGlow:    MatugenColors.sapphire     // #74c7ec — Orb glow
    readonly property color accentTeal:    MatugenColors.teal         // #94e2d5 — Speaking state

    // ── Border ───────────────────────────────────────────────
    readonly property color borderDefault: MatugenColors.surface1     // #45475a
    readonly property color borderFocus:   MatugenColors.mauve        // #cba6f7
    readonly property color borderSubtle:  MatugenColors.surface0     // #313244

    // ── Waveform ─────────────────────────────────────────────
    readonly property color waveformBar:   MatugenColors.text         // #cdd6f4
    readonly property color waveformGlow:  MatugenColors.blue         // #89b4fa

    // ── Geometry (dari design.md) ─────────────────────────────
    readonly property int radiusWindow:  24
    readonly property int radiusInput:   24   // pill shape
    readonly property int radiusBubble:  16
    readonly property int radiusButton:  16
    readonly property int radiusSmall:   8

    // ── Spacing (base 4px) ────────────────────────────────────
    readonly property int sp4:  4
    readonly property int sp8:  8
    readonly property int sp12: 12
    readonly property int sp16: 16
    readonly property int sp24: 24
    readonly property int sp32: 32
    readonly property int sp48: 48

    // ── Animasi (dari design.md) ──────────────────────────────
    readonly property int durationFast:   150  // hover, focus
    readonly property int durationStd:    200  // mode switch, bubble
    readonly property int durationSlow:   400  // orb pulse

    // ── Tipografi ─────────────────────────────────────────────
    readonly property string fontFamily:  "Inter"
    readonly property int fontBody:       14   // body text
    readonly property int fontCaption:    18   // voice subtitle
    readonly property int fontSmall:      12   // quick reply, timestamp
    readonly property int fontMono:       13   // kode inline
}
