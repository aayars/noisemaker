#version 300 es

precision highp float;
precision highp int;

// Kaleido - reuses Voronoi distance field to mirror the source texture into wedge slices.
// Low-level Voronoi generation is handled by a separate pass; this shader only remaps samples.

const float PI = 3.14159265358979323846;
const float TAU = 6.28318530717958647692;

uniform sampler2D input_texture;
uniform vec4 dims;
uniform vec4 misc;
uniform sampler2D radius_texture;

out vec4 fragColor;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

float positive_mod(float value, float modulus) {
    if (modulus == 0.0) {
        return 0.0;
    }
    float result = value - floor(value / modulus) * modulus;
    if (result < 0.0) {
        result = result + modulus;
    }
    return result;
}

int wrap_index(int value, int limit) {
    if (limit <= 0) {
        return 0;
    }
    int wrapped = value % limit;
    if (wrapped < 0) {
        wrapped = wrapped + limit;
    }
    return wrapped;
}

float compute_edge_fade(uint x, uint y, uint width, uint height) {
    if (width <= 1u || height <= 1u) {
        return 0.0;
    }
    float nx = float(x) / float(width - 1u);
    float ny = float(y) / float(height - 1u);
    float dx = abs(nx - 0.5) * 2.0;
    float dy = abs(ny - 0.5) * 2.0;
    float chebyshev = clamp(max(dx, dy), 0.0, 1.0);
    return pow(chebyshev, 5.0);
}

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width_u = max(as_u32(dims.x), 1u);
    uint height_u = max(as_u32(dims.y), 1u);
    if (global_id.x >= width_u || global_id.y >= height_u) {
        return;
    }

    float width_f = max(dims.x, 1.0);
    float height_f = max(dims.y, 1.0);
    float sides = max(dims.w, 1.0);
    bool blend_edges_flag = misc.y > 0.5;

    float normalized_x = 0.0;
    if (width_u > 1u) {
        normalized_x = float(global_id.x) / float(width_u - 1u) - 0.5;
    }
    float normalized_y = 0.0;
    if (height_u > 1u) {
        normalized_y = float(global_id.y) / float(height_u - 1u) - 0.5;
    }

    ivec2 coord_i = ivec2(int(global_id.x), int(global_id.y));
    float radius_sample = clamp01(texelFetch(radius_texture, coord_i, 0).x);

    float angle_step = TAU / max(sides, 1.0);
    float angle = atan(normalized_y, normalized_x) + PI * 0.5;
    angle = positive_mod(angle, angle_step);
    angle = abs(angle - angle_step * 0.5);

    float sample_x = radius_sample * width_f * sin(angle);
    float sample_y = radius_sample * height_f * cos(angle);

    if (blend_edges_flag) {
        float fade = clamp01(compute_edge_fade(global_id.x, global_id.y, width_u, height_u));
        sample_x = mix(sample_x, float(global_id.x), fade);
        sample_y = mix(sample_y, float(global_id.y), fade);
    }

    int wrapped_x = wrap_index(int(round(sample_x)), int(width_u));
    int wrapped_y = wrap_index(int(round(sample_y)), int(height_u));
    vec4 color = texelFetch(input_texture, ivec2(wrapped_x, wrapped_y), 0);

    fragColor = color;
}
