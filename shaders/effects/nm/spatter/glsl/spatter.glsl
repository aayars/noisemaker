#version 300 es

precision highp float;
precision highp int;

// Final spatter blend pass. Expects a precomputed mask texture and reuses the
// previously implemented blend_layers logic for feathered transitions between
// the original image and the tinted splash layer.

const uint CHANNEL_CAP = 4u;
const float BLEND_FEATHER = 0.005;


uniform sampler2D input_texture;
uniform vec4 size;
uniform vec4 color;
uniform vec4 timing;
uniform sampler2D mask_texture;

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

vec3 pick_layer(uint index, vec3 base_rgb, vec3 tinted_rgb) {
    if (index == 0u) {
        return base_rgb;
    }
    return tinted_rgb;
}

vec3 blend_spatter_layers(float control, vec3 base_rgb, vec3 tinted_rgb) {
    float normalized = clamp01(control);
    uint layer_count = 2u;
    uint extended_count = layer_count + 1u;
    float scaled = normalized * float(extended_count);
    float floor_value = floor(scaled);
    uint floor_index = min(uint(floor_value), extended_count - 1u);
    uint next_index = (floor_index + 1u) % extended_count;
    vec3 lower_layer = pick_layer(floor_index, base_rgb, tinted_rgb);
    vec3 upper_layer = pick_layer(next_index, base_rgb, tinted_rgb);
    float fract_value = scaled - floor_value;
    float safe_feather = max(BLEND_FEATHER, 1e-6);
    float feather_mix = clamp01((fract_value - (1.0 - safe_feather)) / safe_feather);
    return mix(lower_layer, upper_layer, feather_mix);
}

uint sanitized_channel_count(float channel_value) {
    int rounded = int(round(channel_value));
    if (rounded <= 1) {
        return 1u;
    }
    if (rounded >= int(CHANNEL_CAP)) {
        return CHANNEL_CAP;
    }
    return uint(rounded);
}

float hash21(vec2 p) {
    float h = dot(p, vec2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

vec3 rgb_to_hsv(vec3 rgb) {
    float c_max = max(max(rgb.x, rgb.y), rgb.z);
    float c_min = min(min(rgb.x, rgb.y), rgb.z);
    float delta = c_max - c_min;

    float hue = 0.0;
    if (delta > 0.0) {
        if (c_max == rgb.x) {
            hue = (rgb.y - rgb.z) / delta;
        } else if (c_max == rgb.y) {
            hue = (rgb.z - rgb.x) / delta + 2.0;
        } else {
            hue = (rgb.x - rgb.y) / delta + 4.0;
        }
        hue = fract(hue / 6.0);
    }

    float sat = select(0.0, delta / c_max, c_max > 0.0);
    return vec3(hue, sat, c_max);
}

vec3 hsv_to_rgb(vec3 hsv) {
    float hue = fract(hsv.x) * 6.0;
    float sat = clamp01(hsv.y);
    float val = clamp01(hsv.z);
    float c = val * sat;
    float x = c * (1.0 - abs(fract(hue) * 2.0 - 1.0));
    float m = val - c;
    if (hue < 1.0) {
        return vec3(c + m, x + m, m);
    }
    if (hue < 2.0) {
        return vec3(x + m, c + m, m);
    }
    if (hue < 3.0) {
        return vec3(m, c + m, x + m);
    }
    if (hue < 4.0) {
        return vec3(m, x + m, c + m);
    }
    if (hue < 5.0) {
        return vec3(x + m, m, c + m);
    }
    return vec3(c + m, m, x + m);
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = uint(max(round(size.x), 0.0));
    uint height = uint(max(round(size.y), 0.0));
    if (width == 0u || height == 0u) {
        return;
    }
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    vec2 coords = vec2(int(global_id.x), int(global_id.y));
    vec4 base_color = texture(input_texture, (vec2(coords) + vec2(0.5)) / vec2(textureSize(input_texture, 0)));
    vec4 mask_sample = texture(mask_texture, (vec2(coords) + vec2(0.5)) / vec2(textureSize(mask_texture, 0)));

    uint channel_count = sanitized_channel_count(size.z);
    float color_toggle = color.x;
    float time_value = timing.x;

    vec3 base_splash_rgb = clamp(
        vec3(color.y, color.z, color.w),
        vec3(0.0),
        vec3(1.0),
    );

    vec3 splash_rgb = vec3(0.0, 0.0, 0.0);
    if (color_toggle > 0.5 && channel_count >= 3u) {
        if (color_toggle > 1.5) {
            splash_rgb = base_splash_rgb;
        } else {
            vec3 base_hsv = rgb_to_hsv(base_splash_rgb);
            float hue_jitter = hash21(vec2(floor(time_value * 60.0) + 211.0, 307.0)) - 0.5;
            vec3 randomized_hsv = vec3(
                base_hsv.x + hue_jitter,
                base_hsv.y,
                base_hsv.z,
            );
            splash_rgb = hsv_to_rgb(randomized_hsv);
        }
    }

    vec3 tinted_rgb = base_color.xyz * splash_rgb;
    float mask_value = clamp01(mask_sample.x);
    vec3 final_rgb = blend_spatter_layers(mask_value, base_color.xyz, tinted_rgb);

    uint base_index = (global_id.y * width + global_id.x) * CHANNEL_CAP;
    fragColor = vec4(clamp01(final_rgb.x), clamp01(final_rgb.y), clamp01(final_rgb.z), base_color.w);
}