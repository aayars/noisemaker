#version 300 es

precision highp float;
precision highp int;

// Blends intermediate spatter layers into a final mask.
// Inputs are grayscale textures (smear, spatter 1, spatter 2, removal).

const uint CHANNEL_COUNT = 4u;


uniform sampler2D smear_texture;
uniform sampler2D spatter_primary_texture;
uniform sampler2D spatter_secondary_texture;
uniform sampler2D removal_texture;
uniform vec4 size;

uint as_u32(float value) {
    if (value <= 0.0) {
        return 0u;
    }
    return uint(round(value));
}

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

float sample_grayscale(sampler2D tex, ivec2 coords) {
    return clamp01(texture(tex, (vec2(coords) + vec2(0.5)) / vec2(textureSize(tex, 0))).x);
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = as_u32(size.x);
    uint height = as_u32(size.y);
    if (width == 0u || height == 0u) {
        return;
    }
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    vec2 coords = vec2(int(global_id.x), int(global_id.y));
    float smear_value = sample_grayscale(smear_texture, ivec2(coords));
    float primary_value = sample_grayscale(spatter_primary_texture, ivec2(coords));
    float secondary_value = sample_grayscale(spatter_secondary_texture, ivec2(coords));
    float removal_value = sample_grayscale(removal_texture, ivec2(coords));

    float combined = max(smear_value, max(primary_value, secondary_value));
    float masked = max(0.0, combined - removal_value);
    float result = clamp01(masked);

    uint base_index = (global_id.y * width + global_id.x) * CHANNEL_COUNT;
    fragColor = vec4(result, result, result, 1.0);
}