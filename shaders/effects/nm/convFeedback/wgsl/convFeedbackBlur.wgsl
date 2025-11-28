// Conv2d feedback - Blur pass
// Applies 5x5 Gaussian blur to the current input texture

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
}

@group(0) @binding(0) var inputTex: texture_2d<f32>;

// 5x5 Gaussian blur kernel (matches Python ValueMask.conv2d_blur)
const BLUR_KERNEL: array<f32, 25> = array<f32, 25>(
    1.0, 4.0, 6.0, 4.0, 1.0,
    4.0, 16.0, 24.0, 16.0, 4.0,
    6.0, 24.0, 36.0, 24.0, 6.0,
    4.0, 16.0, 24.0, 16.0, 4.0,
    1.0, 4.0, 6.0, 4.0, 1.0
);
const BLUR_KERNEL_SUM: f32 = 256.0;

@fragment
fn main(in: VertexOutput) -> @location(0) vec4<f32> {
    let tex_size = vec2<i32>(textureDimensions(inputTex));
    let coord = vec2<i32>(in.position.xy);
    
    var sum = vec3<f32>(0.0);
    
    for (var ky: i32 = -2; ky <= 2; ky = ky + 1) {
        for (var kx: i32 = -2; kx <= 2; kx = kx + 1) {
            var sample_pos = coord + vec2<i32>(kx, ky);
            sample_pos = clamp(sample_pos, vec2<i32>(0), tex_size - vec2<i32>(1));
            
            let sample_val = textureLoad(inputTex, sample_pos, 0);
            
            let idx = (ky + 2) * 5 + (kx + 2);
            let weight = BLUR_KERNEL[idx];
            sum = sum + sample_val.rgb * weight;
        }
    }
    
    let blurred = sum / BLUR_KERNEL_SUM;
    let alpha = textureLoad(inputTex, coord, 0).a;
    
    return vec4<f32>(blurred, alpha);
}
