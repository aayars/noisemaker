#version 300 es
precision highp float;

uniform sampler2D srcTex;
uniform int brightness;
uniform int contrast;
uniform int hue;
uniform int saturation;

out vec4 fragColor;

void main() {
    vec2 uv = gl_FragCoord.xy / vec2(textureSize(srcTex, 0));
    fragColor = texture(srcTex, uv);
}
