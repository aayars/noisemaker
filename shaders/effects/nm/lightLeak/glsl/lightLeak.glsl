#version 300 es
precision highp float;
precision highp int;

const float TAU = 6.28318530717958647692;

uniform sampler2D inputTex;
uniform vec4 size;
uniform vec4 alphaTimeSpeed;

layout(location = 0) out vec4 fragColor;

const uint POINT_COUNT = 6u;
const uint LAYOUT_COUNT = 4u;
const uint LEAK_BLOOM_COUNT = 4u;
const uint BLOOM_SAMPLE_COUNT = 8u;
const float BLOOM_CENTER_WEIGHT = 4.0;

struct PointData {
    vec2 positions[POINT_COUNT];
    vec3 colors[POINT_COUNT];
};

const uvec2 LAYOUTS[LAYOUT_COUNT] = uvec2[](
    uvec2(3u, 2u),
    uvec2(2u, 3u),
    uvec2(1u, 6u),
    uvec2(6u, 1u)
);

const ivec2 LEAK_BLOOM_OFFSETS[LEAK_BLOOM_COUNT] = ivec2[](
    ivec2(1, 0),
    ivec2(-1, 0),
    ivec2(0, 1),
    ivec2(0, -1)
);

const ivec2 BLOOM_KERNEL_OFFSETS[BLOOM_SAMPLE_COUNT] = ivec2[](
    ivec2(1, 0),
    ivec2(-1, 0),
    ivec2(0, 1),
    ivec2(0, -1),
    ivec2(1, 1),
    ivec2(-1, 1),
    ivec2(1, -1),
    ivec2(-1, -1)
);

const float BLOOM_KERNEL_WEIGHTS[BLOOM_SAMPLE_COUNT] = float[](
    2.0,
    2.0,
    2.0,
    2.0,
    1.0,
    1.0,
    1.0,
    1.0
);

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

vec3 clamp_vec3(vec3 value) {
    return clamp(value, vec3(0.0), vec3(1.0));
}

int wrap_coord(int value, int limit) {
    if (limit <= 0) {
        return 0;
    }
    int wrapped = value % limit;
    if (wrapped < 0) {
        wrapped = wrapped + limit;
    }
    return wrapped;
}

float hash31(vec3 p) {
    float h = dot(p, vec3(127.1, 311.7, 74.7));
    return fract(sin(h) * 43758.5453123);
}

vec2 random_vec2(vec3 seed) {
    float h1 = hash31(seed);
    float h2 = hash31(seed + vec3(17.13, 29.97, 42.75));
    return vec2(h1, h2);
}

uvec2 select_layout(float time_value, float speed_value) {
    float phase = floor((time_value * speed_value) * 0.25 + 0.5);
    float index_value = hash31(vec3(phase, time_value * 0.5, speed_value + 11.0));
    uint layout_index = min(uint(floor(index_value * float(LAYOUT_COUNT))), LAYOUT_COUNT - 1u);
    return LAYOUTS[layout_index];
}

vec3 sample_base_color(vec2 uv, int width, int height) {
    int px = wrap_coord(int(floor(uv.x * float(width))), width);
    int py = wrap_coord(int(floor(uv.y * float(height))), height);
    return texelFetch(inputTex, ivec2(px, py), 0).xyz;
}

float luminance(vec3 color) {
    return dot(color, vec3(0.299, 0.587, 0.114));
}

float chebyshev_mask(vec2 uv, vec2 dimensions) {
    if (dimensions.x <= 0.0 || dimensions.y <= 0.0) {
        return 0.0;
    }

    vec2 centered = abs(uv - vec2(0.5, 0.5));
    float px = centered.x * dimensions.x;
    float py = centered.y * dimensions.y;
    float dist = max(px, py);
    float max_dimension = max(dimensions.x, dimensions.y) * 0.5;
    if (max_dimension <= 0.0) {
        return 0.0;
    }

    return clamp(dist / max_dimension, 0.0, 1.0);
}

