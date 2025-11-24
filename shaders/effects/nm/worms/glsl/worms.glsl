#version 300 es

precision highp float;
precision highp int;

// Worms effect compute shader.
//
// Faithfully reproduces the TensorFlow implementation found in
// noisemaker/effects.py::worms. Each dispatch simulates a collection of worms
// that follow a flow field derived from the input texture and blends the
// results back onto the original image.

const float PI = 3.14159265358979323846;
const float TAU = 6.28318530717958647692;
const float MAX_FLOAT = 3.402823466e38;
const float MIN_FLOAT = -MAX_FLOAT;

// Limit worms to control additional arrays' size; avoid large per-image arrays to keep stack usage low.
const uint MAX_WORMS = 128u;

const uint BEHAVIOR_OBEDIENT = 1u;
const uint BEHAVIOR_CROSSHATCH = 2u;
const uint BEHAVIOR_UNRULY = 3u;
const uint BEHAVIOR_CHAOTIC = 4u;
const uint BEHAVIOR_RANDOM = 5u;
const uint BEHAVIOR_MEANDERING = 10u;


uniform sampler2D input_texture;
uniform vec4 size;
uniform vec4 behavior_density_stride_padding;
uniform vec3 stride_deviation_alpha_kink;
uniform vec4 quantize_time_padding_intensity;
uniform vec4 inputIntensity_lifetime_padding;
// Optional previous framebuffer for accumulation
uniform sampler2D prev_texture;
// Persistent per-agent state, provided by the viewer when declared

float clamp_01(float value) {
    return clamp(value, 0.0, 1.0);
}

uint sanitized_channel_count(float value) {
    int rounded = int(round(value));
    if (rounded <= 1) {
        return 1u;
    }
    if (rounded >= 4) {
        return 4u;
    }
    return uint(rounded);
}

int wrap_int(int value, int size) {
    if (size <= 0) {
        return 0;
    }
    int wrapped = value % size;
    if (wrapped < 0) {
        wrapped = wrapped + size;
    }
    return wrapped;
}

float wrap_float(float value, float size) {
    if (size <= 0.0) {
        return 0.0;
    }
    float scaled = floor(value / size);
    float wrapped = value - scaled * size;
    if (wrapped < 0.0) {
        wrapped = wrapped + size;
    }
    return wrapped;
}

float srgb_to_linear(float value) {
    if (value <= 0.04045) {
        return value / 12.92;
    }
    return pow((value + 0.055) / 1.055, 2.4);
}

float cube_root(float value) {
    if (value == 0.0) {
        return 0.0;
    }
    float sign_value = select(-1.0, 1.0, value >= 0.0);
    return sign_value * pow(abs(value), 1.0 / 3.0);
}

float oklab_l(vec3 rgb) {
    float r_lin = srgb_to_linear(clamp_01(rgb.x));
    float g_lin = srgb_to_linear(clamp_01(rgb.y));
    float b_lin = srgb_to_linear(clamp_01(rgb.z));

    float l = 0.4121656120 * r_lin + 0.5362752080 * g_lin + 0.0514575653 * b_lin;
    float m = 0.2118591070 * r_lin + 0.6807189584 * g_lin + 0.1074065790 * b_lin;
    float s = 0.0883097947 * r_lin + 0.2818474174 * g_lin + 0.6302613616 * b_lin;

    float l_c = cube_root(l);
    float m_c = cube_root(m);
    float s_c = cube_root(s);

    return 0.2104542553 * l_c + 0.7936177850 * m_c - 0.0040720468 * s_c;
}

float value_map_component(vec4 texel, uint channel_count) {
    if (channel_count <= 1u) {
        return texel.x;
    }
    if (channel_count == 2u) {
        return texel.x;
    }
    vec3 rgb = vec3(texel.x, texel.y, texel.z);
    return oklab_l(rgb);
}

float normalized_sine(float value) {
    return (sin(value) + 1.0) * 0.5;
}

float periodic_value(float time_value, float raw_value) {
    return normalized_sine((time_value - raw_value) * TAU);
}

