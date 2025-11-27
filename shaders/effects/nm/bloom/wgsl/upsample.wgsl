// Bloom upsample pass - fragment shader version for texture output
// Uses 9-tap tent filter for smooth upsampling without expensive global mean calculation

const BRIGHTNESS_ADJUST : f32 = 0.25;

@group(0) @binding(0) var inputTex : texture_2d<f32>;
@group(0) @binding(1) var downsampleBuffer : texture_2d<f32>;
@group(0) @binding(2) var downsampleSampler : sampler;
@group(0) @binding(3) var<uniform> resolution : vec2<f32>;
@group(0) @binding(4) var<uniform> downsampleSize : vec2<f32>;
@group(0) @binding(5) var<uniform> bloomAlpha : f32;

struct VertexOutput {
    @builtin(position) position : vec4<f32>,
    @location(0) uv : vec2<f32>,
}

fn clamp_vec01(value : vec3<f32>) -> vec3<f32> {
    return clamp(value, vec3<f32>(0.0), vec3<f32>(1.0));
}

@fragment
fn main(input : VertexOutput) -> @location(0) vec4<f32> {
    let coords : vec2<i32> = vec2<i32>(input.position.xy);
    let alpha : f32 = clamp(bloomAlpha, 0.0, 1.0);
    let source_sample : vec4<f32> = textureLoad(inputTex, coords, 0);

    // Calculate UV in downsample texture space
    let uv : vec2<f32> = (vec2<f32>(coords) + 0.5) / resolution;
    
    // 9-tap tent filter for smooth upsampling
    // This samples in a 3x3 pattern with bilinear filtering for a 4x4 effective footprint
    let texel_size : vec2<f32> = 1.0 / downsampleSize;
    
    var sum : vec3<f32> = vec3<f32>(0.0);
    
    // Center tap (weight 4)
    sum = sum + textureSample(downsampleBuffer, downsampleSampler, uv).xyz * 4.0;
    
    // Edge taps (weight 2 each)
    sum = sum + textureSample(downsampleBuffer, downsampleSampler, uv + vec2<f32>(-texel_size.x, 0.0)).xyz * 2.0;
    sum = sum + textureSample(downsampleBuffer, downsampleSampler, uv + vec2<f32>( texel_size.x, 0.0)).xyz * 2.0;
    sum = sum + textureSample(downsampleBuffer, downsampleSampler, uv + vec2<f32>(0.0, -texel_size.y)).xyz * 2.0;
    sum = sum + textureSample(downsampleBuffer, downsampleSampler, uv + vec2<f32>(0.0,  texel_size.y)).xyz * 2.0;
    
    // Corner taps (weight 1 each)
    sum = sum + textureSample(downsampleBuffer, downsampleSampler, uv + vec2<f32>(-texel_size.x, -texel_size.y)).xyz;
    sum = sum + textureSample(downsampleBuffer, downsampleSampler, uv + vec2<f32>( texel_size.x, -texel_size.y)).xyz;
    sum = sum + textureSample(downsampleBuffer, downsampleSampler, uv + vec2<f32>(-texel_size.x,  texel_size.y)).xyz;
    sum = sum + textureSample(downsampleBuffer, downsampleSampler, uv + vec2<f32>( texel_size.x,  texel_size.y)).xyz;
    
    // Normalize (4 + 2*4 + 1*4 = 16)
    let bloom_sample : vec3<f32> = sum / 16.0;
    
    // Add brightness boost
    let boosted : vec3<f32> = clamp_vec01(bloom_sample + vec3<f32>(BRIGHTNESS_ADJUST));
    
    // Blend with original using additive-style blend
    let source_clamped : vec3<f32> = clamp_vec01(source_sample.xyz);
    let mixed : vec3<f32> = clamp_vec01((source_clamped + boosted) * 0.5);
    let final_rgb : vec3<f32> = clamp_vec01(source_clamped * (1.0 - alpha) + mixed * alpha);

    return vec4<f32>(final_rgb, source_sample.w);
}
