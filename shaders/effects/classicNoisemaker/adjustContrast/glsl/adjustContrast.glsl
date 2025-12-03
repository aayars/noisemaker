#version 300 es

precision highp float;
precision highp int;

// Adjusts per-pixel contrast by scaling distance from mid-gray (0.5), matching tf.image.adjust_contrast
// behaviour for normalized inputs while favouring performance over an exact global mean.

uniform sampler2D inputTex;
uniform vec2 resolution;
uniform float amount;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

vec3 clamp01_vec3(vec3 value) {
    vec3 min_value = vec3(0.0);
    vec3 max_value = vec3(1.0);
    return clamp(value, min_value, max_value);
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = as_u32(resolution.x);
    uint height = as_u32(resolution.y);
    if (width == 0u || height == 0u) {
        return;
    }

    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    vec2 coords = vec2(int(global_id.x), int(global_id.y));
    vec4 texel = texture(inputTex, (vec2(coords) + vec2(0.5)) / vec2(textureSize(inputTex, 0)));

    float amount = amount;
    if (amount == 1.0) {
        fragColor = vec4(texel.x, texel.y, texel.z, texel.w);
        return;
    }

    vec3 mid_gray = vec3(0.5);
    vec3 adjusted_rgb = clamp01_vec3((texel.xyz - mid_gray) * vec3(amount) + mid_gray);

    fragColor = vec4(adjusted_rgb.x, adjusted_rgb.y, adjusted_rgb.z, texel.w);
}