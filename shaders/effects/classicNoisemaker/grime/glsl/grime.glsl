#version 300 es

precision highp float;
precision highp int;

// Grime: dusty speckles and grime derived from Noisemaker's Python reference.
// Translated to WGSL with matching parameters (time, speed) and 4-channel output.

const uint CHANNEL_COUNT = 4u;

uniform sampler2D inputTex;
uniform vec2 resolution;
uniform float time;
uniform float speed;
uniform float strength;
uniform float debugMode;

out vec4 fragColor;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

vec2 freq_for_shape(float freq, float width, float height) {
    if (width <= 0.0 || height <= 0.0) {
        return vec2(freq, freq);
    }

    if (abs(width - height) < 0.5) {
        return vec2(freq, freq);
    }

    if (height < width) {
        float scaled = freq * width / height;
        return vec2(freq, scaled);
    }

    float scaled = freq * height / width;
    return vec2(scaled, freq);
}

float hash21(vec2 p) {
    float dot_value = dot(p, vec2(127.1, 311.7));
    return fract(sin(dot_value) * 43758.5453123);
}

float hash31(vec3 p) {
    float dot_value = dot(p, vec3(127.1, 311.7, 74.7));
    return fract(sin(dot_value) * 43758.5453123);
}

float fade(float value) {
    return value * value * (3.0 - 2.0 * value);
}

float value_noise(vec2 coord, float seed) {
    vec2 cell = floor(coord);
    vec2 frac_part = fract(coord);

    float top_left = hash31(vec3(cell, seed));
    float top_right = hash31(vec3(cell + vec2(1.0, 0.0), seed));
    float bottom_left = hash31(vec3(cell + vec2(0.0, 1.0), seed));
    float bottom_right = hash31(vec3(cell + vec2(1.0, 1.0), seed));

    vec2 smooth_t = vec2(fade(frac_part.x), fade(frac_part.y));
    float top = mix(top_left, top_right, smooth_t.x);
    float bottom = mix(bottom_left, bottom_right, smooth_t.x);
    return mix(top, bottom, smooth_t.y);
}

vec2 periodic_offset(float time_value, float speed_value, float seed) {
    float angle = time_value * 0.5 + seed * 0.1375;
    float radius = (0.35 + speed_value * 0.15) * (0.25 + 0.75 * sin(seed * 1.37));
    return vec2(cos(angle), sin(angle)) * radius;
}

float simple_multires(
    vec2 uv,
    vec2 base_freq,
    float time_value,
    float speed_value,
    uint octaves,
    float seed
) {
    vec2 freq = base_freq;
    float amplitude = 0.5;
    float total_weight = 0.0;
    float accum = 0.0;
    uint octave = 0u;
    
    // Cap octaves to 4 for performance
    uint max_octaves = min(octaves, 4u);

    for (uint i = 0u; i < 4u; i++) {
        if (octave >= max_octaves) {
            break;
        }

        float octave_seed = seed + float(octave) * 37.11;
        vec2 offset = periodic_offset(
            time_value + float(octave) * 0.17,
            speed_value,
            octave_seed
        );
        vec2 sample_coord = uv * freq + offset;
        float sample_value = value_noise(sample_coord, octave_seed);

        accum = accum + sample_value * amplitude;
        total_weight = total_weight + amplitude;
        freq = freq * 2.0;
        amplitude = amplitude * 0.5;
        octave = octave + 1u;
    }

    if (total_weight > 0.0) {
        accum = accum / total_weight;
    }

    return clamp01(accum);
}

float refracted_scalar_field(
    vec2 uv,
    vec2 base_freq,
    float time_value,
    float speed_value,
    vec2 pixel_size,
    float displacement,
    float seed
) {
    float base_mask = simple_multires(uv, base_freq, time_value, speed_value, 8u, seed);
    vec2 offset_uv = fract(uv + vec2(0.5, 0.5));
    float offset_mask = simple_multires(
        offset_uv,
        base_freq,
        time_value,
        speed_value,
        8u,
        seed + 19.0
    );

    vec2 offset_vec = vec2(
        (base_mask * 2.0 - 1.0) * displacement * pixel_size.x,
        (offset_mask * 2.0 - 1.0) * displacement * pixel_size.y
    );
    vec2 warped_uv = fract(uv + offset_vec);
    return simple_multires(warped_uv, base_freq, time_value, speed_value, 8u, seed + 41.0);
}

float chebyshev_gradient(
    vec2 uv,
    vec2 base_freq,
    float time_value,
    float speed_value,
    vec2 pixel_size,
    float displacement,
    float seed
) {
    vec2 offset_x = vec2(pixel_size.x, 0.0);
    vec2 offset_y = vec2(0.0, pixel_size.y);

    float right = refracted_scalar_field(
        fract(uv + offset_x),
        base_freq,
        time_value,
        speed_value,
        pixel_size,
        displacement,
        seed
    );
    float left = refracted_scalar_field(
        fract(uv - offset_x),
        base_freq,
        time_value,
        speed_value,
        pixel_size,
        displacement,
        seed
    );
    float up = refracted_scalar_field(
        fract(uv + offset_y),
        base_freq,
        time_value,
        speed_value,
        pixel_size,
        displacement,
        seed
    );
    float down = refracted_scalar_field(
        fract(uv - offset_y),
        base_freq,
        time_value,
        speed_value,
        pixel_size,
        displacement,
        seed
    );

    float dx = (right - left) * 0.5;
    float dy = (up - down) * 0.5;
    float gradient = max(abs(dx), abs(dy));
    return clamp01(gradient * 4.0);
}

