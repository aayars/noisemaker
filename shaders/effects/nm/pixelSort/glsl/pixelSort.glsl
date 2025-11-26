#version 300 es

precision highp float;
precision highp int;

// Pixel Sort effect shader. Mirrors noisemaker.effects.pixel_sort and the
// JavaScript reference implementation. Three-stage pipeline:
//   1. prepare   - pad and rotate into a square buffer.
//   2. sort_rows - per-row counting sort with brightest alignment.
//   3. finalize  - rotate back, crop, and blend with the source image.

const float PI = 3.141592653589793;
const uint CHANNEL_COUNT = 4u;
const uint NUM_BUCKETS = 256u;
const uint MAX_ROW_PIXELS = 4096u;


uniform sampler2D inputTex;
uniform float width;
uniform float height;
uniform float channelCount;
uniform float angled;
uniform float darkest;
uniform float time;
uniform float speed;
uniform float wantSize;

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

float srgb_to_linear(float value) {
    if (value <= 0.04045) {
        return value / 12.92;
    }
    return pow((value + 0.055) / 1.055, 2.4);
}

float oklab_l_component(vec3 rgb) {
    float r = srgb_to_linear(clamp01(rgb.x));
    float g = srgb_to_linear(clamp01(rgb.y));
    float b = srgb_to_linear(clamp01(rgb.z));

    float l = 0.4121656120 * r + 0.5362752080 * g + 0.0514575653 * b;
    float m = 0.2118591070 * r + 0.6807189584 * g + 0.1074065790 * b;
    float s = 0.0883097947 * r + 0.2818474174 * g + 0.6302613616 * b;

    float l_c = pow(abs(l), 1.0 / 3.0) * sign(l);
    float m_c = pow(abs(m), 1.0 / 3.0) * sign(m);
    float s_c = pow(abs(s), 1.0 / 3.0) * sign(s);

    return clamp01(0.2104542553 * l_c + 0.7936177850 * m_c - 0.0040720468 * s_c);
}

float compute_brightness(vec4 color) {
    return oklab_l_component(vec3(color.x, color.y, color.z));
}

uint clamp_bucket(float value) {
    float scaled = clamp(value, 0.0, 0.999999) * float(NUM_BUCKETS - 1u);
    return uint(scaled + 0.5);
}

float resolve_angle() {
    float angle = angled;
    if (angle != 0.0 && abs(angle) <= 1.0) {
        angle = time * speed * 360.0;
    }
    return angle * PI / 180.0;
}

uint resolve_want_size() {
    float safe_want = clamp(round(max(want_size, 0.0)), 0.0, float(MAX_ROW_PIXELS));
    return uint(safe_want);
}

void write_output_pixel(uint index, vec4 color) {
}

// -----------------------------------------------------------------------------
// Pass 1: pad and rotate into prepared_buffer
// -----------------------------------------------------------------------------

void prepare(uvec3 @builtin(global_invocation_id) global_id) {
    uint want = resolve_want_size();
    if (want == 0u || global_id.x >= want || global_id.y >= want) {
        return;
    }

    uint width = max(uint(width), 1u);
    uint height = max(uint(height), 1u);

    int pad_x = (int(want) - int(width)) / 2;
    int pad_y = (int(want) - int(height)) / 2;
    float angle_rad = resolve_angle();
    float cos_a = cos(angle_rad);
    float sin_a = sin(angle_rad);

    float center = (float(want) - 1.0) * 0.5;
    float px = float(global_id.x);
    float py = float(global_id.y);

    float dx = px - center;
    float dy = py - center;

    float src_x_f = cos_a * dx + sin_a * dy + center;
    float src_y_f = -sin_a * dx + cos_a * dy + center;

    int src_x = int(round(src_x_f));
    int src_y = int(round(src_y_f));

    int orig_x = src_x - pad_x;
    int orig_y = src_y - pad_y;

    vec4 color = vec4(0.0, 0.0, 0.0, 1.0);
    if (orig_x >= 0 && orig_x < int(width) && orig_y >= 0 && orig_y < int(height)) {
        color = textureLoad(inputTex, vec2(orig_x, orig_y), 0);
    }

    if (darkest != 0.0) {
        color = vec4(1.0) - color;
    }

    uint base = (global_id.y * want + global_id.x) * CHANNEL_COUNT;
    prepared_buffer[base + 0u] = color.x;
    prepared_buffer[base + 1u] = color.y;
    prepared_buffer[base + 2u] = color.z;
    prepared_buffer[base + 3u] = color.w;

    sorted_buffer[base + 0u] = color.x;
    sorted_buffer[base + 1u] = color.y;
    sorted_buffer[base + 2u] = color.z;
    sorted_buffer[base + 3u] = color.w;
}

// -----------------------------------------------------------------------------
// Pass 2: per-row counting sort with brightest alignment
// -----------------------------------------------------------------------------

