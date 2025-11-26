#version 300 es
precision highp float;

uniform sampler2D stateTex;

out vec4 fragColor;

void main() {
    vec2 texSize = vec2(textureSize(stateTex, 0));
    vec2 uv = gl_FragCoord.xy / texSize;
    fragColor = texture(stateTex, uv);
}
