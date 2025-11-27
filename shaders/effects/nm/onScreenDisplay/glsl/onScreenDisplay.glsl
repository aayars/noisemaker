#version 300 es
precision highp float;
precision highp int;

const float INV_UINT_RANGE = 1.0 / 4294967296.0;
const float TAU = 6.283185307179586;

uniform sampler2D inputTex;
uniform vec2 resolution;
uniform float time;
uniform float speed;

layout(location = 0) out vec4 fragColor;

const float BANK_OCR_ATLAS[] = float[](0.0,1.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,0.0,0.0,1.0,1.0,0.0,1.0,1.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,1.0,1.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,1.0,1.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,1.0,1.0,1.0,1.0,0.0,1.0,1.0,0.0,0.0,1.0,1.0,0.0,1.0,1.0,0.0,0.0,1.0,1.0,0.0,1.0,1.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0);
const float ALPHANUM_NUMERIC_ATLAS[] = float[](0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,0.0,1.0,0.0,1.0,0.0,1.0,0.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,0.0,0.0,1.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0);
const float ALPHANUM_HEX_ATLAS[] = float[](0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,0.0,1.0,0.0,1.0,0.0,1.0,0.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,0.0,0.0,1.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,1.0,0.0,1.0,1.0,1.0,1.0,1.0,0.0,1.0,0.0,0.0,0.0,1.0,0.0,1.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,1.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,1.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,1.0,0.0,1.0,0.0,0.0,0.0,1.0,0.0,1.0,0.0,0.0,0.0,1.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,1.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,1.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,1.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0,1.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0,1.0,0.0,0.0,0.0,0.0,0.0);

float get_bank_ocr(int digit, int row, int col) {
    return BANK_OCR_ATLAS[digit * 56 + row * 7 + col];
}

float get_num_atlas(int digit, int row, int col) {
    return ALPHANUM_NUMERIC_ATLAS[digit * 36 + row * 6 + col];
}

float get_hex_atlas(int digit, int row, int col) {
    return ALPHANUM_HEX_ATLAS[digit * 36 + row * 6 + col];
}

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

uvec3 pcg3d(uvec3 v_in) {
    uvec3 v = v_in * 1664525u + 1013904223u;
    v.x = v.x + v.y * v.z;
    v.y = v.y + v.z * v.x;
    v.z = v.z + v.x * v.y;
    v = v ^ (v >> uvec3(16u));
    v.x = v.x + v.y * v.z;
    v.y = v.y + v.z * v.x;
    v.z = v.z + v.x * v.y;
    return v;
}

uint random_u32(uint base_seed, uint salt) {
    uvec3 mixed = uvec3(
        (base_seed) ^ ((salt * 0x9e3779b9u) + 0x632be59bu),
        ((base_seed + 0x7f4a7c15u)) ^ ((salt * 0x165667b1u) + 0x85ebca6bu),
        ((base_seed ^ 0x27d4eb2du) + (salt * 0x94d049bbu) + 0x5bf03635u)
    );
    return pcg3d(mixed).x;
}

float random_float(uint base_seed, uint salt) {
    return float(random_u32(base_seed, salt)) * INV_UINT_RANGE;
}

int random_range(uint base_seed, uint salt, int min_value, int max_value) {
    int lo = min_value;
    int hi = max_value;
    if (lo > hi) {
        int tmp = lo;
        lo = hi;
        hi = tmp;
    }
    int span = hi - lo;
    if (span <= 0) {
        return lo;
    }
    float scaled = random_float(base_seed, salt) * float(span + 1);
    int offset = clamp(int(floor(scaled)), 0, span);
    return lo + offset;
}

