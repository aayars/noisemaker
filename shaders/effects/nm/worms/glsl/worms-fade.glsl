#version 300 es
precision highp float;

uniform sampler2D trailTex;
uniform float intensity;

out vec4 fragColor;

void main() {
    ivec2 size = textureSize(trailTex, 0);
    vec2 uv = gl_FragCoord.xy / vec2(size);
    
    vec4 trail = texture(trailTex, uv);
    
    // Decay based on intensity (higher intensity = slower decay)
    float decay = clamp(intensity / 100.0, 0.0, 0.99);
    fragColor = trail * decay;
}
