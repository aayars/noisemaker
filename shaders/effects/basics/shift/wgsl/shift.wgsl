// WGSL version – WebGPU
@group(0) @binding(0) var u_sampler: sampler;
@group(0) @binding(1) var u_tex0: texture_2d<f32>;
@group(0) @binding(2) var<uniform> u_r: f32;
@group(0) @binding(3) var<uniform> u_g: f32;
@group(0) @binding(4) var<uniform> u_b: f32;
@group(0) @binding(5) var<uniform> u_a: f32;

/* Offsets each color channel by sampling nearby texels. */
@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  let texSize = vec2<f32>(textureDimensions(u_tex0, 0));
  if (texSize.x <= 0.0 || texSize.y <= 0.0) {
    return vec4<f32>(0.0);
  }

  let uv = position.xy / texSize;
  let scale = max(0.0, 1.0 + u_a);

  let sampleR = fract(uv + vec2<f32>(u_r, 0.0) * scale);
  let sampleG = fract(uv + vec2<f32>(u_g, 0.0) * scale);
  let sampleB = fract(uv + vec2<f32>(u_b, 0.0) * scale);

  let base = textureSample(u_tex0, u_sampler, uv);
  let red = textureSample(u_tex0, u_sampler, sampleR).r;
  let green = textureSample(u_tex0, u_sampler, sampleG).g;
  let blue = textureSample(u_tex0, u_sampler, sampleB).b;

  return vec4<f32>(red, green, blue, base.a);
}
