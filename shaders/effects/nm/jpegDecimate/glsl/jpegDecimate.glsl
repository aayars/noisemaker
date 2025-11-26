#version 300 es

precision highp float;
precision highp int;

// GPU recreation of Noisemaker's jpeg_decimate effect. Approximates repeated JPEG
// compression in a single compute dispatch by performing a fixed series of randomized
// quantization and block-sampling steps that mutate the working color.

const uint CHANNEL_COUNT = 4u;
const float INV_U32_MAX = 1.0 / 4294967296.0;
const uint QUALITY_MIN = 5u;
const uint QUALITY_MAX = 50u;
const float QUALITY_SPAN = float(QUALITY_MAX - QUALITY_MIN);
const uint DENSITY_MIN = 50u;
const uint DENSITY_MAX = 500u;
const float DENSITY_SCALE_MIN = 0.5;
const float DENSITY_SCALE_MAX = 4.0;
const float BLOCK_SIZE_MIN = 1.0;
const float BLOCK_SIZE_MAX = 12.0;
const float BLOCK_BLEND_MIN = 0.25;
const float BLOCK_BLEND_MAX = 0.95;
const float NOISE_BASE = 0.02;
const float TIME_SCALE = 1024.0;
const float SPEED_SCALE = 2048.0;
const float KEY_MAX_VALUE = 16777215.0;
const uint INTERNAL_ITERATIONS = 12u;

uniform sampler2D inputTex;
uniform vec4 size;
uniform vec4 timeSpeed;

out vec4 fragColor;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

float sanitized_time(float value) {
    return clamp(value, 0.0, 1.0e6);
}

float sanitized_speed(float value) {
    return clamp(value, 0.0, 1.0e4);
}

uint hash_u32(uint value) {
    uint hashed = value;
    hashed = hashed ^ 0x9e3779b9u;
    hashed = hashed * 0x85ebca6bu;
    hashed = hashed ^ (hashed >> 13u);
    hashed = hashed * 0xc2b2ae35u;
    hashed = hashed ^ (hashed >> 16u);
    return hashed;
}

uint build_time_key(float time_value, float speed_value) {
    uint time_component = uint(round(clamp(time_value * TIME_SCALE, 0.0, KEY_MAX_VALUE)));
    uint speed_component = uint(round(clamp(speed_value * SPEED_SCALE, 0.0, KEY_MAX_VALUE)));
    uint mixed = (time_component) ^ (speed_component * 0x27d4eb2du);
    return hash_u32(mixed);
}

float sequence_random(uint iteration, uint salt, uint time_key) {
    uint combined = (iteration * 0xcb1ab31fu) ^ (salt * 0x165667b1u) ^ time_key;
    return float(hash_u32(combined)) * INV_U32_MAX;
}

uint random_inclusive(uint iteration, uint salt, uint time_key, uint min_value, uint max_value) {
    if (max_value <= min_value) {
        return min_value;
    }
    uint range = max_value - min_value + 1u;
    float rand = sequence_random(iteration, salt, time_key);
    float scaled = rand * float(range);
    uint index = min(uint(scaled), range - 1u);
    return min_value + index;
}

float jitter_random(uvec2 coords, uint iteration, uint salt, uint time_key) {
    uint mix0 = coords.x * 0x8da6b343u;
    uint mix1 = coords.y * 0xd8163841u;
    uint mix2 = iteration * 0xcb1ab31fu;
    uint mix3 = salt * 0x165667b1u;
    return float(hash_u32(mix0 ^ mix1 ^ mix2 ^ mix3 ^ time_key)) * INV_U32_MAX;
}

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

vec3 rgb_to_ycbcr(vec3 rgb) {
    float y = dot(rgb, vec3(0.299, 0.587, 0.114));
    float cb = (rgb.z - y) * 0.564 + 0.5;
    float cr = (rgb.x - y) * 0.713 + 0.5;
    return vec3(clamp01(y), clamp01(cb), clamp01(cr));
}

vec3 ycbcr_to_rgb(vec3 ycbcr) {
    float y = ycbcr.x;
    float cb = ycbcr.y - 0.5;
    float cr = ycbcr.z - 0.5;
    float r = y + 1.403 * cr;
    float g = y - 0.344 * cb - 0.714 * cr;
    float b = y + 1.773 * cb;
    return clamp(vec3(r, g, b), vec3(0.0), vec3(1.0));
}

float quantize_channel(float value, float level_count) {
    float safe_levels = max(level_count, 1.0);
    if (safe_levels <= 1.0) {
        return clamp01(value);
    }
    float steps = safe_levels - 1.0;
    float scaled = clamp01(value) * steps;
    return floor(scaled + 0.5) / steps;
}

vec3 quantize_ycbcr(vec3 color, float quality_norm) {
    float luma_levels = mix(24.0, 256.0, quality_norm * quality_norm);
    float chroma_levels = mix(16.0, 196.0, quality_norm);
    vec3 result = color;
    result.x = quantize_channel(result.x, luma_levels);
    float chroma_mix = mix(0.65, 1.0, quality_norm);
    result.y = mix(0.5, quantize_channel(result.y, chroma_levels), chroma_mix);
    result.z = mix(0.5, quantize_channel(result.z, chroma_levels), chroma_mix);
    return result;
}

