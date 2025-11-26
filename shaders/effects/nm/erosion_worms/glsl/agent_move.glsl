#version 300 es
precision highp float;
precision highp int;

// Erosion Worms - GPGPU Agent Movement Pass
// Agent state stored in 3 textures (MRT):
//   state1: [x, y, x_dir, y_dir]
//   state2: [r, g, b, inertia]
//   state3: [age, unused, unused, unused]

uniform vec2 resolution;
uniform sampler2D state1_tex;      // Agent position/direction
uniform sampler2D state2_tex;      // Agent color/inertia
uniform sampler2D state3_tex;      // Agent age
uniform sampler2D input_texture;   // Source image for gradient sampling

uniform float stride;
uniform float quantize;
uniform float time;
uniform float inverse;
uniform float xy_blend;
uniform float worm_lifetime;
uniform float intensity;

layout(location = 0) out vec4 outState1;  // Updated position/direction
layout(location = 1) out vec4 outState2;  // Updated color/inertia
layout(location = 2) out vec4 outState3;  // Updated age

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
    if (size <= 0.0) return 0.0;
    float scaled = floor(value / size);
    float wrapped = value - scaled * size;
    if (wrapped < 0.0) wrapped += size;
    return wrapped;
}

int wrap_int(int value, int size) {
    if (size <= 0) return 0;
    int result = value % size;
    if (result < 0) result += size;
    return result;
}

float srgb_to_linear(float value) {
    if (value <= 0.04045) return value / 12.92;
    return pow((value + 0.055) / 1.055, 2.4);
}

float cube_root(float value) {
    if (value == 0.0) return 0.0;
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

vec4 fetch_input(int x, int y, int width, int height) {
    int wx = wrap_int(x, width);
    int wy = wrap_int(y, height);
    return texelFetch(input_texture, ivec2(wx, wy), 0);
}

float luminance_at(int x, int y, int width, int height) {
    vec4 texel = fetch_input(x, y, width, height);
    return oklab_l(texel.xyz);
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

    for (int oy = -kernelRadius; oy <= kernelRadius; oy++) {
        for (int ox = -kernelRadius; ox <= kernelRadius; ox++) {
            float lum = luminance_at(x + ox, y + oy, width, height);
            int row = oy + kernelRadius;
            int col = ox + kernelRadius;
            float w = kernel[row * kernelSize + col];
            total += lum * w;
            weight_sum += w;
        }
    }

    return total / max(weight_sum, 1e-6);
}

void main() {
    ivec2 stateSize = textureSize(state1_tex, 0);
    ivec2 coord = ivec2(clamp(gl_FragCoord.xy, vec2(0.0), vec2(stateSize) - vec2(1.0)));
    
    // Read current agent state
    vec4 s1 = texelFetch(state1_tex, coord, 0);
    vec4 s2 = texelFetch(state2_tex, coord, 0);
    vec4 s3 = texelFetch(state3_tex, coord, 0);

    float x = s1.x;
    float y = s1.y;
    float x_dir = s1.z;
    float y_dir = s1.w;
    float cr = s2.r;
    float cg = s2.g;
    float cb = s2.b;
    float inertia = s2.w;
    float age = s3.x;

    int width = int(resolution.x);
    int height = int(resolution.y);
    
    // Agent indexing for respawn timing
    uint agent_id = uint(coord.y * stateSize.x + coord.x);
    uint total_agents = uint(stateSize.x * stateSize.y);
    
    // Respawn logic with rolling window lifetime
    float normalized_lifetime = worm_lifetime / 60.0;
    float normalized_index = float(agent_id) / float(max(total_agents, 1u));
    float agent_phase = fract(normalized_index);
    
    float time_in_cycle = fract(time + agent_phase);
    float prev_time_in_cycle = fract(time - (1.0 / 60.0) + agent_phase);
    
    bool respawn_check = worm_lifetime > 0.0 && normalized_lifetime > 0.0 &&
                         time_in_cycle < normalized_lifetime &&
                         prev_time_in_cycle >= normalized_lifetime;
    
    bool needs_initial_color = age < 0.0;
    
    // Initialize or respawn
    if (needs_initial_color) {
        int init_xi = wrap_int(int(floor(x)), width);
        int init_yi = wrap_int(int(floor(y)), height);
        vec4 init_sample = texelFetch(input_texture, ivec2(init_xi, init_yi), 0);
        cr = init_sample.x;
        cg = init_sample.y;
        cb = init_sample.z;
        age = 0.0;
    }
    
    if (respawn_check) {
        uint seed = agent_id + uint(time * 1000.0);
        vec2 pos = hash2(seed);
        x = pos.x * resolution.x;
        y = pos.y * resolution.y;
        
        int spawn_xi = wrap_int(int(floor(x)), width);
        int spawn_yi = wrap_int(int(floor(y)), height);
        vec4 spawn_sample = texelFetch(input_texture, ivec2(spawn_xi, spawn_yi), 0);
        cr = spawn_sample.x;
        cg = spawn_sample.y;
        cb = spawn_sample.z;
        age = 0.0;
        
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

    // Gradient descent
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
    float effective_stride = max(stride, 0.1);
    if (glen > 1e-6) {
        float scale = effective_stride / glen;
        gx *= scale;
        gy *= scale;
    } else {
        gx = 0.0;
        gy = 0.0;
    }
    
    // Apply inertia
    x_dir = mix(x_dir, gx, inertia);
    y_dir = mix(y_dir, gy, inertia);
    
    // Update position with wrapping
    x = wrap_float(x + x_dir, resolution.x);
    y = wrap_float(y + y_dir, resolution.y);

    age = max(age, 0.0) + 1.0;

    // Output updated agent state
    outState1 = vec4(x, y, x_dir, y_dir);
    outState2 = vec4(cr, cg, cb, inertia);
    outState3 = vec4(age, 0.0, 0.0, 0.0);
}
