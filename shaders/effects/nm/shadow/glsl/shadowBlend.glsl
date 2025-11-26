#version 300 es

precision highp float;
precision highp int;

uniform sampler2D inputTex;
uniform sampler2D sobelTexture;
uniform sampler2D sharpenTexture;
uniform float alpha;

out vec4 fragColor;

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

vec3 clampVec3(vec3 value) {
    return clamp(value, vec3(0.0), vec3(1.0));
}

vec3 rgbToHsv(vec3 rgb) {
    vec3 color = clampVec3(rgb);
    float maxVal = max(max(color.r, color.g), color.b);
    float minVal = min(min(color.r, color.g), color.b);
    float delta = maxVal - minVal;

    float hue = 0.0;
    if (delta > 1e-6) {
        if (maxVal == color.r) {
            hue = (color.g - color.b) / delta;
        } else if (maxVal == color.g) {
            hue = 2.0 + (color.b - color.r) / delta;
        } else {
            hue = 4.0 + (color.r - color.g) / delta;
        }
        hue /= 6.0;
        if (hue < 0.0) {
            hue += 1.0;
        }
    }

    float saturation = maxVal <= 1e-6 ? 0.0 : delta / maxVal;
    return vec3(hue, saturation, maxVal);
}

vec3 hsvToRgb(vec3 hsv) {
    float h = hsv.x * 6.0;
    float s = clamp01(hsv.y);
    float v = clamp01(hsv.z);

    float sector = floor(h);
    float fraction = h - sector;

    float p = v * (1.0 - s);
    float q = v * (1.0 - fraction * s);
    float t = v * (1.0 - (1.0 - fraction) * s);

    if (sector == 0.0) {
        return vec3(v, t, p);
    }
    if (sector == 1.0) {
        return vec3(q, v, p);
    }
    if (sector == 2.0) {
        return vec3(p, v, t);
    }
    if (sector == 3.0) {
        return vec3(p, q, v);
    }
    if (sector == 4.0) {
        return vec3(t, p, v);
    }
    return vec3(v, p, q);
}

float shadeComponent(float srcValue, float finalShade, float highlight) {
    float dark = (1.0 - srcValue) * (1.0 - highlight);
    float lit = 1.0 - dark;
    return clamp01(lit * finalShade);
}

void main() {
    ivec2 dimensions = textureSize(inputTex, 0);
    if (dimensions.x == 0 || dimensions.y == 0) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 uv = (gl_FragCoord.xy - vec2(0.5)) / vec2(max(dimensions.x, 1), max(dimensions.y, 1));
    vec4 baseColor = texture(inputTex, uv);
    float shadeNorm = texture(sobelTexture, uv).r;
    float sharpenNorm = texture(sharpenTexture, uv).r;

    float finalShade = mix(shadeNorm, sharpenNorm, 0.5);
    float highlight = clamp01(finalShade * finalShade);
    float blendFactor = clamp01(alpha);

    float shadeR = shadeComponent(baseColor.r, finalShade, highlight);
    float shadeG = shadeComponent(baseColor.g, finalShade, highlight);
    float shadeB = shadeComponent(baseColor.b, finalShade, highlight);

    vec3 baseHSV = rgbToHsv(baseColor.rgb);
    vec3 shadeHSV = rgbToHsv(vec3(shadeR, shadeG, shadeB));
    float finalValue = mix(baseHSV.z, shadeHSV.z, blendFactor);
    vec3 finalRGB = hsvToRgb(vec3(baseHSV.x, baseHSV.y, finalValue));

    fragColor = vec4(finalRGB, baseColor.a);
}
