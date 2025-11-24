#version 300 es
precision highp float;
precision highp int;

uniform sampler2D inputTexture;
uniform vec4 size;      // (width, height, channels, unused)
uniform vec4 timeSpeed; // (time, speed, unused, unused)

out vec4 fragColor;

const float PI = 3.141592653589793;
const uint CHANNEL_COUNT = 4u;

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

uint as_u32(float value) {
    if (value <= 0.0) {
        return 0u;
    }
    return uint(value + 0.5);
}

int as_i32(float value) {
    if (value <= 0.0) {
        return 0;
    }
    return int(value + 0.5);
}

float luminance(vec3 rgb) {
    return dot(rgb, vec3(0.299, 0.587, 0.114));
}

float hash21(vec2 p) {
    float h = dot(p, vec2(127.1, 311.7));
    return fract(sin(h) * 43758.5453);
}

float hash31(vec3 p) {
    float h = dot(p, vec3(12.9898, 78.233, 37.719));
    return fract(sin(h) * 43758.5453);
}

float fade(float t) {
    return t * t * (3.0 - 2.0 * t);
}

float value_noise(vec2 p, float seed) {
    vec2 cell = floor(p);
    vec2 local = fract(p);

    float a = hash21(vec2(cell.x + seed, cell.y - seed));
    float b = hash21(vec2(cell.x + 1.0 - seed, cell.y + seed));
    float c = hash21(vec2(cell.x - seed, cell.y + 1.0 + seed));
    float d = hash21(vec2(cell.x + 1.0 + seed, cell.y + 1.0 - seed));

    float ux = fade(local.x);
    float uy = fade(local.y);
    float lerp_x0 = mix(a, b, ux);
    float lerp_x1 = mix(c, d, ux);
    return mix(lerp_x0, lerp_x1, uy);
}

float simple_multires(
    vec2 uv,
    vec2 base_freq,
    float time_value,
    float speed_value,
    int octaves,
    float seed
) {
    vec2 freq = base_freq;
    float amplitude = 0.5;
    float total_weight = 0.0;
    float accum = 0.0;
    
    for (int octave = 0; octave < octaves; octave++) {
        float octave_seed = seed + float(octave) * 19.37;
        vec2 offset = vec2(
            time_value * (0.05 + speed_value * 0.02) + octave_seed * 0.11,
            time_value * (0.09 + speed_value * 0.015) - octave_seed * 0.07
        );
        float sample_val = value_noise(uv * freq + offset, octave_seed);

        accum += sample_val * amplitude;
        total_weight += amplitude;
        freq *= 2.0;
        amplitude *= 0.5;
    }
    
    if (total_weight > 0.0) {
        return accum / total_weight;
    }
    return 0.0;
}

vec4 safe_load(int x, int y, int width, int height) {
    int sx = clamp(x, 0, max(width - 1, 0));
    int sy = clamp(y, 0, max(height - 1, 0));
    return texelFetch(inputTexture, ivec2(sx, sy), 0);
}

vec3 adjust_brightness(vec3 rgb, float value) {
    return clamp(rgb + vec3(value), vec3(0.0), vec3(1.0));
}

vec3 adjust_contrast(vec3 rgb, float contrast) {
    vec3 mid = vec3(0.5);
    return clamp((rgb - mid) * contrast + mid, vec3(0.0), vec3(1.0));
}

vec3 adjust_saturation(vec3 rgb, float factor) {
    float gray = luminance(rgb);
    vec3 base = vec3(gray, gray, gray);
    return clamp(base + (rgb - base) * factor, vec3(0.0), vec3(1.0));
}

vec3 rotate_hue(vec3 rgb, float angle) {
    float cos_a = cos(angle);
    float sin_a = sin(angle);

    mat3 to_yiq = mat3(
        vec3(0.299, 0.587, 0.114),
        vec3(0.596, -0.274, -0.322),
        vec3(0.211, -0.523, 0.312)
    );
    mat3 from_yiq = mat3(
        vec3(1.0, 0.956, 0.621),
        vec3(1.0, -0.272, -0.647),
        vec3(1.0, -1.105, 1.702)
    );

    vec3 yiq = to_yiq * rgb; // Matrix * vector
    float i = yiq.y * cos_a - yiq.z * sin_a;
    float q = yiq.y * sin_a + yiq.z * cos_a;
    return clamp(from_yiq * vec3(yiq.x, i, q), vec3(0.0), vec3(1.0));
}

float chebyshev_distance(vec2 uv, vec2 aspect) {
    vec2 centered = abs(uv - vec2(0.5, 0.5));
    return max(centered.x * aspect.x, centered.y * aspect.y);
}

float frame_mask_value(
    vec2 uv,
    vec2 aspect,
    float time_value,
    float speed_value,
    float seed_value
) {
    float dist = chebyshev_distance(uv, aspect);
    float noise = simple_multires(
        uv,
        vec2(64.0, 64.0),
        time_value + seed_value * 2.0,
        speed_value,
        8,
        11.0
    );
    // Narrower frame with subtle anti-aliased edge
    float threshold = 0.38 + (noise - 0.5) * 0.025;
    float edge_width = 0.008; // Small AA band
    float mask = clamp((dist - threshold) / edge_width, 0.0, 1.0);
    return mask;
}

float vignette_mask(vec2 uv, vec2 aspect) {
    float dist = length((uv - vec2(0.5, 0.5)) * aspect);
    return clamp(dist, 0.0, 1.0);
}

