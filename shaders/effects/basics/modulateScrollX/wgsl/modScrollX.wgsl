// WGSL version – WebGPU
@group(0) @binding(0) var sampler: sampler;
@group(0) @binding(1) var tex0: texture_2d<f32>;
@group(0) @binding(2) var tex1: texture_2d<f32>;
@group(0) @binding(3) var<uniform> scrollX: f32;
@group(0) @binding(4) var<uniform> speed: f32;
@group(0) @binding(5) var<uniform> time: f32;
@group(0) @binding(6) var<uniform> amount: f32;

/* Scrolls the modulator along X before displacement. */
@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  var st = position.xy / vec2<f32>(textureDimensions(tex0, 0));
  let shift = scrollX + time * speed;
  let m = textureSample(tex1, sampler, st + vec2<f32>(shift, 0.0));
  st = st + (m.xy * 2.0 - vec2<f32>(1.0, 1.0)) * amount;
  return vec4<f32>(textureSample(tex0, sampler, st).rgb, 1.0);
}
