#version 300 es
precision highp float;

uniform sampler2D trailTex;
uniform float intensity; // Trail persistence

out vec4 fragColor;

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5) / vec2(textureSize(trailTex, 0));
    vec4 trail = texture(trailTex, uv);
    float fade = clamp(intensity / 100.0, 0.0, 1.0);
    fragColor = trail * fade;
}
