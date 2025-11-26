#version 300 es
precision highp float;
precision highp int;

// Refract: displacement driven by luminance-derived offsets, matching value.refract().

const float PI = 3.14159265358979323846;
const float TAU = 6.28318530717958647692;
const float FLOAT_EPSILON = 1e-5;

uniform sampler2D inputTex;
uniform float displacement;
uniform float warp;
uniform int splineOrder;
uniform bool derivative;
uniform float range;
uniform float speed;
uniform float time;

out vec4 fragColor;

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

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

float wrap_float(float value, float limit) {
    if (limit <= 0.0) {
        return 0.0;
    }
    float wrapped = mod(value, limit);
    if (wrapped < 0.0) {
        wrapped += limit;
    }
    return wrapped;
}

float srgb_to_linear(float value) {
    if (value <= 0.04045) {
        return value / 12.92;
    }
    return pow((value + 0.055) / 1.055, 2.4);
}

float cube_root(float value) {
    if (abs(value) < 1e-8) {
        return 0.0;
    }
    float sign_value = value >= 0.0 ? 1.0 : -1.0;
    return sign_value * pow(abs(value), 1.0 / 3.0);
}

float oklab_l_component(vec3 rgb) {
    float r_lin = srgb_to_linear(clamp01(rgb.x));
    float g_lin = srgb_to_linear(clamp01(rgb.y));
    float b_lin = srgb_to_linear(clamp01(rgb.z));

    float l = 0.4121656120 * r_lin + 0.5362752080 * g_lin + 0.0514575653 * b_lin;
    float m = 0.2118591070 * r_lin + 0.6807189584 * g_lin + 0.1074065790 * b_lin;
    float s = 0.0883097947 * r_lin + 0.2818474174 * g_lin + 0.6302613616 * b_lin;

    float l_c = cube_root(l);
    float m_c = cube_root(m);
    float s_c = cube_root(s);

    return clamp01(0.2104542553 * l_c + 0.7936177850 * m_c - 0.0040720468 * s_c);
}

float value_map(vec4 texel, bool signed_range) {
    float value = oklab_l_component(texel.xyz);
    if (signed_range) {
        value = value * 2.0 - 1.0;
    }
    return value;
}
vec2 freq_for_shape(float base_freq, float width, float height) {
    if (base_freq <= FLOAT_EPSILON) {
        return vec2(0.0);
    }
    if (abs(width - height) < FLOAT_EPSILON) {
        return vec2(base_freq);
    }
    if (height < width && height > 0.0) {
        return vec2(base_freq, base_freq * width / height);
    }
    if (width > 0.0) {
        return vec2(base_freq * height / width, base_freq);
    }
    return vec2(base_freq);
}

