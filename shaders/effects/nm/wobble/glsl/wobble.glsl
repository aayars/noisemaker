#version 300 es

precision highp float;
precision highp int;

// Wobble effect: offsets the entire frame using simplex noise-driven jitter.

const float TAU = 6.28318530717958647692;
const uint CHANNEL_COUNT = 4u;
const vec3 X_NOISE_SEED = vec3(17.0, 29.0, 11.0);
const vec3 Y_NOISE_SEED = vec3(41.0, 23.0, 7.0);


uniform sampler2D input_texture;
uniform vec4 dims_time;
uniform vec4 speed_pad;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

int wrap_index(int coord, int offset, int size) {
    if (size <= 0) {
        return 0;
    }
    int sum = coord + offset;
    int modulo = sum % size;
    if (modulo < 0) {
        return modulo + size;
    }
    return modulo;
}

void store_texel(uint base_index, vec4 texel) {
}

vec3 mod_289_vec3(vec3 value) {
    vec3 divisor = vec3(289.0);
    vec3 quotient = floor(value / divisor);
    return value - quotient * divisor;
}

vec4 mod_289_vec4(vec4 value) {
    vec4 divisor = vec4(289.0);
    vec4 quotient = floor(value / divisor);
    return value - quotient * divisor;
}

vec4 permute(vec4 value) {
    vec4 scale = vec4(34.0);
    vec4 offset = vec4(1.0);
    return mod_289_vec4(((value * scale) + offset) * value);
}

vec4 taylor_inv_sqrt(vec4 value) {
    vec4 numerator = vec4(1.79284291400159);
    vec4 denominator = vec4(0.85373472095314);
    return numerator - denominator * value;
}

float simplex_noise(vec3 v) {
    vec2 c = vec2(1.0 / 6.0, 1.0 / 3.0);
    vec4 d = vec4(0.0, 0.5, 1.0, 2.0);

    vec3 c_y = vec3(c.y);
    vec3 c_x = vec3(c.x);
    vec3 i0 = floor(v + vec3(dot(v, c_y)));
    vec3 x0 = v - i0 + vec3(dot(i0, c_x));

    vec3 step1 = step(vec3(x0.y, x0.z, x0.x), x0);
    vec3 l = vec3(1.0) - step1;
    vec3 i1 = min(step1, vec3(l.z, l.x, l.y));
    vec3 i2 = max(step1, vec3(l.z, l.x, l.y));

    vec3 x1 = x0 - i1 + c_x;
    vec3 x2 = x0 - i2 + c_y;
    vec3 x3 = x0 - vec3(d.y);

    vec3 i = mod_289_vec3(i0);
    vec4 permute0 = permute(vec4(i.z) + vec4(0.0, i1.z, i2.z, 1.0));
    vec4 permute1 = permute(permute0 + vec4(i.y) + vec4(0.0, i1.y, i2.y, 1.0));
    vec4 p = permute(permute1 + vec4(i.x) + vec4(0.0, i1.x, i2.x, 1.0));

    float n = 0.14285714285714285;
    vec3 ns = vec3(n) * vec3(d.w, d.y, d.z) - vec3(d.x, d.z, d.x);

    float ns_zz = ns.z * ns.z;
    vec4 j = p - vec4(49.0) * floor(p * vec4(ns_zz));
    vec4 x_ = floor(j * vec4(ns.z));
    vec4 y_ = floor(j - vec4(7.0) * x_);

    vec4 x = x_ * vec4(ns.x) + vec4(ns.y);
    vec4 y = y_ * vec4(ns.x) + vec4(ns.y);
    vec4 h = vec4(1.0) - abs(x) - abs(y);

    vec4 b0 = vec4(x.x, x.y, y.x, y.y);
    vec4 b1 = vec4(x.z, x.w, y.z, y.w);

    vec4 s0 = floor(b0) * vec4(2.0) + vec4(1.0);
    vec4 s1 = floor(b1) * vec4(2.0) + vec4(1.0);
    vec4 sh = -step(h, vec4(0.0));

    vec4 a0 = vec4(b0.x, b0.z, b0.y, b0.w)
        + vec4(s0.x, s0.z, s0.y, s0.w) * vec4(sh.x, sh.x, sh.y, sh.y);
    vec4 a1 = vec4(b1.x, b1.z, b1.y, b1.w)
        + vec4(s1.x, s1.z, s1.y, s1.w) * vec4(sh.z, sh.z, sh.w, sh.w);

    vec3 g0 = vec3(a0.x, a0.y, h.x);
    vec3 g1 = vec3(a0.z, a0.w, h.y);
    vec3 g2 = vec3(a1.x, a1.y, h.z);
    vec3 g3 = vec3(a1.z, a1.w, h.w);

    vec4 norm = taylor_inv_sqrt(vec4(
        dot(g0, g0),
        dot(g1, g1),
        dot(g2, g2),
        dot(g3, g3)
    ));
    vec3 g0n = g0 * vec3(norm.x);
    vec3 g1n = g1 * vec3(norm.y);
    vec3 g2n = g2 * vec3(norm.z);
    vec3 g3n = g3 * vec3(norm.w);

    float m0 = max(0.6 - dot(x0, x0), 0.0);
    float m1 = max(0.6 - dot(x1, x1), 0.0);
    float m2 = max(0.6 - dot(x2, x2), 0.0);
    float m3 = max(0.6 - dot(x3, x3), 0.0);

    float m0_sq = m0 * m0;
    float m1_sq = m1 * m1;
    float m2_sq = m2 * m2;
    float m3_sq = m3 * m3;

    return 42.0 * (
        m0_sq * m0_sq * dot(g0n, x0)
        + m1_sq * m1_sq * dot(g1n, x1)
        + m2_sq * m2_sq * dot(g2n, x2)
        + m3_sq * m3_sq * dot(g3n, x3)
    );
}

float simplex_random(float time, float speed, vec3 seed) {
    float angle = time * TAU;
    float z = cos(angle) * speed + seed.x;
    float w = sin(angle) * speed + seed.y;
    float noise_value = simplex_noise(vec3(z, w, seed.z));
    return clamp(noise_value * 0.5 + 0.5, 0.0, 1.0);
}

int compute_offset(float time, float speed, float dimension, vec3 seed) {
    if (dimension <= 0.0) {
        return 0;
    }
    float random_value = simplex_random(time, speed, seed);
    float scaled = random_value * dimension;
    return int(floor(scaled));
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = as_u32(dims_time.x);
    uint height = as_u32(dims_time.y);

    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    if (width == 0u || height == 0u) {
        return;
    }

    float time_value = dims_time.w;
    float speed_value = speed_pad.x * 0.5;

    int x_offset = compute_offset(
        time_value,
        speed_value,
        dims_time.x,
        X_NOISE_SEED
    );
    int y_offset = compute_offset(
        time_value,
        speed_value,
        dims_time.y,
        Y_NOISE_SEED
    );

    int wrapped_x = wrap_index(int(global_id.x), x_offset, int(width));
    int wrapped_y = wrap_index(int(global_id.y), y_offset, int(height));

    vec4 texel = textureLoad(input_texture, vec2(wrapped_x, wrapped_y), 0);

    store_texel(base_index, texel);
}