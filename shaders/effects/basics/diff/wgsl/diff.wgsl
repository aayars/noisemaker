// WGSL version – WebGPU
@group(0) @binding(0) var sampler: sampler;
@group(0) @binding(1) var tex0: texture_2d<f32>;
@group(0) @binding(2) var tex1: texture_2d<f32>;

/* Absolute difference between two textures. */
@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  let st = position.xy / vec2<f32>(textureDimensions(tex0, 0));
  let a = textureSample(tex0, sampler, st);
  let b = textureSample(tex1, sampler, st);
  let rgb = abs(a.rgb - b.rgb);
  return vec4<f32>(rgb, 1.0);
}
