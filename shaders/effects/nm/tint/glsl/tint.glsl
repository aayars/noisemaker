#version 300 es

precision highp float;
precision highp int;

// Tint effect: remap hue with deterministic RNG and blend with the source.
// Mirrors ``noisemaker.effects.tint``.

const uint CHANNEL_COUNT = 4u;
const vec3 ZERO_RGB = vec3(0.0);
const vec3 ONE_RGB = vec3(1.0);
const float ONE_THIRD = 1.0 / 3.0;
const float UINT32_SCALE = 1.0 / 4294967296.0;


uniform sampler2D input_texture;
uniform float width;
uniform float height;
uniform float channels;
uniform float time;
uniform float speed;
uniform float alpha;
uniform float seed;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

float positive_fract(float value) {
    return value - floor(value);
}

}

uint rotate_left(uint value, uint shift) {
    uint amount = shift & 31u;
    return (value << amount) | (value >> (32u - amount));
}

uint seed_from_params(TintParams p) {
    uint width_bits = floatBitsToUint(p.width);
    uint height_bits = floatBitsToUint(p.height);
    uint seed_bits = floatBitsToUint(p.seed);
    uint hash = 0x12345678u ^ width_bits;
    hash = hash ^ rotate_left(height_bits ^ 0x9e3779b9u, 7u);
    hash = hash ^ rotate_left(seed_bits ^ 0xc2b2ae35u, 3u);
    return hash;
}

float rng_next() {
    uint state = *(state_ptr);
    uint t = state + 0x6d2b79f5u;
    t = (t ^ (t >> 15u)) * (t | 1u);
    t = t ^ (t + ((t ^ (t >> 7u)) * (t | 61u)));
    uint masked = t & 0xffffffffu;
    state_ptr = masked;
    uint sample = (t ^ (t >> 14u)) & 0xffffffffu;
    return float(sample) * UINT32_SCALE;
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

    uint width = max(as_u32(width), 1u);
    uint height = max(as_u32(height), 1u);
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    vec2 coords = vec2(int(global_id.x), int(global_id.y));
    vec4 texel = texture(input_texture, (vec2(coords) + vec2(0.5)) / vec2(textureSize(input_texture, 0)));

    uint channel_count = max(as_u32(channels), 1u);
    bool has_color = channel_count >= 3u;
    bool has_alpha = channel_count >= 4u;
    float base_alpha = select(1.0, texel.w, has_alpha);

    if (!has_color) {
        fragColor = clamp(texel.xyz, ZERO_RGB, ONE_RGB), base_alpha;
        return;
    }

    float blend_alpha = clamp01(alpha);
    if (blend_alpha <= 0.0) {
        fragColor = clamp(texel.xyz, ZERO_RGB, ONE_RGB), base_alpha;
        return;
    }

    uint rng_state = seed_from_params(params);
    float random_a = rng_next(&rng_state);
    float random_b = rng_next(&rng_state);

    vec3 base_rgb = clamp(texel.xyz, ZERO_RGB, ONE_RGB);
    float hue_source = base_rgb.x * ONE_THIRD + random_a * ONE_THIRD + random_b;
    float hue = positive_fract(hue_source);

    vec3 base_hsv = rgb_to_hsv(base_rgb);
    vec3 tinted_hsv = vec3(hue, clamp01(base_rgb.y), clamp01(base_hsv.z));
    vec3 tinted_rgb = clamp(hsv_to_rgb(tinted_hsv), ZERO_RGB, ONE_RGB);

    vec3 blended_rgb = mix(base_rgb, tinted_rgb, vec3(blend_alpha));
    fragColor = blended_rgb, base_alpha;
}