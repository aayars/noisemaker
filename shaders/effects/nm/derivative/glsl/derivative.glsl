#version 300 es
precision highp float;
precision highp int;

uniform sampler2D input_texture;
uniform vec4 size;
uniform vec4 options;

out vec4 fragColor;

const float PI = 3.14159265358979323846;
const float TAU = 6.28318530717958647692;
const float SDF_SIDES = 5.0;

const ivec2 DERIVATIVE_KERNEL_OFFSETS[9] = ivec2[](
    ivec2(-1, -1), ivec2(0, -1), ivec2(1, -1),
    ivec2(-1,  0), ivec2(0,  0), ivec2(1,  0),
    ivec2(-1,  1), ivec2(0,  1), ivec2(1,  1)
);

const float DERIVATIVE_KERNEL_X[9] = float[](
    -1.0, 0.0, 1.0,
    -2.0, 0.0, 2.0,
    -1.0, 0.0, 1.0
);

const float DERIVATIVE_KERNEL_Y[9] = float[](
    -1.0, -2.0, -1.0,
     0.0,  0.0,  0.0,
     1.0,  2.0,  1.0
);

uint as_u32(float value) {
    return uint(max(value, 0.0));
}

int wrap_coord(int coord, int limit) {
    if (limit <= 0) {
        return 0;
    }
    int wrapped = coord % limit;
    if (wrapped < 0) {
        wrapped = wrapped + limit;
    }
    return wrapped;
}

vec4 fetch_texel(int x, int y, int width, int height) {
    int wrapped_x = wrap_coord(x, width);
    int wrapped_y = wrap_coord(y, height);
    return texelFetch(input_texture, ivec2(wrapped_x, wrapped_y), 0);
}

float get_component(vec4 value, uint index) {
    if (index == 0u) return value.x;
    if (index == 1u) return value.y;
    if (index == 2u) return value.z;
    return value.w;
}

// Helper to set component in a vector (by returning a new vector)
vec4 set_component(vec4 vector, uint index, float value) {
    if (index == 0u) vector.x = value;
    else if (index == 1u) vector.y = value;
    else if (index == 2u) vector.z = value;
    else vector.w = value;
    return vector;
}

float distance_metric(float delta_x, float delta_y, uint metric) {
    float abs_dx = abs(delta_x);
    float abs_dy = abs(delta_y);
    
    if (metric == 2u) { // Manhattan
        return abs_dx + abs_dy;
    }
    if (metric == 3u) { // Chebyshev
        return max(abs_dx, abs_dy);
    }
    if (metric == 4u) { // Octagram
        float cross = (abs_dx + abs_dy) / sqrt(2.0);
        return max(cross, max(abs_dx, abs_dy));
    }
    if (metric == 101u) { // Triangular
        return max(abs_dx - delta_y * 0.5, delta_y);
    }
    if (metric == 102u) { // Hexagram
        float a = max(abs_dx - delta_y * 0.5, delta_y);
        float b = max(abs_dx + delta_y * 0.5, -delta_y);
        return max(a, b);
    }
    if (metric == 201u) { // Signed distance field
        float angle = atan(delta_x, -delta_y) + PI;
        float step = TAU / SDF_SIDES;
        float sector = floor(0.5 + angle / step);
        float offset = sector * step - angle;
        float radius = sqrt(max(delta_x * delta_x + delta_y * delta_y, 0.0));
        return cos(offset) * radius;
    }
    
    // Default: Euclidean
    float sum = delta_x * delta_x + delta_y * delta_y;
    return sqrt(max(sum, 0.0));
}

struct GradientPair {
    vec4 dx;
    vec4 dy;
};

GradientPair compute_gradients(ivec2 coords, int width, int height) {
    vec4 grad_x = vec4(0.0);
    vec4 grad_y = vec4(0.0);

    for (int i = 0; i < 9; i++) {
        ivec2 offset = coords + DERIVATIVE_KERNEL_OFFSETS[i];
        vec4 sample_val = fetch_texel(offset.x, offset.y, width, height);
        float weight_x = DERIVATIVE_KERNEL_X[i];
        float weight_y = DERIVATIVE_KERNEL_Y[i];
        grad_x += sample_val * weight_x;
        grad_y += sample_val * weight_y;
    }

    return GradientPair(grad_x, grad_y);
}

void main() {
    ivec2 dims = textureSize(input_texture, 0);
    uint width = as_u32(size.x);
    uint height = as_u32(size.y);
    
    // Use texture dims if size uniform is 0
    if (width == 0u) width = uint(dims.x);
    if (height == 0u) height = uint(dims.y);
    
    uvec2 global_id = uvec2(gl_FragCoord.xy);
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    int width_i = int(width);
    int height_i = int(height);
    
    uint channel_count = as_u32(size.z);
    if (channel_count == 0u) channel_count = 4u;
    channel_count = min(channel_count, 4u);
    
    uint metric = uint(floor(size.w + 0.5));
    bool do_normalize = options.x > 0.5;
    float alpha = clamp(options.y, 0.0, 1.0);

    int xi = int(global_id.x);
    int yi = int(global_id.y);
    vec4 source_texel = fetch_texel(xi, yi, width_i, height_i);
    GradientPair gradients = compute_gradients(ivec2(xi, yi), width_i, height_i);

    vec4 distances = vec4(0.0);
    for (uint c = 0u; c < channel_count; c++) {
        float dist = distance_metric(
            get_component(gradients.dx, c),
            get_component(gradients.dy, c),
            metric
        );
        distances = set_component(distances, c, dist);
    }

    if (!do_normalize) {
        distances = clamp(distances, 0.0, 1.0);
    }

    distances.w = 1.0;
    
    if (alpha < 1.0) {
        vec4 blended = distances;
        for (uint c = 0u; c < channel_count; c++) {
            float orig = get_component(source_texel, c);
            float der = get_component(distances, c);
            float val = mix(orig, der, alpha);
            blended = set_component(blended, c, val);
        }
        distances = blended;
    }

    fragColor = distances;
}
