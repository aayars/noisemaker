#version 300 es

precision highp float;
precision highp int;

// Clouds effect: multi-pass translation of noisemaker.effects.clouds.

const uint CHANNEL_COUNT = 4u;
const uint CONTROL_OCTAVES = 8u;
const uint WARP_OCTAVES = 2u;
const uint WARP_SUB_OCTAVES = 3u;
const float WARP_DISPLACEMENT = 0.125;
const float SHADE_PRE_SCALE = 2.5;
const float SHADE_SCALE = 1.0;
const int BLUR_RADIUS = 6;
const float PI = 3.14159265358979323846;
const float TAU = 6.28318530717958647692;

const vec3 CONTROL_BASE_SEED = vec3(17.0, 29.0, 47.0);
const vec3 CONTROL_TIME_SEED = vec3(71.0, 113.0, 191.0);
const vec3 WARP_BASE_SEED = vec3(23.0, 37.0, 59.0);
const vec3 WARP_TIME_SEED = vec3(83.0, 127.0, 211.0);

const float TRIPLE_GAUSS_KERNEL[13] = float[13](
    0.0002441406,
    0.0029296875,
    0.0161132812,
    0.0537109375,
    0.1208496094,
    0.1933593750,
    0.2255859375,
    0.1933593750,
    0.1208496094,
    0.0537109375,
    0.0161132812,
    0.0029296875,
    0.0002441406
);


uniform sampler2D inputTex;
uniform vec4 sizeTime;
uniform vec4 animDown;
uniform vec4 invOffset;

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

float wrap_component(float value, float size) {
    if (size <= 0.0) {
        return 0.0;
    }
    float wrapped = value - floor(value / size) * size;
    if (wrapped < 0.0) {
        return wrapped + size;
    }
    return wrapped;
}

vec2 wrap_coord(vec2 coord, vec2 dims) {
    return vec2(wrap_component(coord.x, dims.x), wrap_component(coord.y, dims.y));
}

int wrap_index(int value, int limit) {
    if (limit <= 0) {
        return 0;
    }
    int wrapped = value % limit;
    if (wrapped < 0) {
        wrapped = wrapped + limit;
    }
    return wrapped;
}

vec2 freq_for_shape(float base_freq, vec2 dims) {
    // Python takes [height, width] and returns [freq_y, freq_x]
    // Shader dims are (width, height), so dims.y = height, dims.x = width
    float width = max(dims.x, 1.0);
    float height = max(dims.y, 1.0);
    if (abs(width - height) < 0.5) {
        return vec2(base_freq, base_freq);
    }
    if (height < width) {
        return vec2(base_freq, base_freq * width / height);
    }
    return vec2(base_freq * height / width, base_freq);
}

float ridge_transform(float value) {
    return 1.0 - abs(value * 2.0 - 1.0);
}
float normalized_sine(float value) {
    return sin(value) * 0.5 + 0.5;
}

