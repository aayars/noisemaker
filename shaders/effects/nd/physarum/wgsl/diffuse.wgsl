/*
 * Physarum diffuse shader (WGSL port).
 * Blurs and decays the trail texture.
 */

@group(0) @binding(0) var samp: sampler;
@group(0) @binding(1) var sourceTex: texture_2d<f32>;
@group(0) @binding(2) var<uniform> u: Uniforms;

struct Uniforms {
    time: f32,
    deltaTime: f32,
    frame: i32,
    _pad0: f32,
    resolution: vec2f,
    aspect: f32,
    decay: f32,
    diffusion: f32,
    intensity: f32,
}

@fragment
fn main(@builtin(position) fragCoord: vec4f) -> @location(0) vec4f {
    let texel = 1.0 / u.resolution;
    let uv = fragCoord.xy * texel;

    var sum = 0.0;
    for (var x = -1; x <= 1; x++) {
        for (var y = -1; y <= 1; y++) {
            let offset = vec2f(f32(x), f32(y)) * texel;
            sum += textureSample(sourceTex, samp, uv + offset).r;
        }
    }

    let current = textureSample(sourceTex, samp, uv).r;
    let blurred = mix(current, sum / 9.0, clamp(u.diffusion, 0.0, 1.0));
    let value = max(blurred - max(u.decay, 0.0), 0.0);
    
    return vec4f(value, 0.0, 0.0, 1.0);
}
