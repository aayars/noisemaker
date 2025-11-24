#version 300 es

precision highp float;
precision highp int;

// Worms effect - Pass 2: Agent movement and trail deposition
// Each thread handles one agent

const float TAU = 6.28318530717958647692;

uniform sampler2D input_texture;
uniform vec4 size;
uniform vec4 behavior_density_stride_padding;
uniform vec3 stride_deviation_alpha_kink;
uniform vec4 quantize_time_padding_intensity;
uniform vec4 inputIntensity_lifetime_padding;
uniform sampler2D prev_texture;


float clamp_01(float value) {
    return clamp(value, 0.0, 1.0);
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

float fract_f32(float value) {
    return value - floor(value);
}

float normalized_sine(float value) {
    return (sin(value) + 1.0) * 0.5;
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


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint agent_idx = global_id.x;
    uint floats_len = arrayLength(&agent_state_in);
    
    // Each agent is 9 floats: [x, y, rot, stride, r, g, b, seed, age]
    if (agent_idx * 9u >= floats_len) {
        return;
    }
    
    uvec2 dims = uvec2(textureSize(input_texture, 0));
    uint width = dims.x;
    uint height = dims.y;
    if (width == 0u || height == 0u) {
        return;
    }
    
    uint channel_count = 4u;
    float kink = clamp(stride_deviation_alpha_kink.z, 0.0, 100.0);
    bool quantize_flag = quantize_time_padding_intensity.x > 0.5;
    float time = quantize_time_padding_intensity.y;
    float worm_lifetime = inputIntensity_lifetime_padding.y;
    
    // Load agent state
    // Agent format: [x, y, rot, stride, r, g, b, seed, age]
    // Note: x/y in agent state correspond to column/row (width/height)
    uint base_state = agent_idx * 9u;
    float worms_x = agent_state_in[base_state + 0u];
    float worms_y = agent_state_in[base_state + 1u];
    float worms_rot = agent_state_in[base_state + 2u];
    float worms_stride = agent_state_in[base_state + 3u];
    float cr = agent_state_in[base_state + 4u];
    float cg = agent_state_in[base_state + 5u];
    float cb = agent_state_in[base_state + 6u];
    float wseed = agent_state_in[base_state + 7u];
    float age = agent_state_in[base_state + 8u];

    // Lifetime respawn logic
    uint agent_count = floats_len / 9u;
    float normalized_index = float(agent_idx) / float(max(agent_count, 1u));
    float agent_phase = fract(normalized_index);
    bool needs_initial_color = age < 0.0;
    
    // When lifetime > 0, agents respawn after living for 'lifetime' seconds
    // Each agent gets a staggered offset so they don't all respawn at once
    // Normalize lifetime from 0-60 range to 0-1 for the cycle duration
    float normalized_lifetime = worm_lifetime / 60.0;
    
    // Calculate when this agent should respawn based on its phase offset
    float time_with_offset = time + agent_phase;
    float time_in_cycle = fract(time_with_offset);
    float prev_time_in_cycle = fract(time_with_offset - 0.016);
    
    // Respawn when we cross the lifetime boundary (wrapping from high to low)
    // This only happens if lifetime > 0 and we actually have a valid normalized lifetime
    respawn_check : bool = worm_lifetime > 0.0 && normalized_lifetime > 0.0 &&
                                time_in_cycle < normalized_lifetime &&
                                prev_time_in_cycle >= normalized_lifetime;
    
    if (needs_initial_color) {
        int init_xi = wrap_int(int(floor(worms_x)), int(width));
        int init_yi = wrap_int(int(floor(worms_y)), int(height));
        vec4 init_sample = textureLoad(input_texture, vec2(init_xi, init_yi), 0);
        cr = init_sample.x;
        cg = init_sample.y;
        cb = init_sample.z;
        age = 0.0;
    }

    if (respawn_check) {
        // Move to random location
        uint seed = agent_idx + uint(time * 1000.0);
        vec2 pos = hash2(seed);
        worms_x = pos.x * float(width);
        worms_y = pos.y * float(height);

        // Sample spawn color from the current input texture
        int spawn_xi = wrap_int(int(floor(worms_x)), int(width));
        int spawn_yi = wrap_int(int(floor(worms_y)), int(height));
        vec4 spawn_sample = textureLoad(input_texture, vec2(spawn_xi, spawn_yi), 0);
        cr = spawn_sample.x;
        cg = spawn_sample.y;
        cb = spawn_sample.z;
        age = 0.0;

        // Randomize rotation so respawned agents immediately move in a new heading
        uint dir_seed = seed + 12345u;
        float rand_rot = hash(dir_seed);
        worms_rot = rand_rot * TAU;
    }
    
    // Convert to pixel coordinates (wrapping)
    // Python: worm_positions = tf.cast(tf.stack([worms_y % height, worms_x % width], 1), tf.int32)
    // This means position is [row, col] = [y, x]
    float worms_y_wrapped = wrap_float(worms_y, float(height));
    float worms_x_wrapped = wrap_float(worms_x, float(width));
    int yi = int(floor(worms_y_wrapped));
    int xi = int(floor(worms_x_wrapped));
    
    uint pixel_index = uint(yi) * width + uint(xi);
    uint base = pixel_index * 4u;
    
    // Deposit trail at current position using agent's spawn color
    vec4 color = vec4(cr, cg, cb, 1.0);
    
    
    vec4 texel_here = textureLoad(input_texture, vec2(xi, yi), 0);
    float index_value = value_map_component(texel_here, channel_count);
    
    int behavior_mode = int(floor(behavior_density_stride_padding.x + 0.5));
    float rotation_bias;

    if (behavior_mode <= 0) {
        rotation_bias = 0.0;
    } else if (behavior_mode == 10) {
        float phase = fract_f32(worms_rot);
        rotation_bias = normalized_sine((quantize_time_padding_intensity.y - phase) * TAU);
    } else {
        rotation_bias = worms_rot;
    }

    float final_angle = index_value * TAU * kink + rotation_bias;
    
    if (quantize_flag) {
        final_angle = round(final_angle);
    }
    
    float new_worms_y = worms_y + cos(final_angle) * worms_stride;
    float new_worms_x = worms_x + sin(final_angle) * worms_stride;

    agent_state_out[base_state + 0u] = new_worms_x;
    agent_state_out[base_state + 1u] = new_worms_y;
    agent_state_out[base_state + 2u] = worms_rot;
    agent_state_out[base_state + 3u] = worms_stride;
    agent_state_out[base_state + 4u] = cr;
    agent_state_out[base_state + 5u] = cg;
    agent_state_out[base_state + 6u] = cb;
    agent_state_out[base_state + 7u] = wseed + 1.0;
    agent_state_out[base_state + 8u] = age;
}