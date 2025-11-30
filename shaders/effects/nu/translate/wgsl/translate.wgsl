/*
 * Translate image X and Y
 */

struct Uniforms {
    translateX: f32,
    translateY: f32,
    _pad1: f32,
    _pad2: f32,
}

@group(0) @binding(0) var inputSampler: sampler;
@group(0) @binding(1) var inputTex: texture_2d<f32>;
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

@fragment
fn main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let texSize = vec2<f32>(textureDimensions(inputTex));
    var uv = pos.xy / texSize;
    
    // Apply translation with wrap
    uv.x = fract(uv.x - uniforms.translateX);
    uv.y = fract(uv.y - uniforms.translateY);

    return textureSample(inputTex, inputSampler, uv);
}
