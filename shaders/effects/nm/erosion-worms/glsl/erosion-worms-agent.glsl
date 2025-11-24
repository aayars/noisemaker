#version 300 es
precision highp float;
precision highp int;

uniform vec2 resolution;
uniform sampler2D stateTex1;
uniform sampler2D stateTex2;
uniform sampler2D mixerTex;
uniform float stride;
uniform float quantize;
uniform float time;
uniform float inverse;
uniform float xy_blend;
uniform float worm_lifetime;
uniform sampler2D stateTex3;

layout(location = 0) out vec4 outState1;
layout(location = 1) out vec4 outState2;
layout(location = 2) out vec4 outState3;

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

int wrap_int(int value, int size) {
    if (size <= 0) {
        return 0;
    }
    int result = value % size;
    if (result < 0) {
        result = result + size;
    }
    return result;
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

vec4 fetch_texel(int x, int y, int width, int height) {
    int wrapped_x = wrap_int(x, width);
    int wrapped_y = wrap_int(y, height);
    return texelFetch(mixerTex, ivec2(wrapped_x, wrapped_y), 0);
}

float luminance_at(int x, int y, int width, int height) {
    vec4 texel = fetch_texel(x, y, width, height);
    vec3 rgb = vec3(texel.x, texel.y, texel.z);
    return oklab_l(rgb);
}

float blurred_luminance_at(int x, int y, int width, int height) {
    const int kernelRadius = 2;
    const int kernelSize = 5;
    const float kernel[25] = float[25](
        1.0, 4.0, 6.0, 4.0, 1.0,
        4.0, 16.0, 24.0, 16.0, 4.0,
        6.0, 24.0, 36.0, 24.0, 6.0,
        4.0, 16.0, 24.0, 16.0, 4.0,
        1.0, 4.0, 6.0, 4.0, 1.0
    );

    float total = 0.0;
    float weight_sum = 0.0;

    for (int offset_y = -kernelRadius; offset_y <= kernelRadius; offset_y++) {
        for (int offset_x = -kernelRadius; offset_x <= kernelRadius; offset_x++) {
            float luminanceSample = luminance_at(x + offset_x, y + offset_y, width, height);
            int row = offset_y + kernelRadius;
            int col = offset_x + kernelRadius;
            float weight = kernel[row * kernelSize + col];
            total += luminanceSample * weight;
            weight_sum += weight;
        }
    }

    return total / max(weight_sum, 1e-6);
}

void main() {
    ivec2 stateSize = textureSize(stateTex1, 0);
    ivec2 coord = ivec2(clamp(gl_FragCoord.xy, vec2(0.0), vec2(stateSize) - vec2(1.0)));
    vec4 state1 = texelFetch(stateTex1, coord, 0);
    vec4 state2 = texelFetch(stateTex2, coord, 0);
    vec4 state3 = texelFetch(stateTex3, coord, 0);

    // Agent format mirrors WGSL layout (x, y, x_dir, y_dir, r, g, b, inertia, age)
    // We store: state1=[x, y, x_dir, y_dir], state2=[r, g, b, inertia], state3=[age, 0, 0, 0]
    float age = state3.x;
    bool inactive = age < -1.0;
    if (inactive) {
        outState1 = state1;
        outState2 = state2;
        outState3 = state3;
        return;
    }

    float x = state1.x;
    float y = state1.y;
    float x_dir = state1.z;
    float y_dir = state1.w;
    float cr = state2.r;
    float cg = state2.g;
    float cb = state2.b;
    float inertia = state2.w;

    int width = int(resolution.x);
    int height = int(resolution.y);
    
    // Compute agent index from fragment coordinate
    uint agent_id = uint(coord.y * stateSize.x + coord.x);
    uint total_agents = uint(stateSize.x * stateSize.y);
    
    // Respawn logic using rolling window lifetime
    float normalized_lifetime = worm_lifetime / 60.0;
    float normalized_index = float(agent_id) / float(total_agents);
    float agent_phase = fract(normalized_index);
    
    float time_in_cycle = fract(time + agent_phase);
    float prev_time_in_cycle = fract(time - (1.0 / 60.0) + agent_phase);
    
    bool respawn_check = worm_lifetime > 0.0 && normalized_lifetime > 0.0 &&
                         time_in_cycle < normalized_lifetime &&
                         prev_time_in_cycle >= normalized_lifetime;
    
    bool needs_initial_color = age < 0.0;
    if (needs_initial_color) {
        int init_xi = wrap_int(int(floor(x)), width);
        int init_yi = wrap_int(int(floor(y)), height);
        vec4 init_sample = texelFetch(mixerTex, ivec2(init_xi, init_yi), 0);
        cr = init_sample.x;
        cg = init_sample.y;
        cb = init_sample.z;
        age = 0.0;
    }
    
    if (respawn_check) {
        // Move to random location
        uint seed = agent_id + uint(time * 1000.0);
        vec2 pos = hash2(seed);
        x = pos.x * resolution.x;
        y = pos.y * resolution.y;
        
        // Sample spawn color
        int spawn_xi = wrap_int(int(floor(x)), width);
        int spawn_yi = wrap_int(int(floor(y)), height);
    vec4 spawn_sample = texelFetch(mixerTex, ivec2(spawn_xi, spawn_yi), 0);
    cr = spawn_sample.x;
    cg = spawn_sample.y;
    cb = spawn_sample.z;
    age = 0.0;
        
        // Randomize direction
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

    // Gradient descent logic (single iteration per frame)
    int xi = wrap_int(int(floor(x)), width);
    int yi = wrap_int(int(floor(y)), height);
    int x1i = wrap_int(xi + 1, width);
    int y1i = wrap_int(yi + 1, height);
    
    float u = x - floor(x);
    float v = y - floor(y);
    
    float c00 = blurred_luminance_at(xi, yi, width, height);
    float c10 = blurred_luminance_at(x1i, yi, width, height);
    float c01 = blurred_luminance_at(xi, y1i, width, height);
    float c11 = blurred_luminance_at(x1i, y1i, width, height);
    
    float gx = mix(c01 - c00, c11 - c10, u);
    float gy = mix(c10 - c00, c11 - c01, v);
    
    if (quantize > 0.5) {
        gx = floor(gx);
        gy = floor(gy);
    }
    
    float glen = length(vec2(gx, gy));
    if (glen > 1e-6) {
        float scale = stride / glen;
        gx *= scale;
        gy *= scale;
    } else {
        gx = 0.0;
        gy = 0.0;
    }
    
    x_dir = mix(x_dir, gx, inertia);
    y_dir = mix(y_dir, gy, inertia);
    
    // Update position with wrapping
    x = wrap_float(x + x_dir, resolution.x);
    y = wrap_float(y + y_dir, resolution.y);

    outState1 = vec4(x, y, x_dir, y_dir);
    outState2 = vec4(cr, cg, cb, inertia);
    outState3 = vec4(max(age, 0.0), 0.0, 0.0, 0.0);
}
