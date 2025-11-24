#version 300 es

precision highp float;
precision highp int;

// Generates intermediate noise fields used by the Spatter effect.
// Variant selector (size_variant.w) controls which noise recipe to emit:
// 0 = smear base, 1 = primary spatter dots, 2 = secondary dots, 3 = ridge mask.

const uint CHANNEL_COUNT = 4u;


uniform vec4 size_variant;
uniform vec4 timing_seed;

uint as_u32(float value) {
    if (value <= 0.0) {
        return 0u;
    }
    return uint(round(value));
}

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

float hash21(vec2 p) {
    float h = dot(p, vec2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

float hash31(vec3 p) {
    float h = dot(p, vec3(127.1, 311.7, 74.7));
    return fract(sin(h) * 43758.5453123);
}

float fade(float value) {
    return value * value * (3.0 - 2.0 * value);
}

float value_noise(vec2 p, float seed) {
    vec2 cell = floor(p);
    vec2 frac_part = fract(p);
    float tl = hash31(vec3(cell, seed));
    float tr = hash31(vec3(cell + vec2(1.0, 0.0), seed));
    float bl = hash31(vec3(cell + vec2(0.0, 1.0), seed));
    float br = hash31(vec3(cell + vec2(1.0, 1.0), seed));
    vec2 smooth_t = vec2(fade(frac_part.x), fade(frac_part.y));
    float top = mix(tl, tr, smooth_t.x);
    float bottom = mix(bl, br, smooth_t.x);
    return mix(top, bottom, smooth_t.y);
}

vec2 freq_for_shape(float base_freq, float width, float height) {
    if (base_freq <= 0.0) {
        return vec2(1.0, 1.0);
    }
    if (abs(width - height) < 1e-5) {
        return vec2(base_freq, base_freq);
    }
    if (height < width && height > 0.0) {
        return vec2(base_freq, base_freq * width / height);
    }
    if (width > 0.0) {
        return vec2(base_freq * height / width, base_freq);
    }
    return vec2(base_freq, base_freq);
}

vec2 periodic_offset(float time_value, float speed, float seed) {
    float angle = time_value * (0.35 + speed * 0.15) + seed * 1.97;
    float radius = 0.25 + 0.45 * hash21(vec2(seed, seed + 19.0));
    return vec2(cos(angle), sin(angle)) * radius;
}

void simple_multires_exp(float ridge(float value) {
    return 1.0 - abs(value * 2.0 - 1.0);
}

uint random_range_u32(vec2 seed, uint min_value, uint max_value) {
    if (max_value <= min_value) {
        return min_value;
    }
    float span = float(max_value - min_value + 1u);
    float value = hash21(seed) * span;
    return min_value + uint(floor(value));
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = as_u32(size_variant.x);
    uint height = as_u32(size_variant.y);
    if (width == 0u || height == 0u) {
        return;
    }
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    vec2 coords = vec2(int(global_id.x), int(global_id.y));
    vec2 dims = vec2(max(size_variant.x, 1.0), max(size_variant.y, 1.0));
    vec2 pixel_size = vec2(1.0 / dims.x, 1.0 / dims.y);
    vec2 uv = (vec2(float(coords.x), float(coords.y)) + 0.5) * pixel_size;

    float time_value = timing_seed.x;
    float speed_value = timing_seed.y;
    float base_seed = timing_seed.z;
    float variant_seed = timing_seed.w;
    uint variant = uint(max(round(size_variant.w), 0.0));

    float result = 0.0;
    if (variant == 0u) {
        uint freq_choice = random_range_u32(vec2(time_value * 0.17 + base_seed + 3.0, base_seed + 29.0), 3u, 6u);
        vec2 freq = freq_for_shape(float(freq_choice), dims.x, dims.y);
        result = simple_multires_exp(uv, freq, 6u, time_value, speed_value, base_seed + 23.0 + variant_seed);
    } else if (variant == 1u) {
        uint freq_choice = random_range_u32(vec2(time_value * 0.37 + base_seed + 5.0, base_seed + 59.0), 32u, 64u);
        vec2 freq = freq_for_shape(float(freq_choice), dims.x, dims.y);
        result = simple_multires_exp(uv, freq, 4u, time_value, speed_value, base_seed + 43.0 + variant_seed);
    } else if (variant == 2u) {
        uint freq_choice = random_range_u32(vec2(time_value * 0.41 + base_seed + 13.0, base_seed + 97.0), 150u, 200u);
        vec2 freq = freq_for_shape(float(freq_choice), dims.x, dims.y);
        result = simple_multires_exp(uv, freq, 4u, time_value, speed_value, base_seed + 71.0 + variant_seed);
    } else {
        uint freq_choice = random_range_u32(vec2(time_value * 0.23 + base_seed + 31.0, base_seed + 149.0), 2u, 3u);
        vec2 freq = freq_for_shape(float(freq_choice), dims.x, dims.y);
        float base_value = simple_multires_exp(uv, freq, 3u, time_value, speed_value, base_seed + 89.0 + variant_seed);
        result = ridge(base_value);
    }

    float clamped = clamp01(result);
    uint base_index = (global_id.y * width + global_id.x) * CHANNEL_COUNT;
    fragColor = vec4(clamped, clamped, clamped, 1.0);
}