#version 300 es
precision highp float;

uniform sampler2D sourceTex;
uniform vec2 resolution;
uniform float intensity;

out vec4 fragColor;

void main() {
    vec2 uv = gl_FragCoord.xy / resolution;
    vec2 texelSize = 1.0 / resolution;
    
    // 3x3 box blur
    vec4 sum = vec4(0.0);
    for (int dy = -1; dy <= 1; dy++) {
        for (int dx = -1; dx <= 1; dx++) {
            vec2 offset = vec2(float(dx), float(dy)) * texelSize;
            sum += texture(sourceTex, uv + offset);
        }
    }
    vec4 blurred = sum / 9.0;
    
    // Apply intensity decay (persistence)
    float decay = clamp(intensity / 100.0, 0.0, 1.0);
    fragColor = blurred * decay;
}
