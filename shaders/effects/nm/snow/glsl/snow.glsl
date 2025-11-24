#version 300 es

precision highp float;
precision highp int;

// Snow effect: blends animated static noise into the source image.

const uint CHANNEL_COUNT = 4u;
const float TAU = 6.283185307179586;
const vec3 TIME_SEED_OFFSETS = vec3(97.0, 57.0, 131.0);
const vec3 STATIC_SEED = vec3(37.0, 17.0, 53.0);
const vec3 LIMITER_SEED = vec3(113.0, 71.0, 193.0);


uniform sampler2D input_texture;
uniform float width;
uniform float height;
uniform float channels;
uniform float alpha;
uniform float time;
uniform float speed;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

float clamp_01(float value) {
    return clamp(value, 0.0, 1.0);
}

float normalized_sine(float value) {
    return (sin(value) + 1.0) * 0.5;
}

float periodic_value(float time, float value) {
    return normalized_sine((time - value) * TAU);
}

vec3 snow_fract_vec3(vec3 value) {
    return value - floor(value);
}

float snow_hash(vec3 input_sample) {
    vec3 scaled = snow_fract_vec3(input_sample * 0.1031);
    float dot_val = dot(scaled, scaled.yzx + vec3(33.33));
    vec3 shifted = scaled + dot_val;
    float combined = (shifted.x + shifted.y) * shifted.z;
    float fractional = combined - floor(combined);
    return clamp(fractional, 0.0, 1.0);
}

float snow_noise(vec2 coord, float time, float speed, vec3 seed) {
    float angle = time * TAU;
    float z_base = cos(angle) * speed;
    vec3 base_sample = vec3(coord.x + seed.x, coord.y + seed.y, z_base + seed.z);
    float base_value = snow_hash(base_sample);

    if (speed == 0.0 || time == 0.0) {
        return base_value;
    }

    vec3 time_seed = seed + TIME_SEED_OFFSETS;
    vec3 time_sample = vec3(
        coord.x + time_seed.x,
        coord.y + time_seed.y,
        1.0 + time_seed.z
    );
    float time_value = snow_hash(time_sample);
    float scaled_time = periodic_value(time, time_value) * speed;
    float periodic = periodic_value(scaled_time, base_value);
    return clamp(periodic, 0.0, 1.0);
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = max(as_u32(width), 1u);
    uint height = max(as_u32(height), 1u);
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    float alpha = clamp(alpha, 0.0, 1.0);
    uint base_index = (global_id.y * width + global_id.x) * CHANNEL_COUNT;
    vec2 coords = vec2(int(global_id.x), int(global_id.y));
    vec4 texel = texture(input_texture, (vec2(coords) + vec2(0.5)) / vec2(textureSize(input_texture, 0)));

    if (alpha <= 0.0) {
        fragColor = vec4(texel.xyz, texel.w);
        return;
    }

    vec2 coord = vec2(float(global_id.x), float(global_id.y));
    float time = time;
    float speed = speed * 100.0;

    float static_value = snow_noise(coord, time, speed, STATIC_SEED);
    float limiter_value = snow_noise(coord, time, speed, LIMITER_SEED);
    float limiter_sq = limiter_value * limiter_value;
    float limiter_pow4 = limiter_sq * limiter_sq;
    float limiter_mask = clamp(limiter_pow4 * alpha, 0.0, 1.0);

    vec3 static_color = vec3(static_value);
    vec3 mixed_rgb = mix(texel.xyz, static_color, vec3(limiter_mask));

    fragColor = vec4(mixed_rgb, texel.w);
}