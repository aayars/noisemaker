// WGSL version – WebGPU
@group(0) @binding(0) var samp: sampler;
@group(0) @binding(1) var tex0: texture_2d<f32>;
@group(0) @binding(2) var tex1: texture_2d<f32>;

/* Overlays tex1 atop tex0 using tex1 alpha. */
@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  let size = vec2<f32>(textureDimensions(tex0, 0));
  let st = position.xy / size;
  let a = textureSample(tex0, samp, st);
  let b = textureSample(tex1, samp, st);
  let rgb = mix(a.rgb, b.rgb, b.a);
  return vec4<f32>(rgb, 1.0);
}
