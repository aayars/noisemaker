// Wormhole: per-pixel field flow driven by luminance
// Matches GLSL implementation - simple per-pixel offset based on luminance

const TAU : f32 = 6.28318530717958647692;

@group(0) @binding(0) var u_sampler : sampler;
@group(0) @binding(1) var inputTex : texture_2d<f32>;
@group(0) @binding(2) var<uniform> resolution : vec2<f32>;
@group(0) @binding(3) var<uniform> time : f32;
@group(0) @binding(4) var<uniform> kink : f32;
@group(0) @binding(5) var<uniform> stride : f32;
@group(0) @binding(6) var<uniform> alpha : f32;
@group(0) @binding(7) var<uniform> speed : f32;

fn luminance(color : vec4<f32>) -> f32 {
    return dot(color.xyz, vec3<f32>(0.2126, 0.7152, 0.0722));
}

@fragment
fn main(@builtin(position) position : vec4<f32>) -> @location(0) vec4<f32> {
    let dims = textureDimensions(inputTex, 0);
    let uv = position.xy / resolution;
    
    // Get source pixel
    let src = textureSample(inputTex, u_sampler, uv);
    let lum = luminance(src);
    
    // Calculate flow angle based on luminance
    let angle = lum * TAU * kink + time * speed;
    
    // Calculate offset - stride controls displacement in pixels
    // With default stride=0.5, this gives roughly 5-10 pixel offset
    let stridePixels = stride * 10.0;
    let offsetX = (cos(angle) + 1.0) * stridePixels;
    let offsetY = (sin(angle) + 1.0) * stridePixels;
    
    // Sample from offset position
    var sampleCoord = uv + vec2<f32>(offsetX, offsetY) / vec2<f32>(f32(dims.x), f32(dims.y));
    sampleCoord = fract(sampleCoord);
    
    let sampled = textureSample(inputTex, u_sampler, sampleCoord);
    
    // Blend with original
    let result = mix(src, sampled, alpha);
    
    return result;
}
