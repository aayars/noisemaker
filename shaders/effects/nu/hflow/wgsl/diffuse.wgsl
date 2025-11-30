// Hydraulic Flow - Pass 3: Diffuse/blur trail texture
// Applies 3x3 blur with decay for trail spreading

struct Uniforms {
    resolution: vec2<f32>,
    intensity: f32,
    _pad: f32,
}

@group(0) @binding(0) var u_sampler: sampler;
@group(0) @binding(1) var sourceTex: texture_2d<f32>;
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
    let texel = 1.0 / uniforms.resolution;
    let uv = position.xy * texel;
    
    // Simple 3x3 blur for trail diffusion
    var sum = vec4<f32>(0.0);
    for (var x: i32 = -1; x <= 1; x = x + 1) {
        for (var y: i32 = -1; y <= 1; y = y + 1) {
            let offset = vec2<f32>(f32(x), f32(y)) * texel;
            sum = sum + textureSample(sourceTex, u_sampler, uv + offset);
        }
    }
    
    let current = textureSample(sourceTex, u_sampler, uv);
    let decay = (100.0 - uniforms.intensity) * 0.001; // intensity controls persistence
    let blurred = mix(current, sum / 9.0, 0.25);
    let value = max(blurred - vec4<f32>(decay), vec4<f32>(0.0));
    
    return vec4<f32>(value.rgb, 1.0);
}
