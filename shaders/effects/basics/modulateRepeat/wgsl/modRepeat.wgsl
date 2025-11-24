// WGSL version – WebGPU
@group(0) @binding(0) var sampler: sampler;
@group(0) @binding(1) var tex0: texture_2d<f32>;
@group(0) @binding(2) var tex1: texture_2d<f32>;
@group(0) @binding(3) var<uniform> repeatX: f32;
@group(0) @binding(4) var<uniform> repeatY: f32;
@group(0) @binding(5) var<uniform> offsetX: f32;
@group(0) @binding(6) var<uniform> offsetY: f32;
@group(0) @binding(7) var<uniform> amount: f32;

/* Tiles the modulating texture before offsetting the base coordinates. */
@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  var st = position.xy / vec2<f32>(textureDimensions(tex0, 0));
  let rpt = vec2<f32>(repeatX, repeatY);
  let offs = vec2<f32>(offsetX, offsetY);
  let modUV = fract(st * rpt + offs);
  let m = textureSample(tex1, sampler, modUV);
  st = st + (m.xy * 2.0 - vec2<f32>(1.0, 1.0)) * amount;
  return vec4<f32>(textureSample(tex0, sampler, st).rgb, 1.0);
}
