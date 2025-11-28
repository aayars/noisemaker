// Normalize render pass - normalizes convolved output and blends with original
// Matches normalizeRender.glsl (GPGPU fragment shader)

const KERNEL_CONV2D_EDGES: i32 = 803;

struct Uniforms {
    kernel: i32,
    withNormalize: f32,
    alpha: f32,
    _pad: f32,
};

@group(0) @binding(0) var convolvedTexture: texture_2d<f32>;
@group(0) @binding(1) var minmaxTexture: texture_2d<f32>;
@group(0) @binding(2) var inputTex: texture_2d<f32>;
@group(0) @binding(3) var<uniform> uniforms: Uniforms;

@fragment
fn main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {
    let minmax = textureLoad(minmaxTexture, vec2<i32>(0, 0), 0);
    var min_val = minmax.x;
    var max_val = minmax.y;
    
    let coord = vec2<i32>(fragCoord.xy);
    var processed = textureLoad(convolvedTexture, coord, 0);
    
    let do_normalize = uniforms.withNormalize > 0.5;
    let alpha_val = clamp(uniforms.alpha, 0.0, 1.0);
    let kernel_id = uniforms.kernel;
    
    if (min_val > max_val) {
        min_val = 0.0;
        max_val = 0.0;
    }
    
    if (do_normalize && max_val > min_val) {
        let inv_range = 1.0 / (max_val - min_val);
        processed = (processed - min_val) * inv_range;
    }
    
    if (kernel_id == KERNEL_CONV2D_EDGES) {
        // abs(value - 0.5) * 2.0
        processed = abs(processed - 0.5) * 2.0;
    }
    
    let original = textureLoad(inputTex, coord, 0);
    var result = mix(original, processed, alpha_val);
    result.a = original.a;
    
    return result;
}