float rng_next() {
    uint current = *state;
    current = (current + 0x6D2B79F5u) & 0xFFFFFFFFu;
    current = ((current ^ (current >> 15u)) * (current | 1u)) & 0xFFFFFFFFu;
    current = (current ^ (current + ((current ^ (current >> 7u)) * (current | 61u)))) & 0xFFFFFFFFu;
    *state = current;
    uint result = (current ^ (current >> 14u)) & 0xFFFFFFFFu;
    return float(result) / 4294967296.0;
}

float rng_uniform(float min_value, float max_value) {
    float span = max_value - min_value;
    return min_value + span * rng_next(state);
}

float rng_normal(float mean, float stddev) {
    float u1 = rng_next(state);
    loop {
        if (u1 > 0.0) {
            break;
        }
        u1 = rng_next(state);
    }
    float u2 = rng_next(state);
    float magnitude = sqrt(-2.0 * log(u1));
    float angle = TAU * u2;
    float z0 = magnitude * cos(angle);
    return mean + stddev * z0;
}

vec4 fetch_texel(int x, int y, int width, int height) {
    int wrapped_x = wrap_int(x, width);
    int wrapped_y = wrap_int(y, height);
    return textureLoad(input_texture, vec2(wrapped_x, wrapped_y), 0);
}

