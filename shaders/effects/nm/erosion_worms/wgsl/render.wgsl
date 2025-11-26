// Erosion Worms - Final render pass
// Blends trail texture with input

// Packed uniform layout:
// data[0].xy = resolution
// data[0].z  = inputIntensity

struct Uniforms {
    data : array<vec4<f32>, 1>,
};

@group(0) @binding(0) var u_sampler : sampler;
@group(0) @binding(1) var trailTex : texture_2d<f32>;
@group(0) @binding(2) var inputTex : texture_2d<f32>;
@group(0) @binding(3) var<uniform> uniforms : Uniforms;

@fragment
fn main(@builtin(position) position : vec4<f32>) -> @location(0) vec4<f32> {
    // Unpack uniforms
    let resolution = uniforms.data[0].xy;
    let inputIntensity = uniforms.data[0].z;
    
    let size = vec2<f32>(max(resolution.x, 1.0), max(resolution.y, 1.0));
    let uv = position.xy / size;
    
    let trail = textureSample(trailTex, u_sampler, uv);
    let img = textureSample(inputTex, u_sampler, uv);
    
    let intensity = clamp(inputIntensity / 100.0, 0.0, 1.0);
    
    // Combine: add trails on top of input image
    let combined = img.rgb * intensity + trail.rgb;
    let finalAlpha = max(img.a, trail.a);
    
    return vec4<f32>(combined, finalAlpha);
}
