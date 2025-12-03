/*
 * Smoothstep threshold effect
 * Creates smooth transition between edge0 and edge1
 */

#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D inputTex;
uniform float edge0;
uniform float edge1;

out vec4 fragColor;

void main() {
    ivec2 texSize = textureSize(inputTex, 0);
    vec2 uv = gl_FragCoord.xy / vec2(texSize);
    vec4 color = texture(inputTex, uv);

    color.rgb = smoothstep(edge0, edge1, color.rgb);

    fragColor = color;
}
