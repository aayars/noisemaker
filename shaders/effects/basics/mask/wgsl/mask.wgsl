// WGSL version – WebGPU
@group(0) @binding(0) var sampler: sampler;
@group(0) @binding(1) var tex0: texture_2d<f32>;
@group(0) @binding(2) var tex1: texture_2d<f32>;

/* Uses tex1 red channel as alpha mask for tex0. */
@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
  let st = position.xy / vec2<f32>(textureDimensions(tex0, 0));
  let a = textureSample(tex0, sampler, st);
  let m = textureSample(tex1, sampler, st).r;
  return vec4<f32>(a.rgb * m, 1.0);
}
