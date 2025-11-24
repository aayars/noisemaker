struct WormsUniforms {
    resolution : vec2<f32>,
    channelCount : f32,
    padding0 : f32,
    behavior_density_stride_padding : vec4<f32>,
    strideDeviation_alpha_kink : vec3<f32>,
    quantize_time_padding_intensity : vec4<f32>,
    inputIntensity_padding : vec4<f32>,
};

@group(0) @binding(0) var sampler : sampler;
@group(0) @binding(1) var inputTex : texture_2d<f32>;
@group(0) @binding(2) var wormsTex : texture_2d<f32>;
@group(0) @binding(3) var<uniform> uniforms : WormsUniforms;

fn sampleTextureOrFallback(tex : texture_2d<f32>, uv : vec2<f32>) -> vec4<f32> {
    let dims = textureDimensions(tex, 0);
    if (dims.x == 0u || dims.y == 0u) {
        return vec4<f32>(-1.0, -1.0, -1.0, -1.0);
    }
    return textureSample(tex, sampler, uv);
}

@fragment
fn main(@builtin(position) position : vec4<f32>) -> @location(0) vec4<f32> {
    let size = vec2<f32>(max(uniforms.resolution.x, 1.0), max(uniforms.resolution.y, 1.0));
    var uv = position.xy / size;
    uv.y = 1.0 - uv.y;
    let intensity = clamp(uniforms.inputIntensity_padding.x / 100.0, 0.0, 1.0);
    let baseSample = textureSample(inputTex, sampler, uv);
    let baseColor = vec4<f32>(baseSample.xyz * intensity, baseSample.w);
    let wormsColor = sampleTextureOrFallback(wormsTex, uv);
    if (wormsColor.w < 0.0) {
        return baseColor;
    }
    // Don't scale by alpha here - that would affect feedback
    let combinedRgb = clamp(baseColor.xyz + wormsColor.xyz, vec3<f32>(0.0), vec3<f32>(1.0));
    let finalAlpha = clamp(max(baseColor.w, wormsColor.w), 0.0, 1.0);
    return vec4<f32>(combinedRgb, finalAlpha);
}
