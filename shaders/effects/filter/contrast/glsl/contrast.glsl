/*
 * Contrast adjustment effect
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

    float contrast = amount * 2.0;  // 0..1 -> 0..2
    color.rgb = (color.rgb - 0.5) * contrast + 0.5;

    fragColor = color;
}
