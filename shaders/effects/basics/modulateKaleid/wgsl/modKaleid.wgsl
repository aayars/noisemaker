// WGSL version – WebGPU
@group(0) @binding(0) var samp: sampler;
@group(0) @binding(1) var tex0: texture_2d<f32>;
@group(0) @binding(2) var tex1: texture_2d<f32>;
@group(0) @binding(3) var<uniform> n: f32;
@group(0) @binding(4) var<uniform> amount: f32;

/* Mirrors the modulator into n segments before displacement. */
const PI: f32 = 3.141592653589793;

fn mod_f32(x: f32, y: f32) -> f32 {
  return x - y * floor(x / y);
}
@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  var st = position.xy / vec2<f32>(textureDimensions(tex0, 0));
  var p = st - vec2<f32>(0.5, 0.5);
  let r = length(p);
  var a = atan2(p.y, p.x);
  let sector = 2.0 * PI / n;
  a = mod_f32(a, sector);
  let uv = vec2<f32>(cos(a), sin(a)) * r + vec2<f32>(0.5, 0.5);
  let m = textureSample(tex1, samp, uv);
  st = st + (m.xy * 2.0 - vec2<f32>(1.0, 1.0)) * amount;
  return vec4<f32>(textureSample(tex0, samp, st).rgb, 1.0);
}
