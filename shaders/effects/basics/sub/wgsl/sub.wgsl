// WGSL version – WebGPU
@group(0) @binding(0) var sampler: sampler;
@group(0) @binding(1) var tex0: texture_2d<f32>;
@group(0) @binding(2) var tex1: texture_2d<f32>;
@group(0) @binding(3) var<uniform> amount: f32;

/* Subtracts tex1 from tex0 scaled by amount, clamped to zero. */
@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  let st = position.xy / vec2<f32>(textureDimensions(tex0, 0));
  let a = textureSample(tex0, sampler, st);
  let b = textureSample(tex1, sampler, st).rgb * amount;
  let rgb = max(a.rgb - b, vec3<f32>(0.0));
  return vec4<f32>(rgb, 1.0);
}
