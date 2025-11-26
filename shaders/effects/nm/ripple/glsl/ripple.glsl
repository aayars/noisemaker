#version 300 es

precision highp float;
precision highp int;

// Ripple displaces pixels using angular offsets derived from a value map.
// Mirrors the WGSL compute implementation while producing fragment output.

const float PI = 3.14159265358979323846;
const float TAU = 6.28318530717958647692;

const uint INTERPOLATION_CONSTANT = 0u;
const uint INTERPOLATION_LINEAR = 1u;
const uint INTERPOLATION_COSINE = 2u;
const uint INTERPOLATION_BICUBIC = 3u;

uniform sampler2D inputTex;
uniform sampler2D referenceTexture;
uniform float freq;
uniform float displacement;
uniform float kink;
uniform float splineOrder;
uniform float speed;
uniform float time;

out vec4 fragColor;

int wrap_coord(int coord, int limit) {
    if (limit <= 0) {
        return 0;
    }
    int wrapped = coord % limit;
    if (wrapped < 0) {
        wrapped += limit;
    }
    return wrapped;
}

int wrap_index(int coord, int limit) {
    return wrap_coord(coord, limit);
}

float clamp_01(float value) {
    return clamp(value, 0.0, 1.0);
}

vec2 freq_for_shape(float base_freq, float width, float height) {
    float freq_value = max(base_freq, 1.0);
    if (abs(width - height) < 1.0e-5) {
        return vec2(freq_value, freq_value);
    }
    if (height < width && height > 0.0) {
        return vec2(freq_value, freq_value * width / height);
    }
    if (width > 0.0) {
        return vec2(freq_value * height / width, freq_value);
    }
    return vec2(freq_value, freq_value);
}

float srgb_to_linear(float value) {
    if (value <= 0.04045) {
        return value / 12.92;
    }
    return pow((value + 0.055) / 1.055, 2.4);
}

float oklab_l_component(vec3 rgb) {
    float r_lin = srgb_to_linear(rgb.x);
    float g_lin = srgb_to_linear(rgb.y);
    float b_lin = srgb_to_linear(rgb.z);

    float l_val = 0.4121656120 * r_lin + 0.5362752080 * g_lin + 0.0514575653 * b_lin;
    float m_val = 0.2118591070 * r_lin + 0.6807189584 * g_lin + 0.1074065790 * b_lin;
    float s_val = 0.0883097947 * r_lin + 0.2818474174 * g_lin + 0.6302613616 * b_lin;

    float l_cbrt = pow(max(l_val, 0.0), 1.0 / 3.0);
    float m_cbrt = pow(max(m_val, 0.0), 1.0 / 3.0);
    float s_cbrt = pow(max(s_val, 0.0), 1.0 / 3.0);

    return 0.2104542553 * l_cbrt + 0.7936177850 * m_cbrt - 0.0040720468 * s_cbrt;
}

float value_map_component(vec4 texel) {
    float eps = 1.0e-5;
    float diff_xy = abs(texel.x - texel.y);
    float diff_xz = abs(texel.x - texel.z);
    float alpha = clamp_01(texel.w);
    float alpha_multiplier = (alpha < 0.999) ? alpha : 1.0;

    if (diff_xy < eps && diff_xz < eps) {
        return clamp_01(texel.x * alpha_multiplier);
    }

    vec3 rgb = clamp(texel.xyz, vec3(0.0), vec3(1.0));
    float lum = clamp_01(oklab_l_component(rgb));
    return clamp_01(lum * alpha_multiplier);
}

float hash_21(ivec2 p) {
    vec2 pf = vec2(float(p.x), float(p.y));
    float dot_val = dot(pf, vec2(127.1, 311.7));
    return fract(sin(dot_val) * 43758.5453);
}

float cosine_mix(float a, float b, float t) {
    float weight = (1.0 - cos(clamp(t, 0.0, 1.0) * PI)) * 0.5;
    return mix(a, b, weight);
}

float cubic_mix(float a, float b, float c, float d, float t) {
    float clamped = clamp(t, 0.0, 1.0);
    float t2 = clamped * clamped;
    float a0 = (d - c) - (a - b);
    float a1 = (a - b) - a0;
    float a2 = c - a;
    float a3 = b;
    return ((a0 * clamped) * t2) + (a1 * t2) + (a2 * clamped) + a3;
}

float lattice_value(ivec2 coord, ivec2 freq) {
    int wrapped_x = wrap_index(coord.x, max(freq.x, 1));
    int wrapped_y = wrap_index(coord.y, max(freq.y, 1));
    return hash_21(ivec2(wrapped_x, wrapped_y));
}

