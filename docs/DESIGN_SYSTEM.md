# Lumi AI v2 — Design System & UI Guide

## Visual Philosophy

Lumi AI v2 is built using modern UI principles for Linux desktop widgets:

1. **Rich Aesthetics & Glassmorphism**: Soft ambient shadows, translucent surfaces, and Catppuccin / Matugen color palettes.
2. **Official SVG Vector Logo**: Clean minimalist cat-on-planet icon (`assets/lumi_logo.svg`) supporting dynamic `currentColor` fill.
3. **Dynamic Micro-Animations**: Smooth transition curves (`OutExpo`, `OutCubic`), glowing active aura states, and 7-band FFT animated waveform visualizer.
4. **Typography**: Uses modern fonts including **Inter** for interface text, **JetBrains Mono** for code/input fields, and **Iosevka Nerd Font** for crisp icons.

---

## Color Tokens & Theme Integration

The UI dynamically inherits color tokens from **Matugen / Catppuccin**:

```qml
// Theme Token Reference
property color base:     "#1e1e2e" // Background surface
property color mantle:   "#181825" // Header & container background
property color surface0: "#313244" // Sub-surfaces & borders
property color red:      "#f38ba8" // Accent color (mic active / errors)
property color green:    "#a6e3a1" // Success state / calibration ok
property color mauve:    "#cba6f7" // Mode toggles & primary buttons
property color text:     "#cdd6f4" // Primary typography
```

---

## UI Components Overview

### 1. `assets/lumi_logo.svg`
- Scalable SVG vector icon featuring a sleeping cat wrapped around a ringed planet with a 4-point sparkle star.
- Uses `fill="currentColor"` so it automatically inherits theme text/accent color.

### 2. `VoicePanel.qml`
- **Ambient Aura Glow**: Soft pulsing background glow reflecting active voice states (`listening`, `thinking`, `speaking`, `error`).
- **7-Bar Waveform Visualizer**: Real-time frequency analyzer driven by 7-band FFT input from `mic_level.py`.
- **Karaoke Flow**: Word-by-word highlighted text preview as Lumi synthesizes speech.
- **Interactive Ring Controls**: ChatGPT-style action buttons for interrupting, force-sending, or canceling sessions.

### 3. `ChatView.qml`
- **Message Bubbles**: Styled user, assistant, and error message cards.
- **Auto-scroll**: Automatically scrolls down as new assistant text arrives.
- **Thinking Indicator**: Pulsing dot animation indicating background Gemini API processing.

### 4. `LumiConfigTab.qml` (Settings UI)
- **Calibration Card**: Dedicated 2-stage calibration container featuring a clean trigger button, threshold input, and multi-line status card.
- **Device Selector**: PulseAudio / PipeWire source selection dropdown.
