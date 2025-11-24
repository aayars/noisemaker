#version 300 es

precision highp float;
precision highp int;

// Adjusts image brightness by adding a uniform delta and clamping to [-1, 1],
// mirroring tf.image.adjust_brightness from the Python reference.

const uint CHANNEL_COUNT = 4u;

uniform sampler2D input_texture;
uniform vec2 resolution;
uniform float amount;

vec3 clamp_symmetric_vec3(vec3 value) {
    vec3 limits = vec3(1.0);
    return clamp(value, -limits, limits);
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = uint(max(round(resolution.x), 0.0));
    uint height = uint(max(round(resolution.y), 0.0));
    if (width == 0u || height == 0u) {
        return;
    }
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    vec2 coords = vec2(int(global_id.x), int(global_id.y));
    vec4 texel = texture(input_texture, (vec2(coords) + vec2(0.5)) / vec2(textureSize(input_texture, 0)));

    float brightness_delta = amount;
    vec3 adjusted_rgb = clamp_symmetric_vec3(texel.xyz + vec3(brightness_delta));

    fragColor = vec4(adjusted_rgb, texel.w);
}