#version 300 es

precision highp float;
precision highp int;

// Single-pass spatter effect: generates noise mask and applies tinted blend.
// Combines the functionality of noise_seed, combine, and spatter passes.

uniform sampler2D inputTex;
uniform float time;
uniform float color;  // 0 = no color, 1 = randomized hue, 2+ = fixed color

in vec2 v_texCoord;
out vec4 fragColor;

// Hash functions for procedural noise
float hash21(vec2 p) {
    float h = dot(p, vec2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

float hash31(vec3 p) {
    float h = dot(p, vec3(127.1, 311.7, 74.7));
    return fract(sin(h) * 43758.5453123);
}

// Smooth interpolation
float fade(float t) {
    return t * t * (3.0 - 2.0 * t);
}

// Value noise
float value_noise(vec2 p, float seed) {
    vec2 cell = floor(p);
    vec2 f = fract(p);
    float tl = hash31(vec3(cell, seed));
    float tr = hash31(vec3(cell + vec2(1.0, 0.0), seed));
    float bl = hash31(vec3(cell + vec2(0.0, 1.0), seed));
    float br = hash31(vec3(cell + vec2(1.0, 1.0), seed));
    vec2 st = vec2(fade(f.x), fade(f.y));
    return mix(mix(tl, tr, st.x), mix(bl, br, st.x), st.y);
}

// Offset for animation
vec2 periodic_offset(float t, float speed, float seed) {
    float angle = t * (0.35 + speed * 0.15) + seed * 1.97;
    float radius = 0.25 + 0.45 * hash21(vec2(seed, seed + 19.0));
    return vec2(cos(angle), sin(angle)) * radius;
}

// Multi-octave noise with exponential falloff
float multires_noise(vec2 uv, vec2 base_freq, int octaves, float t, float speed, float seed) {
    vec2 freq = base_freq;
    float amplitude = 0.5;
    float accum = 0.0;
    float weight = 0.0;
    for (int i = 0; i < octaves; i++) {
        float octave_seed = seed + float(i) * 37.17;
        vec2 offset = periodic_offset(t + float(i) * 0.31, speed, octave_seed);
        float sample_val = value_noise(uv * freq + offset, octave_seed);
        accum += pow(sample_val, 4.0) * amplitude;
        weight += amplitude;
        freq *= 2.0;
        amplitude *= 0.5;
    }
    return weight > 0.0 ? clamp(accum / weight, 0.0, 1.0) : 0.0;
}

// Ridge function for mask
float ridge(float v) {
    return 1.0 - abs(v * 2.0 - 1.0);
}

// Random range helper
float random_range(vec2 seed, float min_val, float max_val) {
    return min_val + hash21(seed) * (max_val - min_val);
}

// HSV conversion
vec3 rgb_to_hsv(vec3 rgb) {
    float c_max = max(max(rgb.r, rgb.g), rgb.b);
    float c_min = min(min(rgb.r, rgb.g), rgb.b);
    float delta = c_max - c_min;
    float hue = 0.0;
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
    float sat = c_max > 0.0 ? delta / c_max : 0.0;
    return vec3(hue, sat, c_max);
}

vec3 hsv_to_rgb(vec3 hsv) {
    float h = fract(hsv.x) * 6.0;
    float s = clamp(hsv.y, 0.0, 1.0);
    float v = clamp(hsv.z, 0.0, 1.0);
    float c = v * s;
    float x = c * (1.0 - abs(mod(h, 2.0) - 1.0));
    float m = v - c;
    vec3 rgb;
    if (h < 1.0) rgb = vec3(c, x, 0.0);
    else if (h < 2.0) rgb = vec3(x, c, 0.0);
    else if (h < 3.0) rgb = vec3(0.0, c, x);
    else if (h < 4.0) rgb = vec3(0.0, x, c);
    else if (h < 5.0) rgb = vec3(x, 0.0, c);
    else rgb = vec3(c, 0.0, x);
    return rgb + m;
}

void main() {
    vec4 base_color = texture(inputTex, v_texCoord);
    vec2 dims = vec2(textureSize(inputTex, 0));
    
    // Seed for reproducible randomness
    float base_seed = floor(time * 0.5) * 17.3;
    float speed = 0.5;
    
    // Generate aspect-corrected frequency
    float aspect = dims.x / dims.y;
    
    // Smear: low frequency base (3-6 octaves)
    float smear_freq = random_range(vec2(time * 0.17 + base_seed + 3.0, base_seed + 29.0), 3.0, 6.0);
    vec2 smear_freq_adj = vec2(smear_freq, smear_freq * aspect);
    float smear = multires_noise(v_texCoord, smear_freq_adj, 6, time, speed, base_seed + 23.0);
    
    // Primary spatter: medium frequency dots (32-64)
    float primary_freq = random_range(vec2(time * 0.37 + base_seed + 5.0, base_seed + 59.0), 32.0, 64.0);
    vec2 primary_freq_adj = vec2(primary_freq, primary_freq * aspect);
    float primary = multires_noise(v_texCoord, primary_freq_adj, 4, time, speed, base_seed + 43.0);
    
    // Secondary spatter: high frequency fine dots (150-200)
    float secondary_freq = random_range(vec2(time * 0.41 + base_seed + 13.0, base_seed + 97.0), 150.0, 200.0);
    vec2 secondary_freq_adj = vec2(secondary_freq, secondary_freq * aspect);
    float secondary = multires_noise(v_texCoord, secondary_freq_adj, 4, time, speed, base_seed + 71.0);
    
    // Removal mask: ridge-filtered low frequency (2-3)
    float removal_freq = random_range(vec2(time * 0.23 + base_seed + 31.0, base_seed + 149.0), 2.0, 3.0);
    vec2 removal_freq_adj = vec2(removal_freq, removal_freq * aspect);
    float removal_base = multires_noise(v_texCoord, removal_freq_adj, 3, time, speed, base_seed + 89.0);
    float removal = ridge(removal_base);
    
    // Combine masks
    float combined = max(smear, max(primary, secondary));
    float mask = clamp(combined - removal, 0.0, 1.0);
    
    // Determine splash color
    vec3 splash_rgb = vec3(0.7, 0.2, 0.1);  // Default reddish-brown color
    
    if (color > 0.5) {
        if (color > 1.5) {
            // Fixed color mode - keep default
        } else {
            // Randomized hue mode
            vec3 base_hsv = rgb_to_hsv(splash_rgb);
            float hue_jitter = hash21(vec2(floor(time * 60.0) + 211.0, 307.0)) - 0.5;
            splash_rgb = hsv_to_rgb(vec3(base_hsv.x + hue_jitter, base_hsv.y, base_hsv.z));
        }
    } else {
        splash_rgb = vec3(0.0);  // No color - black
    }
    
    // Blend with original based on mask
    vec3 tinted = base_color.rgb * splash_rgb;
    vec3 final_rgb = mix(base_color.rgb, tinted, mask);
    
    fragColor = vec4(final_rgb, base_color.a);
}