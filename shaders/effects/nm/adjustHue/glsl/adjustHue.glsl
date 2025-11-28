#version 300 es

precision highp float;
precision highp int;

// Adjusts image hue to mirror tf.image.adjust_hue from the Python reference.


const uint CHANNEL_COUNT = 4u;
const vec3 ZERO_RGB = vec3(0.0);
const vec3 ONE_RGB = vec3(1.0);

uniform sampler2D inputTex;
uniform vec2 resolution;
uniform float amount;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

float wrap_unit(float value) {
    return fract(value + 1.0);
}

vec3 rgb_to_hsv(vec3 rgb) {
    float r = rgb.x;
    float g = rgb.y;
    float b = rgb.z;
    float max_c = max(max(r, g), b);
    float min_c = min(min(r, g), b);
    float delta = max_c - min_c;

    float hue = 0.0;
    if (delta != 0.0) {
        if (max_c == r) {
            float raw = (g - b) / delta;
            raw = raw - floor(raw / 6.0) * 6.0;
            if (raw < 0.0) {
                raw = raw + 6.0;
            }
            hue = raw;
        } else if (max_c == g) {
            hue = (b - r) / delta + 2.0;
        } else {
            hue = (r - g) / delta + 4.0;
        }
    }

    hue = hue / 6.0;
    if (hue < 0.0) {
        hue = hue + 1.0;
    }

    float saturation = 0.0;
    if (max_c != 0.0) {
        saturation = delta / max_c;
    }

    return vec3(hue, saturation, max_c);
}

vec3 hsv_to_rgb(vec3 hsv) {
    float h = hsv.x;
    float s = hsv.y;
    float v = hsv.z;
    float dh = h * 6.0;
    float dr = clamp01(abs(dh - 3.0) - 1.0);
    float dg = clamp01(-abs(dh - 2.0) + 2.0);
    float db = clamp01(-abs(dh - 4.0) + 2.0);
    float one_minus_s = 1.0 - s;
    float sr = s * dr;
    float sg = s * dg;
    float sb = s * db;
    float r = (one_minus_s + sr) * v;
    float g = (one_minus_s + sg) * v;
    float b = (one_minus_s + sb) * v;
    return vec3(r, g, b);
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = as_u32(resolution.x);
    uint height = as_u32(resolution.y);
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    vec2 coords = vec2(int(global_id.x), int(global_id.y));
    vec4 texel = texture(inputTex, (vec2(coords) + vec2(0.5)) / vec2(textureSize(inputTex, 0)));

    uint channelCount = 4u;
    float hueAmount = amount;
    if (channelCount < 3u || hueAmount == 0.0 || hueAmount == 1.0) {
        fragColor = vec4(texel.xyz, texel.w);
        return;
    }

    vec3 rgb = clamp(texel.xyz, ZERO_RGB, ONE_RGB);
    vec3 hsv = rgb_to_hsv(rgb);
    hsv.x = wrap_unit(hsv.x + hueAmount);
    hsv.y = clamp01(hsv.y);
    hsv.z = clamp01(hsv.z);
    vec3 adjusted = clamp(hsv_to_rgb(hsv), ZERO_RGB, ONE_RGB);

    fragColor = vec4(adjusted, texel.w);
}