#version 300 es

precision highp float;
precision highp int;

// DLA - Save Cluster Pass
// After final_blend, extract and save ONLY the cluster state for next frame
// This undoes the blending so output_buffer contains only magenta cluster


uniform vec4 size_padding;
uniform vec4 density_time;
uniform vec4 speed_padding;


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = uint(size_padding.x);
    uint height = uint(size_padding.y);
    
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }
    
    uint idx = global_id.y * width + global_id.x;
    uint base = idx * 4u;
    
    // Read current pixel (which has cluster + gliders + input blended)
    
    // Extract ONLY the magenta cluster component
    // If pixel is magenta-ish, keep it; otherwise clear it
    if (r > 0.5 && g < 0.5 && b > 0.5) {
        // This is a cluster pixel, keep it pure magenta
    } else {
        // Not a cluster pixel, clear it
    }
}