# Lumi AI v2 — Design System & UI Guide

## Visual Philosophy

Lumi AI v2 is built using modern UI principles for Linux desktop widgets:

1. **Rich Aesthetics & Glassmorphism**: Soft ambient shadows, translucent surfaces, and Catppuccin / Matugen color palettes.
2. **Dynamic Micro-Animations**: Smooth transition curves (`OutExpo`, `OutCubic`), glowing active states, and animated pulsing orb visualizers.
3. **Typography**: Uses modern fonts including **Inter** for interface text, **JetBrains Mono** for code/input fields, and **Iosevka Nerd Font** for crisp icons.

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

### 1. `VoicePanel.qml`
- **Animated Audio Orb**: Multi-ring canvas glowing based on speech state (`listening`, `thinking`, `speaking`).
- **Waveform Visualizer**: Real-time sine wave audio visualizer reactive to microphone volume level.
- **Transcript Display**: Live partial transcript preview and assistant subtitle display.

### 2. `ChatView.qml`
- **Message Bubbles**: Styled user, assistant, and error message cards.
- **Auto-scroll**: Automatically scrolls down as new assistant text or streaming updates arrive.
- **Thinking Indicator**: Pulsing dot animation indicating background Gemini processing.

### 3. `LumiConfigTab.qml` (Settings UI)
- **Calibration Card**: Dedicated 2-stage calibration container featuring a clean trigger button, threshold input, and multi-line error card with text wrapping.
- **Device Selector**: PulseAudio / PipeWire source selection dropdown.
