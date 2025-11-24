#version 300 es

precision highp float;
precision highp int;

// Normalize Pass 2 (Reduce): Reduce workgroup statistics to final global min/max
// This intermediate pass consolidates all workgroup results from pass 1


const uint CHANNEL_COUNT = 4u;
const float F32_MAX = 0x1.fffffep+127;
const float F32_MIN = -0x1.fffffep+127;

uniform sampler2D input_texture;
uniform vec4 dimensions;
uniform vec4 animation;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    // Only thread (0,0,0) does the reduction
    if (global_id.x != 0u || global_id.y != 0u || global_id.z != 0u) {
        return;
    }

    uint width = as_u32(dimensions.x);
    uint height = as_u32(dimensions.y);
    uint num_workgroups = ((width + 7u) / 8u) * ((height + 7u) / 8u);
    
    float global_min = F32_MAX;
    float global_max = F32_MIN;
    
    // Reduce all workgroup results
    for (uint i = 0u; i < num_workgroups; i = i + 1u) {
        uint offset = 2u + i * 2u;
        if (offset + 1u < arrayLength(stats_buffer)) {
            global_min = min(global_min, stats_buffer[offset]);
            global_max = max(global_max, stats_buffer[offset + 1u]);
        }
    }
    
    // Store final results in first two slots
    stats_buffer[0] = global_min;
    stats_buffer[1] = global_max;
}