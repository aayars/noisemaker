// WGSL version – WebGPU
@group(0) @binding(0) var sampler: sampler;
@group(0) @binding(1) var tex0: texture_2d<f32>;
@group(0) @binding(2) var<uniform> resolution: vec2<f32>;
@group(0) @binding(3) var<uniform> aspect: f32;
@group(0) @binding(4) var<uniform> x: f32;
@group(0) @binding(5) var<uniform> speed: f32;
@group(0) @binding(6) var<uniform> time: f32;

/* Scrolls texture horizontally with wraparound. */
@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  var st = position.xy / resolution;
  st.x *= aspect;
  let shift = (x + time * speed) * aspect;
  st.x += shift;
  st.x /= aspect;
  st = fract(st);
  let color = textureSample(tex0, sampler, st).rgb;
  return vec4<f32>(color, 1.0);
}
