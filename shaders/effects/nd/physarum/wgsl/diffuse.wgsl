/*
 * Physarum diffuse shader (WGSL port).
 * Blurs and decays the trail texture.
 * Uses textureLoad for exact texel sampling (no interpolation).
 */

@group(0) @binding(0) var sourceTex: texture_2d<f32>;
@group(0) @binding(1) var<uniform> u: Uniforms;

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

fn wrap_int(value: i32, size: i32) -> i32 {
    if (size <= 0) { return 0; }
    var result = value % size;
    if (result < 0) { result = result + size; }
    return result;
}

fn sampleAt(x: i32, y: i32, width: i32, height: i32) -> f32 {
    let wx = wrap_int(x, width);
    let wy = wrap_int(y, height);
    return textureLoad(sourceTex, vec2<i32>(wx, wy), 0).r;
}

@fragment
fn main(@builtin(position) fragCoord: vec4f) -> @location(0) vec4f {
    let width = i32(u.resolution.x);
    let height = i32(u.resolution.y);
    let x = i32(fragCoord.x);
    let y = i32(fragCoord.y);

    var sum = 0.0;
    for (var ox = -1; ox <= 1; ox++) {
        for (var oy = -1; oy <= 1; oy++) {
            sum += sampleAt(x + ox, y + oy, width, height);
        }
    }

    let current = sampleAt(x, y, width, height);
    let blurred = mix(current, sum / 9.0, clamp(u.diffusion, 0.0, 1.0));
    let value = max(blurred - max(u.decay, 0.0), 0.0);
    
    return vec4f(value, 0.0, 0.0, 1.0);
}
