#version 300 es

precision highp float;
precision highp int;

// Reindex remaps pixels along a monotonic index derived from value_map(), mirroring
// noisemaker.effects.reindex(). Optimized for parallel execution.


const uint CHANNEL_COUNT = 4u;

uniform sampler2D input_texture;
uniform vec4 width_height_channels_displacement;
uniform vec4 time_speed_padding;

uint as_u32(float value) {
    return uint(max(value, 0.0));
}

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
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
    float r_lin = srgb_to_linear(clamp01(rgb.x));
    float g_lin = srgb_to_linear(clamp01(rgb.y));
    float b_lin = srgb_to_linear(clamp01(rgb.z));

    float l = 0.4121656120 * r_lin + 0.5362752080 * g_lin + 0.0514575653 * b_lin;
    float m = 0.2118591070 * r_lin + 0.6807189584 * g_lin + 0.1074065790 * b_lin;
    float s = 0.0883097947 * r_lin + 0.2818474174 * g_lin + 0.6302613616 * b_lin;

    float l_c = cube_root(l);
    float m_c = cube_root(m);
    float s_c = cube_root(s);

    float lightness = 0.2104542553 * l_c + 0.7936177850 * m_c - 0.0040720468 * s_c;
    return clamp01(lightness);
}

float value_map_component(vec4 texel) {
    vec3 rgb = vec3(texel.x, texel.y, texel.z);
    return oklab_l_component(rgb);
}

float wrap_float(float value, float range) {
    if (range <= 0.0) {
        return 0.0;
    }
    float scaled = floor(value / range);
    return value - range * scaled;
}

int wrap_index(float value, int dimension) {
    if (dimension <= 0) {
        return 0;
    }
    float dimension_f = float(dimension);
    float wrapped = wrap_float(value, dimension_f);
    float max_index = float(dimension - 1);
    return int(clamp(floor(wrapped), 0.0, max_index));
}

}

uint float_to_sortable_uint(float f) {
    uint bits = floatBitsToUint(f);
    uint mask = select(0xFFFFFFFFu, 0x80000000u, (bits & 0x80000000u) != 0u);
    return bits ^ mask;
}

float sortable_uint_to_float(uint u) {
    uint mask = select(0x80000000u, 0xFFFFFFFFu, (u & 0x80000000u) != 0u);
    return uintBitsToFloat(u ^ mask);
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = as_u32(width_height_channels_displacement.x);
    uint height = as_u32(width_height_channels_displacement.y);
    
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    int width_i = int(width);
    int height_i = int(height);
    uint min_dimension = min(width, height);
    float mod_range = float(min_dimension);
    float displacement = width_height_channels_displacement.w;

    // Load and compute reference value for this pixel
    vec2 coord = vec2(int(global_id.x), int(global_id.y));
    vec4 texel = texture(input_texture, (vec2(coord) + vec2(0.5)) / vec2(textureSize(input_texture, 0)));
    float reference_value = value_map_component(texel);
    
    // Use precomputed min/max from params (computed by effect.js)
    float min_value = time_speed_minmax.z;
    float max_value = time_speed_minmax.w;
    float range = max_value - min_value;
    
    float normalized = reference_value;
    if (range > 0.0001) {
        normalized = clamp01((reference_value - min_value) / range);
    }

    float offset_value = normalized * displacement * mod_range + normalized;
    int sample_x = wrap_index(offset_value, width_i);
    int sample_y = wrap_index(offset_value, height_i);

    vec4 sampled = textureLoad(input_texture, vec2(sample_x, sample_y), 0);

    fragColor = sampled;
}