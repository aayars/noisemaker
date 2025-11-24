#version 300 es

precision highp float;
precision highp int;

// Erosion Worms fallback single-pass implementation.
// Provides a degraded simulation path when multi-pass pipelines are unavailable.

const float TAU = 6.283185307179586;


uniform sampler2D input_texture;
uniform vec4 size;
uniform vec4 controls0;
uniform vec4 controls1;
uniform vec4 controls2;
uniform sampler2D prev_texture;

uint sanitized_channel_count(float value) {
    int rounded = int(round(value));
    if (rounded <= 1) { return 1u; }
    if (rounded >= 4) { return 4u; }
    return uint(rounded);
}

int wrap_int(int value, int size) {
    if (size <= 0) { return 0; }
    int result = value % size;
    if (result < 0) { result = result + size; }
    return result;
}

float wrap_float(float value, float range) {
    if (range <= 0.0) { return 0.0; }
    float scaled = floor(value / range);
    float wrapped = value - scaled * range;
    if (wrapped < 0.0) { wrapped = wrapped + range; }
    return wrapped;
}

float srgb_to_linear(float value) {
    if (value <= 0.04045) { return value / 12.92; }
    return pow((value + 0.055) / 1.055, 2.4);
}

float cube_root(float value) {
    if (value == 0.0) { return 0.0; }
    float sign_value = select(-1.0, 1.0, value >= 0.0);
    return sign_value * pow(abs(value), 1.0 / 3.0);
}

float oklab_l(vec3 rgb) {
    float r_lin = srgb_to_linear(clamp(rgb.x, 0.0, 1.0));
    float g_lin = srgb_to_linear(clamp(rgb.y, 0.0, 1.0));
    float b_lin = srgb_to_linear(clamp(rgb.z, 0.0, 1.0));
    float l = 0.4121656120 * r_lin + 0.5362752080 * g_lin + 0.0514575653 * b_lin;
    float m = 0.2118591070 * r_lin + 0.6807189584 * g_lin + 0.1074065790 * b_lin;
    float s = 0.0883097947 * r_lin + 0.2818474174 * g_lin + 0.6302613616 * b_lin;
    float l_c = cube_root(l);
    float m_c = cube_root(m);
    float s_c = cube_root(s);
    return 0.2104542553 * l_c + 0.7936177850 * m_c - 0.0040720468 * s_c;
}

float hash(uint seed) {
    uint x = seed;
    x = x ^ (x >> 16u);
    x = x * 0x7feb352du;
    x = x ^ (x >> 15u);
    x = x * 0x846ca68bu;
    x = x ^ (x >> 16u);
    return float(x) / float(0xffffffffu);
}

vec2 hash2(uint seed) {
    return vec2(hash(seed), hash(seed + 1u));
}

vec4 fetch_texel(int x, int y, uint width, uint height) {
    int wrapped_x = wrap_int(x, int(width));
    int wrapped_y = wrap_int(y, int(height));
    return textureLoad(input_texture, vec2(wrapped_x, wrapped_y), 0);
}

float luminance_at(int x, int y, uint width, uint height, uint channel_count) {
    vec4 texel = fetch_texel(x, y, width, height);
    if (channel_count <= 1u) { return texel.x; }
    if (channel_count == 2u) { return texel.x; }
    vec3 rgb = vec3(texel.x, texel.y, texel.z);
    return oklab_l(rgb);
}

