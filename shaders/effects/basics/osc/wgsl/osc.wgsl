// WGSL version – WebGPU
@group(0) @binding(0) var<uniform> resolution: vec2<f32>;
@group(0) @binding(1) var<uniform> aspect: f32;
@group(0) @binding(2) var<uniform> time: f32;
@group(0) @binding(3) var<uniform> freq: f32;
@group(0) @binding(4) var<uniform> sync: f32;
@group(0) @binding(5) var<uniform> amp: f32;

/* Inspired by the idea of Hydra's osc: a time-varying sine pattern, reimplemented from scratch. */
@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  var st = position.xy / resolution;
  st.x = st.x * aspect;
  let phase = st.x * freq + time * sync;
  let r = sin(phase) * 0.5 + 0.5;
  let g = sin(phase + 2.0) * 0.5 + 0.5;
  let b = sin(phase + 4.0) * 0.5 + 0.5;
  let col = vec3<f32>(r, g, b) * amp;
  return vec4<f32>(col, 1.0);
}
