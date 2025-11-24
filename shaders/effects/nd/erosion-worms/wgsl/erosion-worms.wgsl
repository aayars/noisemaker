struct ErosionWormsUniforms {
    resolution : vec2<f32>,
    channelCount : f32,
    padding0 : f32,
    controls0 : vec4<f32>,
    controls1 : vec4<f32>,
    controls2 : vec4<f32>,
};

@group(0) @binding(0) var sampler : sampler;
@group(0) @binding(1) var inputTex : texture_2d<f32>;
@group(0) @binding(2) var erosionTex : texture_2d<f32>;
@group(0) @binding(3) var<uniform> uniforms : ErosionWormsUniforms;

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
    let inputIntensity = clamp(uniforms.controls2.y / 100.0, 0.0, 1.0);
    let baseSample = textureSample(inputTex, sampler, uv);
    let baseColor = vec4<f32>(baseSample.xyz * inputIntensity, baseSample.w);
    let erosionColor = sampleTextureOrFallback(erosionTex, uv);
    if (erosionColor.w < 0.0) {
        return baseColor;
    }
    let combinedRgb = clamp(baseColor.xyz + erosionColor.xyz, vec3<f32>(0.0), vec3<f32>(1.0));
    let finalAlpha = clamp(max(baseColor.w, erosionColor.w), 0.0, 1.0);
    return vec4<f32>(combinedRgb, finalAlpha);
}
