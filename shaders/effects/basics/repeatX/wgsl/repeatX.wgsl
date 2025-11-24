// WGSL version – WebGPU
@group(0) @binding(0) var samp: sampler;
@group(0) @binding(1) var tex0: texture_2d<f32>;
@group(0) @binding(2) var<uniform> resolution: vec2<f32>;
@group(0) @binding(3) var<uniform> aspect: f32;
@group(0) @binding(4) var<uniform> x: f32;
@group(0) @binding(5) var<uniform> offset: f32;

/* Repeats the input texture along the X axis. */
@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  var st = position.xy / resolution;
  st.x = st.x * aspect;
  st.x = st.x * x + offset * aspect;
  st.x = st.x / aspect;
  st.x = fract(st.x);
  return vec4<f32>(textureSample(tex0, samp, st).rgb, 1.0);
}
