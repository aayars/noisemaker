/*
 * Color posterization effect
 * Reduces color levels for poster-like appearance
 */

struct Uniforms {
    levels: f32,
    _pad1: f32,
    _pad2: f32,
    _pad3: f32,
}

@group(0) @binding(0) var inputSampler: sampler;
@group(0) @binding(1) var inputTex: texture_2d<f32>;
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

fn posterize(color: vec3<f32>, lev: f32) -> vec3<f32> {
    if (lev == 0.0) {
        return color;
    } else if (lev == 1.0) {
        return step(vec3<f32>(0.5), color);
    }
    
    let gamma = 0.65;
    var c = pow(color, vec3<f32>(gamma));
    c = floor(c * lev) / lev;
    c = pow(c, vec3<f32>(1.0 / gamma));
    
    return c;
}

@fragment
fn main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let texSize = vec2<f32>(textureDimensions(inputTex));
    let uv = pos.xy / texSize;
    
    var color = textureSample(inputTex, inputSampler, uv);
    color = vec4<f32>(posterize(color.rgb, uniforms.levels), color.a);
    
    return color;
}
