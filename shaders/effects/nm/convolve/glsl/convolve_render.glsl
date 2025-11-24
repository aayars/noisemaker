#version 300 es
precision highp float;
precision highp int;

uniform sampler2D input_texture;
uniform int kernel;

out vec4 fragColor;

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

const float KERNEL_CONV2D_BLUR_WEIGHTS[25] = float[25](
    1.0, 4.0, 6.0, 4.0, 1.0,
    4.0, 16.0, 24.0, 16.0, 4.0,
    6.0, 24.0, 36.0, 24.0, 6.0,
    4.0, 16.0, 24.0, 16.0, 4.0,
    1.0, 4.0, 6.0, 4.0, 1.0
);

const float KERNEL_CONV2D_BOX_BLUR_WEIGHTS[9] = float[9](
    1.0, 2.0, 1.0,
    2.0, 4.0, 2.0,
    1.0, 2.0, 1.0
);

const float KERNEL_CONV2D_DERIV_X_WEIGHTS[9] = float[9](
    0.0, 0.0, 0.0,
    0.0, 1.0, -1.0,
    0.0, 0.0, 0.0
);

const float KERNEL_CONV2D_DERIV_Y_WEIGHTS[9] = float[9](
    0.0, 0.0, 0.0,
    0.0, 1.0, 0.0,
    0.0, -1.0, 0.0
);

const float KERNEL_CONV2D_EDGES_WEIGHTS[9] = float[9](
    1.0, 2.0, 1.0,
    2.0, -12.0, 2.0,
    1.0, 2.0, 1.0
);

const float KERNEL_CONV2D_EMBOSS_WEIGHTS[9] = float[9](
    0.0, 2.0, 4.0,
    -2.0, 1.0, 2.0,
    -4.0, -2.0, 0.0
);

const float KERNEL_CONV2D_INVERT_WEIGHTS[9] = float[9](
    0.0, 0.0, 0.0,
    0.0, -1.0, 0.0,
    0.0, 0.0, 0.0
);

const float KERNEL_CONV2D_RAND_WEIGHTS[25] = float[25](
    1.382026172983832, 0.7000786041836117, 0.9893689920528697, 1.620446599600729, 1.4337789950749837,
    0.011361060061794492, 0.9750442087627946, 0.42432139585115103, 0.4483905741032211, 0.7052992509691862,
    0.572021785580439, 1.2271367534814877, 0.8805188625734968, 0.5608375082464142, 0.7219316163727129,
    0.6668371636871334, 1.2470395365788032, 0.39742086811709953, 0.6565338508254507, 0.07295213034913761,
    -0.7764949079170393, 0.8268092977201803, 0.9322180994297529, 0.12891748979677903, 1.6348773119938038
);

const float KERNEL_CONV2D_SHARPEN_WEIGHTS[9] = float[9](
    0.0, -1.0, 0.0,
    -1.0, 5.0, -1.0,
    0.0, -1.0, 0.0
);

const float KERNEL_CONV2D_SOBEL_X_WEIGHTS[9] = float[9](
    1.0, 0.0, -1.0,
    2.0, 0.0, -2.0,
    1.0, 0.0, -1.0
);

const float KERNEL_CONV2D_SOBEL_Y_WEIGHTS[9] = float[9](
    1.0, 2.0, 1.0,
    0.0, 0.0, 0.0,
    -1.0, -2.0, -1.0
);

ivec2 get_kernel_dims(int kernel_id) {
    if (kernel_id == KERNEL_CONV2D_BLUR || kernel_id == KERNEL_CONV2D_RAND) {
        return ivec2(5, 5);
    }
    return ivec2(3, 3);
}

float get_weight(int kernel_id, int index) {
    if (kernel_id == KERNEL_CONV2D_BLUR) return KERNEL_CONV2D_BLUR_WEIGHTS[index];
    if (kernel_id == KERNEL_CONV2D_BOX_BLUR) return KERNEL_CONV2D_BOX_BLUR_WEIGHTS[index];
    if (kernel_id == KERNEL_CONV2D_DERIV_X) return KERNEL_CONV2D_DERIV_X_WEIGHTS[index];
    if (kernel_id == KERNEL_CONV2D_DERIV_Y) return KERNEL_CONV2D_DERIV_Y_WEIGHTS[index];
    if (kernel_id == KERNEL_CONV2D_EDGES) return KERNEL_CONV2D_EDGES_WEIGHTS[index];
    if (kernel_id == KERNEL_CONV2D_EMBOSS) return KERNEL_CONV2D_EMBOSS_WEIGHTS[index];
    if (kernel_id == KERNEL_CONV2D_INVERT) return KERNEL_CONV2D_INVERT_WEIGHTS[index];
    if (kernel_id == KERNEL_CONV2D_RAND) return KERNEL_CONV2D_RAND_WEIGHTS[index];
    if (kernel_id == KERNEL_CONV2D_SHARPEN) return KERNEL_CONV2D_SHARPEN_WEIGHTS[index];
    if (kernel_id == KERNEL_CONV2D_SOBEL_X) return KERNEL_CONV2D_SOBEL_X_WEIGHTS[index];
    if (kernel_id == KERNEL_CONV2D_SOBEL_Y) return KERNEL_CONV2D_SOBEL_Y_WEIGHTS[index];
    return 0.0;
}

float get_kernel_denom(int kernel_id) {
    ivec2 dims = get_kernel_dims(kernel_id);
    float max_abs = 0.0;
    for (int i = 0; i < dims.x * dims.y; i++) {
        float w = abs(get_weight(kernel_id, i));
        max_abs = max(max_abs, w);
    }
    if (max_abs == 0.0) return 1.0;
    return max_abs;
}

void main() {
    int kernel_id = kernel;
    ivec2 dims = get_kernel_dims(kernel_id);
    float denom = get_kernel_denom(kernel_id);
    
    ivec2 tex_size = textureSize(input_texture, 0);
    ivec2 coord = ivec2(gl_FragCoord.xy);
    
    vec4 accum = vec4(0.0);
    
    for (int ky = 0; ky < dims.y; ky++) {
        for (int kx = 0; kx < dims.x; kx++) {
            int offset_x = kx - dims.x / 2;
            int offset_y = ky - dims.y / 2;
            
            ivec2 sample_pos = coord + ivec2(offset_x, offset_y);
            
            // Wrap around
            sample_pos.x = sample_pos.x % tex_size.x;
            if (sample_pos.x < 0) sample_pos.x += tex_size.x;
            sample_pos.y = sample_pos.y % tex_size.y;
            if (sample_pos.y < 0) sample_pos.y += tex_size.y;
            
            vec4 sample_val = texelFetch(input_texture, sample_pos, 0);
            
            int index = ky * dims.x + kx;
            float weight = get_weight(kernel_id, index);
            
            accum += sample_val * (weight / denom);
        }
    }
    
    fragColor = accum;
}
