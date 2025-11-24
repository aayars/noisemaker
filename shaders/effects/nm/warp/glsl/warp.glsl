#version 300 es

precision highp float;
precision highp int;

// Warp effect: multi-octave displacement using simplex noise or a supplied warp map.
// Mirrors noisemaker.effects.warp, emitting offsets that refract the input texture.

const float PI = 3.14159265358979323846;
const float TAU = 6.28318530717958647692;


uniform sampler2D input_texture;
uniform vec4 dims_freq;
uniform vec4 octave_disp_spline_map;
uniform vec4 signed_time_speed_pad;

uint as_u32(float value) {
    return uint(max(value, 0.0));
}

float clamp_01(float value) {
    return clamp(value, 0.0, 1.0);
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
    if (limit <= 0.0) {
        return 0.0;
    }
    float result = value - floor(value / limit) * limit;
    if (result < 0.0) {
        result = result + limit;
    }
    return result;
}

float srgb_to_linear(float value) {
    if (value <= 0.04045) {
        return value / 12.92;
    }
    return pow((value + 0.055) / 1.055, 2.4);
}

float cube_root(float value) {
    if (value == 0.0) {
        return 0.0;
    }
    float sign_value = select(-1.0, 1.0, value >= 0.0);
    return sign_value * pow(abs(value), 1.0 / 3.0);
}

float oklab_l_component(vec3 rgb) {
    float r = srgb_to_linear(clamp_01(rgb.x));
    float g = srgb_to_linear(clamp_01(rgb.y));
    float b = srgb_to_linear(clamp_01(rgb.z));

    float l = 0.4121656120 * r + 0.5362752080 * g + 0.0514575653 * b;
    float m = 0.2118591070 * r + 0.6807189584 * g + 0.1074065790 * b;
    float s = 0.0883097947 * r + 0.2818474174 * g + 0.6302613616 * b;

    float l_c = cube_root(l);
    float m_c = cube_root(m);
    float s_c = cube_root(s);

    return clamp_01(0.2104542553 * l_c + 0.7936177850 * m_c - 0.0040720468 * s_c);
}

float value_map_from_texel(vec4 texel, uint channel_count) {
    if (channel_count <= 2u) {
        return clamp_01(texel.x);
    }
    return oklab_l_component(vec3(texel.x, texel.y, texel.z));
}

vec2 freq_for_shape(float base_freq, float width, float height) {
    if (base_freq <= 0.0) {
        return vec2(1.0, 1.0);
    }
    if (abs(width - height) < 1e-5) {
        return vec2(base_freq, base_freq);
    }
    if (height < width && height > 0.0) {
        return vec2(base_freq, base_freq * width / height);
    }
    if (width > 0.0) {
        return vec2(base_freq * height / width, base_freq);
    }
    return vec2(base_freq, base_freq);
}

float normalized_sine(float value) {
    return sin(value) * 0.5 + 0.5;
}

float periodic_value(float time, float value) {
    return normalized_sine((time - value) * TAU);
}

