/*
 * Rotate image 0..1 (0..360 degrees)
 */

struct Uniforms {
    rotation: f32,
    _pad1: f32,
    _pad2: f32,
    _pad3: f32,
}

@group(0) @binding(0) var inputSampler: sampler;
@group(0) @binding(1) var inputTex: texture_2d<f32>;
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

const TAU: f32 = 6.283185307179586;

fn rotate2D(angle: f32) -> mat2x2<f32> {
    let c = cos(angle);
    let s = sin(angle);
    return mat2x2<f32>(c, -s, s, c);
}

@fragment
fn main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let texSize = vec2<f32>(textureDimensions(inputTex));
    var uv = pos.xy / texSize;
    
    // Center, rotate, uncenter
    let center = vec2<f32>(0.5);
    uv -= center;
    uv = rotate2D(uniforms.rotation * TAU) * uv;
    uv += center;
    
    // Wrap coordinates
    uv = fract(uv);

    return textureSample(inputTex, inputSampler, uv);
}
