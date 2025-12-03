// Adjusts image brightness by adding a uniform delta and clamping to [-1, 1],
// mirroring tf.image.adjust_brightness from the Python reference.

@group(0) @binding(0) var u_sampler: sampler;
@group(0) @binding(1) var inputTex: texture_2d<f32>;
@group(0) @binding(2) var<uniform> amount: f32;

fn clamp_symmetric_vec3(value: vec3<f32>) -> vec3<f32> {
    return clamp(value, vec3<f32>(-1.0), vec3<f32>(1.0));
}

@fragment
fn main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {
    let dims = textureDimensions(inputTex, 0);
    let uv = fragCoord.xy / vec2<f32>(dims);
    let texel = textureSample(inputTex, u_sampler, uv);
    
    let adjusted_rgb = clamp_symmetric_vec3(texel.xyz + vec3<f32>(amount));
    
    return vec4<f32>(adjusted_rgb, texel.w);
}
