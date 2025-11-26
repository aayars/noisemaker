#version 300 es

precision highp float;
precision highp int;

// Adjust Saturation: matches tf.image.adjust_saturation by scaling HSV saturation.


const uint CHANNEL_COUNT = 4u;

uniform sampler2D inputTex;
uniform vec2 resolution;
uniform float amount;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

float clamp_unit(float value) {
    return clamp(value, 0.0, 1.0);
}

float wrap_unit(float value) {
    float wrapped = value - floor(value);
    return (wrapped < 0.0 ? wrapped + 1.0 : wrapped);
}

vec3 rgb_to_hsv(vec3 rgb) {
    float r = rgb.x;
    float g = rgb.y;
    float b = rgb.z;
    float max_c = max(max(r, g), b);
    float min_c = min(min(r, g), b);
    float delta = max_c - min_c;

    float hue = 0.0;
    if (delta > 0.0) {
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

        hue = wrap_unit(hue / 6.0);
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
    float dr = clamp_unit(abs(dh - 3.0) - 1.0);
    float dg = clamp_unit(-abs(dh - 2.0) + 2.0);
    float db = clamp_unit(-abs(dh - 4.0) + 2.0);
    float one_minus_s = 1.0 - s;
    float sr = s * dr;
    float sg = s * dg;
    float sb = s * db;
    float r = clamp_unit((one_minus_s + sr) * v);
    float g = clamp_unit((one_minus_s + sg) * v);
    float b = clamp_unit((one_minus_s + sb) * v);
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
    if (channelCount < 3u) {
        fragColor = vec4(texel.xyz, texel.w);
        return;
    }

    float amount = amount;
    vec3 hsv = rgb_to_hsv(texel.xyz);
    hsv.y = clamp_unit(hsv.y * amount);
    vec3 adjusted_rgb = clamp(hsv_to_rgb(hsv), vec3(0.0), vec3(1.0));

    fragColor = vec4(adjusted_rgb, texel.w);
}