void generate_point_data(
    inout PointData data,
    uvec2 grid_layout,
    float width,
    float height,
    float time_value,
    float speed_value
) {
    float layout_x = max(float(grid_layout.x), 1.0);
    float layout_y = max(float(grid_layout.y), 1.0);
    vec2 cell_size = vec2(1.0 / layout_x, 1.0 / layout_y);
    float drift_strength = 0.05;
    int width_i = max(int(width), 1);
    int height_i = max(int(height), 1);

    for (uint index = 0u; index < POINT_COUNT; index++) {
        float cell_x = float(index % grid_layout.x);
        float cell_y = float(index / grid_layout.x);
        vec2 base_center = (vec2(cell_x, cell_y) + vec2(0.5, 0.5)) * cell_size;

        float drift_phase = time_value * speed_value;
        vec2 oscillation = vec2(
            sin(drift_phase * 0.7 + float(index) * 1.618),
            cos(drift_phase * 0.5 + float(index) * 2.236)
        ) * drift_strength;

        vec2 jitter = (random_vec2(vec3(float(index), drift_phase, speed_value)) - vec2(0.5, 0.5))
            * (drift_strength * 0.5);

        vec2 position = fract(base_center + oscillation + jitter);
        data.positions[index] = position;
        data.colors[index] = sample_base_color(position, width_i, height_i);
    }
}

vec3 nearest_color(vec2 uv, PointData data) {
    uint best_index = 0u;
    float best_distance = 1e9;

    for (uint i = 0u; i < POINT_COUNT; i++) {
        vec2 point = data.positions[i];
        vec2 delta = abs(uv - point);
        vec2 wrap_delta = min(delta, vec2(1.0, 1.0) - delta);
        float dist = dot(wrap_delta, wrap_delta);
        if (dist < best_distance) {
            best_distance = dist;
            best_index = i;
        }
    }

    return data.colors[best_index];
}

vec3 leak_bloom_color(vec2 uv, PointData data, vec2 inv_size) {
    vec3 base_color = nearest_color(uv, data);
    vec3 accum = base_color * 4.0;
    float weight = 4.0;

    for (uint i = 0u; i < LEAK_BLOOM_COUNT; i++) {
        ivec2 offset = LEAK_BLOOM_OFFSETS[i];
        vec2 sample_uv = fract(uv + vec2(float(offset.x), float(offset.y)) * inv_size * 3.5);
        vec3 sample_color = nearest_color(sample_uv, data);
        accum = accum + sample_color * 2.0;
        weight = weight + 2.0;
    }

    return clamp_vec3(accum / weight);
}

vec3 compute_leak_stage(
    vec2 uv,
    PointData data,
    float width,
    float height,
    float time_value,
    float speed_value
) {
    int width_i = max(int(width), 1);
    int height_i = max(int(height), 1);

    vec3 base_sample = texelFetch(
        inputTex,
        ivec2(
            wrap_coord(int(floor(uv.x * width)), width_i),
            wrap_coord(int(floor(uv.y * height)), height_i)
        ),
        0
    ).xyz;

    vec3 base_leak = nearest_color(uv, data);
    float luma = luminance(base_leak);
    float swirl_phase = time_value * speed_value * 0.5;
    float angle = luma * TAU + swirl_phase;
    float stride = 0.25;
    vec2 warp_vector = vec2(cos(angle), sin(angle)) * stride;
    vec2 drift_offset = vec2(time_value * 0.05, time_value * 0.033) * speed_value;
    vec2 warped_uv = fract(uv + warp_vector + drift_offset);
    vec3 wormhole_sample = nearest_color(warped_uv, data);
    vec3 wormhole_color = mix(base_leak, clamp_vec3(sqrt(clamp_vec3(wormhole_sample))), 0.65);

    vec2 inv_size = vec2(
        1.0 / max(width, 1.0),
        1.0 / max(height, 1.0)
    );
    vec3 bloom_color = leak_bloom_color(warped_uv, data, inv_size);
    vec3 leak_color = clamp_vec3(mix(wormhole_color, bloom_color, 0.55));

    vec3 lighten_color = vec3(1.0) - (vec3(1.0) - base_sample) * (vec3(1.0) - leak_color);
    float mask = pow(chebyshev_mask(uv, vec2(width, height)), 4.0);
    vec3 center_blend = mix(base_sample, lighten_color, mask);
    return clamp_vec3(center_blend);
}

