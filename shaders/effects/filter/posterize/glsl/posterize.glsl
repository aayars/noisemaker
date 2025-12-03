/*
 * Color posterization effect
 * Reduces color levels for poster-like appearance
 */

#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D inputTex;
uniform float levels;

out vec4 fragColor;

vec3 posterize(vec3 color, float lev) {
    if (lev == 0.0) {
        return color;
    } else if (lev == 1.0) {
        return step(0.5, color);
    }
    
    float gamma = 0.65;
    color = pow(color, vec3(gamma));
    color = floor(color * lev) / lev;
    color = pow(color, vec3(1.0 / gamma));
    
    return color;
}

void main() {
    ivec2 texSize = textureSize(inputTex, 0);
    vec2 uv = gl_FragCoord.xy / vec2(texSize);
    
    vec4 color = texture(inputTex, uv);
    color.rgb = posterize(color.rgb, levels);
    
    fragColor = color;
}
