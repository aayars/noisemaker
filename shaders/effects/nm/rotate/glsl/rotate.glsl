#version 300 es

precision highp float;
precision highp int;

// Rotate effect: matches Noisemaker's rotate() by tiling the input into a square,
// rotating in normalized space, and cropping back to the original dimensions.

uniform sampler2D inputTex;
uniform float angle;

int wrap_index(int value, int size) {
    if (size <= 0) {
        return 0;
    }

    int wrapped = value % size;
    if (wrapped < 0) {
        wrapped = wrapped + size;
    }

    return wrapped;
}

out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    ivec2 input_size = textureSize(inputTex, 0);
    uint width = uint(input_size.x);
    uint height = uint(input_size.y);
    if (width == 0u || height == 0u) {
        fragColor = vec4(0.0);
        return;
    }
    if (global_id.x >= width || global_id.y >= height) {
        fragColor = vec4(0.0);
        return;
    }

    int width_i = int(width);
    int height_i = int(height);
    if (width_i <= 0 || height_i <= 0) {
        return;
    }

    int padded_size_i = max(width_i, height_i) * 2;
    if (padded_size_i <= 0) {
        return;
    }

    float padded_size_f = float(padded_size_i);
    int crop_offset_x = (padded_size_i - width_i) / 2;
    int crop_offset_y = (padded_size_i - height_i) / 2;
    int tile_offset_x = width_i / 2;
    int tile_offset_y = height_i / 2;

    ivec2 padded_coord = ivec2(
        int(global_id.x) + crop_offset_x,
        int(global_id.y) + crop_offset_y
    );

    vec2 padded_coord_f = vec2(
        float(padded_coord.x),
        float(padded_coord.y)
    );
    vec2 normalized = padded_coord_f / padded_size_f - vec2(0.5, 0.5);

    float angle_radians = radians(angle);
    float cos_angle = cos(angle_radians);
    float sin_angle = sin(angle_radians);
    mat2 rotation = mat2(
        cos_angle, -sin_angle,
        sin_angle, cos_angle
    );

    vec2 rotated = rotation * normalized + vec2(0.5, 0.5);
    vec2 rotated_scaled = rotated * padded_size_f;

    ivec2 padded_sample = ivec2(
        wrap_index(int(rotated_scaled.x), padded_size_i),
        wrap_index(int(rotated_scaled.y), padded_size_i)
    );

    ivec2 source = ivec2(
        wrap_index(padded_sample.x + tile_offset_x, width_i),
        wrap_index(padded_sample.y + tile_offset_y, height_i)
    );

    ivec2 coords = source;
    vec4 texel = texelFetch(inputTex, coords, 0);

    fragColor = texel;
}