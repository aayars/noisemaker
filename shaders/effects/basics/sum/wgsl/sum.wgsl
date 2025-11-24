// WGSL version – WebGPU
@group(0) @binding(0) var u_sampler: sampler;
@group(0) @binding(1) var tex0: texture_2d<f32>;
@group(0) @binding(2) var<uniform> scale: f32;

/* Sums all channels, wrapping the magnitude to preserve variation. */
@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  let st = position.xy / vec2<f32>(textureDimensions(tex0, 0));
  let inputColor = textureSample(tex0, u_sampler, st);
  let summed = dot(inputColor, vec4<f32>(1.0));
  let scaled = summed * scale;

  var wrapped: f32;
  if (scaled >= 0.0) {
    wrapped = fract(scaled);
  } else {
    wrapped = 1.0 - fract(abs(scaled));
  }

  return vec4<f32>(vec3<f32>(wrapped), 1.0);
}