float dropout_mask(vec2 uv, vec2 dims, float seed) {
    float rnd = hash21(uv * dims + vec2(seed, seed * 1.37));
    return (rnd < 0.25 ? 1.0 : 0.0);
}

float exponential_noise(
    vec2 uv,
    vec2 freq,
    float time_value,
    float speed_value,
    float seed
) {
    vec2 offset = periodic_offset(time_value + seed * 0.07, speed_value, seed + 7.0);
    float noise_value = value_noise(uv * freq + offset, seed + 13.0);
    return pow(clamp01(noise_value), 4.0);
}

float refracted_exponential(
    vec2 uv,
    vec2 freq,
    float time_value,
    float speed_value,
    vec2 pixel_size,
    float displacement,
    float seed
) {
    float base = exponential_noise(uv, freq, time_value, speed_value, seed);
    float offset_x = exponential_noise(uv, freq, time_value + 0.77, speed_value, seed + 23.0);
    vec2 shifted_uv = fract(uv + vec2(0.5, 0.5));
    float offset_y = exponential_noise(shifted_uv, freq, time_value + 1.23, speed_value, seed + 47.0);

    vec2 offset_vec = vec2(
        (offset_x * 2.0 - 1.0) * displacement * pixel_size.x,
        (offset_y * 2.0 - 1.0) * displacement * pixel_size.y
    );
    vec2 warped_uv = fract(uv + offset_vec);
    float warped = exponential_noise(warped_uv, freq, time_value, speed_value, seed + 59.0);
    return clamp01((base + warped) * 0.5);
}

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = max(as_u32(resolution.x), 1u);
    uint height = max(as_u32(resolution.y), 1u);

    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    ivec2 coords = ivec2(int(global_id.x), int(global_id.y));
    vec4 base_color = texelFetch(inputTex, coords, 0);

    vec2 dims = vec2(
        max(resolution.x, 1.0),
        max(resolution.y, 1.0)
    );
    vec2 pixel_size = vec2(1.0 / dims.x, 1.0 / dims.y);
    vec2 uv = (vec2(float(global_id.x), float(global_id.y)) + 0.5) * pixel_size;

    float time_value = time;
    float speed_value = speed;
    float strength_val = max(strength, 0.0);
    float debug_mode = debugMode;

    vec2 freq_mask = freq_for_shape(5.0, dims.x, dims.y);
    float mask_refracted = refracted_scalar_field(
        uv,
        freq_mask,
        time_value,
        speed_value,
        pixel_size,
        1.0,
        11.0
    );
    float mask_gradient = chebyshev_gradient(
        uv,
        freq_mask,
        time_value,
        speed_value,
        pixel_size,
        1.0,
        11.0
    );
    float mask_value = clamp01(mix(mask_refracted, mask_gradient, 0.125));

    float mask_power = clamp01(mask_value * mask_value * 0.075);
    vec3 dusty = mix(
        base_color.xyz,
        vec3(0.25, 0.25, 0.25),
        vec3(mask_power)
    );

    vec2 freq_specks = dims * 0.25;
    float dropout = dropout_mask(uv, dims, 37.0);
    float specks_field = refracted_exponential(
        uv,
        freq_specks,
        time_value,
        speed_value,
        pixel_size,
        0.25,
        71.0
    ) * dropout;
    float trimmed = clamp01((specks_field - 0.625) / 0.375);
    float specks = 1.0 - sqrt(trimmed);

    vec2 freq_sparse = dims;
    float sparse_mask = (hash21(uv * dims + vec2(113.0, 171.0)) < 0.15) ? 1.0 : 0.0;
    float sparse_noise = exponential_noise(
        uv,
        freq_sparse,
        time_value,
        speed_value,
        131.0
    ) * sparse_mask;

    dusty = mix(dusty, vec3(sparse_noise), vec3(0.075));
    dusty = dusty * specks;

    float blend_mask = clamp01(mask_value * 0.75 * strength_val);
    
    // Debug visualization modes
    vec3 final_rgb;
    if (debug_mode > 3.5) {
        // Mode 4: Show sparse noise
        final_rgb = vec3(sparse_noise);
    } else if (debug_mode > 2.5) {
        // Mode 3: Show specks
        final_rgb = vec3(specks);
    } else if (debug_mode > 1.5) {
        // Mode 2: Show dusty layer
        final_rgb = dusty;
    } else if (debug_mode > 0.5) {
        // Mode 1: Show mask
        final_rgb = vec3(mask_value);
    } else {
        // Mode 0: Normal blending - blend the dusty grime layer over the input
        // For now, just show the dusty layer directly to verify it's not identical to input
        final_rgb = clamp(dusty, vec3(0.0), vec3(1.0));
    }
    
    fragColor = vec4(
        clamp01(final_rgb.x),
        clamp01(final_rgb.y),
        clamp01(final_rgb.z),
        base_color.w
    );
}