int compute_block_size(float quality_norm, float density, int dimension) {
    if (dimension <= 1) {
        return 1;
    }
    float safe_density = max(density, 1.0);
    float density_scale = clamp(
        float(DENSITY_MAX) / safe_density,
        DENSITY_SCALE_MIN,
        DENSITY_SCALE_MAX
    );
    float base_block = mix(BLOCK_SIZE_MIN, BLOCK_SIZE_MAX, 1.0 - quality_norm);
    float sized = clamp(base_block * density_scale, BLOCK_SIZE_MIN, float(dimension));
    int rounded = int(round(sized));
    if (rounded < 1) {
        return 1;
    }
    if (rounded > dimension) {
        return dimension;
    }
    return rounded;
}

int clamp_coord(int value, int limit) {
    if (limit <= 1) {
        return 0;
    }
    int clamped = value;
    if (clamped < 0) {
        clamped = 0;
    }
    if (clamped >= limit) {
        clamped = limit - 1;
    }
    return clamped;
}

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = max(as_u32(size.x), 1u);
    uint height = max(as_u32(size.y), 1u);
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    int width_i = int(width);
    int height_i = int(height);
    ivec2 coords_i = ivec2(int(global_id.x), int(global_id.y));
    uvec2 coords_u = global_id.xy;

    vec4 texel = texelFetch(inputTex, coords_i, 0);
    vec3 state_rgb = texel.xyz;
    float alpha = texel.w;

    float time_value = sanitized_time(timeSpeed.x);
    float speed_value = sanitized_speed(timeSpeed.y);
    uint time_key = build_time_key(time_value, speed_value);

    for (uint iteration = 0u; iteration < INTERNAL_ITERATIONS; iteration = iteration + 1u) {
        uint quality_value = random_inclusive(iteration, 0u, time_key, QUALITY_MIN, QUALITY_MAX);
        float quality = float(quality_value);
        float quality_norm = clamp(
            (quality - float(QUALITY_MIN)) / max(QUALITY_SPAN, 1.0),
            0.0,
            1.0
        );

        uint density_x_value = random_inclusive(iteration, 1u, time_key, DENSITY_MIN, DENSITY_MAX);
        uint density_y_value = random_inclusive(iteration, 2u, time_key, DENSITY_MIN, DENSITY_MAX);
        float density_x = float(density_x_value);
        float density_y = float(density_y_value);

        int block_width = compute_block_size(quality_norm, density_x, width_i);
        int block_height = compute_block_size(quality_norm, density_y, height_i);

        ivec2 block_coord = ivec2(
            coords_i.x / block_width,
            coords_i.y / block_height
        );
        ivec2 block_origin = ivec2(
            block_coord.x * block_width,
            block_coord.y * block_height
        );
        ivec2 block_center = ivec2(
            block_origin.x + block_width / 2,
            block_origin.y + block_height / 2
        );

        int jitter_x = int(round(
            (jitter_random(coords_u, iteration, 3u, time_key) - 0.5) * float(block_width)
        ));
        int jitter_y = int(round(
            (jitter_random(coords_u, iteration, 4u, time_key) - 0.5) * float(block_height)
        ));

        ivec2 sample_coords = ivec2(
            clamp_coord(block_center.x + jitter_x, width_i),
            clamp_coord(block_center.y + jitter_y, height_i)
        );
        vec3 sample_rgb = texelFetch(inputTex, sample_coords, 0).xyz;

        vec3 state_ycbcr = rgb_to_ycbcr(state_rgb);
        state_ycbcr = quantize_ycbcr(state_ycbcr, quality_norm);

        vec3 sample_ycbcr = rgb_to_ycbcr(sample_rgb);
        sample_ycbcr = quantize_ycbcr(sample_ycbcr, quality_norm);

        vec3 current_rgb = ycbcr_to_rgb(state_ycbcr);
        vec3 block_rgb = ycbcr_to_rgb(sample_ycbcr);

        float block_blend = mix(BLOCK_BLEND_MIN, BLOCK_BLEND_MAX, 1.0 - quality_norm);
        vec3 mixed_rgb = mix(current_rgb, block_rgb, vec3(block_blend));

        float noise_strength = (1.0 - quality_norm) * NOISE_BASE;
        vec3 noise_vec = vec3(
            (jitter_random(coords_u, iteration, 5u, time_key) - 0.5) * 2.0 * noise_strength,
            (jitter_random(coords_u, iteration, 6u, time_key) - 0.5) * 2.0 * noise_strength,
            (jitter_random(coords_u, iteration, 7u, time_key) - 0.5) * 2.0 * noise_strength
        );

        state_rgb = clamp(mixed_rgb + noise_vec, vec3(0.0), vec3(1.0));
    }

    fragColor = vec4(state_rgb, alpha);
}
