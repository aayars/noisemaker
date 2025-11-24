#version 300 es

precision highp float;
precision highp int;

// Vortex tiling effect.
// Port of noisemaker.effects.vortex. Builds a displacement field from a
// singularity map, modulates it with a Chebyshev fade mask, and refracts the
// source texture using a simplex-driven displacement amount.

const float TAU = 6.28318530717958647692;
const uint CHANNEL_COUNT = 4u;


uniform sampler2D input_texture;
uniform vec4 size_displacement;
uniform vec4 time_speed;

uint to_u32(float value) {
    return uint(max(value, 0.0));
}

int wrap_coord(int coord, int limit) {
    if (limit <= 0) {
        return 0;
    }

    int wrapped = coord % limit;
    if (wrapped < 0) {
        wrapped = wrapped + limit;
    }

    return wrapped;
}

float wrap_float(float value, float limit) {
    if (limit == 0.0) {
        return 0.0;
    }

    float cycles = floor(value / limit);
    float result = value - cycles * limit;
    if (result < 0.0) {
        result = result + limit;
    }

    return result;
}

void store_texel(uint base_index, vec4 texel) {
}

vec3 mod289_vec3(vec3 x) {
    return x - floor(x / 289.0) * 289.0;
}

vec4 mod289_vec4(vec4 x) {
    return x - floor(x / 289.0) * 289.0;
}

vec4 permute(vec4 x) {
    return mod289_vec4(((x * 34.0) + 1.0) * x);
}

vec4 taylor_inv_sqrt(vec4 r) {
    return 1.79284291400159 - 0.85373472095314 * r;
}

float simplex_noise(vec3 v) {
    vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
    vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

    vec3 i0 = floor(v + dot(v, vec3(C.y)));
    vec3 x0 = v - i0 + dot(i0, vec3(C.x));

    vec3 step1 = step(vec3(x0.y, x0.z, x0.x), x0);
    vec3 l = vec3(1.0) - step1;
    vec3 i1 = min(step1, vec3(l.z, l.x, l.y));
    vec3 i2 = max(step1, vec3(l.z, l.x, l.y));

    vec3 x1 = x0 - i1 + vec3(C.x);
    vec3 x2 = x0 - i2 + vec3(C.y);
    vec3 x3 = x0 - vec3(D.y);

    vec3 i = mod289_vec3(i0);
    p = permute(
        permute(
            permute(i.z + vec4(0.0, i1.z, i2.z, 1.0))
            + i.y + vec4(0.0, i1.y, i2.y, 1.0)
        ) + i.x + vec4(0.0, i1.x, i2.x, 1.0)
    );

    float n_ = 0.14285714285714285;
    vec3 ns = n_ * vec3(D.w, D.y, D.z) - vec3(D.x, D.z, D.x);

    vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);

    x = x_ * ns.x + ns.y;
    y = y_ * ns.x + ns.y;
    h = 1.0 - abs(x) - abs(y);

    vec4 b0 = vec4(x.x, x.y, y.x, y.y);
    vec4 b1 = vec4(x.z, x.w, y.z, y.w);

    vec4 s0 = floor(b0) * 2.0 + 1.0;
    vec4 s1 = floor(b1) * 2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));

    vec4 a0 = vec4(b0.x, b0.z, b0.y, b0.w)
        + vec4(s0.x, s0.z, s0.y, s0.w) * vec4(sh.x, sh.x, sh.y, sh.y);
    vec4 a1 = vec4(b1.x, b1.z, b1.y, b1.w)
        + vec4(s1.x, s1.z, s1.y, s1.w) * vec4(sh.z, sh.z, sh.w, sh.w);

    vec3 g0 = vec3(a0.x, a0.y, h.x);
    vec3 g1 = vec3(a0.z, a0.w, h.y);
    vec3 g2 = vec3(a1.x, a1.y, h.z);
    vec3 g3 = vec3(a1.z, a1.w, h.w);

    vec4 norm = taylor_inv_sqrt(
        vec4(dot(g0, g0), dot(g1, g1), dot(g2, g2), dot(g3, g3))
    );
    vec3 g0n = g0 * norm.x;
    vec3 g1n = g1 * norm.y;
    vec3 g2n = g2 * norm.z;
    vec3 g3n = g3 * norm.w;

    float m0 = max(0.6 - dot(x0, x0), 0.0);
    float m1 = max(0.6 - dot(x1, x1), 0.0);
    float m2 = max(0.6 - dot(x2, x2), 0.0);
    float m3 = max(0.6 - dot(x3, x3), 0.0);

    float m0sq = m0 * m0;
    float m1sq = m1 * m1;
    float m2sq = m2 * m2;
    float m3sq = m3 * m3;

    return 42.0 * (
        m0sq * m0sq * dot(g0n, x0)
        + m1sq * m1sq * dot(g1n, x1)
        + m2sq * m2sq * dot(g2n, x2)
        + m3sq * m3sq * dot(g3n, x3)
    );
}

