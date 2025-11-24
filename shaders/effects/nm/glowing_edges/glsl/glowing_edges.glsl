#version 300 es

precision highp float;
precision highp int;

// Glowing Edges final combine shader
// Reuses: posterize, convolve (Sobel), sobel (combine), bloom, normalize
// This shader performs only the last blend step:
//   edges_prep = clamp(edges * 8.0, 0.0, 1.0) * clamp(base * 1.25, 0.0, 1.0)
//   screen = 1.0 - (1.0 - edges_prep) * (1.0 - base)
//   out = mix(base, screen, alpha)

const uint CHANNEL_COUNT = 4u;


uniform sampler2D base_texture;
uniform float width;
uniform float height;
uniform float channel_count;
uniform float alpha;
uniform float sobel_metric;
uniform float time;
uniform float speed;
uniform sampler2D edges_texture;


vec3 clamp01(vec3 v) {
    return clamp(v, vec3(0.0), vec3(1.0));
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = max(uint(width), 1u);
    uint height = max(uint(height), 1u);
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    vec2 xy = vec2(int(global_id.x), int(global_id.y));
    vec4 base = texture(base_texture, (vec2(xy) + vec2(0.5)) / vec2(textureSize(base_texture, 0)));
    vec4 edges = texture(edges_texture, (vec2(xy) + vec2(0.5)) / vec2(textureSize(edges_texture, 0)));

    vec3 edges_scaled = clamp01(edges.xyz * 8.0);
    vec3 base_scaled = clamp01(base.xyz * 1.25);
    vec3 edges_prep = edges_scaled * base_scaled;

    vec3 screen_rgb = vec3(1.0) - (vec3(1.0) - edges_prep) * (vec3(1.0) - base.xyz);
    float alpha = clamp(alpha, 0.0, 1.0);
    vec3 mixed_rgb = mix(base.xyz, screen_rgb, alpha);

    vec4 out_color = vec4(clamp01(mixed_rgb), base.w);
    uint base_index = (global_id.y * width + global_id.x) * CHANNEL_COUNT;
    fragColor = out_color;
}