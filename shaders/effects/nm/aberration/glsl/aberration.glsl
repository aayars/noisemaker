#version 300 es

precision highp float;
precision highp int;

// Chromatic aberration effect mirroring Noisemaker's aberration() implementation.
// Applies a hue jitter, offsets RGB channels horizontally, and blends offsets
// toward the image center with a cosine falloff mask.

const float PI = 3.14159265358979323846;
const float TAU = 6.28318530717958647692;


uniform sampler2D input_texture;
uniform float displacement;
uniform float speed;
uniform float time;
uniform vec2 resolution;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

float clamp_01(float value) {
    return clamp(value, 0.0, 1.0);
}

float wrap_unit(float value) {
    float wrapped = value - floor(value);
    if (wrapped < 0.0) {
        return wrapped + 1.0;
    }
    return wrapped;
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
        m0sq * m0sq * dot(g0n, x0)
        + m1sq * m1sq * dot(g1n, x1)
        + m2sq * m2sq * dot(g2n, x2)
        + m3sq * m3sq * dot(g3n, x3)
    );
}

float slow_motion_rate(float speed) {
    float clamped_speed = max(speed, 0.0);
    float normalized = clamp(clamped_speed, 0.0, 1.0);
    float extended = max(clamped_speed - 1.0, 0.0);
    return normalized * 0.2 + extended * 0.05;
}

float gentle_noise(float time, float speed, vec3 offset) {
    float rate = slow_motion_rate(speed);
    float phase = time * TAU * rate;
    vec3 samplePos = offset + vec3(
        phase * 0.11,
        phase * 0.17,
        phase * 0.23
    );
    float noise_value = simplex_noise(samplePos);
    return clamp(noise_value * 0.5 + 0.5, 0.0, 1.0);
}

float blend_linear(float a, float b, float t) {
    return a * (1.0 - t) + b * t;
}

float blend_cosine(float a, float b, float g) {
    float weight = (1.0 - cos(g * PI)) * 0.5;
    return a * (1.0 - weight) + b * weight;
}

uint clamp_index(float value, float max_index) {
    if (max_index <= 0.0) {
        return 0u;
    }
    float clamped_value = clamp(value, 0.0, max_index);
    return uint(clamped_value);
}

float aberration_mask(float width, float height, float x, float y) {
    if (width <= 0.0 || height <= 0.0) {
        return 0.0;
    }
    float px = x + 0.5;
    float py = y + 0.5;
    float half_w = width * 0.5;
    float half_h = height * 0.5;
    float dx = (px - half_w) / width;
    float dy = (py - half_h) / height;
    float max_dx = abs((half_w - 0.5) / width);
    float max_dy = abs((half_h - 0.5) / height);
    float max_dist = sqrt(max_dx * max_dx + max_dy * max_dy);
    if (max_dist <= 0.0) {
        return 0.0;
    }
    float dist = sqrt(dx * dx + dy * dy);
    float normalized = clamp(dist / max_dist, 0.0, 1.0);
    return pow(normalized, 3.0);
}

vec3 rgb_to_hsv(vec3 rgb) {
    float c_max = max(max(rgb.x, rgb.y), rgb.z);
    float c_min = min(min(rgb.x, rgb.y), rgb.z);
    float delta = c_max - c_min;

    float hue = 0.0;
    if (delta > 0.0) {
        if (c_max == rgb.x) {
            float segment = (rgb.y - rgb.z) / delta;
            if (segment < 0.0) {
                segment = segment + 6.0;
            }
            hue = segment;
        } else if (c_max == rgb.y) {
            hue = ((rgb.z - rgb.x) / delta) + 2.0;
        } else {
            hue = ((rgb.x - rgb.y) / delta) + 4.0;
        }
        hue = wrap_unit(hue / 6.0);
    }

    float saturation = (c_max != 0.0) ? (delta / c_max) : 0.0;
    return vec3(hue, saturation, c_max);
}

vec3 hsv_to_rgb(vec3 hsv) {
    float h = hsv.x;
    float s = hsv.y;
    float v = hsv.z;

    float dh = h * 6.0;
    float r_comp = clamp_01(abs(dh - 3.0) - 1.0);
    float g_comp = clamp_01(-abs(dh - 2.0) + 2.0);
    float b_comp = clamp_01(-abs(dh - 4.0) + 2.0);

    float one_minus_s = 1.0 - s;
    float sr = s * r_comp;
    float sg = s * g_comp;
    float sb = s * b_comp;

    float r = clamp_01((one_minus_s + sr) * v);
    float g = clamp_01((one_minus_s + sg) * v);
    float b = clamp_01((one_minus_s + sb) * v);

    return vec3(r, g, b);
}