float simplex_random(float time, float speed) {
    float angle = time * TAU;
    float z = cos(angle) * speed;
    float w = sin(angle) * speed;
    float noise_value = simplex_noise(vec3(z + 17.0, w + 29.0, 11.0));
    return clamp(noise_value * 0.5 + 0.5, 0.0, 1.0);
}

float displacement_value(ivec2 coord, vec2 dims) {
    if (dims.x <= 0.0 || dims.y <= 0.0) {
        return 0.0;
    }

    vec2 half_dims = dims * 0.5;
    vec2 pos = vec2(float(coord.x), float(coord.y)) + vec2(0.5, 0.5);
    vec2 centered = pos - half_dims;
    float distance = length(centered);
    float max_distance = length(half_dims);
    if (max_distance <= 0.0) {
        return 0.0;
    }

    return clamp(distance / max_distance, 0.0, 1.0);
}

float fade_value(ivec2 coord, vec2 dims) {
    if (dims.x <= 0.0 || dims.y <= 0.0) {
        return 0.0;
    }

    vec2 half_dims = dims * 0.5;
    vec2 pos = vec2(float(coord.x), float(coord.y)) + vec2(0.5, 0.5);
    vec2 offset = abs(pos - half_dims);
    float max_component = max(offset.x / half_dims.x, offset.y / half_dims.y);
    return 1.0 - clamp(max_component, 0.0, 1.0);
}

vec2 gradient_at(ivec2 coord, vec2 dims) {
    int width_i = int(dims.x);
    int height_i = int(dims.y);
    if (width_i <= 0 || height_i <= 0) {
        return vec2(0.0, 0.0);
    }

    float center = displacement_value(coord, dims);

    vec2 right_coord = vec2(wrap_coord(coord.x + 1, width_i), coord.y);
    vec2 down_coord = vec2(coord.x, wrap_coord(coord.y + 1, height_i));

    float right = displacement_value(right_coord, dims);
    float down = displacement_value(down_coord, dims);

    return vec2(center - right, center - down);
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = max(to_u32(size_displacement.x), 1u);
    uint height = max(to_u32(size_displacement.y), 1u);
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }


    float width_f = max(size_displacement.x, 1.0);
    float height_f = max(size_displacement.y, 1.0);
    vec2 dims = vec2(width_f, height_f);
    vec2 coord_i = vec2(int(global_id.x), int(global_id.y));

    float fade = fade_value(coord_i, dims);
    vec2 gradient = gradient_at(coord_i, dims) * fade;

    float random_factor = simplex_random(time_speed.x, time_speed.y);
    float warp_amount = random_factor * 100.0 * size_displacement.w;

    float scale_x = warp_amount * width_f * 2.0;
    float scale_y = warp_amount * height_f * 2.0;

    float sample_x = float(global_id.x) + gradient.x * scale_x;
    float sample_y = float(global_id.y) + gradient.y * scale_y;

    float wrapped_x = wrap_float(sample_x, width_f);
    float wrapped_y = wrap_float(sample_y, height_f);

    int x0 = int(floor(wrapped_x));
    int y0 = int(floor(wrapped_y));

    int width_i = int(width);
    int height_i = int(height);

    if (x0 < 0) {
        x0 = 0;
    } else if (x0 >= width_i) {
        x0 = width_i - 1;
    }

    if (y0 < 0) {
        y0 = 0;
    } else if (y0 >= height_i) {
        y0 = height_i - 1;
    }

    int x1 = wrap_coord(x0 + 1, width_i);
    int y1 = wrap_coord(y0 + 1, height_i);

    float fx = clamp(wrapped_x - float(x0), 0.0, 1.0);
    float fy = clamp(wrapped_y - float(y0), 0.0, 1.0);

    vec4 tex00 = textureLoad(input_texture, vec2(x0, y0), 0);
    vec4 tex10 = textureLoad(input_texture, vec2(x1, y0), 0);
    vec4 tex01 = textureLoad(input_texture, vec2(x0, y1), 0);
    vec4 tex11 = textureLoad(input_texture, vec2(x1, y1), 0);

    vec4 mix_x0 = mix(tex00, tex10, vec4(fx));
    vec4 mix_x1 = mix(tex01, tex11, vec4(fx));
    vec4 result = mix(mix_x0, mix_x1, vec4(fy));

    store_texel(base_index, result);
}