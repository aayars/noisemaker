// WGSL version – WebGPU
@group(0) @binding(0) var samp: sampler;
@group(0) @binding(1) var tex0: texture_2d<f32>;
@group(0) @binding(2) var<uniform> threshold: f32;
@group(0) @binding(3) var<uniform> tolerance: f32;

fn luminance(c: vec3<f32>) -> f32 {
  return dot(c, vec3<f32>(0.2126, 0.7152, 0.0722));
}

/* Outputs alpha mask of pixels near a luminance threshold. */
@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  let size = vec2<f32>(textureDimensions(tex0, 0));
  let st = position.xy / size;
  let c = textureSample(tex0, samp, st);
  let a = smoothstep(threshold - (tolerance + 0.0000001), threshold + (tolerance + 0.0000001), luminance(c.rgb));
  return vec4<f32>(c.rgb * a, a);
}
