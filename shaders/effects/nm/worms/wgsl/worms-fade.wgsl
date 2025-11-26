// Worms effect - Fade trails pass
// Decays the trail texture each frame for temporal accumulation

// Packed uniform layout:
// data[0].xy = resolution
// data[0].z  = time
// data[0].w  = frame
// data[1].x  = intensity
// data[1].y  = inputIntensity

struct Uniforms {
    data : array<vec4<f32>, 2>,
};

@group(0) @binding(0) var u_sampler : sampler;
@group(0) @binding(1) var trailTex : texture_2d<f32>;
@group(0) @binding(2) var<uniform> uniforms : Uniforms;

@fragment
fn main(@builtin(position) position : vec4<f32>) -> @location(0) vec4<f32> {
    // Unpack uniforms
    let resolution = uniforms.data[0].xy;
    let intensity = uniforms.data[1].x;
    
    let size = vec2<f32>(max(resolution.x, 1.0), max(resolution.y, 1.0));
    let uv = position.xy / size;
    
    let trail = textureSample(trailTex, u_sampler, uv);
    
    // Decay based on intensity (higher intensity = slower decay)
    let decay = clamp(intensity / 100.0, 0.0, 0.99);
    
    return trail * decay;
}
