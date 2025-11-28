// Single-pass spatter effect: generates noise mask and applies tinted blend.
// Combines the functionality of noise_seed, combine, and spatter passes.
// Matches the GLSL implementation.

const CHANNEL_COUNT : u32 = 4u;

struct SpatterParams {
    size : vec4<f32>,   // (width, height, channels, _)
    timing : vec4<f32>, // (time, speed, color, _)
};

@group(0) @binding(0) var inputTex : texture_2d<f32>;
@group(0) @binding(1) var<storage, read_write> output_buffer : array<f32>;
@group(0) @binding(2) var<uniform> params : SpatterParams;

fn clamp01(value : f32) -> f32 {
    return clamp(value, 0.0, 1.0);
}

// Hash functions for procedural noise
fn hash21(p : vec2<f32>) -> f32 {
    let h : f32 = dot(p, vec2<f32>(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

fn hash31(p : vec3<f32>) -> f32 {
    let h : f32 = dot(p, vec3<f32>(127.1, 311.7, 74.7));
    return fract(sin(h) * 43758.5453123);
}

// Smooth interpolation
fn fade(t : f32) -> f32 {
    return t * t * (3.0 - 2.0 * t);
}

// Value noise
fn value_noise(p : vec2<f32>, seed : f32) -> f32 {
    let cell : vec2<f32> = floor(p);
    let f : vec2<f32> = fract(p);
    let tl : f32 = hash31(vec3<f32>(cell, seed));
    let tr : f32 = hash31(vec3<f32>(cell + vec2<f32>(1.0, 0.0), seed));
    let bl : f32 = hash31(vec3<f32>(cell + vec2<f32>(0.0, 1.0), seed));
    let br : f32 = hash31(vec3<f32>(cell + vec2<f32>(1.0, 1.0), seed));
    let st : vec2<f32> = vec2<f32>(fade(f.x), fade(f.y));
    return mix(mix(tl, tr, st.x), mix(bl, br, st.x), st.y);
}

// Offset for animation
fn periodic_offset(t : f32, speed : f32, seed : f32) -> vec2<f32> {
    let angle : f32 = t * (0.35 + speed * 0.15) + seed * 1.97;
    let radius : f32 = 0.25 + 0.45 * hash21(vec2<f32>(seed, seed + 19.0));
    return vec2<f32>(cos(angle), sin(angle)) * radius;
}

// Multi-octave noise with exponential falloff
fn multires_noise(uv : vec2<f32>, base_freq : vec2<f32>, octaves : i32, t : f32, speed : f32, seed : f32) -> f32 {
    var freq : vec2<f32> = base_freq;
    var amplitude : f32 = 0.5;
    var accum : f32 = 0.0;
    var weight : f32 = 0.0;
    for (var i : i32 = 0; i < octaves; i = i + 1) {
        let octave_seed : f32 = seed + f32(i) * 37.17;
        let offset : vec2<f32> = periodic_offset(t + f32(i) * 0.31, speed, octave_seed);
        let sample_val : f32 = value_noise(uv * freq + offset, octave_seed);
        accum = accum + pow(sample_val, 4.0) * amplitude;
        weight = weight + amplitude;
        freq = freq * 2.0;
        amplitude = amplitude * 0.5;
    }
    if (weight > 0.0) {
        return clamp01(accum / weight);
    }
    return 0.0;
}

// Ridge function for mask
fn ridge(v : f32) -> f32 {
    return 1.0 - abs(v * 2.0 - 1.0);
}

// Random range helper
fn random_range(seed : vec2<f32>, min_val : f32, max_val : f32) -> f32 {
    return min_val + hash21(seed) * (max_val - min_val);
}

// HSV conversion
fn rgb_to_hsv(rgb : vec3<f32>) -> vec3<f32> {
    let c_max : f32 = max(max(rgb.r, rgb.g), rgb.b);
    let c_min : f32 = min(min(rgb.r, rgb.g), rgb.b);
    let delta : f32 = c_max - c_min;
    var hue : f32 = 0.0;
    if (delta > 0.0) {
        if (c_max == rgb.r) {
            hue = (rgb.g - rgb.b) / delta;
        } else if (c_max == rgb.g) {
            hue = (rgb.b - rgb.r) / delta + 2.0;
        } else {
            hue = (rgb.r - rgb.g) / delta + 4.0;
        }
        hue = fract(hue / 6.0);
    }
    let sat : f32 = select(0.0, delta / c_max, c_max > 0.0);
    return vec3<f32>(hue, sat, c_max);
}

fn hsv_to_rgb(hsv : vec3<f32>) -> vec3<f32> {
    let h : f32 = fract(hsv.x) * 6.0;
    let s : f32 = clamp01(hsv.y);
    let v : f32 = clamp01(hsv.z);
    let c : f32 = v * s;
    let x : f32 = c * (1.0 - abs(h % 2.0 - 1.0));
    let m : f32 = v - c;
    var rgb : vec3<f32>;
    if (h < 1.0) { rgb = vec3<f32>(c, x, 0.0); }
    else if (h < 2.0) { rgb = vec3<f32>(x, c, 0.0); }
    else if (h < 3.0) { rgb = vec3<f32>(0.0, c, x); }
    else if (h < 4.0) { rgb = vec3<f32>(0.0, x, c); }
    else if (h < 5.0) { rgb = vec3<f32>(x, 0.0, c); }
    else { rgb = vec3<f32>(c, 0.0, x); }
    return rgb + m;
}

@compute @workgroup_size(8, 8, 1)
fn main(@builtin(global_invocation_id) gid : vec3<u32>) {
    let width : u32 = u32(max(round(params.size.x), 0.0));
    let height : u32 = u32(max(round(params.size.y), 0.0));
    if (width == 0u || height == 0u) {
        return;
    }
    if (gid.x >= width || gid.y >= height) {
        return;
    }

    let coords : vec2<i32> = vec2<i32>(i32(gid.x), i32(gid.y));
    let base_color : vec4<f32> = textureLoad(inputTex, coords, 0);
    
    // UV coordinates for noise sampling
    let uv : vec2<f32> = vec2<f32>(f32(gid.x) / f32(width), f32(gid.y) / f32(height));
    let dims : vec2<f32> = vec2<f32>(f32(width), f32(height));
    
    let time_value : f32 = params.timing.x;
    let speed : f32 = 0.5;
    let color_toggle : f32 = params.timing.z;
    
    // Seed for reproducible randomness
    let base_seed : f32 = floor(time_value * 0.5) * 17.3;
    
    // Generate aspect-corrected frequency
    let aspect : f32 = dims.x / dims.y;
    
    // Smear: low frequency base (3-6 octaves)
    let smear_freq : f32 = random_range(vec2<f32>(time_value * 0.17 + base_seed + 3.0, base_seed + 29.0), 3.0, 6.0);
    let smear_freq_adj : vec2<f32> = vec2<f32>(smear_freq, smear_freq * aspect);
    let smear : f32 = multires_noise(uv, smear_freq_adj, 6, time_value, speed, base_seed + 23.0);
    
    // Primary spatter: medium frequency dots (32-64)
    let primary_freq : f32 = random_range(vec2<f32>(time_value * 0.37 + base_seed + 5.0, base_seed + 59.0), 32.0, 64.0);
    let primary_freq_adj : vec2<f32> = vec2<f32>(primary_freq, primary_freq * aspect);
    let primary : f32 = multires_noise(uv, primary_freq_adj, 4, time_value, speed, base_seed + 43.0);
    
    // Secondary spatter: high frequency fine dots (150-200)
    let secondary_freq : f32 = random_range(vec2<f32>(time_value * 0.41 + base_seed + 13.0, base_seed + 97.0), 150.0, 200.0);
    let secondary_freq_adj : vec2<f32> = vec2<f32>(secondary_freq, secondary_freq * aspect);
    let secondary : f32 = multires_noise(uv, secondary_freq_adj, 4, time_value, speed, base_seed + 71.0);
    
    // Removal mask: ridge-filtered low frequency (2-3)
    let removal_freq : f32 = random_range(vec2<f32>(time_value * 0.23 + base_seed + 31.0, base_seed + 149.0), 2.0, 3.0);
    let removal_freq_adj : vec2<f32> = vec2<f32>(removal_freq, removal_freq * aspect);
    let removal_base : f32 = multires_noise(uv, removal_freq_adj, 3, time_value, speed, base_seed + 89.0);
    let removal : f32 = ridge(removal_base);
    
    // Combine masks
    let combined : f32 = max(smear, max(primary, secondary));
    let mask : f32 = clamp01(combined - removal);
    
    // Determine splash color
    var splash_rgb : vec3<f32> = vec3<f32>(0.7, 0.2, 0.1);  // Default reddish-brown color
    
    if (color_toggle > 0.5) {
        if (color_toggle > 1.5) {
            // Fixed color mode - keep default
        } else {
            // Randomized hue mode
            let base_hsv : vec3<f32> = rgb_to_hsv(splash_rgb);
            let hue_jitter : f32 = hash21(vec2<f32>(floor(time_value * 60.0) + 211.0, 307.0)) - 0.5;
            splash_rgb = hsv_to_rgb(vec3<f32>(base_hsv.x + hue_jitter, base_hsv.y, base_hsv.z));
        }
    } else {
        splash_rgb = vec3<f32>(0.0);  // No color - black
    }
    
    // Blend with original based on mask
    let tinted : vec3<f32> = base_color.rgb * splash_rgb;
    let final_rgb : vec3<f32> = mix(base_color.rgb, tinted, mask);
    
    let base_index : u32 = (gid.y * width + gid.x) * CHANNEL_COUNT;
    output_buffer[base_index + 0u] = clamp01(final_rgb.x);
    output_buffer[base_index + 1u] = clamp01(final_rgb.y);
    output_buffer[base_index + 2u] = clamp01(final_rgb.z);
    output_buffer[base_index + 3u] = base_color.a;
}
