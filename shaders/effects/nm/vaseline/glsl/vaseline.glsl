#version 300 es

precision highp float;
precision highp int;

// Vaseline effect: blend a full-strength bloom toward the edges using a Chebyshev
// center mask. The bloom is authored separately and injected as an additional
// texture, letting us reuse the low-level bloom implementation without
// duplicating its work here.

const uint CHANNEL_COUNT = 4u;


uniform sampler2D input_texture;
uniform float width;
uniform float height;
uniform float channel_count;
uniform float alpha;
uniform float time;
uniform float speed;
uniform sampler2D bloom_texture;

uint to_u32(float value) {
    return uint(max(round(value), 0.0));
}

vec4 clamp_vec4_01(vec4 value) {
    return clamp(value, vec4(0.0), vec4(1.0));
}

vec3 clamp_vec3_01(vec3 value) {
    return clamp(value, vec3(0.0), vec3(1.0));
}

vec2 safe_dimensions() {
    return vec2(max(width, 1.0), max(height, 1.0));
}

float chebyshev_mask(vec2 norm_uv, vec2 dimensions) {
    if (dimensions.x <= 0.0 || dimensions.y <= 0.0) {
        return 0.0;
    }

    vec2 centered = abs(norm_uv - vec2(0.5, 0.5));
    float px = centered.x * dimensions.x;
    float py = centered.y * dimensions.y;
    float dist = max(px, py);
    float max_dimension = max(dimensions.x, dimensions.y) * 0.5;
    if (max_dimension <= 0.0) {
        return 0.0;
    }

    return clamp(dist / max_dimension, 0.0, 1.0);
}

void store_pixel(uint pixel_index, vec4 value) {
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = to_u32(width);
    uint height = to_u32(height);
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    vec2 coord = vec2(int(global_id.x), int(global_id.y));
    vec4 base_sample = clamp_vec4_01(texture(input_texture, (vec2(coord) + vec2(0.5)) / vec2(textureSize(input_texture, 0))));

    float alpha = clamp(alpha, 0.0, 1.0);
    if (alpha <= 0.0) {
        uint idx = (global_id.y * width + global_id.x) * CHANNEL_COUNT;
        store_pixel(idx, base_sample);
        return;
    }

    // The bloom texture contains the full bloom effect: (original + blurred) * 0.5
    vec4 bloom_sample = clamp_vec4_01(texture(bloom_texture, (vec2(coord) + vec2(0.5)) / vec2(textureSize(bloom_texture, 0))));
    vec2 dims = safe_dimensions();
    vec2 uv = (vec2(float(coord.x), float(coord.y)) + vec2(0.5, 0.5)) / dims;
    float mask_base = chebyshev_mask(uv, dims);
    float mask = mask_base * mask_base;

    // Python: center_mask(original, bloom, shape) means blend from original (center) to bloom (edges)
    // mask=0 at center → use original
    // mask=1 at edges → use bloom
    vec3 center_masked = mix(base_sample.xyz, bloom_sample.xyz, vec3(mask));
    
    // Then blend this masked result with original by alpha
    vec3 final_rgb = clamp_vec3_01(mix(base_sample.xyz, center_masked, vec3(alpha)));
    vec4 final_color = vec4(final_rgb, base_sample.w);

    store_pixel(pixel_index, final_color);
}