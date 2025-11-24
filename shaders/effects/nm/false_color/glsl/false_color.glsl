#version 300 es
precision highp float;
precision highp int;

const uint CHANNEL_COUNT = 4u;
const float TAU = 6.283185307179586;
const float F32_MAX = 3.402823466e+38;
const float F32_MIN = -3.402823466e+38;

uniform sampler2D input_texture;
uniform float width;
uniform float height;
uniform float channels;
uniform float horizontal;
uniform float displacement;
uniform float time;
uniform float speed;

out vec4 fragColor;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

uint sanitized_channel_count(float channel_value) {
    int rounded = int(round(channel_value));
    if (rounded <= 1) { return 1u; }
    if (rounded >= 4) { return 4u; }
    return uint(rounded);
}

int wrap_coord(int value, int extent) {
    if (extent <= 0) { return 0; }
    int wrapped = value % extent;
    if (wrapped < 0) { wrapped = wrapped + extent; }
    return wrapped;
}

float srgb_to_linear(float value) {
    if (value <= 0.04045) { return value / 12.92; }
    return pow((value + 0.055) / 1.055, 2.4);
}

float cbrt(float value) {
    if (value == 0.0) { return 0.0; }
    float sign_value = (value >= 0.0) ? 1.0 : -1.0;
    return sign_value * pow(abs(value), 1.0 / 3.0);
}

float oklab_l_component(vec3 rgb) {
    float r = srgb_to_linear(clamp01(rgb.x));
    float g = srgb_to_linear(clamp01(rgb.y));
    float b = srgb_to_linear(clamp01(rgb.z));

    float l = 0.4121656120 * r + 0.5362752080 * g + 0.0514575653 * b;
    float m = 0.2118591070 * r + 0.6807189584 * g + 0.1074065790 * b;
    float s = 0.0883097947 * r + 0.2818474174 * g + 0.6302613616 * b;

    float l_c = cbrt(l);
    float m_c = cbrt(m);
    float s_c = cbrt(s);

    return clamp01(0.2104542553 * l_c + 0.7936177850 * m_c - 0.0040720468 * s_c);
}

float value_map_component(vec4 texel, uint channel_count) {
    if (channel_count <= 2u) { return clamp01(texel.x); }
    return oklab_l_component(vec3(texel.x, texel.y, texel.z));
}

vec2 freq_for_shape(float base_freq, vec2 dims) {
    float w = max(dims.x, 1.0);
    float h = max(dims.y, 1.0);
    if (h == w) { return vec2(base_freq, base_freq); }
    if (h < w) {
        float freq_y = base_freq;
        float freq_x = max(1.0, floor(base_freq * w / h));
        return vec2(freq_x, freq_y);
    }
    float freq_x = base_freq;
    float freq_y = max(1.0, floor(base_freq * h / w));
    return vec2(freq_x, freq_y);
}

vec3 mod289_vec3(vec3 value) {
    return value - floor(value * (1.0 / 289.0)) * 289.0;
}

vec4 mod289_vec4(vec4 value) {
    return value - floor(value * (1.0 / 289.0)) * 289.0;
}

vec4 permute4(vec4 value) {
    return mod289_vec4(((value * 34.0) + 1.0) * value);
}

vec4 taylor_inv_sqrt4(vec4 value) {
    return 1.79284291400159 - 0.85373472095314 * value;
}

