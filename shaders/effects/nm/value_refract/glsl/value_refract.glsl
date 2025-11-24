#version 300 es

precision highp float;
precision highp int;

// Value Refract: replicates Noisemaker's value_refract effect by generating a value
// distribution map and using it as the refractive driver for the source texture.
const float PI = 3.14159265358979323846;
const float TAU = 6.28318530717958647692;


uniform sampler2D input_texture;
uniform vec4 size_freq;
uniform vec4 displacement_time_speed_distrib;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
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
    if (limit == 0.0) {
        return 0.0;
    }
    float div = floor(value / limit);
    float result = value - div * limit;
    if (result < 0.0) {
        result = result + limit;
    }
    return result;
}

vec2 freq_for_shape(float base_freq, float width, float height) {
    float safe_freq = max(base_freq, 1.0);
    float safe_width = max(width, 1.0);
    float safe_height = max(height, 1.0);

    if (abs(safe_width - safe_height) < 1e-5) {
        return vec2(safe_freq, safe_freq);
    }

    if (safe_height < safe_width) {
        float second = floor(safe_freq * safe_width / safe_height);
        return vec2(safe_freq, max(second, 1.0));
    }

    float first = floor(safe_freq * safe_height / safe_width);
    return vec2(max(first, 1.0), safe_freq);
}

float normalized_sine(float value) {
    return sin(value) * 0.5 + 0.5;
}

float periodic_value(float time, float value) {
    return normalized_sine((time - value) * TAU);
}

float rounded_speed(float speed) {
    if (speed > 0.0) {
        return floor(1.0 + speed);
    }
    return ceil(-1.0 + speed);
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
    p = permute_vec4(
        permute_vec4(permute_vec4(i.z + vec4(0.0, i1.z, i2.z, 1.0)) + i.y
            + vec4(0.0, i1.y, i2.y, 1.0))
        + i.x + vec4(0.0, i1.x, i2.x, 1.0)
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


DistributionInfo distribution_info(int distribution) {
    // Defaults to center circle (euclidean) if unknown.
    int metric = 1;
    float sdf_sides = 0.0;

    switch distribution {
        case 20: { // center_circle
            metric = 1;
        }
        case 21: { // center_diamond
            metric = 2;
        }
        case 23: { // center_triangle
            metric = 101;
        }
        case 24: { // center_square
            metric = 3;
        }
        case 25: { // center_pentagon
            metric = 201;
            sdf_sides = 5.0;
        }
        case 26: { // center_hexagon
            metric = 102;
        }
        case 27: { // center_heptagon
            metric = 201;
            sdf_sides = 7.0;
        }
        case 28: { // center_octagon
            metric = 4;
        }
        case 29: { // center_nonagon
            metric = 201;
            sdf_sides = 9.0;
        }
        case 30: { // center_decagon
            metric = 201;
            sdf_sides = 10.0;
        }
        case 31: { // center_hendecagon
            metric = 201;
            sdf_sides = 11.0;
        }
        case 32: { // center_dodecagon
            metric = 201;
            sdf_sides = 12.0;
        }
        default: {
            // leave defaults
        }
    }

    return DistributionInfo(metric, sdf_sides);
}

float compute_distance(float a, float b, int metric, float sdf_sides) {
    switch metric {
        case 1: { // euclidean
            return sqrt(a * a + b * b);
        }
        case 2: { // manhattan
            return abs(a) + abs(b);
        }
        case 3: { // chebyshev
            return max(abs(a), abs(b));
        }
        case 4: { // octagram
            float combo = (abs(a) + abs(b)) / sqrt(2.0);
            return max(combo, max(abs(a), abs(b)));
        }
        case 101: { // triangular
            return max(abs(a) - b * 0.5, b);
        }
        case 102: { // hexagram
            float pos = max(abs(a) - b * 0.5, b);
            float neg = max(abs(a) - b * -0.5, b * -1.0);
            return max(pos, neg);
        }
        case 201: { // sdf polygon
            if (sdf_sides <= 0.0) {
                return sqrt(a * a + b * b);
            }
            float angle = atan2(a, -b) + PI;
            float r = TAU / sdf_sides;
            float k = floor(0.5 + angle / r);
            float diff = k * r - angle;
            return cos(diff) * sqrt(a * a + b * b);
        }
        default: {
            return sqrt(a * a + b * b);
        }
    }
}

void compute_center_value(fn compute_noise_value(      fn generate_distribution_value(   vec4 sample_texture_bilinear(float x, float y, uint width, uint height) {
    float width_f = float(width);
    float height_f = float(height);

    float wrapped_x = wrap_float(x, width_f);
    float wrapped_y = wrap_float(y, height_f);

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
    return mix(mix_x0, mix_x1, vec4(fy));
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width_u = max(as_u32(size_freq.x), 1u);
    uint height_u = max(as_u32(size_freq.y), 1u);
    if (global_id.x >= width_u || global_id.y >= height_u) {
        return;
    }

    float width_f = size_freq.x;
    float height_f = size_freq.y;
    uint channel_count = max(as_u32(size_freq.z), 1u);
    float freq_param = size_freq.w;

    float displacement = displacement_time_speed_distrib.x;
    float time = displacement_time_speed_distrib.y;
    float speed = displacement_time_speed_distrib.z;
    int distribution_id = int(round(displacement_time_speed_distrib.w));

    vec2 freq_vec = freq_for_shape(freq_param, width_f, height_f);
    float phase_speed = rounded_speed(speed);
    float value_sample = generate_distribution_value(
        global_id.xy,
        width_f,
        height_f,
        freq_vec,
        distribution_id,
        time,
        speed,
        phase_speed
    );

    float angle_value = value_sample * TAU;
    float ref_x = clamp_01(cos(angle_value) * 0.5 + 0.5);
    float ref_y = clamp_01(sin(angle_value) * 0.5 + 0.5);

    float offset_x = (ref_x * 2.0 - 1.0) * displacement * width_f;
    float offset_y = (ref_y * 2.0 - 1.0) * displacement * height_f;

    float sample_x = float(global_id.x) + offset_x;
    float sample_y = float(global_id.y) + offset_y;

    vec4 sampled = sample_texture_bilinear(sample_x, sample_y, width_u, height_u);

    uint base_index = (global_id.y * width_u + global_id.x) * channel_count;
    uint channel = 0u;
    loop {
        if (channel >= channel_count) {
            break;
        }
        float component = sampled[min(channel, 3u)];
        channel = channel + 1u;
    }
}