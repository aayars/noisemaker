// Convolve render pass - applies convolution kernel
// Matches convolveRender.glsl (GPGPU fragment shader)

const KERNEL_CONV2D_BLUR: i32 = 800;
const KERNEL_CONV2D_DERIV_X: i32 = 801;
const KERNEL_CONV2D_DERIV_Y: i32 = 802;
const KERNEL_CONV2D_EDGES: i32 = 803;
const KERNEL_CONV2D_EMBOSS: i32 = 804;
const KERNEL_CONV2D_INVERT: i32 = 805;
const KERNEL_CONV2D_RAND: i32 = 806;
const KERNEL_CONV2D_SHARPEN: i32 = 807;
const KERNEL_CONV2D_SOBEL_X: i32 = 808;
const KERNEL_CONV2D_SOBEL_Y: i32 = 809;
const KERNEL_CONV2D_BOX_BLUR: i32 = 810;

const KERNEL_CONV2D_BLUR_WEIGHTS: array<f32, 25> = array<f32, 25>(
    1.0, 4.0, 6.0, 4.0, 1.0,
    4.0, 16.0, 24.0, 16.0, 4.0,
    6.0, 24.0, 36.0, 24.0, 6.0,
    4.0, 16.0, 24.0, 16.0, 4.0,
    1.0, 4.0, 6.0, 4.0, 1.0
);

const KERNEL_CONV2D_BOX_BLUR_WEIGHTS: array<f32, 9> = array<f32, 9>(
    1.0, 2.0, 1.0,
    2.0, 4.0, 2.0,
    1.0, 2.0, 1.0
);

const KERNEL_CONV2D_DERIV_X_WEIGHTS: array<f32, 9> = array<f32, 9>(
    0.0, 0.0, 0.0,
    0.0, 1.0, -1.0,
    0.0, 0.0, 0.0
);

const KERNEL_CONV2D_DERIV_Y_WEIGHTS: array<f32, 9> = array<f32, 9>(
    0.0, 0.0, 0.0,
    0.0, 1.0, 0.0,
    0.0, -1.0, 0.0
);

const KERNEL_CONV2D_EDGES_WEIGHTS: array<f32, 9> = array<f32, 9>(
    1.0, 2.0, 1.0,
    2.0, -12.0, 2.0,
    1.0, 2.0, 1.0
);

const KERNEL_CONV2D_EMBOSS_WEIGHTS: array<f32, 9> = array<f32, 9>(
    0.0, 2.0, 4.0,
    -2.0, 1.0, 2.0,
    -4.0, -2.0, 0.0
);

const KERNEL_CONV2D_INVERT_WEIGHTS: array<f32, 9> = array<f32, 9>(
    0.0, 0.0, 0.0,
    0.0, -1.0, 0.0,
    0.0, 0.0, 0.0
);

const KERNEL_CONV2D_RAND_WEIGHTS: array<f32, 25> = array<f32, 25>(
    1.382026172983832, 0.7000786041836117, 0.9893689920528697, 1.620446599600729, 1.4337789950749837,
    0.011361060061794492, 0.9750442087627946, 0.42432139585115103, 0.4483905741032211, 0.7052992509691862,
    0.572021785580439, 1.2271367534814877, 0.8805188625734968, 0.5608375082464142, 0.7219316163727129,
    0.6668371636871334, 1.2470395365788032, 0.39742086811709953, 0.6565338508254507, 0.07295213034913761,
    -0.7764949079170393, 0.8268092977201803, 0.9322180994297529, 0.12891748979677903, 1.6348773119938038
);

const KERNEL_CONV2D_SHARPEN_WEIGHTS: array<f32, 9> = array<f32, 9>(
    0.0, -1.0, 0.0,
    -1.0, 5.0, -1.0,
    0.0, -1.0, 0.0
);

const KERNEL_CONV2D_SOBEL_X_WEIGHTS: array<f32, 9> = array<f32, 9>(
    1.0, 0.0, -1.0,
    2.0, 0.0, -2.0,
    1.0, 0.0, -1.0
);