float sample_value_field(vec2 sample_pos, ivec2 freq, uint splineOrder) {
    int freq_x = max(freq.x, 1);
    int freq_y = max(freq.y, 1);
    vec2 base_floor = floor(sample_pos);
    ivec2 base_coord = ivec2(int(base_floor.x), int(base_floor.y));
    vec2 frac = sample_pos - base_floor;

    int x0 = wrap_index(base_coord.x, freq_x);
    int y0 = wrap_index(base_coord.y, freq_y);

    if (splineOrder == INTERPOLATION_CONSTANT) {
        return lattice_value(ivec2(x0, y0), freq);
    }

    int x1 = wrap_index(x0 + 1, freq_x);
    int y1 = wrap_index(y0 + 1, freq_y);

    float v00 = lattice_value(ivec2(x0, y0), freq);
    float v10 = lattice_value(ivec2(x1, y0), freq);
    float v01 = lattice_value(ivec2(x0, y1), freq);
    float v11 = lattice_value(ivec2(x1, y1), freq);

    if (splineOrder == INTERPOLATION_LINEAR) {
        float xa = mix(v00, v10, frac.x);
        float xb = mix(v01, v11, frac.x);
        return mix(xa, xb, frac.y);
    }

    if (splineOrder == INTERPOLATION_COSINE) {
        float xa = cosine_mix(v00, v10, frac.x);
        float xb = cosine_mix(v01, v11, frac.x);
        return cosine_mix(xa, xb, frac.y);
    }

    float rows[4];
    for (int i = -1; i <= 2; i += 1) {
        int sample_y = wrap_index(y0 + i, freq_y);
        float cols[4];
        for (int j = -1; j <= 2; j += 1) {
            int sample_x = wrap_index(x0 + j, freq_x);
            cols[j + 1] = lattice_value(ivec2(sample_x, sample_y), freq);
        }
        rows[i + 1] = cubic_mix(cols[0], cols[1], cols[2], cols[3], frac.x);
    }

    return cubic_mix(rows[0], rows[1], rows[2], rows[3], frac.y);
}

uint sanitize_splineOrder(float raw_value) {
    int rounded = int(round(raw_value));
    if (rounded <= 0) {
        return INTERPOLATION_CONSTANT;
    }
    if (rounded == 1) {
        return INTERPOLATION_LINEAR;
    }
    if (rounded == 2) {
        return INTERPOLATION_COSINE;
    }
    return INTERPOLATION_BICUBIC;
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
    vec4 p = permute(permute(permute(
        i.z + vec4(0.0, i1.z, i2.z, 1.0))
        + i.y + vec4(0.0, i1.y, i2.y, 1.0))
        + i.x + vec4(0.0, i1.x, i2.x, 1.0));

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

float simplex_random(float time_value, float speed_value) {
    float angle = time_value * TAU;
    float z = cos(angle) * speed_value;
    float w = sin(angle) * speed_value;
    float noise_value = simplex_noise(vec3(z + 17.0, w + 29.0, 11.0));
    return clamp(noise_value * 0.5 + 0.5, 0.0, 1.0);
}

float reference_value(ivec2 coord, ivec2 dims, float freq_param, uint splineOrder_value) {
    if (freq_param > 0.0) {
        vec2 freq_vec = freq_for_shape(freq_param, float(dims.x), float(dims.y));
        ivec2 freq_int = ivec2(
            max(int(round(freq_vec.x)), 1),
            max(int(round(freq_vec.y)), 1)
        );

        vec2 uv = vec2(float(coord.x), float(coord.y));
        vec2 scale = vec2(max(float(dims.x), 1.0), max(float(dims.y), 1.0));
        vec2 sample_pos = vec2(
            uv.x / scale.x * float(freq_int.x),
            uv.y / scale.y * float(freq_int.y)
        );

        return clamp_01(sample_value_field(sample_pos, freq_int, splineOrder_value));
    }

    ivec2 ref_dims = textureSize(referenceTexture, 0);
    if (ref_dims.x <= 0 || ref_dims.y <= 0) {
        return 0.0;
    }

    int safe_x = wrap_coord(coord.x, ref_dims.x);
    int safe_y = wrap_coord(coord.y, ref_dims.y);
    vec4 texel = texelFetch(referenceTexture, ivec2(safe_x, safe_y), 0);
    return value_map_component(texel);
}

void main() {
    ivec2 dims = textureSize(inputTex, 0);
    if (dims.x <= 0 || dims.y <= 0) {
        fragColor = vec4(0.0);
        return;
    }

    ivec2 gid = ivec2(int(gl_FragCoord.x), int(gl_FragCoord.y));
    if (gid.x < 0 || gid.x >= dims.x || gid.y < 0 || gid.y >= dims.y) {
        fragColor = vec4(0.0);
        return;
    }

    uint spline_value = sanitize_splineOrder(splineOrder);
    float freq_param = freq;

    float ref_value = reference_value(gid, dims, freq_param, spline_value);

    float random_factor = simplex_random(time, speed);
    float index_value = ref_value * TAU * kink * random_factor;

    float width_f = float(dims.x);
    float height_f = float(dims.y);

    float reference_x = cos(index_value) * displacement * width_f;
    float reference_y = sin(index_value) * displacement * height_f;

    reference_x = reference_x - floor(reference_x / width_f) * width_f;
    reference_y = reference_y - floor(reference_y / height_f) * height_f;

    float base_x = floor(reference_x);
    float base_y = floor(reference_y);

    int x0 = wrap_coord(int(base_x) + gid.x, dims.x);
    int y0 = wrap_coord(int(base_y) + gid.y, dims.y);
    int x1 = wrap_coord(x0 + 1, dims.x);
    int y1 = wrap_coord(y0 + 1, dims.y);

    vec4 x0y0 = texelFetch(inputTex, ivec2(x0, y0), 0);
    vec4 x1y0 = texelFetch(inputTex, ivec2(x1, y0), 0);
    vec4 x0y1 = texelFetch(inputTex, ivec2(x0, y1), 0);
    vec4 x1y1 = texelFetch(inputTex, ivec2(x1, y1), 0);

    float frac_x = reference_x - base_x;
    float frac_y = reference_y - base_y;

    vec4 x_y0 = mix(x0y0, x1y0, frac_x);
    vec4 x_y1 = mix(x0y1, x1y1, frac_x);
    vec4 result = mix(x_y0, x_y1, frac_y);

    fragColor = vec4(result.rgb, 1.0);
}
