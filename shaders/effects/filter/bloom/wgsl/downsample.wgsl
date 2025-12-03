/*
 * Bloom downsample pass
 * Averages pixels into a smaller grid with highlight boost
 */

struct Uniforms {
    _pad: vec4<f32>,
}

@group(0) @binding(0) var inputSampler: sampler;
@group(0) @binding(1) var inputTex: texture_2d<f32>;
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

const BOOST: f32 = 4.0;
const DOWNSAMPLE_SIZE: vec2<i32> = vec2<i32>(64, 64);

@fragment
fn main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let downCoord = vec2<i32>(pos.xy);
    let fullSize = vec2<i32>(textureDimensions(inputTex));
    
    // Early out if outside downsample bounds
    if (downCoord.x >= DOWNSAMPLE_SIZE.x || downCoord.y >= DOWNSAMPLE_SIZE.y) {
        return vec4<f32>(0.0);
    }
    
    // Calculate kernel size - how many source pixels per downsample cell
    let kernelWidth = max((fullSize.x + DOWNSAMPLE_SIZE.x - 1) / DOWNSAMPLE_SIZE.x, 1);
    let kernelHeight = max((fullSize.y + DOWNSAMPLE_SIZE.y - 1) / DOWNSAMPLE_SIZE.y, 1);
    
    // Origin in full resolution space
    let originX = downCoord.x * kernelWidth;
    let originY = downCoord.y * kernelHeight;
    
    // Accumulate pixel values
    var accum = vec3<f32>(0.0);
    var sampleCount: f32 = 0.0;
    
    for (var ky: i32 = 0; ky < kernelHeight; ky++) {
        let sampleY = originY + ky;
        if (sampleY >= fullSize.y) { break; }
        
        for (var kx: i32 = 0; kx < kernelWidth; kx++) {
            let sampleX = originX + kx;
            if (sampleX >= fullSize.x) { break; }
            
            let texel = textureLoad(inputTex, vec2<i32>(sampleX, sampleY), 0).rgb;
            let highlight = clamp(texel, vec3<f32>(0.0), vec3<f32>(1.0));
            accum += highlight;
            sampleCount += 1.0;
        }
    }
    
    if (sampleCount <= 0.0) {
        return vec4<f32>(0.0);
    }
    
    // Average and boost
    let average = accum / sampleCount;
    let boosted = average * BOOST;
    
    return vec4<f32>(boosted, sampleCount);
}