const KERNEL_CONV2D_SOBEL_Y_WEIGHTS: array<f32, 9> = array<f32, 9>(
    1.0, 2.0, 1.0,
    0.0, 0.0, 0.0,
    -1.0, -2.0, -1.0
);

struct Uniforms {
    kernel: i32,
    _pad0: i32,
    _pad1: i32,
    _pad2: i32,
};

@group(0) @binding(0) var inputTex: texture_2d<f32>;
@group(0) @binding(1) var<uniform> uniforms: Uniforms;

fn get_kernel_dims(kernel_id: i32) -> vec2<i32> {
    if (kernel_id == KERNEL_CONV2D_BLUR || kernel_id == KERNEL_CONV2D_RAND) {
        return vec2<i32>(5, 5);
    }
    return vec2<i32>(3, 3);
}

fn get_weight(kernel_id: i32, index: i32) -> f32 {
    if (kernel_id == KERNEL_CONV2D_BLUR) { return KERNEL_CONV2D_BLUR_WEIGHTS[index]; }
    if (kernel_id == KERNEL_CONV2D_BOX_BLUR) { return KERNEL_CONV2D_BOX_BLUR_WEIGHTS[index]; }
    if (kernel_id == KERNEL_CONV2D_DERIV_X) { return KERNEL_CONV2D_DERIV_X_WEIGHTS[index]; }
    if (kernel_id == KERNEL_CONV2D_DERIV_Y) { return KERNEL_CONV2D_DERIV_Y_WEIGHTS[index]; }
    if (kernel_id == KERNEL_CONV2D_EDGES) { return KERNEL_CONV2D_EDGES_WEIGHTS[index]; }
    if (kernel_id == KERNEL_CONV2D_EMBOSS) { return KERNEL_CONV2D_EMBOSS_WEIGHTS[index]; }
    if (kernel_id == KERNEL_CONV2D_INVERT) { return KERNEL_CONV2D_INVERT_WEIGHTS[index]; }
    if (kernel_id == KERNEL_CONV2D_RAND) { return KERNEL_CONV2D_RAND_WEIGHTS[index]; }
    if (kernel_id == KERNEL_CONV2D_SHARPEN) { return KERNEL_CONV2D_SHARPEN_WEIGHTS[index]; }
    if (kernel_id == KERNEL_CONV2D_SOBEL_X) { return KERNEL_CONV2D_SOBEL_X_WEIGHTS[index]; }
    if (kernel_id == KERNEL_CONV2D_SOBEL_Y) { return KERNEL_CONV2D_SOBEL_Y_WEIGHTS[index]; }
    return 0.0;
}

fn get_kernel_denom(kernel_id: i32) -> f32 {
    let dims = get_kernel_dims(kernel_id);
    var max_abs: f32 = 0.0;
    for (var i = 0; i < dims.x * dims.y; i++) {
        let w = abs(get_weight(kernel_id, i));
        max_abs = max(max_abs, w);
    }
    if (max_abs == 0.0) { return 1.0; }
    return max_abs;
}

@fragment
fn main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {
    let kernel_id = uniforms.kernel;
    let dims = get_kernel_dims(kernel_id);
    let denom = get_kernel_denom(kernel_id);
    
    let tex_size = textureDimensions(inputTex);
    let coord = vec2<i32>(fragCoord.xy);
    
    var accum = vec4<f32>(0.0);
    
    for (var ky = 0; ky < dims.y; ky++) {
        for (var kx = 0; kx < dims.x; kx++) {
            let offset_x = kx - dims.x / 2;
            let offset_y = ky - dims.y / 2;
            
            var sample_pos = coord + vec2<i32>(offset_x, offset_y);
            
            // Wrap around
            sample_pos.x = sample_pos.x % i32(tex_size.x);
            if (sample_pos.x < 0) { sample_pos.x += i32(tex_size.x); }
            sample_pos.y = sample_pos.y % i32(tex_size.y);
            if (sample_pos.y < 0) { sample_pos.y += i32(tex_size.y); }
            
            let sample_val = textureLoad(inputTex, sample_pos, 0);
            
            let index = ky * dims.x + kx;
            let weight = get_weight(kernel_id, index);
            
            accum += sample_val * (weight / denom);
        }
    }
    
    return accum;
}
