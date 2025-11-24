#version 300 es

precision highp float;
precision highp int;

// Stray Hair final combine pass.
// Generates sparse, long hair-like strands using worms with high kink values.


uniform sampler2D input_texture;
uniform sampler2D worm_texture;
uniform sampler2D brightness_texture;
uniform float width;
uniform float height;
uniform float channel_count;
uniform float time;
uniform float speed;
uniform float seed;

const uint CHANNEL_COUNT = 4u;


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uvec2 dims = uvec2(textureSize(input_texture, 0));
    if (global_id.x >= dims.x || global_id.y >= dims.y) {
        return;
    }

    vec2 coords = vec2(int(global_id.x), int(global_id.y));
    vec4 base_color = texture(input_texture, (vec2(coords) + vec2(0.5)) / vec2(textureSize(input_texture, 0)));
    vec4 worm_mask = texture(worm_texture, (vec2(coords) + vec2(0.5)) / vec2(textureSize(worm_texture, 0)));
    vec4 brightness_sample = texture(brightness_texture, (vec2(coords) + vec2(0.5)) / vec2(textureSize(brightness_texture, 0)));

    vec3 mask_rgb = clamp(worm_mask.rgb, vec3(0.0), vec3(1.0));
    vec3 blend_factor = clamp(mask_rgb * 0.666, vec3(0.0), vec3(1.0));
    vec3 brightness_rgb = clamp(brightness_sample.rgb * 0.333, vec3(0.0), vec3(1.0));

    vec3 base_component = base_color.rgb * (vec3(1.0) - blend_factor);
    vec3 hair_component = brightness_rgb * blend_factor;
    vec3 hair_rgb = clamp(base_component + hair_component, vec3(0.0), vec3(1.0));

    uint width_u = dims.x;
    uint index = (global_id.y * width_u + global_id.x) * CHANNEL_COUNT;
}