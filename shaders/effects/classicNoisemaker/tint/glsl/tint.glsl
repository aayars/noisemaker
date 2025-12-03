#version 300 es

precision highp float;
precision highp int;

// Tint effect: remap hue with deterministic RNG and blend with the source.

uniform sampler2D inputTex;
uniform float time;
uniform float alpha;

in vec2 v_texCoord;
out vec4 fragColor;

const float ONE_THIRD = 1.0 / 3.0;
const float UINT32_SCALE = 1.0 / 4294967296.0;

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

float positive_fract(float value) {
    return value - floor(value);
}

// Simple hash function for random numbers
float hash21(vec2 p) {
    float h = dot(p, vec2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
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

void main() {
    vec4 texel = texture(inputTex, v_texCoord);
    vec2 dims = vec2(textureSize(inputTex, 0));

    float blend_alpha = clamp01(alpha);
    if (blend_alpha <= 0.0) {
        fragColor = vec4(clamp(texel.rgb, 0.0, 1.0), texel.a);
        return;
    }

    // Generate random values based on time and seed
    float random_a = hash21(vec2(time * 17.3, dims.x));
    float random_b = hash21(vec2(time * 31.7, dims.y));

    vec3 base_rgb = clamp(texel.rgb, 0.0, 1.0);
    float hue_source = base_rgb.x * ONE_THIRD + random_a * ONE_THIRD + random_b;
    float hue = positive_fract(hue_source);

    vec3 base_hsv = rgb_to_hsv(base_rgb);
    vec3 tinted_hsv = vec3(hue, clamp01(base_rgb.y), clamp01(base_hsv.z));
    vec3 tinted_rgb = clamp(hsv_to_rgb(tinted_hsv), 0.0, 1.0);

    vec3 blended_rgb = mix(base_rgb, tinted_rgb, blend_alpha);
    fragColor = vec4(blended_rgb, texel.a);
}
