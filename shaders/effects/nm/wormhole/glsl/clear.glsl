#version 300 es

precision highp float;
precision highp int;

// Wormhole - Pass 0: Clear output buffer (pixel-parallel)

const uint CHANNEL_COUNT = 4u;


uniform vec4 size;
uniform vec4 flow;
uniform vec4 motion;


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
    
}