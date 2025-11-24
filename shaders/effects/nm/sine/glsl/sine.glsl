#version 300 es

precision highp float;
precision highp int;

// Sine: Apply a normalized sine curve to selected channels of the input texture.
// This mirrors noisemaker.effects.sine, with optional RGB mode for multi-channel data.


const uint CHANNEL_COUNT = 4u;

uniform sampler2D input_texture;
uniform float width;
uniform float height;
uniform float channel_count;
uniform float amount;
uniform float time;
uniform float speed;
uniform float rgb;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

uint sanitized_channel_count(float raw) {
    uint count = as_u32(raw);
    if (count <= 1u) {
        return 1u;
    }
    if (count >= CHANNEL_COUNT) {
        return CHANNEL_COUNT;
    }
    return count;
}

float normalized_sine(float value) {
    return (sin(value) + 1.0) * 0.5;
}

vec3 normalized_sine_vec3(vec3 value) {
    return (sin(value) + vec3(1.0)) * 0.5;
}

vec4 apply_sine(vec4 texel, float amount, uint channel_count, bool use_rgb) {
    vec4 result = texel;

    if (channel_count <= 2u) {
        result.x = normalized_sine(texel.x * amount);
        return result;
    }

    if (channel_count == 3u) {
        if (use_rgb) {
            vec3 rgb = normalized_sine_vec3(texel.xyz * amount);
            result = vec4(rgb, result.w);
        } else {
            result.z = normalized_sine(texel.z * amount);
        }
        return result;
    }

    if (use_rgb) {
        vec3 rgb = normalized_sine_vec3(texel.xyz * amount);
        result = vec4(rgb, result.w);
    } else {
        result.z = normalized_sine(texel.z * amount);
    }
    return result;
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    ivec2 tex_dims = textureSize(input_texture, 0);
    int width_px = max(tex_dims.x, 1);
    int height_px = max(tex_dims.y, 1);
    if (int(global_id.x) >= width_px || int(global_id.y) >= height_px) {
        return;
    }

    ivec2 pixel_coord = ivec2(int(global_id.x), int(global_id.y));
    vec4 texel = texelFetch(input_texture, pixel_coord, 0);
    float amount_value = amount;
    bool use_rgb = rgb > 0.5;
    uint channel_count_u = sanitized_channel_count(channel_count);

    vec4 result = apply_sine(texel, amount_value, channel_count_u, use_rgb);
    fragColor = result;
}