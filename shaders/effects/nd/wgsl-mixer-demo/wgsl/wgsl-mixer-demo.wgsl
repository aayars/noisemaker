// Matches the host-side effect uniform layout: four vec4<f32> entries packed in
// an array for alignment with JavaScript-side buffers.
struct Uniforms {
    data : array<vec4<f32>, 4>,
};
// Group 0 bindings align with the WebGPU pipeline configuration in gpu.js.
@group(0) @binding(0) var<uniform> uniforms : Uniforms;
@group(0) @binding(1) var samp : sampler;
@group(0) @binding(2) var tex0 : texture_2d<f32>;
@group(0) @binding(3) var tex1 : texture_2d<f32>;

@fragment
fn fs_main(@builtin(position) pos : vec4<f32>) -> @location(0) vec4<f32> {
    let resolution: vec2<f32> = uniforms.data[0].xy;
    let mixAmount: f32 = uniforms.data[1].x;
    // Fragment positions follow the WGSL upper-left origin convention.
    let uv: vec2<f32> = pos.xy / resolution;
    let synthA: vec4<f32> = textureSample(tex0, samp, uv);
    let synthB: vec4<f32> = textureSample(tex1, samp, uv);
    let blendWeight: f32 = clamp(mixAmount, 0.0, 1.0);
    return mix(synthA, synthB, blendWeight);
}

