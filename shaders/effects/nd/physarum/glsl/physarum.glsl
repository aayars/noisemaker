#version 300 es

precision highp float;
precision highp int;

uniform vec2 resolution;
uniform sampler2D bufTex;
uniform float time;
uniform int colorMode;
uniform int paletteMode;
uniform vec3 paletteOffset;
uniform vec3 paletteAmp;
uniform vec3 paletteFreq;
uniform vec3 palettePhase;
uniform int cyclePalette;
uniform float rotatePalette;
uniform float repeatPalette;
uniform float inputIntensity;
uniform sampler2D inputTex;

out vec4 fragColor;

vec3 hsv2rgb(vec3 hsv) {
    float h = fract(hsv.x);
    float s = clamp(hsv.y, 0.0, 1.0);
    float v = clamp(hsv.z, 0.0, 1.0);

    float c = v * s;
    float x = c * (1.0 - abs(mod(h * 6.0, 2.0) - 1.0));
    float m = v - c;

    vec3 rgb;

    if (h < 1.0 / 6.0) {
        rgb = vec3(c, x, 0.0);
    } else if (h < 2.0 / 6.0) {
        rgb = vec3(x, c, 0.0);
    } else if (h < 3.0 / 6.0) {
        rgb = vec3(0.0, c, x);
    } else if (h < 4.0 / 6.0) {
        rgb = vec3(0.0, x, c);
    } else if (h < 5.0 / 6.0) {
        rgb = vec3(x, 0.0, c);
    } else {
        rgb = vec3(c, 0.0, x);
    }

    return rgb + vec3(m);
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

const mat3 fwdA = mat3(1.0, 1.0, 1.0,
                       0.3963377774, -0.1055613458, -0.0894841775,
                       0.2158037573, -0.0638541728, -1.2914855480);

const mat3 fwdB = mat3(4.0767245293, -1.2681437731, -0.0041119885,
                       -3.3072168827, 2.6093323231, -0.7034763098,
                       0.2307590544, -0.3411344290,  1.7068625689);

const mat3 invB = mat3(0.4121656120, 0.2118591070, 0.0883097947,
                       0.5362752080, 0.6807189584, 0.2818474174,
                       0.0514575653, 0.1074065790, 0.6302613616);

const mat3 invA = mat3(0.2104542553, 1.9779984951, 0.0259040371,
                       0.7936177850, -2.4285922050, 0.7827717662,
                       -0.0040720468, 0.4505937099, -0.8086757660);

vec3 oklab_from_linear_srgb(vec3 c) {
    vec3 lms = invB * c;
    return invA * (sign(lms) * pow(abs(lms), vec3(0.3333333333333)));
}

vec3 linear_srgb_from_oklab(vec3 c) {
    vec3 lms = fwdA * c;
    return fwdB * (lms * lms * lms);
}

vec3 pal(float t) {
    float tt = t * repeatPalette + rotatePalette * 0.01;
    vec3 color = paletteOffset + paletteAmp * cos(6.28318 * (paletteFreq * tt + palettePhase));

    if (paletteMode == 1) {
        color = hsv2rgb(color);
    } else if (paletteMode == 2) {
        color.g = color.g * -.509 + .276;
        color.b = color.b * -.509 + .198;
        color = linear_srgb_from_oklab(color);
        color = linearToSrgb(color);
    }

    return color;
}

vec3 grade(float v) {
    float luma = clamp(v, 0.0, 1.0);
    if (colorMode == 1) {
        float d = luma;
        if (cyclePalette == -1) {
            d += time;
        } else if (cyclePalette == 1) {
            d -= time;
        }
        return pal(d);
    } else {
        return vec3(luma);
    }
}

vec3 sampleInputColor(vec2 uv) {
    vec2 flippedUV = vec2(uv.x, 1.0 - uv.y);
    return texture(inputTex, flippedUV).rgb;
}

void main() {
    vec2 uv = gl_FragCoord.xy / resolution;
    float trail = texture(bufTex, uv).r;
    float tone = trail / (1.0 + trail);
    vec3 color = grade(tone);
    
    // Blend input texture at output stage (like worms), not in feedback loop
    if (inputIntensity > 0.0) {
        float intensity = clamp(inputIntensity * 0.01, 0.0, 1.0);
        vec3 inputColor = sampleInputColor(uv);
        color = clamp(inputColor * intensity + color, 0.0, 1.0);
    }
    
    fragColor = vec4(color, 1.0);
}
