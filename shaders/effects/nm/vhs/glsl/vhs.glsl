#version 300 es

precision highp float;
precision highp int;

// Bad VHS tracking effect replicating noisemaker.effects.vhs.
// Optimized to compute noise values efficiently by minimizing redundant calculations.

const float TAU = 6.28318530717958647692;
const uint CHANNEL_COUNT = 4u;


uniform sampler2D input_texture;
uniform vec4 size;
uniform vec4 motion;

// Simple hash function for pseudo-random values
float hash(vec3 p) {
    vec3 p3 = fract(p * 0.1031);
    p3 = p3 + dot(p3, vec3(p3.y, p3.z, p3.x) + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

// Fast value noise using simple hash-based interpolation
float value_noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    
    // Smooth interpolation
    vec3 u = f * f * (3.0 - 2.0 * f);
    
    // 8 corners of the cube
    float c000 = hash(i + vec3(0.0, 0.0, 0.0));
    float c100 = hash(i + vec3(1.0, 0.0, 0.0));
    float c010 = hash(i + vec3(0.0, 1.0, 0.0));
    float c110 = hash(i + vec3(1.0, 1.0, 0.0));
    float c001 = hash(i + vec3(0.0, 0.0, 1.0));
    float c101 = hash(i + vec3(1.0, 0.0, 1.0));
    float c011 = hash(i + vec3(0.0, 1.0, 1.0));
    float c111 = hash(i + vec3(1.0, 1.0, 1.0));
    
    // Trilinear interpolation
    return mix(
        mix(mix(c000, c100, u.x), mix(c010, c110, u.x), u.y),
        mix(mix(c001, c101, u.x), mix(c011, c111, u.x), u.y),
        u.z
    );
}

float periodic_value(float time, float value) {
    return sin((time - value) * TAU) * 0.5 + 0.5;
}


// Compute value noise with time modulation
float compute_value_noise(vec2 coord, vec2 freq, float time, float speed,
                         vec3 base_offset, vec3 time_offset) {
    vec3 p = vec3(
        coord.x * freq.x + base_offset.x,
        coord.y * freq.y + base_offset.y,
        cos(time * TAU) * speed + base_offset.z
    );
    
    float value = value_noise(p);
    
    if (speed != 0.0 && time != 0.0) {
        vec3 time_p = vec3(
            coord.x * freq.x + time_offset.x,
            coord.y * freq.y + time_offset.y,
            time_offset.z
        );
        float time_value = value_noise(time_p);
        float scaled_time = periodic_value(time, time_value) * speed;
        value = periodic_value(scaled_time, value);
    }
    
    return clamp(value, 0.0, 1.0);
}

// Compute gradient noise for VHS effect (varies vertically, constant horizontally)
float compute_grad_value(float y_norm, float freq_y, float time, float speed) {
    // Only sample along Y axis (X is fixed at 0.0) for horizontal consistency
    vec2 coord = vec2(0.0, y_norm);
    vec2 freq = vec2(1.0, freq_y);
    
    float base = compute_value_noise(
        coord,
        freq,
        time,
        speed,
        vec3(17.0, 29.0, 47.0),
        vec3(71.0, 113.0, 191.0)
    );
    
    float g = max(base - 0.5, 0.0);
    g = min(g * 2.0, 1.0);
    return g;
}

// Compute scan noise for VHS effect
float compute_scan_noise(vec2 coord, vec2 freq, float time, float speed) {
    return compute_value_noise(
        coord,
        freq,
        time,
        speed,
        vec3(37.0, 59.0, 83.0),
        vec3(131.0, 173.0, 211.0)
    );
}

out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = uint(max(round(size.x), 0.0));
    uint height = uint(max(round(size.y), 0.0));
    
    if (width == 0u || height == 0u || global_id.x >= width || global_id.y >= height) {
        return;
    }

    float width_f = float(width);
    float height_f = float(height);
    float time = motion.x;
    float speed = motion.y;

    // Normalized coordinate for current pixel
    float y_norm = (float(global_id.y) + 0.5) / height_f;
    float x_norm = (float(global_id.x) + 0.5) / width_f;
    vec2 dest_coord = vec2(x_norm, y_norm);

    // Compute gradient noise (varies vertically only, constant per row)
    float grad_freq_y = 5.0;
    float grad_dest = compute_grad_value(y_norm, grad_freq_y, time, speed);

    // Compute scan noise frequency
    float scan_base_freq = floor(height_f * 0.5) + 1.0;
    vec2 scan_freq = select(
        vec2(scan_base_freq * (height_f / width_f), scan_base_freq),
        vec2(scan_base_freq, scan_base_freq * (width_f / height_f)),
        height_f < width_f
    );
    
    // Compute scan noise at destination
    float scan_dest = compute_scan_noise(dest_coord, scan_freq, time, speed * 100.0);

    // Calculate horizontal shift
    int shift_amount = int(floor(scan_dest * width_f * grad_dest * grad_dest));
    int src_x_wrapped = (int(global_id.x) - shift_amount) % int(width);
    int src_x = select(src_x_wrapped, src_x_wrapped + int(width), src_x_wrapped < 0);
    vec2 src_coord = vec2(src_x, int(global_id.y));

    // Sample source pixel
    vec4 src_texel = texture(input_texture, (vec2(src_coord) + vec2(0.5)) / vec2(textureSize(input_texture, 0)));
    
    // Compute gradient at source location for blending
    float src_x_norm = (float(src_x) + 0.5) / width_f;
    vec2 src_coord_norm = vec2(src_x_norm, y_norm);
    float scan_source = compute_scan_noise(src_coord_norm, scan_freq, time, speed * 100.0);
    float grad_source = compute_grad_value(y_norm, grad_freq_y, time, speed);

    // Blend source with scan noise based on gradient
    vec4 noise_color = vec4(scan_source, scan_source, scan_source, scan_source);
    vec4 blended = mix(src_texel, noise_color, grad_source);

    // Write output
    uint base_index = (global_id.y * width + global_id.x) * CHANNEL_COUNT;
    for (uint channel = 0u; channel < CHANNEL_COUNT; channel = channel + 1u) {
    }
}