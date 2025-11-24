#version 300 es

precision highp float;
precision highp int;

// Sobel combine shader
// Reuses low-level convolve passes (Sobel X/Y) and combines their results
// into an edge magnitude using the selected distance metric.

const uint CHANNEL_COUNT = 4u;


uniform float width;
uniform float height;
uniform float channel_count;
uniform float dist_metric;
uniform float alpha;
uniform float time;
uniform float speed;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

float get_component(vec4 value, uint index) {
    switch index {
        case 0u: { return value.x; }
        case 1u: { return value.y; }
        case 2u: { return value.z; }
        default: { return value.w; }
    }
}

void set_component(uint index, float value) {
    switch index {
        case 0u: { (*dst).x = value; }
        case 1u: { (*dst).y = value; }
        case 2u: { (*dst).z = value; }
        default: { (*dst).w = value; }
    }
}

float distance_metric(float delta_x, float delta_y, uint metric) {
    float abs_dx = abs(delta_x);
    float abs_dy = abs(delta_y);
    switch metric {
        case 2u: { // Manhattan
            return abs_dx + abs_dy;
        }
        case 3u: { // Chebyshev
            return max(abs_dx, abs_dy);
        }
        case 4u: { // Octagram
            float cross = (abs_dx + abs_dy) / sqrt(2.0);
            return max(cross, max(abs_dx, abs_dy));
        }
        case 101u: { // Triangular (approx)
            return max(abs_dx - delta_y * 0.5, abs_dy);
        }
        case 102u: { // Hexagram (approx)
            float a = max(abs_dx - delta_y * 0.5, abs_dy);
            float b = max(abs_dx + delta_y * 0.5, abs_dy);
            return max(a, b);
        }
        case 201u: { // SDF-like
            float r = sqrt(max(delta_x * delta_x + delta_y * delta_y, 0.0));
            return r;
        }
        default: { // Euclidean
            return sqrt(max(delta_x * delta_x + delta_y * delta_y, 0.0));
        }
    }
}

}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = as_u32(width);
    uint height = as_u32(height);
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    uint channels = max(1u, min(as_u32(channel_count), CHANNEL_COUNT));
    uint base = pixel_index * CHANNEL_COUNT;

    vec4 result = vec4(0.0);
    uint metric = as_u32(dist_metric);

    for (uint c = 0u; c < channels; c = c + 1u) {
        float gx = sobel_x_buffer[base + c];
        float gy = sobel_y_buffer[base + c];
        float d = distance_metric(gx, gy, metric);

        // Rough normalization to [0,1] based on kernel bounds
        float denom = 1.0;
        switch metric {
            case 2u: { denom = 16.0; }              // Manhattan: 8 + 8
            case 3u: { denom = 8.0; }               // Chebyshev: max 8
            case 4u: { denom = 11.314f; }           // Octagram approx
            case 201u: { denom = 11.314f; }         // SDF/Euclid approx
            default: { denom = 11.314f; }           // Euclidean: 8*sqrt(2)
        }
        d = clamp(d / max(denom, 1e-6), 0.0, 1.0);
        set_component(result, c, d);
    }

    // Preserve opaque alpha
    result.w = 1.0;
    fragColor = result;
}