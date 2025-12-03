// WGSL version – WebGPU
// Group 0 bindings follow the live-code mixer convention: sampler, base
// texture, blend texture, and scalar blend weight.
@group(0) @binding(0) var samp: sampler;
@group(0) @binding(1) var tex0: texture_2d<f32>;
@group(0) @binding(2) var tex1: texture_2d<f32>;
@group(0) @binding(3) var<uniform> amount: f32;

/* Adds tex1 over tex0 scaled by amount. */
@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  // WGSL fragment coordinates are upper-left; normalize to [0, 1] UV space.
  let st: vec2<f32> = position.xy / vec2<f32>(textureDimensions(tex0, 0));
  let a: vec4<f32> = textureSample(tex0, samp, st);
  let b: vec3<f32> = textureSample(tex1, samp, st).rgb * amount;
  return vec4<f32>(a.rgb + b, 1.0);
}
