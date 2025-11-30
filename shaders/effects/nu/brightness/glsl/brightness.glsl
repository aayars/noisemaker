/*
 * Brightness adjustment effect
 */

#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D inputTex;
uniform float amount;

out vec4 fragColor;

void main() {
    ivec2 texSize = textureSize(inputTex, 0);
    vec2 uv = gl_FragCoord.xy / vec2(texSize);
    vec4 color = texture(inputTex, uv);

    color.rgb *= amount;

    fragColor = color;
}