float simplex_noise(vec3 coord) {
    vec2 c = vec2(1.0 / 6.0, 1.0 / 3.0);
    vec4 d = vec4(0.0, 0.5, 1.0, 2.0);

    vec3 i0 = floor(coord + dot(coord, vec3(c.y)));
    vec3 x0 = coord - i0 + dot(i0, vec3(c.x));

    vec3 step1 = step(vec3(x0.y, x0.z, x0.x), x0);
    vec3 l = vec3(1.0) - step1;
    vec3 i1 = min(step1, vec3(l.z, l.x, l.y));
    vec3 i2 = max(step1, vec3(l.z, l.x, l.y));

    vec3 x1 = x0 - i1 + vec3(c.x);
    vec3 x2 = x0 - i2 + vec3(c.y);
    vec3 x3 = x0 - vec3(d.y);

    vec3 i = mod289_vec3(i0);
    vec4 p = permute4(permute4(permute4(
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

    vec4 norm = taylor_inv_sqrt4(vec4(
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
        m0sq * m0sq * dot(g0n, x0)
        + m1sq * m1sq * dot(g1n, x1)
        + m2sq * m2sq * dot(g2n, x2)
        + m3sq * m3sq * dot(g3n, x3)
    );
}

float normalized_sine(float value) {
    return (sin(value) + 1.0) * 0.5;
}

float periodic_value(float time_value, float sample_value) {
    return normalized_sine((time_value - sample_value) * TAU);
}

const vec3 SIMPLEX_OFFSETS[4] = vec3[4](
    vec3(37.0, 17.0, 53.0),
    vec3(71.0, 29.0, 97.0),
    vec3(113.0, 47.0, 151.0),
    vec3(157.0, 67.0, 211.0)
);

const vec3 TIME_SIMPLEX_OFFSETS[4] = vec3[4](
    vec3(193.0, 131.0, 271.0),
    vec3(233.0, 163.0, 313.0),
    vec3(271.0, 197.0, 353.0),
    vec3(313.0, 229.0, 397.0)
);

float sample_simplex(vec3 coord) {
    return simplex_noise(coord) * 0.5 + 0.5;
}

vec4 generate_clut_color(
    ivec2 coord,
    vec2 freq,
    vec2 dims,
    float time_value,
    float speed_value
) {
    float w = max(dims.x, 1.0);
    float h = max(dims.y, 1.0);
    vec2 uv = (vec2(coord) + vec2(0.5)) / vec2(w, h);
    vec2 scaled = uv * freq;

    float angle = time_value * TAU;
    float z_base = cos(angle) * speed_value;
    vec3 base = vec3(scaled, z_base);
    vec3 time_base = vec3(scaled, 1.0);
    bool animate = (speed_value != 0.0) && (time_value != 0.0);

    float base_noise[4];
    float time_noise[4];

    for (int i = 0; i < 4; i++) {
        vec3 offset = SIMPLEX_OFFSETS[i];
        base_noise[i] = clamp01(sample_simplex(base + offset));

        if (animate) {
            vec3 time_offset = TIME_SIMPLEX_OFFSETS[i];
            time_noise[i] = clamp01(sample_simplex(time_base + time_offset));
        }
    }

    vec4 values;
    for (int i = 0; i < 4; i++) {
        float value = base_noise[i];
        if (animate) {
            float scaled_time = periodic_value(time_value, time_noise[i]) * speed_value;
            value = periodic_value(scaled_time, value);
        }
        if (i == 0) values.x = clamp01(value);
        if (i == 1) values.y = clamp01(value);
        if (i == 2) values.z = clamp01(value);
        if (i == 3) values.w = clamp01(value);
    }

    return vec4(values.xyz, 1.0);
}

void main() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    
    uint w = as_u32(width);
    uint h = as_u32(height);
    
    if (w == 0u) w = uint(textureSize(input_texture, 0).x);
    if (h == 0u) h = uint(textureSize(input_texture, 0).y);
    
    uint channel_count = sanitized_channel_count(channels);
    bool is_horizontal = horizontal >= 0.5;
    
    vec2 lutDims = vec2(float(w), float(h));
    vec2 freq = freq_for_shape(2.0, lutDims);
    
    vec2 dims = vec2(textureSize(input_texture, 0));
    vec2 uv = (gl_FragCoord.xy - 0.5) / dims;
    vec4 texel = texture(input_texture, uv);
    float reference_raw = value_map_component(texel, channel_count);
    float normalized = clamp01(reference_raw);
    float ref_val = normalized * displacement;
    
    int max_x_offset = int(max(lutDims.x - 1.0, 0.0));
    int max_y_offset = int(max(lutDims.y - 1.0, 0.0));
    
    int offset_x = int(ref_val * float(max_x_offset));
    int sample_x = wrap_coord(coord.x + offset_x, int(w));
    
    int sample_y = coord.y;
    if (!is_horizontal) {
        int offset_y = int(ref_val * float(max_y_offset));
        sample_y = wrap_coord(coord.y + offset_y, int(h));
    }
    
    fragColor = generate_clut_color(ivec2(sample_x, sample_y), freq, lutDims, time, speed);
    fragColor.a = 1.0;
}
