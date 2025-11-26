#version 300 es

precision highp float;
precision highp int;

// Worms effect - Compose trails with input texture for display


uniform vec4 size;
uniform vec4 behavior_density_stride_padding;
uniform vec3 stride_deviation_alpha_kink;
uniform vec4 quantize_time_padding_intensity;
uniform vec4 inputIntensity_lifetime_padding;
uniform sampler2D input_texture;

float clamp_01(float value) {
    return clamp(value, 0.0, 1.0);
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = uint(max(size.x, 1.0));
    uint height = uint(max(size.y, 1.0));
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    uint pixel_idx = global_id.y * width + global_id.x;
    uint base_index = pixel_idx * 4u;

    vec4 base_sample = texelFetch(input_texture, ivec2(global_id.xy), 0);
    float input_intensity = clamp_01(inputIntensity_lifetime_padding.x);
    vec4 base_color = vec4(base_sample.xyz * input_intensity, base_sample.w);

    vec4 trail_color = vec4(0.0);

    vec3 combined_rgb = clamp(base_color.xyz + trail_color.xyz, vec3(0.0), vec3(1.0));
    float final_alpha = clamp(max(base_color.w, trail_color.w), 0.0, 1.0);

    fragColor = vec4(combined_rgb, final_alpha);
}