vec3 mod289_vec3(vec3 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod289_vec4(vec4 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x) {
    return mod289_vec4(((x * 34.0) + 1.0) * x);
}

vec4 taylor_inv_sqrt(vec4 r) {
    return 1.79284291400159 - 0.85373472095314 * r;
}

float simplex_noise(vec3 v) {
    vec2 c = vec2(1.0 / 6.0, 1.0 / 3.0);
    vec4 d = vec4(0.0, 0.5, 1.0, 2.0);

    vec3 i0 = floor(v + dot(v, vec3(c.y)));
    vec3 x0 = v - i0 + dot(i0, vec3(c.x));

    vec3 step1 = step(vec3(x0.y, x0.z, x0.x), x0);
    vec3 l = vec3(1.0) - step1;
    vec3 i1 = min(step1, vec3(l.z, l.x, l.y));
    vec3 i2 = max(step1, vec3(l.z, l.x, l.y));

    vec3 x1 = x0 - i1 + vec3(c.x);
    vec3 x2 = x0 - i2 + vec3(c.y);
    vec3 x3 = x0 - vec3(d.y);

    vec3 i = mod289_vec3(i0);
    vec4 p = permute(
        permute(
            permute(i.z + vec4(0.0, i1.z, i2.z, 1.0))
            + i.y + vec4(0.0, i1.y, i2.y, 1.0)
        )
        + i.x + vec4(0.0, i1.x, i2.x, 1.0)
    );

    float n_ = 0.14285714285714285;
    vec3 ns = n_ * vec3(d.w, d.y, d.z) - vec3(d.x, d.z, d.x);

    vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);

    vec4 x = x_ * ns.x + ns.y;
    vec4 y = y_ * ns.x + ns.y;
    vec4 h = 1.0 - abs(x) - abs(y);

    vec4 b0 = vec4(x.x, x.y, y.x, y.y);
    vec4 b1 = vec4(x.z, x.w, y.z, y.w);

    vec4 s0 = floor(b0) * 2.0 + 1.0;
    vec4 s1 = floor(b1) * 2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));

    vec4 a0 = vec4(
        b0.x,
        b0.z,
        b0.y,
        b0.w
    ) + vec4(
        s0.x,
        s0.z,
        s0.y,
        s0.w
    ) * vec4(
        sh.x,
        sh.x,
        sh.y,
        sh.y
    );
    vec4 a1 = vec4(
        b1.x,
        b1.z,
        b1.y,
        b1.w
    ) + vec4(
        s1.x,
        s1.z,
        s1.y,
        s1.w
    ) * vec4(
        sh.z,
        sh.z,
        sh.w,
        sh.w
    );

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
        m0sq * m0sq * dot(g0n, x0) +
        m1sq * m1sq * dot(g1n, x1) +
        m2sq * m2sq * dot(g2n, x2) +
        m3sq * m3sq * dot(g3n, x3)
    );
}

float sample_atlas(uint mask_type, uint glyph_index, uint row, uint column) {
    if (mask_type == 0u) {
        return get_bank_ocr(int(min(glyph_index, 9u)), int(min(row, 7u)), int(min(column, 6u)));
    } else if (mask_type == 1u) {
        return get_hex_atlas(int(min(glyph_index, 15u)), int(min(row, 5u)), int(min(column, 5u)));
    } else {
        return get_num_atlas(int(min(glyph_index, 9u)), int(min(row, 5u)), int(min(column, 5u)));
    }
}

uint compute_seed(uint width_u, uint height_u) {
    uint seed = (width_u * 0x9e3779b9u) ^ (height_u * 0x7f4a7c15u);
    seed = seed ^ 0x632be59bu;
    return seed;
}

float glyph_noise_value(
    uint base_seed,
    uint mask_choice,
    int glyph_x,
    int glyph_y,
    float time_value,
    float speed_value
) {
    uint noise_seed = random_u32(base_seed, 13u);
    vec3 seed_offset = vec3(
        float((noise_seed >> 16u) & 0xFFFFu) * 0.1,
        float(noise_seed & 0xFFFFu) * 0.1,
        float((noise_seed >> 8u) & 0xFFu) * 0.1
    );
    
    float angle = TAU * time_value;
    float z_coord = cos(angle) * speed_value;
    
    vec3 sample_pos = vec3(
        float(glyph_x),
        float(glyph_y),
        z_coord
    ) + seed_offset;
    
    float noise_value = simplex_noise(sample_pos) * 0.5 + 0.5;
    
    return clamp(noise_value, 0.0, 1.0);
}

