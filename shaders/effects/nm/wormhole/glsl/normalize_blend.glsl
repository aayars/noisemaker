#version 300 es

precision highp float;
precision highp int;

// Wormhole - Pass 2: Normalize and blend (pixel-parallel)
// Reads scattered buffer, finds global min/max, normalizes with sqrt, and blends with input

const uint CHANNEL_COUNT = 4u;


uniform sampler2D input_texture;
uniform vec4 size;
uniform vec4 flow;
uniform vec4 motion;

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width_u = uint(size.x);
    uint height_u = uint(size.y);
    
    if (global_id.x >= width_u || global_id.y >= height_u) {
        return;
    }
    
    uint pixel_idx = global_id.y * width_u + global_id.x;
    uint base = pixel_idx * CHANNEL_COUNT;
    
    // Read original input
    vec4 original = textureLoad(input_texture, vec2(int(global_id.x), int(global_id.y)), 0);
    
    // Read accumulated scattered values and weight
    vec3 accum_rgb = vec3(
    );

    // Normalize by accumulated weight to avoid dark output
    bool has_contrib = accum_weight > 1e-4;
    vec3 averaged = accum_rgb / vec3(max(accum_weight, 1e-4));
    vec3 normalized;
    if (has_contrib) {
        normalized = averaged;
    } else {
        normalized = original.xyz;
    }

    // Apply sqrt compression (matching Python behavior)
    vec3 compressed = sqrt(clamp(normalized, vec3(0.0), vec3(1.0)));

    // Blend with input using alpha
    float alpha = clamp01(flow.z);
    vec3 blended = original.xyz * (1.0 - alpha) + compressed * alpha;
    
    // Write result
}