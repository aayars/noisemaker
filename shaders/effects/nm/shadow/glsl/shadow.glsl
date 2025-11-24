#version 300 es

precision highp float;
precision highp int;

// Shadow effect compute shader.
//
// Mirrors noisemaker.effects.shadow: compute Sobel gradients from a value map,
// sharpen them, and use the highlight ramp to darken/brighten the source image.

const float F32_MAX = 0x1.fffffep+127;
const float F32_MIN = -0x1.fffffep+127;

const SOBEL_X : array<f32, 9> = array<f32, 9>(

const SOBEL_Y : array<f32, 9> = array<f32, 9>(

const SHARPEN_KERNEL : array<f32, 9> = array<f32, 9>(

const float SHARPEN_BLEND = 0.5;


uniform sampler2D input_texture;
uniform vec4 size;
uniform vec4 anim;
uniform sampler2D reference_texture;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

uint sanitized_channel_count(float channel_value) {
    int rounded = int(round(channel_value));
    if (rounded <= 1) {
        return 1u;
    }
    if (rounded >= 4) {
        return 4u;
    }
    return uint(rounded);
}

int wrap_coord(int value, int size) {
    if (size <= 0) {
        return 0;
    }
    int wrapped = value % size;
    if (wrapped < 0) {
        wrapped = wrapped + size;
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
    if (value < 0.0) {
        return -pow(-value, 1.0 / 3.0);
    }
    if (value == 0.0) {
        return 0.0;
    }
    return pow(value, 1.0 / 3.0);
}

float oklab_l_component(vec3 rgb) {
    vec3 clamped = clamp(rgb, vec3(0.0), vec3(1.0));
    float l = 0.4121656120 * srgb_to_linear(clamped.x)
        + 0.5362752080 * srgb_to_linear(clamped.y)
        + 0.0514575653 * srgb_to_linear(clamped.z);
    float m = 0.2118591070 * srgb_to_linear(clamped.x)
        + 0.6807189584 * srgb_to_linear(clamped.y)
        + 0.1074065790 * srgb_to_linear(clamped.z);
    float s = 0.0883097947 * srgb_to_linear(clamped.x)
        + 0.2818474174 * srgb_to_linear(clamped.y)
        + 0.6302613616 * srgb_to_linear(clamped.z);
    float l_c = cube_root(l);
    float m_c = cube_root(m);
    float s_c = cube_root(s);
    return 0.2104542553 * l_c + 0.7936177850 * m_c - 0.0040720468 * s_c;
}

float mix_f32(float a, float b, float t) {
    return mix(a, b, clamp01(t));
}

vec3 clamp_vec3(vec3 value) {
    return clamp(value, vec3(0.0), vec3(1.0));
}

vec3 rgb_to_hsv(vec3 rgb) {
    vec3 color = clamp_vec3(rgb);
    float max_val = max(max(color.x, color.y), color.z);
    float min_val = min(min(color.x, color.y), color.z);
    float delta = max_val - min_val;

    float hue = 0.0;
    if (delta != 0.0) {
        if (max_val == color.x) {
            hue = (color.y - color.z) / delta;
        } else if (max_val == color.y) {
            hue = 2.0 + (color.z - color.x) / delta;
        } else {
            hue = 4.0 + (color.x - color.y) / delta;
        }
        hue = hue / 6.0;
        if (hue < 0.0) {
            hue = hue + 1.0;
        }
    }

    float saturation = 0.0;
    if (max_val != 0.0) {
        saturation = delta / max_val;
    }
    return vec3(hue, saturation, max_val);
}

vec3 hsv_to_rgb(vec3 hsv) {
    float h = hsv.x * 6.0;
    float s = clamp01(hsv.y);
    float v = clamp01(hsv.z);

    float sector = floor(h);
    float fraction = h - sector;

    float p = v * (1.0 - s);
    float q = v * (1.0 - fraction * s);
    float t = v * (1.0 - (1.0 - fraction) * s);

    switch int(sector) {
        case 0: {
            return vec3(v, t, p);
        }
        case 1: {
            return vec3(q, v, p);
        }
        case 2: {
            return vec3(p, v, t);
        }
        case 3: {
            return vec3(p, q, v);
        }
        case 4: {
            return vec3(t, p, v);
        }
        default: {
            return vec3(v, p, q);
        }
    }
}

float value_map_component(vec4 texel, uint channel_count) {
    if (channel_count <= 2u) {
        return texel.x;
    }
    return oklab_l_component(vec3(texel.x, texel.y, texel.z));
}

float sample_reference_raw(int x, int y, int width, int height, uint channel_count) {
    int xi = wrap_coord(x, width);
    int yi = wrap_coord(y, height);
    vec4 texel = textureLoad(reference_texture, vec2(xi, yi), 0);
    return value_map_component(texel, channel_count);
}

void sample_reference_normalized(fn compute_sobel(  float normalize_value(float value, float min_value, float inv_range) {
    if (inv_range == 0.0) {
        return value;
    }
    return clamp((value - min_value) * inv_range, 0.0, 1.0);
}

void compute_sharpen(float shade_component(float src_value, float final_shade, float highlight) {
    float dark = (1.0 - src_value) * (1.0 - highlight);
    float lit = 1.0 - dark;
    return clamp01(lit * final_shade);
}

}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    if (global_id.x != 0u || global_id.y != 0u || global_id.z != 0u) {
        return;
    }

    uint width = as_u32(size.x);
    uint height = as_u32(size.y);
    if (width == 0u || height == 0u) {
        return;
    }

    int width_i = int(width);
    int height_i = int(height);
    uint channel_count = sanitized_channel_count(size.z);

    float ref_min = F32_MAX;
    float ref_max = F32_MIN;
    for (uint y = 0u; y < height; y = y + 1u) {
        for (uint x = 0u; x < width; x = x + 1u) {
            float raw_value = sample_reference_raw(int(x), int(y), width_i, height_i, channel_count);
            ref_min = min(ref_min, raw_value);
            ref_max = max(ref_max, raw_value);
        }
    }
    float ref_range = ref_max - ref_min;
    float inv_ref_range = 0.0;
    if (ref_range != 0.0) {
        inv_ref_range = 1.0 / ref_range;
    }

    float shade_min = F32_MAX;
    float shade_max = F32_MIN;
    for (uint y = 0u; y < height; y = y + 1u) {
        for (uint x = 0u; x < width; x = x + 1u) {
            float shade_raw = compute_sobel(int(x), int(y), width_i, height_i, channel_count, ref_min, inv_ref_range);
            shade_min = min(shade_min, shade_raw);
            shade_max = max(shade_max, shade_raw);
        }
    }
    float shade_range = shade_max - shade_min;
    float inv_shade_range = 0.0;
    if (shade_range != 0.0) {
        inv_shade_range = 1.0 / shade_range;
    }

    float sharpen_min = F32_MAX;
    float sharpen_max = F32_MIN;
    for (uint y = 0u; y < height; y = y + 1u) {
        for (uint x = 0u; x < width; x = x + 1u) {
            float sharpen_raw = compute_sharpen(
                int(x),
                int(y),
                width_i,
                height_i,
                channel_count,
                ref_min,
                inv_ref_range,
                shade_min,
                inv_shade_range,
            );
            sharpen_min = min(sharpen_min, sharpen_raw);
            sharpen_max = max(sharpen_max, sharpen_raw);
        }
    }
    float sharpen_range = sharpen_max - sharpen_min;
    float inv_sharpen_range = 0.0;
    if (sharpen_range != 0.0) {
        inv_sharpen_range = 1.0 / sharpen_range;
    }

    float alpha = clamp01(size.w);

    for (uint y = 0u; y < height; y = y + 1u) {
        for (uint x = 0u; x < width; x = x + 1u) {
            vec2 coords = vec2(int(x), int(y));
            vec4 src_color = texture(input_texture, (vec2(coords) + vec2(0.5)) / vec2(textureSize(input_texture, 0)));
            float base_alpha = clamp01(src_color.w);

            float shade_raw = compute_sobel(coords.x, coords.y, width_i, height_i, channel_count, ref_min, inv_ref_range);
            float shade_norm = normalize_value(shade_raw, shade_min, inv_shade_range);

            float sharpen_raw = compute_sharpen(
                coords.x,
                coords.y,
                width_i,
                height_i,
                channel_count,
                ref_min,
                inv_ref_range,
                shade_min,
                inv_shade_range,
            );
            float sharpen_norm = normalize_value(sharpen_raw, sharpen_min, inv_sharpen_range);

            float final_shade = mix_f32(shade_norm, sharpen_norm, SHARPEN_BLEND);
            float highlight = clamp01(final_shade * final_shade);

            uint pixel_index = y * width + x;

            if (channel_count == 1u) {
                float shade_value = shade_component(src_color.x, final_shade, highlight);
                float mixed = mix_f32(src_color.x, shade_value, alpha);
                float final_value = clamp01(mixed);
                fragColor = vec4(final_value, final_value, final_value, base_alpha);
                continue;
            }

            if (channel_count == 2u) {
                float shade_value = shade_component(src_color.x, final_shade, highlight);
                float mixed = mix_f32(src_color.x, shade_value, alpha);
                float final_value = clamp01(mixed);
                float preserved_alpha = clamp01(src_color.y);
                fragColor = vec4(final_value, final_value, final_value, preserved_alpha);
                continue;
            }

            float shade_r = shade_component(src_color.x, final_shade, highlight);
            float shade_g = shade_component(src_color.y, final_shade, highlight);
            float shade_b = shade_component(src_color.z, final_shade, highlight);

            vec3 base_hsv = rgb_to_hsv(vec3(src_color.x, src_color.y, src_color.z));
            vec3 shade_hsv = rgb_to_hsv(vec3(shade_r, shade_g, shade_b));
            float final_value = mix_f32(base_hsv.z, shade_hsv.z, alpha);
            vec3 final_rgb = hsv_to_rgb(vec3(base_hsv.x, base_hsv.y, final_value));

            fragColor = vec4(final_rgb.x, final_rgb.y, final_rgb.z, base_alpha);
        }
    }
}