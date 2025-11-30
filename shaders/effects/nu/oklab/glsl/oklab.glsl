/*
 * OKLab reinterpretation effect
 * Treats input RGB channels as OKLab values and converts to RGB
 */

#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D inputTex;

out vec4 fragColor;

// OKLab to linear sRGB matrices
const mat3 fwdA = mat3(1.0, 1.0, 1.0,
                       0.3963377774, -0.1055613458, -0.0894841775,
                       0.2158037573, -0.0638541728, -1.2914855480);

const mat3 fwdB = mat3(4.0767245293, -1.2681437731, -0.0041119885,
                       -3.3072168827, 2.6093323231, -0.7034763098,
                       0.2307590544, -0.3411344290, 1.7068625689);

vec3 linear_srgb_from_oklab(vec3 c) {
    vec3 lms = fwdA * c;
    return fwdB * (lms * lms * lms);
}

vec3 linearToSrgb(vec3 linear) {
    vec3 srgb;
    for (int i = 0; i < 3; ++i) {
        if (linear[i] <= 0.0031308) {
            srgb[i] = linear[i] * 12.92;
        } else {
            srgb[i] = 1.055 * pow(linear[i], 1.0 / 2.4) - 0.055;
        }
    }
    return srgb;
}

void main() {
    ivec2 texSize = textureSize(inputTex, 0);
    vec2 uv = gl_FragCoord.xy / vec2(texSize);
    vec4 color = texture(inputTex, uv);

    // Remap RGB to OKLab range and convert
    // magic values from py-noisemaker
    color.g = color.g * -0.509 + 0.276;
    color.b = color.b * -0.509 + 0.198;

    color.rgb = linear_srgb_from_oklab(color.rgb);
    color.rgb = linearToSrgb(color.rgb);

    fragColor = color;
}