float blurred_luminance_at(int x, int y, uint width, uint height, uint channel_count) {
    float total = 0.0;
    float weight_sum = 0.0;
    kernel : array<array<f32, 5u>, 5u> = array<array<f32, 5u>, 5u>(
        array<f32, 5u>(1.0, 4.0, 6.0, 4.0, 1.0),
        array<f32, 5u>(4.0, 16.0, 24.0, 16.0, 4.0),
        array<f32, 5u>(6.0, 24.0, 36.0, 24.0, 6.0),
        array<f32, 5u>(4.0, 16.0, 24.0, 16.0, 4.0),
        array<f32, 5u>(1.0, 4.0, 6.0, 4.0, 1.0),
    );
    for (int offset_y = -2; offset_y <= 2; offset_y = offset_y + 1) {
        for (int offset_x = -2; offset_x <= 2; offset_x = offset_x + 1) {
            float sample = luminance_at(x + offset_x, y + offset_y, width, height, channel_count);
            float weight = kernel[uint(offset_y + 2)][uint(offset_x + 2)];
            total = total + sample * weight;
            weight_sum = weight_sum + weight;
        }
    }
    return total / max(weight_sum, 1e-6);
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uvec2 dims = uvec2(textureSize(input_texture, 0));
    uint width = dims.x;
    uint height = dims.y;
    if (width == 0u || height == 0u) {
        return;
    }

    float fade = clamp(controls1.x, 0.0, 1.0);

    if (global_id.x < width && global_id.y < height) {
        vec4 prev_sample = textureLoad(prev_texture, vec2(int(global_id.x), int(global_id.y)), 0);
        vec4 faded = prev_sample * fade;
        uint pixel_idx = global_id.y * width + global_id.x;
        uint base_index = pixel_idx * 4u;
        fragColor = vec4(faded.x, faded.y, faded.z, faded.w);
    }

    if (global_id.x == 0u && global_id.y == 0u && global_id.z == 0u) {
        uint channel_count = sanitized_channel_count(size.z);
        uint floats_len = arrayLength(&agent_state_in);
        if (floats_len >= 9u) {
            uint agent_count = floats_len / 9u;
            float stride = max(controls0.y, 0.1);
            bool quantize_flag = controls0.z > 0.5;
            float trail_intensity = clamp(controls1.x, 0.0, 1.0);
            bool inverse_flag = controls1.y > 0.5;
            float time_value = controls1.w;
            float worm_lifetime = max(controls2.x, 0.0);

            for (uint agent_id = 0u; agent_id < agent_count; agent_id = agent_id + 1u) {
                uint base_state = agent_id * 9u;
                float x = agent_state_in[base_state + 0u];
                float y = agent_state_in[base_state + 1u];
                float x_dir = agent_state_in[base_state + 2u];
                float y_dir = agent_state_in[base_state + 3u];
                float cr = agent_state_in[base_state + 4u];
                float cg = agent_state_in[base_state + 5u];
                float cb = agent_state_in[base_state + 6u];
                float inertia = clamp(agent_state_in[base_state + 7u], 0.0, 1.0);
                float age = agent_state_in[base_state + 8u];

                float normalized_lifetime = worm_lifetime / 60.0;
                float normalized_index = select(0.0, float(agent_id) / max(float(agent_count), 1.0), agent_count > 0u);
                float agent_phase = fract(normalized_index);
                bool needs_initial_color = age < 0.0;

                float time_in_cycle = fract(time_value + agent_phase);
                float prev_time_in_cycle = fract(time_value - (1.0 / 60.0) + agent_phase);
                respawn_check : bool = worm_lifetime > 0.0
                    && normalized_lifetime > 0.0
                    && time_in_cycle < normalized_lifetime
                    && prev_time_in_cycle >= normalized_lifetime;

                if (needs_initial_color || respawn_check) {
                    uint seed = agent_id + uint(time_value * 1000.0);
                    if (respawn_check) {
                        vec2 pos = hash2(seed);
                        x = pos.x * float(width);
                        y = pos.y * float(height);
                        uint dir_seed = seed + 12345u;
                        vec2 dir_raw = hash2(dir_seed) * 2.0 - 1.0;
                        float dir_len = length(dir_raw);
                        if (dir_len > 1e-5) {
                            x_dir = dir_raw.x / dir_len;
                            y_dir = dir_raw.y / dir_len;
                        } else {
                            x_dir = 1.0;
                            y_dir = 0.0;
                        }
                    }

                    int xi_seed = wrap_int(int(floor(x)), int(width));
                    int yi_seed = wrap_int(int(floor(y)), int(height));
                    vec4 sample_color = textureLoad(input_texture, vec2(xi_seed, yi_seed), 0);
                    cr = sample_color.x;
                    cg = sample_color.y;
                    cb = sample_color.z;
                    age = 0.0;
                }

                int xi = wrap_int(int(floor(x)), int(width));
                int yi = wrap_int(int(floor(y)), int(height));
                int x1i = wrap_int(xi + 1, int(width));
                int y1i = wrap_int(yi + 1, int(height));

                float u = x - floor(x);
                float v = y - floor(y);

                float c00 = blurred_luminance_at(xi, yi, width, height, channel_count);
                float c10 = blurred_luminance_at(x1i, yi, width, height, channel_count);
                float c01 = blurred_luminance_at(xi, y1i, width, height, channel_count);
                float c11 = blurred_luminance_at(x1i, y1i, width, height, channel_count);

                float gx = mix(c01 - c00, c11 - c10, u);
                float gy = mix(c10 - c00, c11 - c01, v);

                if (quantize_flag) {
                    gx = floor(gx);
                    gy = floor(gy);
                }

                float glen = length(vec2(gx, gy));
                if (glen > 1e-6) {
                    float scale = stride / glen;
                    gx = gx * scale;
                    gy = gy * scale;
                } else {
                    gx = 0.0;
                    gy = 0.0;
                }

                x_dir = mix(x_dir, gx, inertia);
                y_dir = mix(y_dir, gy, inertia);

                x = wrap_float(x + x_dir, float(width));
                y = wrap_float(y + y_dir, float(height));

                int xi2 = wrap_int(int(floor(x)), int(width));
                int yi2 = wrap_int(int(floor(y)), int(height));
                uint pixel_idx = uint(yi2) * width + uint(xi2);
                uint base_index = pixel_idx * 4u;

                vec3 tint = vec3(cr, cg, cb);
                vec3 deposit_rgb = tint;
                if (inverse_flag) {
                    deposit_rgb = vec3(1.0) - deposit_rgb;
                }


                age = age + 1.0;
                agent_state_out[base_state + 0u] = x;
                agent_state_out[base_state + 1u] = y;
                agent_state_out[base_state + 2u] = x_dir;
                agent_state_out[base_state + 3u] = y_dir;
                agent_state_out[base_state + 4u] = cr;
                agent_state_out[base_state + 5u] = cg;
                agent_state_out[base_state + 6u] = cb;
                agent_state_out[base_state + 7u] = inertia;
                agent_state_out[base_state + 8u] = age;
            }
        }
    }

    if (global_id.x < width && global_id.y < height) {
        uint pixel_idx = global_id.y * width + global_id.x;
        uint base_index = pixel_idx * 4u;
        vec4 trail_color = vec4(
        );

        vec4 input_sample = textureLoad(input_texture, vec2(int(global_id.x), int(global_id.y)), 0);
        float base_intensity = clamp(controls2.y, 0.0, 1.0);
        vec3 base_rgb = input_sample.xyz * base_intensity;

        vec3 combined_rgb = clamp(base_rgb + trail_color.xyz, vec3(0.0), vec3(1.0));
        float combined_alpha = clamp(max(input_sample.w, trail_color.w), 0.0, 1.0);

        fragColor = vec4(combined_rgb.x, combined_rgb.y, combined_rgb.z, combined_alpha);
    }
}