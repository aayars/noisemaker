#version 300 es
precision highp float;
precision highp int;

const float PI = 3.14159265358979323846;
const float TAU = 6.28318530717958647693;
const float FLOAT_SCALE = 1.0 / 4294967295.0;
const float EPSILON = 1e-4;

const uint PRIMARY_FREQ_SEED = 0x0011u;
const uint SECONDARY_FREQ_SEED = 0x0021u;
const uint ROTATION_SEED = 0x0031u;
const uint HUE_JITTER_SEED_A = 0x00a5u;
const uint HUE_JITTER_SEED_B = 0x00b7u;

uniform sampler2D inputTex;
uniform vec4 size;
uniform vec4 timeSpeed;

layout(location = 0) out vec4 fragColor;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

float saturate(float value) {
    return clamp(value, 0.0, 1.0);
}

float wrap_unit(float value) {
    return value - floor(value);
}

vec2 wrap_coord_unit(vec2 coord) {
    return vec2(wrap_unit(coord.x), wrap_unit(coord.y));
}

vec2 rotate_coord(vec2 coord, float angle) {
    vec2 center = vec2(0.5, 0.5);
    vec2 offset = coord - center;
    float cos_a = cos(angle);
    float sin_a = sin(angle);
    vec2 rotated = vec2(
        offset.x * cos_a - offset.y * sin_a,
        offset.x * sin_a + offset.y * cos_a
    );
    return rotated + center;
}

float ridge_transform(float value) {
    return 1.0 - abs(value * 2.0 - 1.0);
}

uvec3 pcg3d(uvec3 value) {
    uvec3 v = value * 1664525u + 1013904223u;
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v = v ^ (v >> 16u);
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    return v;
}

float seeded_float(uint seed) {
    vec3 hashed = vec3(pcg3d(uvec3(seed, seed ^ 0x9e3779b9u, seed + 0x7f4a7c15u)));
    return hashed.x * FLOAT_SCALE;
}

int seeded_int(uint seed, int min_value, int max_value) {
    int span = max_value - min_value + 1;
    if (span <= 1) {
        return min_value;
    }
    int choice = int(floor(seeded_float(seed) * float(span)));
    return min_value + clamp(choice, 0, span - 1);
}

float random_from_cell(ivec3 cell, uint seed) {
    uvec3 hashed_input = uvec3(
        uint(cell.x) ^ seed,
        uint(cell.y) ^ (seed * 0x9e3779b9u + 0x7f4a7c15u),
        uint(cell.z) ^ (seed * 0x632be59bu + 0x5bf03635u)
    );
    uvec3 noise = pcg3d(hashed_input);
    return float(noise.x) * FLOAT_SCALE;
}

float fade(float t) {
    return t * t * (3.0 - 2.0 * t);
}

float sample_value_noise(vec2 point, uint seed) {
    vec2 cell = floor(point);
    vec2 frac = fract(point);
    uint base_seed = seed ^ (seed >> 17);
    int z_layer = int(base_seed & 1023u);
    float p00 = random_from_cell(ivec3(cell.x, cell.y, z_layer), base_seed);
    float p10 = random_from_cell(ivec3(cell.x + 1.0, cell.y, z_layer), base_seed);
    float p01 = random_from_cell(ivec3(cell.x, cell.y + 1.0, z_layer), base_seed);
    float p11 = random_from_cell(ivec3(cell.x + 1.0, cell.y + 1.0, z_layer), base_seed);
    float ux = fade(frac.x);
    float uy = fade(frac.y);
    float mix_x0 = mix(p00, p10, ux);
    float mix_x1 = mix(p01, p11, ux);
    return mix(mix_x0, mix_x1, uy);
}

vec2 octave_motion(uint octave, float time_value, float speed_value, uint seed) {
    uvec3 hashed = pcg3d(uvec3(seed + octave * 0x9e3779b9u, seed ^ 0x7f4a7c15u, octave + 1u));
    vec2 jitter = (vec2(float(hashed.x), float(hashed.y)) * FLOAT_SCALE - vec2(0.5, 0.5)) * 0.75;
    float angle = float(hashed.z) * FLOAT_SCALE * TAU;
    float motion_scale = time_value * speed_value * 0.35;
    vec2 direction = vec2(cos(angle), sin(angle));
    return jitter + direction * motion_scale;
}

