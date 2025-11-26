#version 300 es

precision highp float;
precision highp int;

// Sketch effect compute shader.
//
// Mirrors the TensorFlow implementation in noisemaker/effects.py::sketch.
// Builds a grayscale value map, enhances contrast, extracts outlines with
// derivative kernels, applies a center-weighted vignette, generates a
// crosshatch shading pass inspired by worms(... behavior=2), blends the
// passes, and finishes with a subtle animated warp.

const float PI = 3.14159265358979323846;
const float TAU = 6.28318530717958647692;
const float SQRT_TWO = 1.4142135623730951;
const uint CHANNEL_COUNT = 4u;

uniform sampler2D inputTex;
uniform vec4 size;      // x: width, y: height, z: channels, w: unused
uniform vec4 controls;  // x: time, y: speed, z/w: unused

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

uint sanitized_channelCount(float raw_channels) {
    int rounded = int(round(raw_channels));
    if (rounded <= 1) {
        return 1u;
    }
    if (rounded >= 4) {
        return 4u;
    }
    return uint(rounded);
}

int wrap_coord(int value, int limit) {
    if (limit <= 0) {
        return 0;
    }
    int wrapped = value % limit;
    if (wrapped < 0) {
        wrapped += limit;
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
    if (value == 0.0) {
        return 0.0;
    }
    float magnitude = pow(abs(value), 1.0 / 3.0);
    return value >= 0.0 ? magnitude : -magnitude;
}

float oklab_luminance(vec3 rgb) {
    float r_lin = srgb_to_linear(clamp01(rgb.x));
    float g_lin = srgb_to_linear(clamp01(rgb.y));
    float b_lin = srgb_to_linear(clamp01(rgb.z));

    float l = 0.4121656120 * r_lin + 0.5362752080 * g_lin + 0.0514575653 * b_lin;
    float m = 0.2118591070 * r_lin + 0.6807189584 * g_lin + 0.1074065790 * b_lin;
    float s = 0.0883097947 * r_lin + 0.2818474174 * g_lin + 0.6302613616 * b_lin;

    float l_c = cube_root(l);
    float m_c = cube_root(m);
    float s_c = cube_root(s);

    return clamp01(0.2104542553 * l_c + 0.7936177850 * m_c - 0.0040720468 * s_c);
}

float value_luminance(ivec2 coord, uint channelCount) {
    vec4 texel = texelFetch(inputTex, coord, 0);
    if (channelCount <= 2u) {
        return clamp01(texel.x);
    }
    return oklab_luminance(texel.xyz);
}

float normalize_value(float value, float min_value, float max_value) {
    float range = max(max_value - min_value, 1e-6);
    return clamp01((value - min_value) / range);
}

float adjust_contrast(float value, float mean_value, float amount) {
    return (value - mean_value) * amount + mean_value;
}

float lerp(float a, float b, float t) {
    return a + (b - a) * t;
}

const ivec2 DERIVATIVE_OFFSETS[9] = ivec2[9](
    ivec2(-1, -1), ivec2(0, -1), ivec2(1, -1),
    ivec2(-1,  0), ivec2(0,  0), ivec2(1,  0),
    ivec2(-1,  1), ivec2(0,  1), ivec2(1,  1)
);

const float DERIVATIVE_KERNEL_X[9] = float[9](
    0.0, 0.0, 0.0,
    0.0, 1.0, -1.0,
    0.0, 0.0, 0.0
);

const float DERIVATIVE_KERNEL_Y[9] = float[9](
    0.0, 0.0, 0.0,
    0.0, 1.0, 0.0,
    0.0, -1.0, 0.0
);

float contrasted_value(
    ivec2 coord,
    uint channelCount,
    float min_value,
    float max_value,
    float normalized_mean
) {
    float luminance = value_luminance(coord, channelCount);
    float normalized = normalize_value(luminance, min_value, max_value);
    float contrasted = adjust_contrast(normalized, normalized_mean, 2.0);
    return clamp01(contrasted);
}

float derivative_response(
    ivec2 coord,
    int width,
    int height,
    uint channelCount,
    float min_value,
    float max_value,
    float normalized_mean,
    bool invert_source
) {
    float grad_x = 0.0;
    float grad_y = 0.0;
    for (int i = 0; i < 9; ++i) {
        ivec2 offset = coord + DERIVATIVE_OFFSETS[i];
        ivec2 wrapped = ivec2(
            wrap_coord(offset.x, width),
            wrap_coord(offset.y, height)
        );
        float value = contrasted_value(wrapped, channelCount, min_value, max_value, normalized_mean);
        if (invert_source) {
            value = 1.0 - value;
        }
        grad_x += value * DERIVATIVE_KERNEL_X[i];
        grad_y += value * DERIVATIVE_KERNEL_Y[i];
    }
    return sqrt(max(grad_x * grad_x + grad_y * grad_y, 0.0));
}

float vignette_weight(ivec2 coord, float width, float height) {
    vec2 uv = (vec2(coord) + vec2(0.5)) / vec2(width, height);
    vec2 center = vec2(0.5);
    float dist = distance(uv, center);
    float max_dist = 0.5 * SQRT_TWO;
    float normalized = clamp(dist / max_dist, 0.0, 1.0);
    return pow(normalized, 2.0);
}

float hash21(vec2 p) {
    float h = dot(p, vec2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

float triangle_wave(float value) {
    float fractional = fract(value);
    return 1.0 - abs(fractional * 2.0 - 1.0);
}

vec2 rotate_2d(vec2 point, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return vec2(
        point.x * c - point.y * s,
        point.x * s + point.y * c
    );
}

float hatch_pattern(vec2 uv, float angle, float density, float phase) {
    vec2 rotated = rotate_2d(uv - vec2(0.5), angle) + vec2(0.5);
    float stripe = triangle_wave(rotated.x * density + phase);
    return clamp01(stripe);
}

float crosshatch_value(
    ivec2 coord,
    float vignette_value,
    float time_value,
    float speed_value,
    float width,
    float height
) {
    vec2 uv = (vec2(coord) + vec2(0.5)) / vec2(width, height);
    float darkness = clamp01(1.0 - vignette_value);
    float density_base = lerp(32.0, 220.0, pow(darkness, 0.85));

    float animation = time_value * (0.5 + speed_value * 0.25);
    vec2 noise_seed = uv * vec2(width * 0.5, height * 0.5);
    float jitter = hash21(noise_seed + vec2(animation, animation * 1.37));

    float pattern0 = hatch_pattern(uv, 0.0, density_base, animation * 0.5 + jitter * 2.0);
    float pattern1 = hatch_pattern(uv, PI * 0.25, density_base * 0.85, animation * 0.75 + jitter * 1.3);
    float pattern2 = hatch_pattern(uv, -PI * 0.25, density_base * 0.9, animation * 0.95 + jitter * 3.7);

    float combined = min(pattern0, min(pattern1, pattern2));
    float texture_noise = hash21(noise_seed * 1.75 + vec2(animation * 0.25, animation * 0.62));

    float modulated = lerp(combined, texture_noise, 0.25);
    float attenuated = lerp(1.0, modulated, clamp01(pow(darkness, 1.4)));
    return clamp01(1.0 - attenuated);
}

out vec4 fragColor;

void main() {
    ivec2 dimensions = textureSize(inputTex, 0);
    int width = max(dimensions.x, 1);
    int height = max(dimensions.y, 1);

    ivec2 coord = ivec2(int(gl_FragCoord.x), int(gl_FragCoord.y));
    if (coord.x < 0 || coord.y < 0 || coord.x >= width || coord.y >= height) {
        return;
    }

    uint channelCount = sanitized_channelCount(size.z);
    float width_f = float(width);
    float height_f = float(height);

    float time_value = controls.x;
    float speed_value = controls.y;

    const float luminance_min = 0.0;
    const float luminance_max = 1.0;
    const float normalized_mean = 0.5;
    const float outline_mean = 0.5;

    const float outline_range = 1.0;
    const float vignette_range = 1.0;
    const float cross_range = 1.0;
    const float contrasted_outline_min = 0.0;
    const float vignette_min = 0.0;
    const float cross_min = 0.0;

    vec4 source_color = texelFetch(inputTex, coord, 0);

    float grad_value = derivative_response(
        coord,
        width,
        height,
        channelCount,
        luminance_min,
        luminance_max,
        normalized_mean,
        false
    );
    float grad_inverted = derivative_response(
        coord,
        width,
        height,
        channelCount,
        luminance_min,
        luminance_max,
        normalized_mean,
        true
    );
    float outline_primary = 1.0 - grad_value;
    float outline_secondary = 1.0 - grad_inverted;
    float combined_outline = min(outline_primary, outline_secondary);
    float contrasted_outline = adjust_contrast(combined_outline, outline_mean, 0.25);
    float normalized_outline = clamp01((contrasted_outline - contrasted_outline_min) / outline_range);

    float contrasted = contrasted_value(
        coord,
        channelCount,
        luminance_min,
        luminance_max,
        normalized_mean
    );
    float vignette_weight_value = vignette_weight(coord, width_f, height_f);
    float edges = lerp(contrasted, 1.0, vignette_weight_value);
    float vignette_value = lerp(contrasted, edges, 0.875);
    float normalized_vignette = clamp01((vignette_value - vignette_min) / vignette_range);

    float cross_value = crosshatch_value(
        coord,
        normalized_vignette,
        time_value,
        speed_value,
        width_f,
        height_f
    );
    float normalized_cross = clamp01((cross_value - cross_min) / cross_range);

    float blended = lerp(normalized_cross, normalized_outline, 0.75);

    vec2 uv = (vec2(coord) + vec2(0.5)) / vec2(width_f, height_f);
    vec2 displacement_seed = uv * vec2(width_f, height_f) * 0.125;
    float warp_noise_a = hash21(displacement_seed + vec2(time_value * speed_value, 0.37));
    float warp_noise_b = hash21(displacement_seed * 1.37 + vec2(0.19, time_value * 0.5));
    float warp_offset = (warp_noise_a - warp_noise_b) * 0.0025;
    float warped = clamp01(blended + warp_offset);

    float final_value = clamp01(warped * warped);
    fragColor = vec4(final_value, final_value, final_value, source_color.w);
}