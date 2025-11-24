// WGSL version – WebGPU
@group(0) @binding(0) var samp: sampler;
@group(0) @binding(1) var tex0: texture_2d<f32>;
@group(0) @binding(2) var<uniform> scale: f32;
@group(0) @binding(3) var<uniform> offset: f32;

/* Extracts blue channel as grayscale. */
@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  let st = position.xy / vec2<f32>(textureDimensions(tex0, 0));
  let c = textureSample(tex0, samp, st);
  let v = c.b * scale + offset;
  return vec4<f32>(vec3<f32>(v), 1.0);
}