float simple_multires(
    vec2 uv,
    ivec2 dims,
    ivec2 base_freq,
    uint octaves,
    float time_value,
    float speed_value,
    uint seed,
    bool use_ridge,
    bool use_exp
) {
    float total = 0.0;
    float weight = 0.0;
    uint current_seed = seed;

    for (uint octave = 1u; octave <= octaves; octave++) {
        uint multiplier = 1u << octave;
        float scaled_x = float(base_freq.x) * 0.5 * float(multiplier);
        float scaled_y = float(base_freq.y) * 0.5 * float(multiplier);
        int freq_x = max(int(floor(scaled_x)), 1);
        int freq_y = max(int(floor(scaled_y)), 1);

        if (freq_x > dims.x && freq_y > dims.y) {
            break;
        }

        vec2 freq_vec = vec2(float(freq_x), float(freq_y));
        vec2 motion = octave_motion(octave - 1u, time_value, speed_value, current_seed);
        vec2 sample_pos = uv * freq_vec + motion;
        float noise_value = sample_value_noise(sample_pos, current_seed);

        if (use_ridge) {
            noise_value = ridge_transform(noise_value);
        }
        if (use_exp) {
            noise_value = pow(noise_value, 4.0);
        }

        float amplitude = 1.0 / float(multiplier);
        total = total + noise_value * amplitude;
        weight = weight + amplitude;
        current_seed = current_seed ^ (0x9e3779b9u + octave * 0x7f4a7c15u);
    }

    if (weight <= EPSILON) {
        return 0.0;
    }

    return clamp(total / weight, 0.0, 1.0);
}

vec3 hsv_to_rgb(vec3 hsv) {
    float h = hsv.x;
    float s = saturate(hsv.y);
    float v = saturate(hsv.z);
    float dh = h * 6.0;
    float dr = saturate(abs(dh - 3.0) - 1.0);
    float dg = saturate(-abs(dh - 2.0) + 2.0);
    float db = saturate(-abs(dh - 4.0) + 2.0);
    float one_minus_s = 1.0 - s;
    float sr = s * dr;
    float sg = s * dg;
    float sb = s * db;
    float r = (one_minus_s + sr) * v;
    float g = (one_minus_s + sg) * v;
    float b = (one_minus_s + sb) * v;
    return clamp(vec3(r, g, b), vec3(0.0), vec3(1.0));
}

vec4 tint_overlay(float overlay_value, uint channelCount) {
    float clamped = clamp(overlay_value, 0.0, 1.0);

    if (channelCount < 3u) {
        return vec4(clamped, clamped, clamped, clamped);
    }

    float hue_bias_a = seeded_float(HUE_JITTER_SEED_A) * 0.33333334;
    float hue_bias_b = seeded_float(HUE_JITTER_SEED_B);
    float hue = fract(clamped * 0.33333334 + hue_bias_a + hue_bias_b);
    float saturation = clamped;
    float value = clamped;
    vec3 rgb = hsv_to_rgb(vec3(hue, saturation, value));
    return vec4(rgb, clamped);
}

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);
    ivec2 dims_tex = textureSize(inputTex, 0);
    uint width = as_u32(size.x);
    uint height = as_u32(size.y);
    if (width == 0u) {
        width = uint(max(dims_tex.x, 1));
    }
    if (height == 0u) {
        height = uint(max(dims_tex.y, 1));
    }

    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    uint channelCount = max(as_u32(size.z), 1u);
    vec2 dims_f = vec2(max(float(width), 1.0), max(float(height), 1.0));
    ivec2 dims_i = ivec2(int(width), int(height));
    vec2 pixel = vec2(float(global_id.x) + 0.5, float(global_id.y) + 0.5);
    vec2 uv = pixel / dims_f;

    float time_value = size.w;
    float speed_value = timeSpeed.x;

    int primary_freq_x = seeded_int(PRIMARY_FREQ_SEED, 3, 4);
    int secondary_freq_x = seeded_int(SECONDARY_FREQ_SEED, 2, 4);
    float rotation_degrees = float(seeded_int(ROTATION_SEED, -15, 15));

    float rotation_angle = radians(rotation_degrees) + time_value * speed_value * 0.05;
    vec2 rotated_uv = wrap_coord_unit(rotate_coord(uv, rotation_angle));

    float primary_noise = simple_multires(
        rotated_uv,
        dims_i,
        ivec2(primary_freq_x, 1),
        6u,
        time_value,
        speed_value,
        0x6c8e9cf5u,
        true,
        true
    );
    float secondary_noise = simple_multires(
        rotated_uv,
        dims_i,
        ivec2(secondary_freq_x, 1),
        4u,
        time_value,
        speed_value,
        0x9e3779b9u,
        true,
        false
    );
    float overlay = (primary_noise - secondary_noise) * 0.125;
    float overlay_positive = max(overlay, 0.0);
    vec4 overlay_color = tint_overlay(overlay_positive, channelCount);

    vec4 base_sample = texelFetch(inputTex, ivec2(global_id.xy), 0);
    vec3 base_rgb = base_sample.xyz;
    float base_alpha = base_sample.w;

    float attenuation = 1.0 - overlay;
    vec3 attenuated_rgb = base_rgb * attenuation;
    vec3 final_rgb = attenuated_rgb + overlay_color.xyz;
    float final_alpha = base_alpha;

    if (channelCount >= 4u) {
        final_alpha = base_alpha * attenuation + overlay_color.w;
    }

    if (channelCount >= 3u) {
        final_rgb = clamp(final_rgb, vec3(0.0), vec3(1.0));
    } else {
        float gray = clamp(attenuated_rgb.x + overlay_positive, 0.0, 1.0);
        final_rgb = vec3(gray);
        final_alpha = clamp(final_alpha, 0.0, 1.0);
    }

    fragColor = vec4(final_rgb, clamp(final_alpha, 0.0, 1.0));
}