float overlay_value_at(
    ivec2 coord,
    ivec2 dims,
    uint base_seed,
    float time_value,
    float speed_value
) {
    int base_segment = int(floor(float(dims.x) / 24.0));
    if (base_segment <= 0) {
        return 0.0;
    }

    uint mask_choice = random_u32(base_seed, 11u) % 3u;
    int mask_width = 6;
    int mask_height = 6;
    uint atlas_length = 10u;
    if (mask_choice == 0u) {
        mask_width = 7;
        mask_height = 8;
        atlas_length = 10u;
    } else if (mask_choice == 1u) {
        mask_width = 6;
        mask_height = 6;
        atlas_length = 16u;
    }

    if (base_segment < mask_width) {
        return 0.0;
    }

    int scale = max(base_segment / mask_width, 1);
    int glyph_height = mask_height * scale;
    int glyph_width = mask_width * scale;
    int glyph_count = random_range(base_seed, 23u, 3, 6);
    if (glyph_count <= 0) {
        return 0.0;
    }

    int overlay_width = glyph_width * glyph_count;
    int overlay_height = glyph_height;
    if (overlay_width <= 0 || overlay_height <= 0) {
        return 0.0;
    }

    int origin_x = dims.x - overlay_width - 25;
    if (origin_x < 0) {
        origin_x = 0;
    }
    int origin_y = dims.y - overlay_height - 25;
    if (origin_y < 0) {
        origin_y = 0;
    }

    if (coord.x < origin_x || coord.x >= origin_x + overlay_width) {
        return 0.0;
    }
    if (coord.y < origin_y || coord.y >= origin_y + overlay_height) {
        return 0.0;
    }

    int local_x = coord.x - origin_x;
    int local_y = coord.y - origin_y;

    int stride = glyph_width;
    if (stride <= 0) {
        return 0.0;
    }

    int glyph_x = local_x / glyph_width;
    int glyph_y = local_y / glyph_height;
    
    if (glyph_x < 0 || glyph_x >= glyph_count || glyph_y < 0 || glyph_y >= 1) {
        return 0.0;
    }

    float glyph_noise = glyph_noise_value(base_seed, mask_choice, glyph_x, glyph_y, time_value, speed_value);
    uint glyph_index = min(uint(floor(glyph_noise * float(atlas_length))), atlas_length - 1u);

    int inner_x = (local_x % glyph_width) / scale;
    int inner_y_raw = (local_y % glyph_height) / scale;
    int inner_y = (mask_height - 1) - inner_y_raw;
    
    int clamped_inner_x = clamp(inner_x, 0, mask_width - 1);
    int clamped_inner_y = clamp(inner_y, 0, mask_height - 1);

    return sample_atlas(mask_choice, glyph_index, uint(clamped_inner_y), uint(clamped_inner_x));
}

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width_u = uint(resolution.x);
    uint height_u = uint(resolution.y);
    ivec2 textureDims = textureSize(inputTex, 0);
    if (width_u == 0u) {
        width_u = uint(max(textureDims.x, 1));
    }
    if (height_u == 0u) {
        height_u = uint(max(textureDims.y, 1));
    }
    if (global_id.x >= width_u || global_id.y >= height_u) {
        return;
    }

    ivec2 coord = ivec2(int(global_id.x), int(global_id.y));
    ivec2 dims = ivec2(int(width_u), int(height_u));
    uint base_seed = compute_seed(width_u, height_u);
    float overlay_value = clamp01(overlay_value_at(coord, dims, base_seed, time, speed));
    float alpha_val = mix(0.5, 0.75, clamp01(random_float(base_seed, 7u)));

    vec4 texSample = texelFetch(inputTex, coord, 0);

    float base_r = clamp01(texSample.x);
    float base_g = clamp01(texSample.y);
    float base_b = clamp01(texSample.z);
    float base_a = clamp01(texSample.w);

    float highlight_r = max(base_r, overlay_value);
    float highlight_g = max(base_g, overlay_value);
    float highlight_b = max(base_b, overlay_value);

    float final_r = clamp01(mix(base_r, highlight_r, alpha_val));
    float final_g = clamp01(mix(base_g, highlight_g, alpha_val));
    float final_b = clamp01(mix(base_b, highlight_b, alpha_val));

    fragColor = vec4(final_r, final_g, final_b, base_a);
}
