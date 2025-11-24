// WGSL version – WebGPU
@group(0) @binding(0) var sampler: sampler;
@group(0) @binding(1) var tex0: texture_2d<f32>;
@group(0) @binding(2) var tex1: texture_2d<f32>;
@group(0) @binding(3) var<uniform> multiple: f32;
@group(0) @binding(4) var<uniform> offset: f32;

/* Rotates coordinates by an angle derived from the modulator. */
@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  let size = vec2<f32>(textureDimensions(tex0, 0));
  var st = position.xy / size - vec2<f32>(0.5, 0.5);
  let m = textureSample(tex1, sampler, st + vec2<f32>(0.5, 0.5));
  let angle = (m.r - 0.5) * multiple + offset;
  let rot = mat2x2<f32>(cos(angle), -sin(angle), sin(angle), cos(angle));
  st = rot * st;
  st = st + vec2<f32>(0.5, 0.5);
  return vec4<f32>(textureSample(tex0, sampler, st).rgb, 1.0);
}
