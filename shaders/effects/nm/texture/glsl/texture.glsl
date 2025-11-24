#version 300 es

precision highp float;
precision highp int;

// Texture effect: generate animated ridged noise, derive a shadow from the
// noise gradient, then blend that shade back into the source pixels. This
// implementation keeps the required 3-stage algorithm (noise → shadow →
// blend) while avoiding the heavyweight single-invocation work that previously
// froze the GPU. Everything runs in a tiled 8x8 compute pass with compact math.

const float INV_UINT32_MAX = 1.0 / 4294967295.0;
const uint OCTAVE_COUNT = 3u;
const float SHADE_GAIN = 4.4;


uniform sampler2D input_texture;
uniform float width;
uniform float height;
uniform float channel_count;
uniform float time;
uniform float speed;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

float clamp01(float value) {
    return clamp(value, 0.0, 1.0);
}

float fade(float t) {
    return t * t * (3.0 - 2.0 * t);
}

vec2 freq_for_shape(float base_freq, vec2 dims) {
    float width = max(dims.x, 1.0);
    float height = max(dims.y, 1.0);
    if (abs(width - height) < 0.5) {
        return vec2(base_freq, base_freq);
    }
    if (width > height) {
        return vec2(base_freq, base_freq * width / height);
    }
    return vec2(base_freq * height / width, base_freq);
}

float fast_hash(ivec3 p, uint salt) {
    uint h = salt ^ 0x9e3779b9u;
    h ^= floatBitsToUint(p.x) * 0x27d4eb2du;
    h = (h ^ (h >> 15u)) * 0x85ebca6bu;
    h ^= floatBitsToUint(p.y) * 0xc2b2ae35u;
    h = (h ^ (h >> 13u)) * 0x27d4eb2du;
    h ^= floatBitsToUint(p.z) * 0x165667b1u;
    h = h ^ (h >> 16u);
    return float(h) * INV_UINT32_MAX;
}

float value_noise(vec2 uv, vec2 freq, float motion, uint salt) {
    vec2 scaled_uv = uv * max(freq, vec2(1.0, 1.0));
    vec2 cell_floor = floor(scaled_uv);
    vec2 frac = fract(scaled_uv);
    vec2 base_cell = vec2(int(cell_floor.x), int(cell_floor.y));

    float z_floor = floor(motion);
    float z_frac = fract(motion);
    int z0 = int(z_floor);
    int z1 = z0 + 1;

    float c000 = fast_hash(vec3(base_cell.x + 0, base_cell.y + 0, z0), salt);
    float c100 = fast_hash(vec3(base_cell.x + 1, base_cell.y + 0, z0), salt);
    float c010 = fast_hash(vec3(base_cell.x + 0, base_cell.y + 1, z0), salt);
    float c110 = fast_hash(vec3(base_cell.x + 1, base_cell.y + 1, z0), salt);
    float c001 = fast_hash(vec3(base_cell.x + 0, base_cell.y + 0, z1), salt);
    float c101 = fast_hash(vec3(base_cell.x + 1, base_cell.y + 0, z1), salt);
    float c011 = fast_hash(vec3(base_cell.x + 0, base_cell.y + 1, z1), salt);
    float c111 = fast_hash(vec3(base_cell.x + 1, base_cell.y + 1, z1), salt);

    float tx = fade(frac.x);
    float ty = fade(frac.y);
    float tz = fade(z_frac);

    float x00 = mix(c000, c100, tx);
    float x10 = mix(c010, c110, tx);
    float x01 = mix(c001, c101, tx);
    float x11 = mix(c011, c111, tx);

    float y0 = mix(x00, x10, ty);
    float y1 = mix(x01, x11, ty);

    return mix(y0, y1, tz);
}

float multi_octave_noise(vec2 uv, vec2 base_freq, float motion) {
    vec2 freq = max(base_freq, vec2(1.0, 1.0));
    float amplitude = 0.5;
    float accum = 0.0;
    float total = 0.0;

    for (uint octave = 0u; octave < OCTAVE_COUNT; octave = octave + 1u) {
        uint salt = 0x9e3779b9u * (octave + 1u);
        float sample = value_noise(uv, freq, motion + float(octave) * 0.37, salt);
        float ridged = 1.0 - abs(sample * 2.0 - 1.0);
        accum = accum + ridged * amplitude;
        total = total + amplitude;
        freq = freq * 2.0;
        amplitude = amplitude * 0.55;
    }

    if (total <= 0.0) {
        return clamp01(accum);
    }
    return clamp01(accum / total);
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = as_u32(width);
    uint height = as_u32(height);
    if (width == 0u || height == 0u) {
        return;
    }
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    vec2 coords = vec2(int(global_id.x), int(global_id.y));
    vec4 base_color = texture(input_texture, (vec2(coords) + vec2(0.5)) / vec2(textureSize(input_texture, 0)));

    vec2 dims = vec2(max(width, 1.0), max(height, 1.0));
    vec2 uv = (vec2(float(coords.x), float(coords.y)) + 0.5) / dims;
    vec2 pixel_step = vec2(1.0 / dims.x, 1.0 / dims.y);

    vec2 base_freq = freq_for_shape(24.0, dims);
    float motion = time * speed;

    float noise_center = multi_octave_noise(uv, base_freq, motion);
    float noise_right = multi_octave_noise(uv + vec2(pixel_step.x, 0.0), base_freq, motion);
    float noise_left = multi_octave_noise(uv - vec2(pixel_step.x, 0.0), base_freq, motion);
    float noise_up = multi_octave_noise(uv + vec2(0.0, pixel_step.y), base_freq, motion);
    float noise_down = multi_octave_noise(uv - vec2(0.0, pixel_step.y), base_freq, motion);

    float gx = noise_right - noise_left;
    float gy = noise_down - noise_up;
    float gradient = sqrt(gx * gx + gy * gy);
    float shade_base = clamp01(gradient * SHADE_GAIN * 0.25);

    float highlight_mix = clamp01((shade_base * shade_base) * 1.25);
    float base_factor = 0.9 + noise_center * 0.35;
    float factor = clamp(base_factor + highlight_mix * 0.35, 0.85, 1.6);

    vec3 scaled_rgb = clamp(base_color.xyz * factor, vec3(0.0), vec3(1.0));

    fragColor = vec4(scaled_rgb.x, scaled_rgb.y, scaled_rgb.z, base_color.w);
}