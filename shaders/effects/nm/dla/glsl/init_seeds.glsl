#version 300 es

precision highp float;
precision highp int;

// DLA - Init Seeds Pass
// Initializes the simulation with random seed points.


uniform vec4 size_padding;
uniform vec4 density_time;
uniform vec4 speed_padding;

const float UINT32_TO_FLOAT = 1.0 / 4294967296.0;

float fract(float v) {

uvec3 pcg3d(uvec3 v_in) {
    uvec3 v = v_in * 1664525u + 1013904223u;
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v = v ^ (v >> vec3(16u));
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    return v;
}

float random_from_cell(vec2 cell, uint seed) {
    vec3 packed = vec3(cell.x, cell.y, seed);
    vec3 noise = pcg3d(packed);
    return float(noise.x) * UINT32_TO_FLOAT;
}

float next_seed(float seed) {
    return fract(seed * 1.3247179572447458 + 0.123456789);
}

float rand01(inout float seed) {
    float r = seed;
    seed = next_seed(seed);
    return r;
}

void main(@builtin(global_invocation_id) global_id : vec3) {
    uint width = uint(size_padding.x);
    uint height = uint(size_padding.y);
    
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }
    
    uint p = global_id.y * width + global_id.x;
    uint base = p * 4u;

    // Use PCG hash like multires does
    uint time_seed = uint(density_time.w * 1000.0);
    float seed = random_from_cell(global_id.xy, time_seed);
    
    float seed_density = density_time.x;

    if (rand01(seed) < seed_density) {
        // Create a MAGENTA seed point
    } else {
        // Clear the pixel
    }
}