void sort_rows(uvec3 @builtin(global_invocation_id) global_id) {
    uint want = resolve_want_size();
    if (want == 0u || global_id.y >= want) {
        return;
    }

    uint channel_limit = min(CHANNEL_COUNT, max(uint(channelCount), 1u));
    uint row_index = global_id.y;
    uint row_start = row_index * want * CHANNEL_COUNT;

    float max_brightness = -1.0;
    uint brightest_index = 0u;
    for (uint x = 0u; x < want; x = x + 1u) {
        uint base = row_start + x * CHANNEL_COUNT;
        vec4 color = vec4(
            prepared_buffer[base + 0u],
            prepared_buffer[base + 1u],
            prepared_buffer[base + 2u],
            prepared_buffer[base + 3u]
        );
        float brightness = compute_brightness(color);
        if (brightness > max_brightness) {
            max_brightness = brightness;
            brightest_index = x;
        }
    }

    histogram : array<u32, NUM_BUCKETS>;
    positions : array<u32, NUM_BUCKETS>;

    uint shift = want - brightest_index;
    if (shift == want) {
        shift = 0u;
    }

    for (uint channel = 0u; channel < channel_limit; channel = channel + 1u) {
        for (uint i = 0u; i < NUM_BUCKETS; i = i + 1u) {
            histogram[i] = 0u;
        }

        for (uint x = 0u; x < want; x = x + 1u) {
            uint idx = row_start + x * CHANNEL_COUNT + channel;
            float value = prepared_buffer[idx];
            uint bucket = clamp_bucket(value);
            histogram[bucket] = histogram[bucket] + 1u;
        }

        uint cumulative = 0u;
        for (uint i = 0u; i < NUM_BUCKETS; i = i + 1u) {
            uint count = histogram[i];
            positions[i] = cumulative;
            cumulative = cumulative + count;
        }

        for (uint x = 0u; x < want; x = x + 1u) {
            uint idx = row_start + x * CHANNEL_COUNT + channel;
            float value = prepared_buffer[idx];
            uint bucket = clamp_bucket(value);
            uint offset = positions[bucket];
            positions[bucket] = offset + 1u;

            uint rotated_index = offset + shift;
            if (rotated_index >= want) {
                rotated_index = rotated_index - want;
            }

            uint dest_idx = row_start + rotated_index * CHANNEL_COUNT + channel;
            sorted_buffer[dest_idx] = value;
        }
    }

    if (channel_limit < CHANNEL_COUNT) {
        uint alpha_channel = CHANNEL_COUNT - 1u;
        for (uint x = 0u; x < want; x = x + 1u) {
            uint idx = row_start + x * CHANNEL_COUNT + alpha_channel;
            float value = prepared_buffer[idx];
            uint rotated_index = x + shift;
            if (rotated_index >= want) {
                rotated_index = rotated_index - want;
            }
            uint dest_idx = row_start + rotated_index * CHANNEL_COUNT + alpha_channel;
            sorted_buffer[dest_idx] = value;
        }
    }
}

// -----------------------------------------------------------------------------
// Pass 3: rotate back, crop, and blend with the source
// -----------------------------------------------------------------------------

void finalize(uvec3 @builtin(global_invocation_id) global_id) {
    uint width = max(uint(width), 1u);
    uint height = max(uint(height), 1u);

    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    uint want = resolve_want_size();

    vec4 original_color = textureLoad(
        inputTex,
        vec2(int(global_id.x), int(global_id.y)),
        0
    );

    if (want == 0u || want > MAX_ROW_PIXELS) {
        write_output_pixel(base_index, original_color);
        return;
    }

    int pad_x = (int(want) - int(width)) / 2;
    int pad_y = (int(want) - int(height)) / 2;
    float angle_rad = resolve_angle();
    float cos_a = cos(angle_rad);
    float sin_a = sin(angle_rad);
    float center = (float(want) - 1.0) * 0.5;

    float padded_x = float(int(global_id.x) + pad_x);
    float padded_y = float(int(global_id.y) + pad_y);

    float dx = padded_x - center;
    float dy = padded_y - center;

    float rot_x_f = cos_a * dx - sin_a * dy + center;
    float rot_y_f = sin_a * dx + cos_a * dy + center;

    int rot_x = int(round(rot_x_f));
    int rot_y = int(round(rot_y_f));

    vec4 sorted_color = original_color;
    if (rot_x >= 0 && rot_x < int(want) && rot_y >= 0 && rot_y < int(want)) {
        uint sorted_base = (uint(rot_y) * want + uint(rot_x)) * CHANNEL_COUNT;
        sorted_color = vec4(
            sorted_buffer[sorted_base + 0u],
            sorted_buffer[sorted_base + 1u],
            sorted_buffer[sorted_base + 2u],
            sorted_buffer[sorted_base + 3u]
        );
    }

    vec4 working_source = original_color;
    vec4 working_sorted = sorted_color;

    if (darkest != 0.0) {
        working_source = vec4(1.0) - working_source;
        working_sorted = vec4(1.0) - working_sorted;
    }

    vec4 blended = max(working_source, working_sorted);
    blended = clamp(blended, vec4(0.0), vec4(1.0));
    blended.w = working_source.w;

    if (darkest != 0.0) {
        blended = vec4(1.0) - blended;
        blended.w = original_color.w;
    } else {
        blended.w = original_color.w;
    }

    write_output_pixel(base_index, blended);
}
