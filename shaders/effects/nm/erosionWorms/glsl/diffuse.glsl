#version 300 es
precision highp float;
uniform sampler2D sourceTex;
uniform vec2 resolution;
uniform float intensity;

out vec4 fragColor;

void main() {
    vec2 texel = 1.0 / resolution;
    vec2 uv = gl_FragCoord.xy * texel;
    
    // Simple blur for trail diffusion
    vec4 sum = vec4(0.0);
    for (int x = -1; x <= 1; ++x) {
        for (int y = -1; y <= 1; ++y) {
            vec2 offset = vec2(float(x), float(y)) * texel;
            sum += texture(sourceTex, uv + offset);
        }
    }
    
    vec4 current = texture(sourceTex, uv);
    float decay = (100.0 - intensity) * 0.001; // intensity controls persistence
    vec4 blurred = mix(current, sum / 9.0, 0.25);
    vec4 value = max(blurred - vec4(decay), vec4(0.0));
    
    fragColor = vec4(value.rgb, 1.0);
}
