#version 300 es
precision highp float;
precision highp int;

uniform sampler2D sourceTex;
uniform vec2 resolution;
uniform float decay;
uniform float diffusion;
uniform float intensity;

out vec4 fragColor;

void main() {
    vec2 texel = 1.0 / resolution;
    vec2 uv = gl_FragCoord.xy * texel;

    float sum = 0.0;
    for (int x = -1; x <= 1; ++x) {
        for (int y = -1; y <= 1; ++y) {
            vec2 offset = vec2(float(x), float(y)) * texel;
            sum += texture(sourceTex, uv + offset).r;
        }
    }

    float current = texture(sourceTex, uv).r;
    float blurred = mix(current, sum / 9.0, clamp(diffusion, 0.0, 1.0));
    float value = max(blurred - max(decay, 0.0), 0.0);
    
    fragColor = vec4(value, 0.0, 0.0, 1.0);
}