vec3 light_leak_color(vec2 uv, float time_value, float speed_value) {
    float motion = time_value * (0.1 + speed_value * 0.05);
    float corner = pow(clamp01((1.0 - uv.x) * uv.y), 2.2);
    float sweep = sin((uv.x + uv.y + motion) * PI) * 0.5 + 0.5;
    vec3 warm = vec3(1.0, 0.75, 0.55);
    vec3 cool = vec3(0.75, 0.6, 1.0);
    return mix(cool, warm, sweep) * (0.08 + corner * 0.25);
}

float grime_overlay(vec2 uv, float time_value, float speed_value, float seed_value) {
    float drift = time_value * (0.25 + speed_value * 0.1);
    float coarse = simple_multires(
        uv + vec2(drift, -drift * 0.5),
        vec2(8.0, 8.0),
        time_value,
        speed_value,
        8,
        seed_value * 3.1
    );
    float streaks = simple_multires(
        vec2(uv.x * 2.0, uv.y * 6.0) + drift,
        vec2(12.0, 18.0),
        time_value,
        speed_value,
        8,
        seed_value * 4.7
    );
    float speck = pow(
        clamp01(1.0 - abs(fract(uv.y * 180.0 + seed_value * 5.0) - 0.5) * 2.0),
        6.0
    );
    return clamp(coarse * 0.7 + streaks * 0.2 + speck * 0.3, 0.0, 1.0);
}

float scratch_mask(vec2 uv, float time_value, float speed_value, float seed_value) {
    // Temporarily disable scratches to test if they're causing the vertical lines
    return 0.0;
}

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = max(as_u32(size.x), 1u);
    uint height = max(as_u32(size.y), 1u);
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    float width_f = max(size.x, 1.0);
    float height_f = max(size.y, 1.0);
    float time_value = timeSpeed.x;
    float speed_value = timeSpeed.y;
    float seed_value = hash31(vec3(
        time_value * 0.123,
        speed_value * 1.37,
        0.417
    ));

    vec2 coords = vec2(float(global_id.x), float(global_id.y));
    vec4 sample_val = texelFetch(inputTexture, ivec2(coords), 0);

    int width_i = as_i32(size.x);
    int height_i = as_i32(size.y);

    vec3 color = sample_val.xyz;
    color = adjust_brightness(color, 0.1);
    color = adjust_contrast(color, 0.75);

    vec2 uv = (coords + vec2(0.5)) / vec2(width_f, height_f);
    vec2 aspect = vec2(width_f / height_f, 1.0);

    vec3 leak_color = clamp(
        color + light_leak_color(uv, time_value, speed_value),
        vec3(0.0),
        vec3(1.0)
    );
    color = mix(color, leak_color, 0.125);

    float vignette = pow(clamp01(vignette_mask(uv, aspect)), 1.25);
    color = mix(color, color * 0.75 + vec3(0.05) * 0.25, vignette * 0.75);

    float mask_value = frame_mask_value(uv, aspect, time_value, speed_value, seed_value);

    float base_noise = simple_multires(
        uv,
        vec2(64.0, 64.0),
        time_value,
        speed_value,
        8,
        7.0
    );
    vec2 delta_x = vec2(1.0 / width_f, 0.0);
    vec2 delta_y = vec2(0.0, 1.0 / height_f);
    float grad_x = simple_multires(
        uv + delta_x,
        vec2(64.0, 64.0),
        time_value,
        speed_value,
        8,
        9.0
    ) - base_noise;
    float grad_y = simple_multires(
        uv + delta_y,
        vec2(64.0, 64.0),
        time_value,
        speed_value,
        8,
        13.0
    ) - base_noise;
    float gradient_mag = clamp01(length(vec2(grad_x, grad_y)) * 12.0);
    float edge_value = 0.9 + gradient_mag * 0.1;
    vec3 edge_texture = vec3(edge_value);
    
    // Frame should fully replace image where mask > 0, not blend
    vec3 blended_frame = clamp(
        (mask_value > 0.5) ? edge_texture : color,
        vec3(0.0),
        vec3(1.0)
    );

    vec3 chroma = blended_frame;
    // Only apply aberration where mask is low (center area, not frame)
    float aberration = 0.00666 * (1.0 - mask_value);
    int offset = int(round(aberration * width_f));
    if (offset > 0) {
        vec3 red_sample = safe_load(int(coords.x) + offset, int(coords.y), width_i, height_i).xyz;
        vec3 blue_sample = safe_load(int(coords.x) - offset, int(coords.y), width_i, height_i).xyz;
        chroma.x = clamp01(mix(chroma.x, red_sample.x, 0.35));
        chroma.z = clamp01(mix(chroma.z, blue_sample.z, 0.35));
    }

    float grime = grime_overlay(uv, time_value, speed_value, seed_value);
    chroma = mix(chroma, chroma * 0.82 + vec3(0.24, 0.18, 0.12) * 0.35, grime * 0.5);

    float scratches = scratch_mask(uv, time_value, speed_value, seed_value);
    float scratch_lift = clamp01(scratches * 8.0);
    chroma = max(chroma, vec3(scratch_lift));

    float grain_strength = 0.35;
    vec3 grain_seed = vec3(
        uv * vec2(width_f, height_f),
        time_value * speed_value + seed_value * 13.0
    );
    float grain_noise = (
        hash31(grain_seed + vec3(0.37, 0.11, 0.53)) - 0.5
    ) * grain_strength;
    chroma = clamp(
        chroma + grain_noise * (0.25 + mask_value * 0.3),
        vec3(0.0),
        vec3(1.0)
    );

    chroma = adjust_saturation(chroma, 0.5);
    float hue_shift = (hash31(vec3(seed_value, time_value, speed_value)) - 0.5) * 0.1;
    chroma = rotate_hue(chroma, hue_shift);

    float alpha = clamp01(sample_val.w * mix(1.0, 0.88, mask_value));

    fragColor = vec4(chroma, alpha);
}
