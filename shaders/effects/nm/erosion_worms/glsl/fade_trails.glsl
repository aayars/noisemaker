#version 300 es
precision highp float;

uniform sampler2D trailTex;
uniform float intensity; // Trail persistence

out vec4 fragColor;

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5) / vec2(textureSize(trailTex, 0));
    vec4 c = texture(trailTex, uv);
    // Fade
    c *= 0.95; // Decay
    fragColor = c;
}
