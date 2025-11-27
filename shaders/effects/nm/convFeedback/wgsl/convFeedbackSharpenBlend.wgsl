// Conv Feedback - Sharpen + Blend pass
// Applies 3x3 sharpen to blurred texture, then blends with input

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
}

@group(0) @binding(0) var blurredTex: texture_2d<f32>;
@group(0) @binding(1) var blurredSampler: sampler;
@group(0) @binding(2) var inputTex: texture_2d<f32>;
@group(0) @binding(3) var inputSampler: sampler;
@group(0) @binding(4) var selfTex: texture_2d<f32>;
@group(0) @binding(5) var selfSampler: sampler;
@group(0) @binding(6) var<uniform> alpha: f32;

const SHARPEN_KERNEL: array<f32, 9> = array<f32, 9>(
    0.0, -1.0, 0.0,
    -1.0, 5.0, -1.0,
    0.0, -1.0, 0.0
);

@fragment
fn main(in: VertexOutput) -> @location(0) vec4<f32> {
    let tex_size = vec2<i32>(textureDimensions(blurredTex));
    let coord = vec2<i32>(in.position.xy);
    
    let input_val = textureLoad(inputTex, coord, 0);
    let self_val = textureLoad(selfTex, coord, 0);
    
    // Check if self (previous frame) is empty - use input as base
    let self_luma = dot(self_val.rgb, vec3<f32>(0.299, 0.587, 0.114));
    let is_first_frame = self_luma < 0.001 && self_val.a < 0.001;
    
    if (is_first_frame) {
        // First frame: just output the input
        return input_val;
    }
    
    // Apply 3x3 sharpen to blurred texture
    var sum = vec3<f32>(0.0);
    
    for (var ky: i32 = -1; ky <= 1; ky = ky + 1) {
        for (var kx: i32 = -1; kx <= 1; kx = kx + 1) {
            var sample_pos = coord + vec2<i32>(kx, ky);
            sample_pos = clamp(sample_pos, vec2<i32>(0), tex_size - vec2<i32>(1));
            
            let sample_val = textureLoad(blurredTex, sample_pos, 0);
            
            let idx = (ky + 1) * 3 + (kx + 1);
            let weight = SHARPEN_KERNEL[idx];
            sum = sum + sample_val.rgb * weight;
        }
    }
    
    let sharpened = clamp(sum, vec3<f32>(0.0), vec3<f32>(1.0));
    
    // Apply the up/down contrast expansion from Python reference
    // up = max((sharpened - 0.5) * 2, 0.0)
    let up = max((sharpened - 0.5) * 2.0, vec3<f32>(0.0));
    
    // down = min(sharpened * 2, 1.0)
    let down = min(sharpened * 2.0, vec3<f32>(1.0));
    
    // Combined: up + (1 - down)
    var processed = up + (vec3<f32>(1.0) - down);
    processed = clamp(processed, vec3<f32>(0.0), vec3<f32>(1.0));
    
    // Blend processed with input based on alpha
    let blended = mix(input_val.rgb, processed, alpha);
    
    return vec4<f32>(blended, input_val.a);
}
