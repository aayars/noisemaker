#version 300 es

precision highp float;
precision highp int;

// Wormhole: per-pixel field flow driven by luminance, ported from the
// Noisemaker Python reference implementation. The shader scatters weighted
// samples according to a sinusoidal offset and normalizes the accumulated
// result before blending with the source image.

const float TAU = 6.28318530717958647692;
const float STRIDE_SCALE = 1024.0;
const float MAX_FLOAT = 3.402823466e38;
const uint CHANNEL_COUNT = 4u;

    // flow = (kink, input_stride, alpha, time)
    // motion = (speed, _pad0, _pad1, _pad2)

uniform sampler2D input_texture;
uniform vec4 flow;
uniform vec4 motion;

float luminance(vec4 color) {
    return dot(color.xyz, vec3(0.2126, 0.7152, 0.0722));
}

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

uint wrap_index(float value, uint limit) {
    if (limit == 0u) {
        return 0u;
    }

    int limit_i = int(limit);
    int wrapped = int(floor(value)) % limit_i;
    if (wrapped < 0) {
        wrapped = wrapped + limit_i;
    }

    return uint(wrapped);
}

float apply_normalization(float value, float min_value, float inv_range, bool enabled) {
    if (!enabled) {
        return value;
    }

    return clamp01((value - min_value) * inv_range);
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    if (global_id.x != 0u || global_id.y != 0u || global_id.z != 0u) {
        return;
    }

    uvec2 dims = uvec2(textureSize(input_texture, 0));
    uint width = dims.x;
    uint height = dims.y;
    if (width == 0u || height == 0u) {
        return;
    }

    if (buffer_length == 0u) {
        return;
    }

    uint clear_index = 0u;
    loop {
        if (clear_index >= buffer_length) {
            break;
        }

        clear_index = clear_index + 1u;
    }

    float kink = flow.x;
    float stride_pixels = flow.y * STRIDE_SCALE;

    uint y = 0u;
    loop {
        if (y >= height) {
            break;
        }

        uint x = 0u;
        loop {
            if (x >= width) {
                break;
            }

            vec4 src_texel = textureLoad(input_texture, vec2(int(x), int(y)), 0);
            float lum = luminance(src_texel);
            float angle = lum * TAU * kink;
            float offset_x = (cos(angle) + 1.0) * stride_pixels;
            float offset_y = (sin(angle) + 1.0) * stride_pixels;

            uint dest_x = wrap_index(float(x) + offset_x, width);
            uint dest_y = wrap_index(float(y) + offset_y, height);
            uint dest_pixel = dest_y * width + dest_x;
            uint base_index = dest_pixel * CHANNEL_COUNT;
            if (base_index + 3u >= buffer_length) {
                x = x + 1u;
                continue;
            }

            float weight = lum * lum;
            vec4 scaled = src_texel * vec4(weight);


            x = x + 1u;
        }

        y = y + 1u;
    }

    float min_value = MAX_FLOAT;
    float max_value = -MAX_FLOAT;

    uint scan_index = 0u;
    loop {
        if (scan_index >= buffer_length) {
            break;
        }

        if (value < min_value) {
            min_value = value;
        }
        if (value > max_value) {
            max_value = value;
        }

        scan_index = scan_index + 1u;
    }

    bool can_normalize = max_value > min_value;
    float inv_range = 0.0;
    if (can_normalize) {
        inv_range = 1.0 / (max_value - min_value);
    }

    float alpha = clamp01(flow.z);
    float inv_alpha = 1.0 - alpha;
    vec3 alpha_vec3 = vec3(alpha, alpha, alpha);
    vec3 inv_alpha_vec3 = vec3(inv_alpha, inv_alpha, inv_alpha);

    uint out_y = 0u;
    loop {
        if (out_y >= height) {
            break;
        }

        uint out_x = 0u;
        loop {
            if (out_x >= width) {
                break;
            }

            uint pixel_index = out_y * width + out_x;
            if (base_index + 3u >= buffer_length) {
                out_x = out_x + 1u;
                continue;
            }

            vec4 original = textureLoad(input_texture, vec2(int(out_x), int(out_y)), 0);

            float norm_r = apply_normalization(raw_r, min_value, inv_range, can_normalize);
            float norm_g = apply_normalization(raw_g, min_value, inv_range, can_normalize);
            float norm_b = apply_normalization(raw_b, min_value, inv_range, can_normalize);
            vec3 worm_rgb = vec3(
                sqrt(max(norm_r, 0.0)),
                sqrt(max(norm_g, 0.0)),
                sqrt(max(norm_b, 0.0)),
            );

            vec3 blended_rgb = (original.xyz * inv_alpha_vec3) + (worm_rgb * alpha_vec3);
            vec3 clamped_rgb = vec3(
                clamp01(blended_rgb.x),
                clamp01(blended_rgb.y),
                clamp01(blended_rgb.z),
            );

            fragColor = vec4(clamped_rgb.x, clamped_rgb.y, clamped_rgb.z, original.w);

            out_x = out_x + 1u;
        }

        out_y = out_y + 1u;
    }
}