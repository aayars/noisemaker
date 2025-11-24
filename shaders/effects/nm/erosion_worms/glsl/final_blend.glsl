#version 300 es

precision highp float;
precision highp int;

// Erosion Worms - Pass 2: Final Blend
// Composites the accumulated trail buffer with the current input texture.


uniform sampler2D input_texture;
uniform vec4 size;
uniform vec4 controls0;
uniform vec4 controls1;
uniform vec4 controls2;


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uvec2 dims = uvec2(textureSize(input_texture, 0));
    uint width = dims.x;
    uint height = dims.y;

    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    uint pixel_idx = global_id.y * width + global_id.x;
    uint base_index = pixel_idx * 4u;

    vec4 trail_color = vec4(
    );

    vec4 input_sample = textureLoad(input_texture, vec2(int(global_id.x), int(global_id.y)), 0);
    float base_intensity = clamp(controls2.y, 0.0, 1.0);
    vec3 base_rgb = input_sample.xyz * base_intensity;

    vec3 combined_rgb = clamp(base_rgb + trail_color.xyz, vec3(0.0), vec3(1.0));
    float combined_alpha = clamp(max(input_sample.w, trail_color.w), 0.0, 1.0);

    fragColor = vec4(combined_rgb.x, combined_rgb.y, combined_rgb.z, combined_alpha);
}