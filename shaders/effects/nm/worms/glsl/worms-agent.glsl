#version 300 es

precision highp float;
precision highp int;

uniform vec2 resolution;
uniform sampler2D stateTex1;
uniform sampler2D stateTex2;
uniform sampler2D mixerTex;
uniform float stride;
uniform float kink;
uniform float quantize;
uniform float time;
uniform float behavior;
uniform float lifetime;

layout(location = 0) out vec4 outState1;
layout(location = 1) out vec4 outState2;

const float TAU = 6.283185307179586;

vec2 hash2(uint seed) {
    uint state = seed * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    uint x_bits = (word >> 22u) ^ word;
    
    state = x_bits * 747796405u + 2891336453u;
    word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    uint y_bits = (word >> 22u) ^ word;
    
    return vec2(float(x_bits) / 4294967295.0, float(y_bits) / 4294967295.0);
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
    float sign_value = value >= 0.0 ? 1.0 : -1.0;
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

float normalized_sine(float value) {
    return (sin(value) + 1.0) * 0.5;
}

void main() {
    ivec2 stateSize = textureSize(stateTex1, 0);
    ivec2 coord = ivec2(clamp(gl_FragCoord.xy, vec2(0.0), vec2(stateSize) - vec2(1.0)));
    vec4 state1 = texelFetch(stateTex1, coord, 0);
    vec4 state2 = texelFetch(stateTex2, coord, 0);

    // Inactive agent sentinel
    if (state2.w < 0.0) {
        outState1 = state1;
        outState2 = state2;
        return;
    }

    // Agent format: state1=[x, y, rot, stride] state2=[r, g, b, seed]
    float worms_x = state1.x;
    float worms_y = state1.y;
    float worms_rot = state1.z;
    float worms_stride = state1.w;
    float cr = state2.r;
    float cg = state2.g;
    float cb = state2.b;
    float wseed = state2.w;
    
    // Compute agent index from fragment coordinate
    uint agent_id = uint(coord.y * stateSize.x + coord.x);
    uint total_agents = uint(stateSize.x * stateSize.y);
    
    // Respawn logic using rolling window lifetime
    float normalized_lifetime = lifetime / 60.0;
    float normalized_index = float(agent_id) / float(total_agents);
    float agent_phase = fract(normalized_index);
    
    float time_in_cycle = fract(time + agent_phase);
    float prev_time_in_cycle = fract(time - (1.0 / 60.0) + agent_phase);
    
    bool respawn_check = lifetime > 0.0 && normalized_lifetime > 0.0 &&
                         time_in_cycle < normalized_lifetime &&
                         prev_time_in_cycle >= normalized_lifetime;
    
    if (respawn_check) {
        // Move to random location
        uint seed = agent_id + uint(time * 1000.0);
        vec2 pos = hash2(seed);
        worms_x = pos.x * resolution.x;
        worms_y = pos.y * resolution.y;
        
        // Sample spawn color
        int spawn_xi = int(floor(wrap_float(worms_x, resolution.x)));
        int spawn_yi = int(floor(wrap_float(worms_y, resolution.y)));
        vec4 spawn_sample = texelFetch(mixerTex, ivec2(spawn_xi, spawn_yi), 0);
        cr = spawn_sample.r;
        cg = spawn_sample.g;
        cb = spawn_sample.b;
        
        // Randomize direction
        uint dir_seed = seed + 12345u;
        vec2 dir_raw = hash2(dir_seed) * 2.0 - 1.0;
        float dir_len = length(dir_raw);
        if (dir_len > 1e-5) {
            worms_rot = atan(dir_raw.y, dir_raw.x) / TAU;
        }
        
        wseed = 0.0;
    }

    // Wrap position
    float worms_y_wrapped = wrap_float(worms_y, resolution.y);
    float worms_x_wrapped = wrap_float(worms_x, resolution.x);
    int yi = int(floor(worms_y_wrapped));
    int xi = int(floor(worms_x_wrapped));

    // Sample input texture
    vec4 texel_here = texelFetch(mixerTex, ivec2(xi, yi), 0);
    float index_value = oklab_l(texel_here.rgb);

    int behavior_mode = int(floor(behavior + 0.5));
    float rotation_bias;

    if (behavior_mode <= 0) {
        rotation_bias = 0.0;
    } else if (behavior_mode == 10) {
        float phase = fract(worms_rot);
        rotation_bias = normalized_sine((time - phase) * TAU);
    } else {
        rotation_bias = worms_rot;
    }

    float final_angle = index_value * TAU * kink + rotation_bias;

    if (quantize > 0.5) {
        final_angle = round(final_angle);
    }

    // Update position
    float new_worms_y = worms_y + cos(final_angle) * worms_stride;
    float new_worms_x = worms_x + sin(final_angle) * worms_stride;

    outState1 = vec4(new_worms_x, new_worms_y, worms_rot, worms_stride);
    outState2 = vec4(cr, cg, cb, wseed + 1.0);
}
