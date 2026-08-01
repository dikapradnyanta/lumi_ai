#version 440

layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;

layout(location = 0) out vec2 v_uv;

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

void main() {
    v_uv = qt_MultiTexCoord0;
    gl_Position = ubuf.qt_Matrix * qt_Vertex;
}
