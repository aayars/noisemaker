/*
 * Translate image X and Y
 */

#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D inputTex;
uniform float translateX;
uniform float translateY;

out vec4 fragColor;

void main() {
    ivec2 texSize = textureSize(inputTex, 0);
    vec2 uv = gl_FragCoord.xy / vec2(texSize);
    
    // Apply translation with wrap
    uv.x = fract(uv.x - translateX);
    uv.y = fract(uv.y - translateY);

    fragColor = texture(inputTex, uv);
}
