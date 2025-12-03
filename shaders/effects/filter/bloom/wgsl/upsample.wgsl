/*
 * Bloom upsample pass
 * Bilinear upsamples the downsampled data and blends with original
 */

struct Uniforms {
    bloomAlpha: f32,
    _pad1: f32,
    _pad2: f32,
    _pad3: f32,
}

@group(0) @binding(0) var inputSampler: sampler;
@group(0) @binding(1) var inputTex: texture_2d<f32>;
@group(0) @binding(2) var downsampleBuffer: texture_2d<f32>;
@group(0) @binding(3) var<uniform> uniforms: Uniforms;

const BRIGHTNESS_ADJUST: f32 = 0.25;
const DOWNSAMPLE_SIZE: vec2<f32> = vec2<f32>(64.0, 64.0);

fn clamp01(v: vec3<f32>) -> vec3<f32> {
    return clamp(v, vec3<f32>(0.0), vec3<f32>(1.0));
}

@fragment
fn main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let coord = vec2<i32>(pos.xy);
    let fullSize = vec2<f32>(textureDimensions(inputTex));
    
    // Get original pixel
    let original = textureLoad(inputTex, coord, 0);
    let alpha = clamp(uniforms.bloomAlpha, 0.0, 1.0);
    
    // Early return if no bloom
    if (alpha <= 0.0) {
        return vec4<f32>(clamp01(original.rgb), original.a);
    }
    
    // Calculate UV in downsample texture space
    let uv = (vec2<f32>(coord) + 0.5) / fullSize;
    
    // 9-tap tent filter for smooth upsampling
    let texelSize = 1.0 / DOWNSAMPLE_SIZE;
    
    var sum = vec3<f32>(0.0);
    
    // Center tap (weight 4)
    sum += textureSample(downsampleBuffer, inputSampler, uv).rgb * 4.0;
    
    // Edge taps (weight 2 each)
    sum += textureSample(downsampleBuffer, inputSampler, uv + vec2<f32>(-texelSize.x, 0.0)).rgb * 2.0;
    sum += textureSample(downsampleBuffer, inputSampler, uv + vec2<f32>( texelSize.x, 0.0)).rgb * 2.0;
    sum += textureSample(downsampleBuffer, inputSampler, uv + vec2<f32>(0.0, -texelSize.y)).rgb * 2.0;
    sum += textureSample(downsampleBuffer, inputSampler, uv + vec2<f32>(0.0,  texelSize.y)).rgb * 2.0;
    
    // Corner taps (weight 1 each)
    sum += textureSample(downsampleBuffer, inputSampler, uv + vec2<f32>(-texelSize.x, -texelSize.y)).rgb;
    sum += textureSample(downsampleBuffer, inputSampler, uv + vec2<f32>( texelSize.x, -texelSize.y)).rgb;
    sum += textureSample(downsampleBuffer, inputSampler, uv + vec2<f32>(-texelSize.x,  texelSize.y)).rgb;
    sum += textureSample(downsampleBuffer, inputSampler, uv + vec2<f32>( texelSize.x,  texelSize.y)).rgb;
    
    // Normalize (4 + 2*4 + 1*4 = 16)
    let bloomSample = sum / 16.0;
    
    // Add brightness boost
    let boosted = clamp01(bloomSample + vec3<f32>(BRIGHTNESS_ADJUST));
    
    // Blend with original using additive-style blend
    let sourceClamped = clamp01(original.rgb);
    let mixed = clamp01((sourceClamped + boosted) * 0.5);
    let finalRgb = clamp01(sourceClamped * (1.0 - alpha) + mixed * alpha);
    
    return vec4<f32>(finalRgb, original.a);
}
