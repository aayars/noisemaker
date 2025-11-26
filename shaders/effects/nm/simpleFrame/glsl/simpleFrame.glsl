#version 300 es

precision highp float;
precision highp int;

// Simple frame mask derived from the Chebyshev distance singularity in the Python reference.
// Applies a binary blend between the source image and a constant brightness value.

const uint CHANNEL_COUNT = 4u;
const float BORDER_BLEND = 0.55;

uniform sampler2D inputTex;
uniform vec4 size;
uniform vec4 timeSpeed;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

vec2 axis_min_max(uint size, float size_f) {
    if (size <= 1u) {
        return vec2(0.5, 0.5);
    }
    if ((size & 1u) == 0u) {
        return vec2(0.0, 0.5);
    }

    float half_floor = float(size / 2u);
    float min_val = 0.5 / size_f;
    float max_val = (half_floor - 0.5) / size_f;
    return vec2(min_val, max_val);
}

float axis_distance(float coord, float center, float dimension) {
    if (dimension <= 0.0) {
        return 0.0;
    }

    return abs(coord - center) / dimension;
}

float posterize_level_one(float value) {
    float scaled = value * BORDER_BLEND;
    return clamp(floor(scaled + 0.5), 0.0, 1.0);
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width_u = max(as_u32(size.x), 1u);
    uint height_u = max(as_u32(size.y), 1u);
    if (global_id.x >= width_u || global_id.y >= height_u) {
        return;
    }

    float width_f = max(float(width_u), 1.0);
    float height_f = max(float(height_u), 1.0);
    uint half_width_u = width_u / 2u;
    uint half_height_u = height_u / 2u;
    float center_x = width_f * 0.5;
    float center_y = height_f * 0.5;

    float fx = float(global_id.x);
    float fy = float(global_id.y);
    float dx = axis_distance(fx, center_x, width_f);
    float dy = axis_distance(fy, center_y, height_f);

    vec2 axis_x = axis_min_max(width_u, width_f);
    vec2 axis_y = axis_min_max(height_u, height_f);
    float min_dist = max(axis_x.x, axis_y.x);
    float max_dist = max(axis_x.y, axis_y.y);
    float dist = max(dx, dy);
    float delta = max_dist - min_dist;

    float normalized;
    if (delta > 0.0) {
        normalized = clamp((dist - min_dist) / delta, 0.0, 1.0);
    } else {
        normalized = clamp(dist, 0.0, 1.0);
    }

    float ramp = sqrt(normalized);
    float mask = posterize_level_one(ramp);

    vec2 coords = vec2(int(global_id.x), int(global_id.y));
    vec4 srcSample = texture(inputTex, (vec2(coords) + vec2(0.5)) / vec2(textureSize(inputTex, 0)));

    float brightness = size.w;
    vec3 brightness_vec = vec3(brightness);
    vec3 blended_rgb = mix(srcSample.xyz, brightness_vec, vec3(mask));

    fragColor = vec4(blended_rgb.x, blended_rgb.y, blended_rgb.z, srcSample.w);
}