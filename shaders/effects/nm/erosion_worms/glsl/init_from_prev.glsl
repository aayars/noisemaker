#version 300 es

precision highp float;
precision highp int;

// Erosion Worms - Pass 0: Initialize from previous frame
// Copies the previous trail texture into the working buffer with configurable fade.


uniform sampler2D input_texture;
uniform vec4 size;
uniform vec4 controls0;
uniform vec4 controls1;
uniform vec4 controls2;
uniform sampler2D prev_texture;


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uvec2 dims = uvec2(textureSize(prev_texture, 0));
    uint width = dims.x;
    uint height = dims.y;

    if (width == 0u || height == 0u) {
        return;
    }

    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    float fade = clamp(controls1.x, 0.0, 1.0);
    uint pixel_idx = global_id.y * width + global_id.x;
    uint base = pixel_idx * 4u;

    vec4 prev_sample = textureLoad(prev_texture, vec2(int(global_id.x), int(global_id.y)), 0);
    vec4 faded = prev_sample * fade;

}