uint behavior_to_enum(float raw) {
    int rounded = int(round(raw));
    if (rounded == 2) {
        return BEHAVIOR_CROSSHATCH;
    }
    if (rounded == 3) {
        return BEHAVIOR_UNRULY;
    }
    if (rounded == 4) {
        return BEHAVIOR_CHAOTIC;
    }
    if (rounded == 5) {
        return BEHAVIOR_RANDOM;
    }
    if (rounded == 10) {
        return BEHAVIOR_MEANDERING;
    }
    return BEHAVIOR_OBEDIENT;
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    // Single-dispatch, serial pass over the frame. We use prev_texture for accumulation,
    // and agent_state_in/out to persist walker state across frames.
    if (global_id.x != 0u || global_id.y != 0u || global_id.z != 0u) { return; }

    uvec2 dims = uvec2(textureSize(input_texture, 0));
    uint width = dims.x;
    uint height = dims.y;
    if (width == 0u || height == 0u) { return; }

    uint channel_count = sanitized_channel_count(size.z);
    uint pixel_count = width * height;
    if (pixel_count == 0u) { return; }

    float behavior_raw = behavior_density_stride_padding.x;
    float density = behavior_density_stride_padding.y;
    float kink = stride_deviation_alpha_kink.z;
    bool quantize_flag = quantize_time_padding_intensity.x > 0.5;
    float intensity_fade = clamp_01(quantize_time_padding_intensity.w);
    float input_intensity = clamp_01(inputIntensity_lifetime_padding.x);
    uint behavior = behavior_to_enum(behavior_raw);

    float max_dim = max(float(width), float(height));
    uint worm_count = 0u;
    if (density > 0.0 && max_dim > 0.0) {
        float desired = floor(max_dim * density);
        if (desired > 0.0) { worm_count = min(uint(desired), MAX_WORMS); }
    }

    uint total_channels = 4u * pixel_count;
    vec4 fade_vec = vec4(intensity_fade, intensity_fade, intensity_fade, intensity_fade);
    vec3 input_vec = vec3(input_intensity, input_intensity, input_intensity);
    // Seed output from prev frame texture for temporal accumulation
    uint idx = 0u;
    for (uint y0 = 0u; y0 < height; y0 = y0 + 1u) {
        for (uint x0 = 0u; x0 < width; x0 = x0 + 1u) {
            uint base_idx = idx * 4u;
            vec4 prev_col = textureLoad(prev_texture, vec2(int(x0), int(y0)), 0);
            vec4 faded = prev_col * fade_vec;
            if (base_idx + 3u < total_channels) {
            }
            idx = idx + 1u;
        }
    }

    int width_i = int(width);
    int height_i = int(height);

    // Scan min/max for normalization
    float min_value = MAX_FLOAT;
    float max_value = MIN_FLOAT;
    for (uint y = 0u; y < height; y = y + 1u) {
        for (uint x = 0u; x < width; x = x + 1u) {
            vec4 texel = textureLoad(input_texture, vec2(int(x), int(y)), 0);
            float v = value_map_component(texel, channel_count);
            min_value = min(min_value, v);
            max_value = max(max_value, v);
        }
    }
    if (!(max_value > min_value)) { min_value = 0.0; max_value = 1.0; }
    float inv_delta = 1.0 / max(max_value - min_value, 1e-6);

    if (worm_count == 0u) {
        // Nothing to draw; softly mix input to output
        uint p = 0u;
        for (uint yy = 0u; yy < height; yy = yy + 1u) {
            for (uint xx = 0u; xx < width; xx = xx + 1u) {
                vec4 texel = textureLoad(input_texture, vec2(int(xx), int(yy)), 0);
                uint base = p * 4u;
                vec4 base_color = vec4(texel.xyz * input_vec, texel.w);
                if (base + 3u < total_channels) {
                    float final_alpha = clamp(max(existing_alpha, base_color.w), 0.0, 1.0);
                }
                p = p + 1u;
            }
        }
        return;
    }

    // Agent-based single step
    float exposure = 1.0;
    for (uint i = 0u; i < worm_count; i = i + 1u) {
        uint base_state = i * 8u;
        float wx = agent_state_in[base_state + 0u];
        float wy = agent_state_in[base_state + 1u];
        float wrot = agent_state_in[base_state + 2u];
        float wstride = agent_state_in[base_state + 3u];
        float cr = agent_state_in[base_state + 4u];
        float cg = agent_state_in[base_state + 5u];
        float cb = agent_state_in[base_state + 6u];

        int xi = wrap_int(int(floor(wx)), width_i);
        int yi = wrap_int(int(floor(wy)), height_i);
        uint pixel_index = uint(yi) * width + uint(xi);
        uint base = pixel_index * 4u;
        if (base + 3u < total_channels) {
            vec4 sample_color = textureLoad(input_texture, vec2(xi, yi), 0) * vec4(exposure);
            vec4 color = vec4(sample_color.x * cr, sample_color.y * cg, sample_color.z * cb, sample_color.w);
        }

        // Flow field angle from normalized channel(s)
        vec4 texel_here = textureLoad(input_texture, vec2(xi, yi), 0);
        float v_here = value_map_component(texel_here, channel_count);
        float norm_here = clamp_01((v_here - min_value) * inv_delta);
        float angle = norm_here * TAU * kink + wrot;
        if (quantize_flag) { angle = round(angle); }
        wy = wrap_float(wy + cos(angle) * wstride, float(height));
        wx = wrap_float(wx + sin(angle) * wstride, float(width));

        // Persist
        agent_state_out[base_state + 0u] = wx;
        agent_state_out[base_state + 1u] = wy;
        agent_state_out[base_state + 2u] = angle;
        agent_state_out[base_state + 3u] = wstride;
        agent_state_out[base_state + 4u] = cr;
        agent_state_out[base_state + 5u] = cg;
        agent_state_out[base_state + 6u] = cb;
        agent_state_out[base_state + 7u] = 0.0;
    }

    // Final blend with input texture and input intensity scaling
    uint blend_idx = 0u;
    for (uint by = 0u; by < height; by = by + 1u) {
        for (uint bx = 0u; bx < width; bx = bx + 1u) {
            uint base = blend_idx * 4u;
            vec4 texel = textureLoad(input_texture, vec2(int(bx), int(by)), 0);
            vec4 base_color = vec4(texel.xyz * input_vec, texel.w);
            if (base + 3u < total_channels) {
                float final_alpha = clamp(max(existing_alpha, base_color.w), 0.0, 1.0);
            }
            blend_idx = blend_idx + 1u;
        }
    }
}