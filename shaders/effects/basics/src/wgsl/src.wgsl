// WGSL version – WebGPU
@group(0) @binding(0) var sampler: sampler;
@group(0) @binding(1) var tex0: texture_2d<f32>;
@group(0) @binding(2) var<uniform> resolution: vec2<f32>;

/* Pass-through sampler to pull from an existing surface. */
@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  let st = position.xy / resolution;
  return textureSample(tex0, sampler, st);
}