vec3 adjust_hue(vec3 rgb, float amount) {
    vec3 hsv = rgb_to_hsv(rgb);
    hsv.x = wrap_unit(hsv.x + amount);
    hsv.y = clamp_01(hsv.y);
    hsv.z = clamp_01(hsv.z);
    return clamp(vec3(hsv_to_rgb(hsv)), vec3(0.0), vec3(1.0));
}

vec4 sample_shifted(ivec2 coords, float hue_shift) {
    vec4 texel = texture(input_texture, (vec2(coords) + vec2(0.5)) / vec2(textureSize(input_texture, 0)));
    vec3 adjusted_rgb = adjust_hue(texel.xyz, hue_shift);
    return vec4(adjusted_rgb, texel.w);
}


out vec4 fragColor;

void main() {
    vec4 size = vec4(resolution.x, resolution.y, 4.0, displacement);
    vec4 anim = vec4(time, speed, 0.0, 0.0);

    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = as_u32(size.x);
    uint height = as_u32(size.y);
    if (width == 0u || height == 0u) {
        return;
    }
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }


    vec2 coords = vec2(int(global_id.x), int(global_id.y));
    vec4 center_sample = texture(input_texture, (vec2(coords) + vec2(0.5)) / vec2(textureSize(input_texture, 0)));

    uint channel_count = as_u32(size.z);
    if (channel_count < 3u) {
        fragColor = vec4(center_sample.x, center_sample.y, center_sample.z, center_sample.w);
        return;
    }

    float width_f = max(size.x, 1.0);
    float height_f = max(size.y, 1.0);
    float x_float = float(global_id.x);
    float y_float = float(global_id.y);
    float width_minus_one = max(width_f - 1.0, 0.0);

    float gradient = 0.0;
    if (width > 1u) {
        gradient = x_float / width_minus_one;
    }

    float time_value = anim.x;
    float speed_value = anim.y;
    float speed_weight = clamp(speed_value, 0.0, 1.0);
    float base_noise = gentle_noise(time_value, speed_value, vec3(17.0, 29.0, 11.0));
    float random_factor = blend_linear(0.5, base_noise, speed_weight);

    float hue_noise = gentle_noise(time_value + 0.37, speed_value, vec3(23.0, 47.0, 19.0));
    float hue_shift = (hue_noise - 0.5) * 0.06;

    float displacement_raw = width_f * size.w * random_factor;
    float displacement_pixels = trunc(displacement_raw);

    float mask_value = aberration_mask(width_f, height_f, x_float, y_float);

    float red_offset = min(x_float + displacement_pixels, width_minus_one);
    red_offset = blend_linear(red_offset, x_float, gradient);
    red_offset = blend_cosine(x_float, red_offset, mask_value);
    uint red_x = clamp_index(red_offset, width_minus_one);

    float green_offset = x_float;
    green_offset = blend_cosine(x_float, green_offset, mask_value);
    uint green_x = clamp_index(green_offset, width_minus_one);

    float blue_offset = max(x_float - displacement_pixels, 0.0);
    blue_offset = blend_linear(x_float, blue_offset, gradient);
    blue_offset = blend_cosine(x_float, blue_offset, mask_value);
    uint blue_x = clamp_index(blue_offset, width_minus_one);

    vec4 red_sample = sample_shifted(ivec2(int(red_x), int(global_id.y)), hue_shift);
    vec4 green_sample = sample_shifted(ivec2(int(green_x), int(global_id.y)), hue_shift);
    vec4 blue_sample = sample_shifted(ivec2(int(blue_x), int(global_id.y)), hue_shift);

    vec3 combined_rgb = vec3(red_sample.x, green_sample.y, blue_sample.z);
    vec3 restored_rgb = adjust_hue(combined_rgb, -hue_shift);

    fragColor = vec4(clamp_01(restored_rgb.x), clamp_01(restored_rgb.y), clamp_01(restored_rgb.z), center_sample.w);
}