#version 300 es
precision highp float;

uniform sampler2D inputTex;
uniform float alpha;

out vec4 fragColor;

void main() {
    vec2 uv = gl_FragCoord.xy / vec2(textureSize(inputTex, 0));
    vec4 color = texture(inputTex, uv);
    fragColor = color;
}
