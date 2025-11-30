/*
 * Lens distortion (barrel/pincushion)
 * Warps sample coordinates radially around the frame center
 */

struct Uniforms {
    lensDisplacement: f32,
    _pad1: f32,
    _pad2: f32,
    _pad3: f32,
}

@group(0) @binding(0) var inputSampler: sampler;
@group(0) @binding(1) var inputTex: texture_2d<f32>;
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

const HALF_FRAME: f32 = 0.5;
const MAX_DISTANCE: f32 = 0.7071067811865476; // sqrt(0.5*0.5 + 0.5*0.5)

@fragment
fn main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let texSize = vec2<f32>(textureDimensions(inputTex));
    let uv = pos.xy / texSize;
    
    // Zoom for negative displacement (pincushion)
    var zoom: f32 = 0.0;
    if (uniforms.lensDisplacement < 0.0) {
        zoom = uniforms.lensDisplacement * -0.25;
    }
    
    // Distance from center
    let dist = uv - HALF_FRAME;
    let distFromCenter = length(dist);
    let normalizedDist = clamp(distFromCenter / MAX_DISTANCE, 0.0, 1.0);
    
    // Stronger effect near edges, weaker at center
    let centerWeight = 1.0 - normalizedDist;
    let centerWeightSq = centerWeight * centerWeight;
    
    // Apply radial distortion
    var offset = uv - dist * zoom - dist * centerWeightSq * uniforms.lensDisplacement;
    
    // Wrap coordinates
    offset = fract(offset);

    return textureSample(inputTex, inputSampler, offset);
}
