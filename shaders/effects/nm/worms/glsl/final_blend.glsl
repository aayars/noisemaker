#version 300 es

precision highp float;
precision highp int;

// Worms effect - Pass 3: Final blend
// Clamp accumulated trails to the displayable range

uniform sampler2D input_texture;
uniform vec4 size;
uniform vec4 behavior_density_stride_padding;
uniform vec3 stride_deviation_alpha_kink;
uniform vec4 quantize_time_padding_intensity;
uniform vec4 inputIntensity_lifetime_padding;


float clamp_01(float value) {
    return clamp(value, 0.0, 1.0);
}


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
    uint base = pixel_idx * 4u;
    
    vec4 worms_color = texelFetch(input_texture, ivec2(global_id.xy), 0);

    vec3 combined_rgb = clamp(worms_color.xyz, vec3(0.0), vec3(1.0));
    float final_alpha = clamp(worms_color.w, 0.0, 1.0);

}