#version 300 es

precision highp float;
precision highp int;

// Lens distortion effect matching `noisemaker.effects.lens_distortion`.
// The shader warps sample coordinates radially around the frame center,
// optionally zooming when the displacement is negative. Time and speed are
// accepted for API parity but do not influence the current math, mirroring the
// reference Python implementation.

const uint CHANNEL_COUNT = 4u;
const float HALF_FRAME = 0.5;
const float MAX_DISTANCE = sqrt(HALF_FRAME * HALF_FRAME + HALF_FRAME * HALF_FRAME);

uniform sampler2D input_texture;
uniform float width;
uniform float height;
uniform float channels;
uniform float displacement;
uniform float time;
uniform float speed;

layout(location = 0) out vec4 fragColor;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

int wrap_index(float value, uint size) {
    if (size == 0u) {
        return 0;
    }

    int truncated = int(value);
    int limit = int(size);
    int wrapped = truncated % limit;
    if (wrapped < 0) {
        wrapped = wrapped + limit;
    }
    return wrapped;
}

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint u_width = as_u32(width);
    uint u_height = as_u32(height);
    ivec2 inputDims = textureSize(input_texture, 0);
    if (u_width == 0u) {
        u_width = uint(max(inputDims.x, 1));
    }
    if (u_height == 0u) {
        u_height = uint(max(inputDims.y, 1));
    }

    if (global_id.x >= u_width || global_id.y >= u_height) {
        return;
    }

    float width_f = float(u_width);
    float height_f = float(u_height);
    float zoom = (displacement < 0.0) ? (displacement * -0.25) : 0.0;

    // Keep layout parity with the Python signature.
    float _unused = (time + speed) * 0.0;

    float x_index = float(global_id.x) / width_f;
    float y_index = float(global_id.y) / height_f;
    float x_dist = x_index - HALF_FRAME;
    float y_dist = y_index - HALF_FRAME;

    float distance_from_center = sqrt(x_dist * x_dist + y_dist * y_dist);
    float normalized_distance = clamp(distance_from_center / MAX_DISTANCE, 0.0, 1.0);
    float center_weight = 1.0 - normalized_distance;
    float center_weight_sq = center_weight * center_weight + _unused;

    float x_offset = (
        x_index -
        x_dist * zoom -
        x_dist * center_weight_sq * displacement
    ) * width_f;
    float y_offset = (
        y_index -
        y_dist * zoom -
        y_dist * center_weight_sq * displacement
    ) * height_f;

    int xi = wrap_index(x_offset, u_width);
    int yi = wrap_index(y_offset, u_height);
    ivec2 sample_coords = ivec2(xi, yi);
    vec4 texel = texelFetch(input_texture, sample_coords, 0);

    fragColor = texel;
}
