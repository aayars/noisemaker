/*
 * Step threshold effect
 * Creates hard edge at threshold value
 */

#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D inputTex;
uniform float threshold;

out vec4 fragColor;

void main() {
    ivec2 texSize = textureSize(inputTex, 0);
    vec2 uv = gl_FragCoord.xy / vec2(texSize);
    vec4 color = texture(inputTex, uv);

    color.rgb = step(threshold, color.rgb);

    fragColor = color;
}