vec3 mod289_vec3(vec3 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod289_vec4(vec4 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute_vec4(vec4 x) {
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
    vec4 p = permute_vec4(
        permute_vec4(
            permute_vec4(i.z + vec4(0.0, i1.z, i2.z, 1.0))
            + i.y + vec4(0.0, i1.y, i2.y, 1.0)
        )
        + i.x + vec4(0.0, i1.x, i2.x, 1.0)
    );

    float n_ = 0.14285714285714285;
    vec3 ns = n_ * vec3(D.w, D.y, D.z) - vec3(D.x, D.z, D.x);

    vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
    vec4 x_ = floor(j * ns.z);
    vec4 y_ = floor(j - 7.0 * x_);

    vec4 x = x_ * ns.x + ns.y;
    vec4 y = y_ * ns.x + ns.y;
    vec4 h = 1.0 - abs(x) - abs(y);

    vec4 b0 = vec4(x.xy, y.xy);
    vec4 b1 = vec4(x.zw, y.zw);

    vec4 s0 = floor(b0) * 2.0 + 1.0;
    vec4 s1 = floor(b1) * 2.0 + 1.0;
    vec4 sh = -step(h, vec4(0.0));

    vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

    vec3 g0 = vec3(a0.xy, h.x);
    vec3 g1 = vec3(a0.zw, h.y);
    vec3 g2 = vec3(a1.xy, h.z);
    vec3 g3 = vec3(a1.zw, h.w);

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

    float m0_4 = pow(m0, 4.0);
    float m1_4 = pow(m1, 4.0);
    float m2_4 = pow(m2, 4.0);
    float m3_4 = pow(m3, 4.0);

    return 42.0 * (
        m0_4 * dot(g0n, x0) +
        m1_4 * dot(g1n, x1) +
        m2_4 * dot(g2n, x2) +
        m3_4 * dot(g3n, x3)
    );
}

float remap_by_spline(float value, int order) {
    float clamped = clamp(value, 0.0, 1.0);
    switch (order) {
        case 0:
            return clamped >= 0.5 ? 1.0 : 0.0;
        case 2:
            return 0.5 - cos(clamped * PI) * 0.5;
        case 3:
            return clamped * clamped * (3.0 - 2.0 * clamped);
        default:
            return clamped;
    }
}

float generate_warp_value(uvec2 coord, vec2 size, vec2 freq, float time_value, float speed_value, int order, float seed_offset) {
    vec2 safe_size = max(size, vec2(1.0));
    vec2 uv = (vec2(coord) + vec2(0.5)) / safe_size;
    vec2 freq_vec = max(freq, vec2(1.0));
    vec3 offset = vec3(seed_offset, seed_offset * 1.37, seed_offset * 2.11);
    vec3 noise_input = vec3(uv * freq_vec, time_value * speed_value) + offset;
    float noise_sample = simplex_noise(noise_input);
    float normalized = clamp(noise_sample * 0.5 + 0.5, 0.0, 1.0);
    return remap_by_spline(normalized, order);
}

vec4 texel_fetch_safe(sampler2D tex, ivec2 coord, ivec2 dims) {
    ivec2 wrapped = ivec2(wrap_coord(coord.x, dims.x), wrap_coord(coord.y, dims.y));
    return texelFetch(tex, wrapped, 0);
}

void main() {
    ivec2 texDims = textureSize(inputTex, 0);
    uint width_u = uint(max(texDims.x, 1));
    uint height_u = uint(max(texDims.y, 1));

    uvec2 gid = uvec2(gl_FragCoord.xy);
    if (gid.x >= width_u || gid.y >= height_u) {
        fragColor = vec4(0.0);
        return;
    }

    float displacement_value = max(displacement, 0.0);
    float range_scale = max(range, 0.0);
    float width_f = float(width_u);
    float height_f = float(height_u);

    float base_scale_x = displacement_value * range_scale * width_f;
    float base_scale_y = displacement_value * range_scale * height_f;

    vec2 normalized_coords = (vec2(gid) + vec2(0.5)) / vec2(texDims);
    vec4 source_texel = texture(inputTex, normalized_coords);

    if (base_scale_x <= FLOAT_EPSILON && base_scale_y <= FLOAT_EPSILON) {
        fragColor = source_texel;
        return;
    }

    float warp_scalar = max(warp, 0.0);
    int splineOrderClamped = clamp(splineOrder, 0, 3);
    bool use_derivative = derivative;
    bool quad_directional = !use_derivative;

    float ref_value_x;
    float ref_value_y;

    ivec2 dims_i = texDims;
    ivec2 base_coord = ivec2(gid);

    if (use_derivative) {
        vec4 center = texelFetch(inputTex, base_coord, 0);
        vec4 right = texel_fetch_safe(inputTex, base_coord + ivec2(1, 0), dims_i);
        vec4 down = texel_fetch_safe(inputTex, base_coord + ivec2(0, 1), dims_i);

        vec4 deriv_x_texel = center - right;
        vec4 deriv_y_texel = center - down;

        ref_value_x = value_map(deriv_x_texel, false);
        ref_value_y = value_map(deriv_y_texel, false);
    } else if (warp_scalar > FLOAT_EPSILON) {
        vec2 freq_vec = freq_for_shape(warp_scalar, width_f, height_f);
        vec2 size_vec = vec2(width_f, height_f);
        float warp_x = generate_warp_value(gid, size_vec, freq_vec, time, speed, splineOrderClamped, 0.0);
        float warp_y = generate_warp_value(gid, size_vec, freq_vec, time, speed, splineOrderClamped, 37.0);
        ref_value_x = warp_x * 2.0 - 1.0;
        ref_value_y = warp_y * 2.0 - 1.0;
    } else {
        vec4 ref_x = source_texel;
        vec4 ref_y = source_texel;

        vec4 angle_x = ref_x * TAU;
        vec4 angle_y = ref_y * TAU;
        ref_x = clamp(cos(angle_x) * 0.5 + 0.5, vec4(0.0), vec4(1.0));
        ref_y = clamp(sin(angle_y) * 0.5 + 0.5, vec4(0.0), vec4(1.0));

        ref_value_x = value_map(ref_x, true);
        ref_value_y = value_map(ref_y, true);
    }

    float scale_x = base_scale_x;
    float scale_y = base_scale_y;
    if (!quad_directional) {
        scale_x *= 2.0;
        scale_y *= 2.0;
    }

    vec2 sample_pos = vec2(gid) + vec2(ref_value_x * scale_x, ref_value_y * scale_y);
    float sample_x = wrap_float(sample_pos.x, width_f);
    float sample_y = wrap_float(sample_pos.y, height_f);

    float fx = fract(sample_x);
    float fy = fract(sample_y);

    int x0 = int(floor(sample_x));
    int y0 = int(floor(sample_y));
    int x1 = wrap_coord(x0 + 1, dims_i.x);
    int y1 = wrap_coord(y0 + 1, dims_i.y);

    vec4 tex00 = texel_fetch_safe(inputTex, ivec2(x0, y0), dims_i);
    vec4 tex10 = texel_fetch_safe(inputTex, ivec2(x1, y0), dims_i);
    vec4 tex01 = texel_fetch_safe(inputTex, ivec2(x0, y1), dims_i);
    vec4 tex11 = texel_fetch_safe(inputTex, ivec2(x1, y1), dims_i);

    vec4 mix_x0 = mix(tex00, tex10, vec4(fx));
    vec4 mix_x1 = mix(tex01, tex11, vec4(fx));
    vec4 result = mix(mix_x0, mix_x1, vec4(fy));

    fragColor = result;
}