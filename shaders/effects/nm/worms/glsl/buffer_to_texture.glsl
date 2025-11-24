#version 300 es

precision highp float;
precision highp int;

// Converts linear RGBA storage buffer data into a 2D storage texture.


uniform vec4 size;
uniform vec4 behavior_density_stride_padding;
uniform vec3 stride_deviation_alpha_kink;
uniform vec4 quantize_time_padding_intensity;
uniform vec4 inputIntensity_lifetime_padding;


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = uint(max(size.x, 1.0));
    uint height = uint(max(size.y, 1.0));
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }
    uint pixel_idx = global_id.y * width + global_id.x;
    uint base = pixel_idx * 4u;
    vec4 color = vec4(
    );
    textureStore(output_texture, vec2(int(global_id.x), int(global_id.y)), color);
}