float periodic_value(float value, float phase) {
    return normalized_sine((value - phase) * TAU);
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

void animated_simplex_value(float seeded_base_frequency(vec2 dims) {
    float hash_val = fract(sin(dot(dims, vec2(12.9898, 78.233))) * 43758.5453123);
    return floor(hash_val * 3.0) + 2.0;
}
void simplex_multires_value(// Python: tensor += layer / multiplier   fn warp_coordinate(        fn control_value_at(     // Python clouds calls warp without time/speed, so we use 0.0, 1.0  float normalize_control(float raw_value, float min_value, float max_value) {
    float delta = max(max_value - min_value, 1e-6);
    return clamp((raw_value - min_value) / delta, 0.0, 1.0);
}

float combined_from_normalized(float control_norm) {
    float scaled = control_norm * 2.0;
    if (scaled < 1.0) {
        return clamp(1.0 - scaled, 0.0, 1.0);
    }
    return 0.0;
}

float combined_from_raw(float raw_value, float min_value, float max_value) {
    float control_norm = normalize_control(raw_value, min_value, max_value);
    return combined_from_normalized(control_norm);
}

float read_channel(ivec2 coord, ivec2 size, uint channel) {
    int width = max(size.x, 1);
    int height = max(size.y, 1);
    int safe_x = wrap_index(coord.x, width);
    int safe_y = wrap_index(coord.y, height);
    uint base_index = (uint(safe_y) * uint(width) + uint(safe_x)) * CHANNEL_COUNT + channel;
    return downsample_buffer[base_index];
}

float cubic_interpolate_scalar(float a, float b, float c, float d, float t) {
    float t2 = t * t;
    float t3 = t2 * t;
    float a0 = d - c - a + b;
    float a1 = a - b - a0;
    float a2 = c - a;
    float a3 = b;
    return a0 * t3 + a1 * t2 + a2 * t + a3;
}

float sample_channel_bicubic(vec2 uv, ivec2 size, uint channel) {
    int width = max(size.x, 1);
    int height = max(size.y, 1);
    vec2 scale = vec2(float(width), float(height));
    vec2 base_coord = uv * scale - vec2(0.5, 0.5);

    int ix = int(floor(base_coord.x));
    int iy = int(floor(base_coord.y));
    float fx = clamp(base_coord.x - floor(base_coord.x), 0.0, 1.0);
    float fy = clamp(base_coord.y - floor(base_coord.y), 0.0, 1.0);

    float column[4];
    float row[4];

    int m = -1;
    loop {
        if (m > 2) {
            break;
        }

        int n = -1;
        loop {
            if (n > 2) {
                break;
            }

            vec2 sample_coord = vec2(
                wrap_index(ix + n, width),
                wrap_index(iy + m, height)
            );
            row[uint(n + 1)] = read_channel(sample_coord, size, channel);
            n = n + 1;
        }

        column[uint(m + 1)] = cubic_interpolate_scalar(row[0], row[1], row[2], row[3], fx);
        m = m + 1;
    }

    float value = cubic_interpolate_scalar(column[0], column[1], column[2], column[3], fy);
    return clamp(value, 0.0, 1.0);
}

float blur_shade(ivec2 coord, ivec2 size, ivec2 offset, float min_value, float max_value) {
    int width = max(size.x, 1);
    int height = max(size.y, 1);
    
    // Python does: shaded = offset(combined) then shaded *= 2.5 then blur(shaded)
    // We need to blur the OFFSET+BOOSTED values
    // Each sample in the blur reads from (coord_in_blur_space + global_offset)
    
    float accum = 0.0;
    int dy = -BLUR_RADIUS;
    loop {
        if (dy > BLUR_RADIUS) {
            break;
        }

        float weight_y = TRIPLE_GAUSS_KERNEL[uint(dy + BLUR_RADIUS)];
        float row_accum = 0.0;
        int dx = -BLUR_RADIUS;
        loop {
            if (dx > BLUR_RADIUS) {
                break;
            }

            float weight_x = TRIPLE_GAUSS_KERNEL[uint(dx + BLUR_RADIUS)];
            // Read from shifted position: (coord + blur_delta + global_offset)
            vec2 sample_coord = vec2(
                wrap_index(coord.x + dx + offset.x, width),
                wrap_index(coord.y + dy + offset.y, height)
            );
            float control_raw = read_channel(sample_coord, size, 2u);
            float combined = combined_from_raw(control_raw, min_value, max_value);
            float boosted = min(combined * 2.5, 1.0);
            row_accum = row_accum + boosted * weight_x;

            dx = dx + 1;
        }

        accum = accum + row_accum * weight_y;
        dy = dy + 1;
    }

    return clamp01(accum);
}

vec4 sample_texture_bilinear(vec2 uv, ivec2 tex_size) {
    float width = float(tex_size.x);
    float height = float(tex_size.y);
    
    vec2 coord = vec2(uv.x * width - 0.5, uv.y * height - 0.5);
    vec2 coord_floor = vec2(int(floor(coord.x)), int(floor(coord.y)));
    vec2 fract_part = vec2(coord.x - floor(coord.x), coord.y - floor(coord.y));
    
    int x0 = wrap_index(coord_floor.x, tex_size.x);
    int y0 = wrap_index(coord_floor.y, tex_size.y);
    int x1 = wrap_index(coord_floor.x + 1, tex_size.x);
    int y1 = wrap_index(coord_floor.y + 1, tex_size.y);
    
    vec4 p00 = textureLoad(inputTex, vec2(x0, y0), 0);
    vec4 p10 = textureLoad(inputTex, vec2(x1, y0), 0);
    vec4 p01 = textureLoad(inputTex, vec2(x0, y1), 0);
    vec4 p11 = textureLoad(inputTex, vec2(x1, y1), 0);
    
    vec4 p0 = mix(p00, p10, fract_part.x);
    vec4 p1 = mix(p01, p11, fract_part.x);
    
    return mix(p0, p1, fract_part.y);
}

vec2 sobel_gradient(vec2 uv, ivec2 size) {
    int width = max(size.x, 1);
    int height = max(size.y, 1);

    // First, blur the input (matching Python's sobel_operator)
    float blurred_value = 0.0;
    for (int i = -1; i <= 1; i = i + 1) {
        for (int j = -1; j <= 1; j = j + 1) {
            vec2 sample_uv = uv + vec2(float(j) / float(width), float(i) / float(height));
            vec4 texel = sample_texture_bilinear(sample_uv, size);
            float luminance = (texel.r + texel.g + texel.b) / 3.0;
            blurred_value = blurred_value + luminance;
        }
    }
    blurred_value = blurred_value / 9.0;

    // Sobel kernels
    x_kernel : mat3x3<f32> = mat3x3<f32>(
        vec3(-1.0, 0.0, 1.0),
        vec3(-2.0, 0.0, 2.0),
        vec3(-1.0, 0.0, 1.0)
    );

    y_kernel : mat3x3<f32> = mat3x3<f32>(
        vec3(-1.0, -2.0, -1.0),
        vec3(0.0, 0.0, 0.0),
        vec3(1.0, 2.0, 1.0)
    );

    float gx = 0.0;
    float gy = 0.0;

    for (int i = -1; i <= 1; i = i + 1) {
        for (int j = -1; j <= 1; j = j + 1) {
            vec2 sample_uv = uv + vec2(float(j) / float(width), float(i) / float(height));
            vec4 texel = sample_texture_bilinear(sample_uv, size);
            float value = (texel.r + texel.g + texel.b) / 3.0;

            gx = gx + value * x_kernel[i + 1][j + 1];
            gy = gy + value * y_kernel[i + 1][j + 1];
        }
    }

    return vec2(gx, gy);
}

vec4 shadow(vec4 original_texel, vec2 uv, ivec2 size, float alpha) {
    // Get Sobel gradients
    vec2 gradient = sobel_gradient(uv, size);
    
    // Calculate Euclidean distance and normalize (simplified - no global normalization)
    float distance = sqrt(gradient.x * gradient.x + gradient.y * gradient.y);
    float normalized_distance = clamp(distance, 0.0, 1.0);
    
    // Apply sharpen effect (simplified - just boost the contrast)
    float shade = normalized_distance;
    shade = clamp((shade - 0.5) * 1.5 + 0.5, 0.0, 1.0);
    
    // Create highlight by squaring
    float highlight = shade * shade;
    
    // Apply shadow formula: shade = (1.0 - ((1.0 - tensor) * (1.0 - highlight))) * shade
    vec3 shadowed = (vec3(1.0) - ((vec3(1.0) - original_texel.rgb) * (1.0 - highlight))) * shade;
    
    // Blend with original
    return vec4(mix(original_texel.rgb, shadowed, alpha), original_texel.a);
}

void downsample_main(uvec3 @builtin(global_invocation_id) global_id) {
    int down_width = max(int(round(anim_down.y)), 1);
    int down_height = max(int(round(anim_down.z)), 1);
    if (global_id.x >= uint(down_width) || global_id.y >= uint(down_height)) {
        return;
    }

    vec2 dims = vec2(float(down_width), float(down_height));
    vec2 coord = vec2(float(global_id.x), float(global_id.y));
    float time_value = size_time.w;
    float speed_value = anim_down.x;

    float control_raw = control_value_at(coord, dims, time_value, speed_value);
    uint base_index = (global_id.y * uint(down_width) + global_id.x) * CHANNEL_COUNT;
    downsample_buffer[base_index + 0u] = 0.0;
    downsample_buffer[base_index + 1u] = 0.0;
    downsample_buffer[base_index + 2u] = control_raw;
    downsample_buffer[base_index + 3u] = 1.0;
}

void shade_main(uvec3 @builtin(global_invocation_id) global_id) {
    int down_width = max(int(round(anim_down.y)), 1);
    int down_height = max(int(round(anim_down.z)), 1);
    if (global_id.x >= uint(down_width) || global_id.y >= uint(down_height)) {
        return;
    }

    vec2 size_i = vec2(down_width, down_height);
    vec2 coord_i = vec2(int(global_id.x), int(global_id.y));
    vec2 offset_i = vec2(
        int(round(inv_offset.z)),
        int(round(inv_offset.w))
    );

    float min_value = stats_buffer[0];
    float max_value = stats_buffer[1];
    float control_raw = read_channel(coord_i, size_i, 2u);
    float combined = combined_from_raw(control_raw, min_value, max_value);
    float shade = blur_shade(coord_i, size_i, offset_i, min_value, max_value);
    uint base_index = (global_id.y * uint(down_width) + global_id.x) * CHANNEL_COUNT;
    downsample_buffer[base_index + 0u] = combined;
    downsample_buffer[base_index + 1u] = shade;
    downsample_buffer[base_index + 2u] = control_raw;
    downsample_buffer[base_index + 3u] = 1.0;
}

// Compute true min and max of combined values for normalization
void normalize_main(uvec3 @builtin(global_invocation_id) global_id) {
    // Only single invocation
    if (global_id.x != 0u || global_id.y != 0u) { return; }
    int down_w = max(int(round(anim_down.y)), 1);
    int down_h = max(int(round(anim_down.z)), 1);
    float minv = 1e30;
    float maxv = -1e30;
    // Iterate all downsample buffer texels
    for (int yy = 0; yy < down_h; yy = yy + 1) {
        for (int xx = 0; xx < down_w; xx = xx + 1) {
            uint base_index = (uint(yy) * uint(down_w) + uint(xx)) * CHANNEL_COUNT;
            float v = downsample_buffer[base_index + 2u];
            minv = min(minv, v);
            maxv = max(maxv, v);
        }
    }
    stats_buffer[0] = minv;
    stats_buffer[1] = maxv;
}

void upsample_main(uvec3 @builtin(global_invocation_id) global_id) {
    int width = max(int(round(size_time.x)), 1);
    int height = max(int(round(size_time.y)), 1);
    if (global_id.x >= uint(width) || global_id.y >= uint(height)) {
        return;
    }

    vec2 down_size_i = vec2(
        max(int(round(anim_down.y)), 1),
        max(int(round(anim_down.z)), 1)
    );

    vec2 uv = vec2(
        (float(global_id.x) + 0.5) / max(size_time.x, 1.0),
        (float(global_id.y) + 0.5) / max(size_time.y, 1.0)
    );

    // Combined is already 0-1 from blend_layers
    float combined_value = clamp01(sample_channel_bicubic(uv, down_size_i, 0u));
    
    // Sample and soften shade mask
    float shade_mask = sample_channel_bicubic(uv, down_size_i, 1u);
    // reduce harshness and boost low values
    float shade_factor = smoothstep(0.0, 0.5, shade_mask * 0.75);

    vec4 texel = textureLoad(
        inputTex,
        vec2(int(global_id.x), int(global_id.y)),
        0,
    );

    vec3 shaded_color = mix(texel.xyz, vec3(0.0), vec3(shade_factor));
    vec4 lit_color = vec4(mix(shaded_color, vec3(1.0), vec3(combined_value)), clamp(mix(texel.w, 1.0, combined_value), 0.0, 1.0));

    vec4 final_texel = shadow(lit_color, uv, vec2(width, height), 0.5);

}
