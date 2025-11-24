#version 300 es
precision highp float;

uniform sampler2D gridTex;
out vec4 fragColor;

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5) / vec2(textureSize(gridTex, 0));
    vec4 c = texture(gridTex, uv);
    fragColor = c;
}
