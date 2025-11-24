#version 300 es

precision highp float;
precision highp int;

// Glyph map effect. Recreates the Python glyph_map effect by mapping
// an input value map to glyph indices and optionally colorizing with the
// source image.

const float PI = 3.141592653589793;


uniform sampler2D input_texture;
uniform sampler2D glyph_texture;
uniform vec4 size;
uniform vec4 grid_layout;
uniform vec4 curve;
uniform vec4 tempo;

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

uint round_to_u32(float value) {
    return uint(max(round(value), 0.0));
}

uint sanitized_channel_count(float raw) {
    uint requested = round_to_u32(raw);
    if (requested < 1u) {
        return 1u;
    }
    if (requested > 4u) {
        return 4u;
    }
    return requested;
}

float read_channel(vec4 texel, uint index) {
    switch (index) {
        case 0u: { return texel.x; }
        case 1u: { return texel.y; }
        case 2u: { return texel.z; }
        default: { return texel.w; }
    }
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

float value_map(vec4 texel, uint channel_count) {
    if (channel_count == 1u) {
        return clamp01(texel.x);
    }
    if (channel_count == 2u) {
        float lum = clamp01(texel.x);
        float alpha = clamp01(texel.y);
        return clamp01(lum * alpha);
    }
    vec3 rgb = clamp(texel.xyz, vec3(0.0), vec3(1.0));
    return clamp01(oklab_l_component(rgb));
}

float lerp_f32(float a, float b, float t) {
    return a + (b - a) * t;
}


layout(location = 0) out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = max(round_to_u32(size.x), 1u);
    uint height = max(round_to_u32(size.y), 1u);
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    uint channel_count = sanitized_channel_count(size.z);
    vec2 src_coords = vec2(int(global_id.x), int(global_id.y));
    vec4 src_texel = texture(input_texture, (vec2(src_coords) + vec2(0.5)) / vec2(textureSize(input_texture, 0)));

    ivec2 atlas_dims_i = textureSize(glyph_texture, 0);
    uvec2 atlas_dims = uvec2(atlas_dims_i);
    if (atlas_dims.x == 0u || atlas_dims.y == 0u) {
        fragColor = src_texel;
        return;
    }

    uint glyph_width_raw = max(round_to_u32(size.w), 1u);
    uint glyph_height_raw = max(round_to_u32(grid_layout.x), 1u);
    uint glyph_width = min(glyph_width_raw, max(atlas_dims.x, 1u));
    uint glyph_height = min(glyph_height_raw, max(atlas_dims.y, 1u));

    uint glyph_count = round_to_u32(grid_layout.y);
    uint atlas_capacity = max(atlas_dims.y / max(glyph_height, 1u), 1u);
    if (glyph_count == 0u) {
        glyph_count = atlas_capacity;
    }
    glyph_count = clamp(glyph_count, 1u, atlas_capacity);

    float mask_value = grid_layout.z;
    bool colorize = grid_layout.w > 0.5;
    float zoom = max(curve.x, 1.0e-5);
    float alpha_factor = clamp01(curve.y);
    float spline_order = curve.z;
    if (abs(mask_value - 1020.0) < 0.5) {
        spline_order = 2.0;
    }

    float inv_zoom = 1.0 / zoom;
    uint input_width = max(uint(floor(float(width) * inv_zoom)), 1u);
    uint input_height = max(uint(floor(float(height) * inv_zoom)), 1u);

    uint grid_width = input_width / glyph_width;
    if (grid_width == 0u) {
        grid_width = 1u;
    }
    uint grid_height = input_height / glyph_height;
    if (grid_height == 0u) {
        grid_height = 1u;
    }

    uint approx_width = max(glyph_width * grid_width, 1u);
    uint approx_height = max(glyph_height * grid_height, 1u);

    float width_f = float(width);
    float height_f = float(height);
    float approx_width_f = float(approx_width);
    float approx_height_f = float(approx_height);

    float approx_x_f = (float(global_id.x) + 0.5) / max(width_f, 1.0) * approx_width_f;
    float approx_y_f = (float(global_id.y) + 0.5) / max(height_f, 1.0) * approx_height_f;
    uint approx_x = min(uint(floor(approx_x_f)), approx_width - 1u);
    uint approx_y = min(uint(floor(approx_y_f)), approx_height - 1u);

    uint glyph_local_x = approx_x % glyph_width;
    uint glyph_local_y = approx_y % glyph_height;
    uint cell_x = min(approx_x / glyph_width, max(grid_width, 1u) - 1u);
    uint cell_y = min(approx_y / glyph_height, max(grid_height, 1u) - 1u);

    float grid_width_f = float(max(grid_width, 1u));
    float grid_height_f = float(max(grid_height, 1u));
    float cell_center_x = (float(cell_x) + 0.5) / grid_width_f;
    float cell_center_y = (float(cell_y) + 0.5) / grid_height_f;

    float input_width_f = float(input_width);
    float input_height_f = float(input_height);
    float sample_input_x =
        clamp(cell_center_x * input_width_f, 0.0, max(input_width_f - 1.0, 0.0));
    float sample_input_y =
        clamp(cell_center_y * input_height_f, 0.0, max(input_height_f - 1.0, 0.0));

    float sample_source_x = clamp((sample_input_x + 0.5) * zoom, 0.0, max(width_f - 1.0, 0.0));
    float sample_source_y = clamp((sample_input_y + 0.5) * zoom, 0.0, max(height_f - 1.0, 0.0));

    vec2 sample_coords = vec2(int(sample_source_x), int(sample_source_y));
    vec4 sample_texel = texture(input_texture, (vec2(sample_coords) + vec2(0.5)) / vec2(textureSize(input_texture, 0)));

    float value_component = value_map(sample_texel, channel_count);
    float glyph_selector = clamp01(value_component);
    if (spline_order >= 1.5) {
        glyph_selector = 0.5 - 0.5 * cos(glyph_selector * PI);
    }

    uint glyph_index = uint(floor(glyph_selector * float(glyph_count)));
    if (glyph_index >= glyph_count) {
        glyph_index = glyph_count - 1u;
    }

    int glyph_sample_x = int(min(glyph_local_x, glyph_width - 1u));
    int glyph_sample_y = int(
        glyph_index * glyph_height + min(glyph_local_y, glyph_height - 1u)
    );
    vec2 glyph_coords = vec2(glyph_sample_x, glyph_sample_y);
    vec4 glyph_texel = texture(glyph_texture, (vec2(glyph_coords) + vec2(0.5)) / vec2(textureSize(glyph_texture, 0)));
    float glyph_value = clamp01(glyph_texel.x);

    vec4 result = vec4(0.0);
    for (uint channel = 0u; channel < channel_count; channel = channel + 1u) {
        float value = glyph_value;
        if (colorize) {
            float src_value = read_channel(src_texel, channel);
            float overlay_value = glyph_value * read_channel(sample_texel, channel);
            if (alpha_factor >= 0.9995) {
                value = overlay_value;
            } else {
                value = lerp_f32(src_value, overlay_value, alpha_factor);
            }
        }

        if (channel == 0u) {
            result.x = value;
        } else if (channel == 1u) {
            result.y = value;
        } else if (channel == 2u) {
            result.z = value;
        } else {
            result.w = value;
        }
    }

    if (channel_count == 1u) {
        result = vec4(result.x);
        result.w = 1.0;
    } else if (channel_count == 2u) {
        result = vec4(result.x, result.x, result.x, result.y);
    } else if (channel_count == 3u) {
        result = vec4(result.x, result.y, result.z, 1.0);
    } else {
        if (!colorize && channel_count >= 4u) {
            result.w = glyph_value;
        }
    }

    fragColor = clamp(result, vec4(0.0), vec4(1.0));
}