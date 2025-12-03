// WGSL version – WebGPU
@group(0) @binding(0) var samp: sampler;
@group(0) @binding(1) var tex0: texture_2d<f32>;
@group(0) @binding(2) var tex1: texture_2d<f32>;
@group(0) @binding(3) var<uniform> amount: f32;

/* Multiplies tex0 by tex1 scaled by amount. */
@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  let st = position.xy / vec2<f32>(textureDimensions(tex0, 0));
  let a = textureSample(tex0, samp, st);
  let mask = textureSample(tex1, samp, st).rgb;
  let mixAmount = clamp(amount, 0.0, 1.0);
  let blended = mix(vec3<f32>(1.0), mask, mixAmount);
  return vec4<f32>(a.rgb * blended, a.a);
}
