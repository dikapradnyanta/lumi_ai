#version 440

layout(location = 0) in vec2 v_uv;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float u_time;
    float u_audio;
    vec2 u_resolution;
    float u_band0;
    float u_band1;
    float u_band2;
    float u_band3;
    float u_band4;
} ubuf;

// Deep space blue
const vec3 C_BASE = vec3(0.0, 0.067, 0.2); // #001133
// Intense electric cyan
const vec3 C_CYAN = vec3(0.0, 0.667, 1.0); // #00aaff
// Lighter cyan for lines
const vec3 C_LINE = vec3(0.4, 0.8, 1.0);

// ── Noise Functions ───────────────────────────────────────────
float hash21(vec2 p) {
    p  = fract(p * vec2(127.1, 311.7));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(hash21(i),             hash21(i + vec2(1.0, 0.0)), u.x),
        mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x),
        u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;
    mat2 rot = mat2(0.866, -0.5, 0.5, 0.866);
    for (int i = 0; i < 4; i++) {
        v += a * vnoise(p);
        p = rot * p * 2.0 + vec2(1.7, 9.2);
        a *= 0.5;
    }
    return v;
}

// Function to get band by index
float getBand(int index) {
    if (index == 0) return ubuf.u_band0;
    if (index == 1) return ubuf.u_band1;
    if (index == 2) return ubuf.u_band2;
    if (index == 3) return ubuf.u_band3;
    return ubuf.u_band4;
}

void main() {
    vec2  uv   = v_uv - 0.5;
    uv.x      *= ubuf.u_resolution.x / ubuf.u_resolution.y;
    float d = length(uv);
    float angle = atan(uv.y, uv.x);

    // Audio reactivity mapping
    float drive = ubuf.u_audio;
    float speedMultiplier = 1.0 + drive * 3.0;
    float t = ubuf.u_time * 0.5 * speedMultiplier;

    // Ring dimensions
    float baseRadius = 0.32 + drive * 0.04;
    float ringThickness = 0.04 + drive * 0.02;
    
    float outerRadius = baseRadius + ringThickness;
    float innerRadius = baseRadius - ringThickness;

    float outerMask = 1.0 - smoothstep(outerRadius - 0.015, outerRadius + 0.005, d);
    float softFade = 0.12 + drive * 0.08;
    float innerMask = smoothstep(innerRadius - softFade, innerRadius + 0.01, d);
    float shapeMask = outerMask * innerMask;

    // Plasma/Noise texture
    vec2 noiseUV = vec2(angle * 2.0 + t, d * 15.0 - t * 0.5);
    float n = fbm(noiseUV * (1.5 + drive));
    
    float energy = shapeMask * n;
    float peakIntensity = smoothstep(0.4, 0.9, n);
    float glowBrightness = energy * (1.0 + drive * 2.5);

    vec3 color = mix(C_BASE, C_CYAN, peakIntensity * (0.5 + drive * 0.5));
    color += C_CYAN * glowBrightness * (0.5 + drive * 1.0);
    
    float ambientBloom = (1.0 - smoothstep(outerRadius, outerRadius + 0.08 + drive * 0.05, d)) * 
                         smoothstep(0.0, innerRadius + softFade, d);
    color += C_BASE * ambientBloom * (0.3 + drive * 0.4);

    float alpha = shapeMask * (0.6 + drive * 0.4) + (ambientBloom * 0.4) + glowBrightness;
    
    // ── Multiple Overlapping Glowing Lines ────────────────────────────────
    float linesGlow = 0.0;
    
    // Draw 10 lines
    for(int i = 0; i < 10; i++) {
        float fi = float(i);
        // Map line to a frequency band (0 to 4)
        float bandVal = getBand(i % 5);
        
        // Wobble math for the curved line
        // Angle offset based on time and index
        float waveFreq = 2.0 + mod(fi, 3.0);
        float waveSpeed = t * (0.5 + 0.2 * fi) + fi;
        
        // Sine wave distortion
        float distortion = sin(angle * waveFreq + waveSpeed) * 0.03 * (1.0 + bandVal * 2.0);
        
        // Slightly varying radius for each line
        float lineRadius = baseRadius + (fi - 4.5) * 0.005 + distortion;
        
        // Distance to this specific line
        float lineDist = abs(d - lineRadius);
        
        // Thickness and glow of the line modulated by the audio band
        float lineThickness = 0.001 + bandVal * 0.003;
        float lineGlowWidth = 0.008 + bandVal * 0.015;
        
        // Core of the line
        float core = smoothstep(lineThickness, 0.0, lineDist);
        
        // Outer glow of the line
        float lineGlow = smoothstep(lineGlowWidth, 0.0, lineDist) * 0.5;
        
        // Fade lines out heavily when there is no audio to keep idle state clean, 
        // or just let them glow gently.
        float lineAlpha = (core + lineGlow) * (0.15 + bandVal * 0.85);
        
        linesGlow += lineAlpha;
    }
    
    // Add lines to final color and alpha (additive)
    color += C_LINE * linesGlow * (0.5 + drive * 0.5);
    alpha += linesGlow * 0.6;
    // ──────────────────────────────────────────────────────────────────────

    alpha = clamp(alpha, 0.0, 1.0);
    alpha *= 1.0 - smoothstep(0.48, 0.50, d);
    
    vec4 finalColor = vec4(color * alpha, alpha) * ubuf.qt_Opacity;

    fragColor = finalColor;
}