vec3 mod_289_vec3(vec3 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod_289_vec4(vec4 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 permute(vec4 x) {
    return mod_289_vec4(((x * 34.0) + 1.0) * x);
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

    vec3 i = mod_289_vec3(i0);
    p = permute(permute(permute(
        i.z + vec4(0.0, i1.z, i2.z, 1.0))
        + i.y + vec4(0.0, i1.y, i2.y, 1.0))
        + i.x + vec4(0.0, i1.x, i2.x, 1.0));

    float n_ = 0.14285714285714285;
    vec3 ns = n_ * vec3(d.w, d.y, d.z) - vec3(d.x, d.z, d.x);

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


float simplex_value(
    uvec2 coord,
    float width,
    float height,
    vec2 freq,
    float time,
    float speed,
    vec3 base_seed,
    vec3 time_seed
) {
    float width_safe = max(width, 1.0);
    float height_safe = max(height, 1.0);
    vec2 sample = vec2(
        (float(coord.x) / width_safe) * max(freq.x, 1.0),
        (float(coord.y) / height_safe) * max(freq.y, 1.0)
    );

    float angle = time * TAU;
    float z_base = cos(angle) * speed;
    float base_noise = simplex_noise(vec3(
        sample.x + base_seed.x,
        sample.y + base_seed.y,
        z_base + base_seed.z
    ));
    float value = clamp(base_noise * 0.5 + 0.5, 0.0, 1.0);

    if (speed != 0.0 && time != 0.0) {
        float time_noise = simplex_noise(vec3(
            sample.x + time_seed.x,
            sample.y + time_seed.y,
            time_seed.z
        ));
        float time_value = clamp(time_noise * 0.5 + 0.5, 0.0, 1.0);
        float scaled_time = periodic_value(time, time_value) * speed;
        value = clamp_01(periodic_value(scaled_time, value));
    }

    return clamp_01(value);
}

vec2 compute_warp_reference(
    uvec2 coord,
    float width,
    float height,
    vec2 freq,
    float time,
    float speed,
    bool warp_map_enabled,
    uint channel_count
) {
    if (warp_map_enabled) {
        vec4 texel = texelFetch(
            input_texture,
            ivec2(int(coord.x), int(coord.y)),
            0
        );
        float map_value = value_map_from_texel(texel, channel_count);
        float angle = map_value * TAU;
        float ref_x = clamp_01(cos(angle) * 0.5 + 0.5);
        float ref_y = clamp_01(sin(angle) * 0.5 + 0.5);
        return vec2(ref_x, ref_y);
    }

    vec3 base_seed_x = vec3(17.0, 29.0, 47.0);
    vec3 time_seed_x = vec3(71.0, 113.0, 191.0);
    vec3 base_seed_y = vec3(23.0, 31.0, 53.0);
    vec3 time_seed_y = vec3(79.0, 131.0, 197.0);

    float ref_x = simplex_value(
        coord,
        width,
        height,
        freq,
        time,
        speed,
        base_seed_x,
        time_seed_x
    );
    float ref_y = simplex_value(
        coord,
        width,
        height,
        freq,
        time,
        speed,
        base_seed_y,
        time_seed_y
    );
    return vec2(ref_x, ref_y);
}

vec2 displacement_offset(
    vec2 reference,
    bool signed_range,
    float displacement,
    float width,
    float height
) {
    vec2 ref_vec = vec2(clamp_01(reference.x), clamp_01(reference.y));
    if (signed_range) {
        ref_vec = ref_vec * 2.0 - vec2(1.0, 1.0);
    }

    vec2 offset = vec2(ref_vec.x * displacement * width, ref_vec.y * displacement * height);
    if (!signed_range) {
        offset = offset * 2.0;
    }
    return offset;
}

float apply_spline(float value, int order) {
    float clamped = clamp(value, 0.0, 1.0);
    if (order == 2) {
        return 0.5 - cos(clamped * PI) * 0.5;
    }
    return clamped;
}

vec4 cubic_interpolate(
    vec4 a,
    vec4 b,
    vec4 c,
    vec4 d,
    float t
) {
    float t2 = t * t;
    float t3 = t2 * t;
    vec4 a0 = d - c - a + b;
    vec4 a1 = a - b - a0;
    vec4 a2 = c - a;
    vec4 a3 = b;
    return a0 * t3 + a1 * t2 + a2 * t + a3;
}

vec4 sample_nearest(vec2 coord, int width, int height) {
    int x = wrap_coord(int(round(coord.x)), width);
    int y = wrap_coord(int(round(coord.y)), height);
    return texelFetch(input_texture, ivec2(x, y), 0);
}

vec4 sample_bilinear(vec2 coord, int width, int height, int order) {
    int x0 = int(floor(coord.x));
    int y0 = int(floor(coord.y));

    if (x0 < 0) {
        x0 = 0;
    } else if (x0 >= width) {
        x0 = width - 1;
    }

    if (y0 < 0) {
        y0 = 0;
    } else if (y0 >= height) {
        y0 = height - 1;
    }

    int x1 = wrap_coord(x0 + 1, width);
    int y1 = wrap_coord(y0 + 1, height);

    float fx = clamp(coord.x - float(x0), 0.0, 1.0);
    float fy = clamp(coord.y - float(y0), 0.0, 1.0);

    float tx = apply_spline(fx, order);
    float ty = apply_spline(fy, order);

    vec4 tex00 = textureLoad(input_texture, vec2(x0, y0), 0);
    vec4 tex10 = textureLoad(input_texture, vec2(x1, y0), 0);
    vec4 tex01 = textureLoad(input_texture, vec2(x0, y1), 0);
    vec4 tex11 = textureLoad(input_texture, vec2(x1, y1), 0);

    vec4 mix_x0 = mix(tex00, tex10, vec4(tx));
    vec4 mix_x1 = mix(tex01, tex11, vec4(tx));
    return mix(mix_x0, mix_x1, vec4(ty));
}

vec4 sample_bicubic(vec2 coord, int width, int height) {
    int base_x = int(floor(coord.x));
    int base_y = int(floor(coord.y));

    vec4 columns[4];
    int m = -1;
    loop {
        if (m >= 3) {
            break;
        }
        vec4 row[4];
        int n = -1;
        loop {
            if (n >= 3) {
                break;
            }
            int sx = wrap_coord(base_x + n, width);
            int sy = wrap_coord(base_y + m, height);
            row[n + 1] = textureLoad(input_texture, vec2(sx, sy), 0);
            n = n + 1;
        }
        columns[m + 1] = cubic_interpolate(
            row[0],
            row[1],
            row[2],
            row[3],
            clamp(coord.x - floor(coord.x), 0.0, 1.0)
        );
        m = m + 1;
    }

    float frac_y = clamp(coord.y - floor(coord.y), 0.0, 1.0);
    return cubic_interpolate(columns[0], columns[1], columns[2], columns[3], frac_y);
}

vec4 sample_with_order(vec2 coord, uint width, uint height, int order) {
    float width_f = float(width);
    float height_f = float(height);
    vec2 wrapped = vec2(
        wrap_float(coord.x, width_f),
        wrap_float(coord.y, height_f)
    );
    int width_i = int(width);
    int height_i = int(height);

    if (order <= 0) {
        return sample_nearest(wrapped, width_i, height_i);
    }
    if (order >= 3) {
        return sample_bicubic(wrapped, width_i, height_i);
    }
    return sample_bilinear(wrapped, width_i, height_i, order);
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = as_u32(dims_freq.x);
    uint height = as_u32(dims_freq.y);
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    float width_f = max(dims_freq.x, 1.0);
    float height_f = max(dims_freq.y, 1.0);
    uint channel_count = max(as_u32(dims_freq.z), 1u);
    float freq_param = dims_freq.w;

    int octave_count = max(int(round(octave_disp_spline_map.x)), 0);
    float displacement_base = octave_disp_spline_map.y;
    int spline_order = int(round(octave_disp_spline_map.z));
    bool warp_map_enabled = octave_disp_spline_map.w > 0.5;

    bool signed_range = signed_time_speed_pad.x > 0.5;
    float time = signed_time_speed_pad.y;
    float speed = signed_time_speed_pad.z;

    vec2 freq_shape = freq_for_shape(freq_param, width_f, height_f);

    vec2 sample_coord = vec2(float(global_id.x), float(global_id.y));

    if (octave_count > 0 && displacement_base != 0.0) {
        vec2 base_coord = global_id.xy;
        int octave = 1;
        loop {
            if (octave > octave_count) {
                break;
            }

            float multiplier = pow(2.0, float(octave));
            vec2 freq_scaled = freq_shape * 0.5 * multiplier;
            vec2 freq_floored = vec2(
                max(floor(freq_scaled.x), 1.0),
                max(floor(freq_scaled.y), 1.0)
            );

            if (freq_floored.x >= width_f || freq_floored.y >= height_f) {
                break;
            }

            vec2 reference = compute_warp_reference(
                base_coord,
                width_f,
                height_f,
                freq_floored,
                time,
                speed,
                warp_map_enabled,
                channel_count
            );
            float displacement_scale = displacement_base / multiplier;
            vec2 offsets = displacement_offset(
                reference,
                signed_range,
                displacement_scale,
                width_f,
                height_f
            );

            sample_coord = sample_coord + offsets;
            sample_coord = vec2(
                wrap_float(sample_coord.x, width_f),
                wrap_float(sample_coord.y, height_f)
            );

            octave = octave + 1;
        }
    }

    vec4 sampled = sample_with_order(sample_coord, width, height, spline_order);

    uint channel = 0u;
    loop {
        if (channel >= channel_count) {
            break;
        }
        float component = sampled[min(channel, 3u)];
        channel = channel + 1u;
    }
}