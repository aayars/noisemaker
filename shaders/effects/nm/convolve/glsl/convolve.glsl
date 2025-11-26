#version 300 es

precision highp float;
precision highp int;

// Convolve effect compute shader.
//
// Mirrors the Python implementation in noisemaker/value.py::convolve.
// Applies the selected convolution kernel with wrap-around sampling,
// optional normalization, and alpha blending. Work is split into three
// dispatches to keep each GPU pass bounded:
//   1. reset_stats_main  – reset the global min/max encodings
//   2. convolve_main     – apply the kernel per pixel, track min/max
//   3. main              – normalize (optional) and alpha blend

const float FLOAT_MAX = 3.402823466e38;
const float FLOAT_MIN = -3.402823466e38;

const uint CHANNEL_CAP = 4u;

const int KERNEL_SIZE_3 = 3;
const int KERNEL_SIZE_5 = 5;

const int KERNEL_CONV2D_BLUR = 800;
const int KERNEL_CONV2D_DERIV_X = 801;
const int KERNEL_CONV2D_DERIV_Y = 802;
const int KERNEL_CONV2D_EDGES = 803;
const int KERNEL_CONV2D_EMBOSS = 804;
const int KERNEL_CONV2D_INVERT = 805;
const int KERNEL_CONV2D_RAND = 806;
const int KERNEL_CONV2D_SHARPEN = 807;
const int KERNEL_CONV2D_SOBEL_X = 808;
const int KERNEL_CONV2D_SOBEL_Y = 809;
const int KERNEL_CONV2D_BOX_BLUR = 810;