vec3 compute_vaseline_bloom(
    vec2 uv,
    PointData data,
    float width,
    float height,
    float time_value,
    float speed_value,
    float blend_alpha,
    vec3 center_base,
    vec3 center_leak
) {
    int width_i = max(int(width), 1);
    int height_i = max(int(height), 1);
    vec2 inv_size = vec2(
        1.0 / max(width, 1.0),
        1.0 / max(height, 1.0)
    );

    vec3 center_blended = mix(center_base, center_leak, blend_alpha);
    vec3 accum = center_blended * BLOOM_CENTER_WEIGHT;
    float weight_sum = BLOOM_CENTER_WEIGHT;

    for (uint i = 0u; i < BLOOM_SAMPLE_COUNT; i++) {
        ivec2 offset = BLOOM_KERNEL_OFFSETS[i];
        float weight = BLOOM_KERNEL_WEIGHTS[i];
        vec2 offset_uv = fract(uv + vec2(float(offset.x), float(offset.y)) * inv_size * 2.0);
        vec3 sample_base = sample_base_color(offset_uv, width_i, height_i);
        vec3 sample_leak = compute_leak_stage(offset_uv, data, width, height, time_value, speed_value);
        vec3 sample_blended = mix(sample_base, sample_leak, blend_alpha);
        accum = accum + sample_blended * weight;
        weight_sum = weight_sum + weight;
    }

    return clamp_vec3(accum / weight_sum);
}

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = as_u32(size.x);
    uint height = as_u32(size.y);
    ivec2 inputDims = textureSize(inputTex, 0);
    if (width == 0u) {
        width = uint(max(inputDims.x, 1));
    }
    if (height == 0u) {
        height = uint(max(inputDims.y, 1));
    }
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    float width_f = float(width);
    float height_f = float(height);
    int width_i = max(int(width_f), 1);
    int height_i = max(int(height_f), 1);

    float alpha = clamp01(alphaTimeSpeed.x);
    float time_value = alphaTimeSpeed.y;
    float speed_value = alphaTimeSpeed.z;

    uvec2 grid_layout = select_layout(time_value, speed_value);
    PointData point_data;
    generate_point_data(point_data, grid_layout, width_f, height_f, time_value, speed_value);

    vec2 coords = vec2(int(global_id.x), int(global_id.y));
    vec4 base_sample = texelFetch(inputTex, ivec2(coords), 0);

    vec2 uv = (vec2(float(global_id.x), float(global_id.y)) + vec2(0.5, 0.5)) / vec2(width_f, height_f);
    vec3 leak_stage = compute_leak_stage(uv, point_data, width_f, height_f, time_value, speed_value);
    vec3 blended = mix(base_sample.xyz, leak_stage, alpha);

    vec3 vaseline_bloom = compute_vaseline_bloom(
        uv,
        point_data,
        width_f,
        height_f,
        time_value,
        speed_value,
        alpha,
        base_sample.xyz,
        leak_stage
    );

    float mask = pow(chebyshev_mask(uv, vec2(width_f, height_f)), 2.0);
    vec3 vaseline_color = mix(blended, vaseline_bloom, mask);
    vec3 final_color = clamp_vec3(mix(blended, vaseline_color, alpha));

    fragColor = vec4(final_color, base_sample.w);
}
