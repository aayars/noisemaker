// WGSL version – WebGPU
@group(0) @binding(0) var samp: sampler;
@group(0) @binding(1) var tex0: texture_2d<f32>;
@group(0) @binding(2) var tex1: texture_2d<f32>;
@group(0) @binding(3) var<uniform> amount: f32;

/* Linear interpolation between two textures. */
@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  let st = position.xy / vec2<f32>(textureDimensions(tex0, 0));
  let a = textureSample(tex0, samp, st);
  let b = textureSample(tex1, samp, st);
  let rgb = mix(a.rgb, b.rgb, amount);
  return vec4<f32>(rgb, 1.0);
}