const KERNEL_CONV2D_BLUR_WEIGHTS : array<f32, 25> = array<f32, 25>(

const KERNEL_CONV2D_BOX_BLUR_WEIGHTS : array<f32, 9> = array<f32, 9>(

const KERNEL_CONV2D_DERIV_X_WEIGHTS : array<f32, 9> = array<f32, 9>(

const KERNEL_CONV2D_DERIV_Y_WEIGHTS : array<f32, 9> = array<f32, 9>(

const KERNEL_CONV2D_EDGES_WEIGHTS : array<f32, 9> = array<f32, 9>(

const KERNEL_CONV2D_EMBOSS_WEIGHTS : array<f32, 9> = array<f32, 9>(

const KERNEL_CONV2D_INVERT_WEIGHTS : array<f32, 9> = array<f32, 9>(

const KERNEL_CONV2D_RAND_WEIGHTS : array<f32, 25> = array<f32, 25>(

const KERNEL_CONV2D_SHARPEN_WEIGHTS : array<f32, 9> = array<f32, 9>(

const KERNEL_CONV2D_SOBEL_X_WEIGHTS : array<f32, 9> = array<f32, 9>(

const KERNEL_CONV2D_SOBEL_Y_WEIGHTS : array<f32, 9> = array<f32, 9>(



uniform sampler2D inputTex;
uniform vec4 size;
uniform vec4 control;

uint as_u32(float value) {
    return uint(max(round(value), 0.0));
}

uint clamp_channelCount(uint raw_count) {
    if (raw_count == 0u) {
        return 0u;
    }
    if (raw_count > CHANNEL_CAP) {
        return CHANNEL_CAP;
    }
    return raw_count;
}

int wrap_index(int coord, int limit) {
    if (limit <= 0) {
        return 0;
    }
    int wrapped = coord % limit;
    if (wrapped < 0) {
        wrapped = wrapped + limit;
    }
    return wrapped;
}

uint float_to_ordered(float value) {
    uint bits = floatBitsToUint(value);
    if ((bits & 0x80000000u) != 0u) {
        return ~bits;
    }
    return bits | 0x80000000u;
}

float ordered_to_float(uint value) {
    if ((value & 0x80000000u) != 0u) {
        return uintBitsToFloat(value & 0x7fffffffu);
    }
    return uintBitsToFloat(~value);
}

ivec2 kernel_dimensions(int kernel_id) {
    switch kernel_id {
        case KERNEL_CONV2D_BLUR, KERNEL_CONV2D_RAND: {
            return vec2(KERNEL_SIZE_5, KERNEL_SIZE_5);
        }
        case KERNEL_CONV2D_BOX_BLUR,
             KERNEL_CONV2D_DERIV_X,
             KERNEL_CONV2D_DERIV_Y,
             KERNEL_CONV2D_EDGES,
             KERNEL_CONV2D_EMBOSS,
             KERNEL_CONV2D_INVERT,
             KERNEL_CONV2D_SHARPEN,
             KERNEL_CONV2D_SOBEL_X,
             KERNEL_CONV2D_SOBEL_Y: {
            return vec2(KERNEL_SIZE_3, KERNEL_SIZE_3);
        }
        default: {
            return vec2(1, 1);
        }
    }
}

float kernel_weight(int kernel_id, int row, int col) {
    switch kernel_id {
        case KERNEL_CONV2D_BLUR: {
            uint index = uint(row * KERNEL_SIZE_5 + col);
            return KERNEL_CONV2D_BLUR_WEIGHTS[index];
        }
        case KERNEL_CONV2D_BOX_BLUR: {
            uint index = uint(row * KERNEL_SIZE_3 + col);
            return KERNEL_CONV2D_BOX_BLUR_WEIGHTS[index];
        }
        case KERNEL_CONV2D_DERIV_X: {
            uint index = uint(row * KERNEL_SIZE_3 + col);
            return KERNEL_CONV2D_DERIV_X_WEIGHTS[index];
        }
        case KERNEL_CONV2D_DERIV_Y: {
            uint index = uint(row * KERNEL_SIZE_3 + col);
            return KERNEL_CONV2D_DERIV_Y_WEIGHTS[index];
        }
        case KERNEL_CONV2D_EDGES: {
            uint index = uint(row * KERNEL_SIZE_3 + col);
            return KERNEL_CONV2D_EDGES_WEIGHTS[index];
        }
        case KERNEL_CONV2D_EMBOSS: {
            uint index = uint(row * KERNEL_SIZE_3 + col);
            return KERNEL_CONV2D_EMBOSS_WEIGHTS[index];
        }
        case KERNEL_CONV2D_INVERT: {
            uint index = uint(row * KERNEL_SIZE_3 + col);
            return KERNEL_CONV2D_INVERT_WEIGHTS[index];
        }
        case KERNEL_CONV2D_RAND: {
            uint index = uint(row * KERNEL_SIZE_5 + col);
            return KERNEL_CONV2D_RAND_WEIGHTS[index];
        }
        case KERNEL_CONV2D_SHARPEN: {
            uint index = uint(row * KERNEL_SIZE_3 + col);
            return KERNEL_CONV2D_SHARPEN_WEIGHTS[index];
        }
        case KERNEL_CONV2D_SOBEL_X: {
            uint index = uint(row * KERNEL_SIZE_3 + col);
            return KERNEL_CONV2D_SOBEL_X_WEIGHTS[index];
        }
        case KERNEL_CONV2D_SOBEL_Y: {
            uint index = uint(row * KERNEL_SIZE_3 + col);
            return KERNEL_CONV2D_SOBEL_Y_WEIGHTS[index];
        }
        default: {
            return 1.0;
        }
    }
}

float kernel_max_abs(int kernel_id) {
    vec2 dims = kernel_dimensions(kernel_id);
    int width = max(dims.x, 1);
    int height = max(dims.y, 1);
    float max_abs = 0.0;
    for (int row = 0; row < height; row = row + 1) {
        for (int col = 0; col < width; col = col + 1) {
            float w = abs(kernel_weight(kernel_id, row, col));
            max_abs = max(max_abs, w);
        }
    }
    if (max_abs == 0.0) {
        return 1.0;
    }
    return max_abs;
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

vec4 lerp_vec4(vec4 a, vec4 b, float t) {
    return a + (b - a) * t;
}

}

vec4 read_pixel(uint base_index) {
    return vec4(
    );
}

void reset_stats_main(uvec3 @builtin(global_invocation_id) global_id) {
    if (global_id.x != 0u || global_id.y != 0u || global_id.z != 0u) {
        return;
    }

    atomicStore(stats_buffer.min_value, float_to_ordered(FLOAT_MAX));
    atomicStore(stats_buffer.max_value, float_to_ordered(FLOAT_MIN));
}

void convolve_main(uvec3 @builtin(global_invocation_id) global_id) {
    uint width = as_u32(size.x);
    uint height = as_u32(size.y);
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    uint channelCount = clamp_channelCount(as_u32(size.z));
    if (channelCount == 0u) {
        return;
    }

    int kernel_id = int(round(size.w));
    vec2 dims = kernel_dimensions(kernel_id);
    if (dims.x <= 0 || dims.y <= 0) {
        return;
    }

    float denom = kernel_max_abs(kernel_id);

    int xi = int(global_id.x);
    int yi = int(global_id.y);
    int width_i = int(width);
    int height_i = int(height);

    vec4 accum = vec4(0.0);
    for (int ky = 0; ky < dims.y; ky = ky + 1) {
        for (int kx = 0; kx < dims.x; kx = kx + 1) {
            int offset_x = kx - dims.x / 2;
            int offset_y = ky - dims.y / 2;
            int sample_x = wrap_index(xi + offset_x, width_i);
            int sample_y = wrap_index(yi + offset_y, height_i);
            vec4 sample = textureLoad(inputTex, vec2(sample_x, sample_y), 0);
            float weight = kernel_weight(kernel_id, ky, kx) / denom;
            accum = accum + sample * weight;
        }
    }

    vec4 original = textureLoad(inputTex, vec2(xi, yi), 0);
    vec4 processed = original;
    float pixel_min = FLOAT_MAX;
    float pixel_max = FLOAT_MIN;

    for (uint c = 0u; c < channelCount; c = c + 1u) {
        float component = get_component(accum, c);
        set_component(processed, c, component);
        pixel_min = min(pixel_min, component);
        pixel_max = max(pixel_max, component);
    }

    processed.w = original.w;

    fragColor = processed;

    if (control.x > 0.5) {
        uint encoded_min = float_to_ordered(pixel_min);
        uint encoded_max = float_to_ordered(pixel_max);
        atomicMin(stats_buffer.min_value, encoded_min);
        atomicMax(stats_buffer.max_value, encoded_max);
    }
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width = as_u32(size.x);
    uint height = as_u32(size.y);
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }

    uint channelCount = clamp_channelCount(as_u32(size.z));
    if (channelCount == 0u) {
        return;
    }

    bool do_normalize = control.x > 0.5;
    float alpha = clamp(control.y, 0.0, 1.0);
    int kernel_id = int(round(size.w));

    uint min_bits = atomicLoad(&stats_buffer.min_value);
    uint max_bits = atomicLoad(&stats_buffer.max_value);
    float min_value = ordered_to_float(min_bits);
    float max_value = ordered_to_float(max_bits);

    if (min_value > max_value) {
        min_value = 0.0;
        max_value = 0.0;
    }

    float inv_range = 0.0;
    if (do_normalize && max_value > min_value) {
        inv_range = 1.0 / (max_value - min_value);
    }


    vec4 processed = read_pixel(base_index);

    if (do_normalize && max_value > min_value) {
        for (uint c = 0u; c < channelCount; c = c + 1u) {
            float value = get_component(processed, c);
            float normalized = (value - min_value) * inv_range;
            set_component(processed, c, normalized);
        }
    }

    if (kernel_id == KERNEL_CONV2D_EDGES) {
        for (uint c_edge = 0u; c_edge < channelCount; c_edge = c_edge + 1u) {
            float value_edge = get_component(processed, c_edge);
            float adjusted = abs(value_edge - 0.5) * 2.0;
            set_component(processed, c_edge, adjusted);
        }
    }

    vec2 coord = vec2(int(global_id.x), int(global_id.y));
    vec4 original = texture(inputTex, (vec2(coord) + vec2(0.5)) / vec2(textureSize(inputTex, 0)));
    vec4 result = lerp_vec4(original, processed, alpha);
    result.w = original.w;

    fragColor = result;
}