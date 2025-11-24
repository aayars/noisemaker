#version 300 es

precision highp float;
precision highp int;

// Vignette: normalize the input frame and blend its edges toward a constant brightness
// value using a radial falloff that matches the Python reference implementation.

const uint CHANNEL_COUNT = 4u;

uniform sampler2D input_texture;
uniform float width;
uniform float height;
uniform float channel_count;
uniform float brightness;
uniform float alpha;
uniform float time;
uniform float speed;


float compute_vignette_mask(uvec2 coord, uvec2 dims) {
    float width_f = float(dims.x);
    float height_f = float(dims.y);
    if (width_f <= 0.0 || height_f <= 0.0) {
        return 0.0;
    }

    vec2 pixel_center = vec2(float(coord.x), float(coord.y)) + vec2(0.5, 0.5);
    vec2 uv = pixel_center / vec2(width_f, height_f);
    vec2 delta = abs(uv - vec2(0.5, 0.5));

    float safe_height = max(height_f, 1.0);
    float aspect = width_f / safe_height;
    vec2 scaled = vec2(delta.x * aspect, delta.y);
    float max_radius = length(vec2(aspect * 0.5, 0.5));
    if (max_radius <= 0.0) {
        return 0.0;
    }

    float normalized_distance = clamp(length(scaled) / max_radius, 0.0, 1.0);
    return pow(normalized_distance, 2.0);
}

vec4 normalize_color(vec4 color) {
    float min_val = min(min(color.r, color.g), min(color.b, color.a));
    float max_val = max(max(color.r, color.g), max(color.b, color.a));
    float range = max_val - min_val;
    
    if (range <= 0.0) {
        return vec4(0.0);
    }
    
    return (color - vec4(min_val)) / vec4(range);
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uvec2 dims = uvec2(textureSize(input_texture, 0));
    uint width = dims.x;
    uint height = dims.y;
    
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    vec2 coords = vec2(int(global_id.x), int(global_id.y));
    vec4 texel = texture(input_texture, (vec2(coords) + vec2(0.5)) / vec2(textureSize(input_texture, 0)));
    
    // Normalize per-pixel (simpler than global min/max which would require multi-pass)
    vec4 normalized = normalize_color(texel);
    
    float brightness = brightness;
    float alpha_param = alpha;
    
    float mask = compute_vignette_mask(vec2(global_id.x, global_id.y), dims);
    
    // Apply brightness to RGB only, preserve alpha channel
    vec3 brightness_rgb = vec3(brightness);
    vec3 edge_blend_rgb = mix(normalized.rgb, brightness_rgb, vec3(mask));
    vec3 final_rgb = mix(normalized.rgb, edge_blend_rgb, vec3(alpha_param));
    
    // Preserve original alpha channel
    vec4 final_color = vec4(final_rgb, normalized.a);

    fragColor = final_color;
}