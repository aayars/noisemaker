// WGSL version – WebGPU
@group(0) @binding(0) var uSampler: sampler;
@group(0) @binding(1) var uTex0: texture_2d<f32>;
@group(0) @binding(2) var<uniform> uR: f32;
@group(0) @binding(3) var<uniform> uG: f32;
@group(0) @binding(4) var<uniform> uB: f32;
@group(0) @binding(5) var<uniform> uA: f32;

/* Offsets each color channel by sampling nearby texels. */
@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  let texSize = vec2<f32>(textureDimensions(uTex0, 0));
  if (texSize.x <= 0.0 || texSize.y <= 0.0) {
    return vec4<f32>(0.0);
  }

  let uv = position.xy / texSize;
  let scale = max(0.0, 1.0 + uA);

  let sampleR = fract(uv + vec2<f32>(uR, 0.0) * scale);
  let sampleG = fract(uv + vec2<f32>(uG, 0.0) * scale);
  let sampleB = fract(uv + vec2<f32>(uB, 0.0) * scale);

  let base = textureSample(uTex0, uSampler, uv);
  let red = textureSample(uTex0, uSampler, sampleR).r;
  let green = textureSample(uTex0, uSampler, sampleG).g;
  let blue = textureSample(uTex0, uSampler, sampleB).b;

  return vec4<f32>(red, green, blue, base.a);
}
