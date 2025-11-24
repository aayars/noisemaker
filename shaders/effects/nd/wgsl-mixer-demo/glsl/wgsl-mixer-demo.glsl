#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform sampler2D tex1;
uniform float mixAmt;

out vec4 fragColor;

void main() {
    vec2 uv = gl_FragCoord.xy / vec2(textureSize(tex0, 0));
    vec4 c0 = texture(tex0, uv);
    vec4 c1 = texture(tex1, uv);
    fragColor = mix(c0, c1, mixAmt);
}
