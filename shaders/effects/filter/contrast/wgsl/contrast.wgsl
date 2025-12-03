/*
 * Contrast adjustment effect
 */

struct Uniforms {
    data: array<vec4<f32>, 1>,
};

@group(0) @binding(0) var inputSampler: sampler;
@group(0) @binding(1) var inputTex: texture_2d<f32>;
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

@fragment
fn main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let amount = uniforms.data[0].x;
    let texSize = vec2<f32>(textureDimensions(inputTex));
    let uv = pos.xy / texSize;
    var color = textureSample(inputTex, inputSampler, uv);

    let contrast = amount * 2.0;  // 0..1 -> 0..2
    color = vec4<f32>((color.rgb - 0.5) * contrast + 0.5, color.a);

    return color;
}
