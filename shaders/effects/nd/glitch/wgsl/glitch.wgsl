// Glitch - PCG PRNG based glitch/noise effects
// Ported from GLSL to WGSL

@group(0) @binding(0) var samp : sampler;
@group(0) @binding(1) var inputTex : texture_2d<f32>;

struct Uniforms {
    time: f32,
    seed: i32,
    aspectLens: i32,
    xChonk: i32,
    yChonk: i32,
    glitchiness: f32,
    scanlinesAmt: i32,
    snowAmt: f32,
    vignetteAmt: f32,
    aberrationAmt: f32,
    distortion: f32,
    kernel: i32,
    levels: f32,
}

@group(0) @binding(2) var<uniform> u : Uniforms;

const PI: f32 = 3.14159265359;

// PCG PRNG - Permuted Congruential Generator
fn pcg(n: u32) -> u32 {
    var h = n * 747796405u + 2891336453u;
    h = ((h >> ((h >> 28u) + 4u)) ^ h) * 277803737u;
    return (h >> 22u) ^ h;
}

fn pcg2d(p: vec2<u32>) -> vec2<u32> {
    var v = p * 1664525u + 1013904223u;
    v.x += v.y * 1664525u;
    v.y += v.x * 1664525u;
    v = v ^ (v >> vec2<u32>(16u));
    v.x += v.y * 1664525u;
    v.y += v.x * 1664525u;
    v = v ^ (v >> vec2<u32>(16u));
    return v;
}

fn pcg2df(p: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(pcg2d(vec2<u32>(bitcast<u32>(p.x), bitcast<u32>(p.y)))) / f32(0xffffffffu);
}

fn pcg3d(p: vec3<u32>) -> vec3<u32> {
    var v = p * 1664525u + 1013904223u;
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    v = v ^ (v >> vec3<u32>(16u));
    v.x += v.y * v.z;
    v.y += v.z * v.x;
    v.z += v.x * v.y;
    return v;
}

fn pcg3df(p: vec3<f32>) -> vec3<f32> {
    return vec3<f32>(pcg3d(vec3<u32>(bitcast<u32>(p.x), bitcast<u32>(p.y), bitcast<u32>(p.z)))) / f32(0xffffffffu);
}

// Bicubic noise from PCG
fn bicubic_noise(fragCoord: vec2<f32>, gridSize: vec2<f32>, seed: f32) -> vec2<f32> {
    let dims = vec2<f32>(textureDimensions(inputTex, 0));
    let p = fragCoord / dims * gridSize;
    let i = floor(p);
    let f = p - i;

    let w = f * f * (3.0 - 2.0 * f);

    let n00 = pcg3df(vec3<f32>(i, seed)).xy * 2.0 - 1.0;
    let n10 = pcg3df(vec3<f32>(i + vec2<f32>(1.0, 0.0), seed)).xy * 2.0 - 1.0;
    let n01 = pcg3df(vec3<f32>(i + vec2<f32>(0.0, 1.0), seed)).xy * 2.0 - 1.0;
    let n11 = pcg3df(vec3<f32>(i + vec2<f32>(1.0, 1.0), seed)).xy * 2.0 - 1.0;

    return mix(mix(n00, n10, w.x), mix(n01, n11, w.x), w.y);
}

// Scanlines effect
fn scanlines(color: vec4<f32>, fragCoord: vec2<f32>, amt: i32) -> vec4<f32> {
    if (amt == 0) {
        return color;
    }

    let scanY = i32(fragCoord.y) % (amt * 2);
    if (scanY < amt) {
        return color * 0.7;
    }
    return color;
}

// Snow/noise effect
fn snow(color: vec4<f32>, fragCoord: vec2<f32>, time: f32, amt: f32) -> vec4<f32> {
    if (amt <= 0.0) {
        return color;
    }

    let noise = pcg3df(vec3<f32>(fragCoord, time)).x;
    let snowColor = vec4<f32>(vec3<f32>(noise), 1.0);
    return mix(color, snowColor, amt * 0.01);
}

// Vignette effect
fn vignette(color: vec4<f32>, uv: vec2<f32>, amt: f32) -> vec4<f32> {
    if (amt == 0.0) {
        return color;
    }

    let center = uv - 0.5;
    let dist = length(center);
    let vig = 1.0 - smoothstep(0.3, 0.7, dist * abs(amt) * 0.02);

    if (amt > 0.0) {
        return color * vig;
    } else {
        return color * (1.0 - vig) + vec4<f32>(vec3<f32>(1.0 - vig), 0.0);
    }
}

// Chromatic aberration
fn aberration(uv: vec2<f32>, amt: f32) -> vec4<f32> {
    if (amt <= 0.0) {
        return textureSample(inputTex, samp, uv);
    }

    let dims = vec2<f32>(textureDimensions(inputTex, 0));
    let offset = amt * 0.001;

    let r = textureSample(inputTex, samp, uv + vec2<f32>(offset, 0.0)).r;
    let g = textureSample(inputTex, samp, uv).g;
    let b = textureSample(inputTex, samp, uv - vec2<f32>(offset, 0.0)).b;
    let a = textureSample(inputTex, samp, uv).a;

    return vec4<f32>(r, g, b, a);
}

// Barrel/pincushion distortion
fn barrel_distort(uv: vec2<f32>, amt: f32, aspectLens: bool) -> vec2<f32> {
    if (amt == 0.0) {
        return uv;
    }

    var centered = uv - 0.5;
    let dims = vec2<f32>(textureDimensions(inputTex, 0));
    let aspect = dims.x / dims.y;

    if (!aspectLens) {
        centered.x *= aspect;
    }

    let r2 = dot(centered, centered);
    let distortFactor = 1.0 + amt * 0.01 * r2;

    var result = centered * distortFactor;

    if (!aspectLens) {
        result.x /= aspect;
    }

    return result + 0.5;
}

// Glitch displacement
fn glitch_displace(uv: vec2<f32>, fragCoord: vec2<f32>, time: f32, seed: i32, gridSize: vec2<f32>, amt: f32) -> vec2<f32> {
    if (amt <= 0.0) {
        return uv;
    }

    let seedF = f32(seed) + floor(time * 10.0);
    let noise = bicubic_noise(fragCoord, gridSize, seedF);

    return uv + noise * amt * 0.001;
}

// Sharpen kernel
fn sharpen(uv: vec2<f32>, strength: f32) -> vec4<f32> {
    let dims = vec2<f32>(textureDimensions(inputTex, 0));
    let texel = 1.0 / dims;

    let center = textureSample(inputTex, samp, uv);
    let top = textureSample(inputTex, samp, uv + vec2<f32>(0.0, -texel.y));
    let bottom = textureSample(inputTex, samp, uv + vec2<f32>(0.0, texel.y));
    let left = textureSample(inputTex, samp, uv + vec2<f32>(-texel.x, 0.0));
    let right = textureSample(inputTex, samp, uv + vec2<f32>(texel.x, 0.0));

    let sharpened = center * (1.0 + 4.0 * strength) - (top + bottom + left + right) * strength;
    return clamp(sharpened, vec4<f32>(0.0), vec4<f32>(1.0));
}

// Blur kernel
fn blur(uv: vec2<f32>, strength: f32) -> vec4<f32> {
    let dims = vec2<f32>(textureDimensions(inputTex, 0));
    let texel = 1.0 / dims * strength;

    var color = vec4<f32>(0.0);
    color += textureSample(inputTex, samp, uv + vec2<f32>(-texel.x, -texel.y));
    color += textureSample(inputTex, samp, uv + vec2<f32>(0.0, -texel.y));
    color += textureSample(inputTex, samp, uv + vec2<f32>(texel.x, -texel.y));
    color += textureSample(inputTex, samp, uv + vec2<f32>(-texel.x, 0.0));
    color += textureSample(inputTex, samp, uv);
    color += textureSample(inputTex, samp, uv + vec2<f32>(texel.x, 0.0));
    color += textureSample(inputTex, samp, uv + vec2<f32>(-texel.x, texel.y));
    color += textureSample(inputTex, samp, uv + vec2<f32>(0.0, texel.y));
    color += textureSample(inputTex, samp, uv + vec2<f32>(texel.x, texel.y));

    return color / 9.0;
}

// Edge detection kernel
fn edge_detect(uv: vec2<f32>) -> vec4<f32> {
    let dims = vec2<f32>(textureDimensions(inputTex, 0));
    let texel = 1.0 / dims;

    let tl = textureSample(inputTex, samp, uv + vec2<f32>(-texel.x, -texel.y));
    let t = textureSample(inputTex, samp, uv + vec2<f32>(0.0, -texel.y));
    let tr = textureSample(inputTex, samp, uv + vec2<f32>(texel.x, -texel.y));
    let l = textureSample(inputTex, samp, uv + vec2<f32>(-texel.x, 0.0));
    let c = textureSample(inputTex, samp, uv);
    let r = textureSample(inputTex, samp, uv + vec2<f32>(texel.x, 0.0));
    let bl = textureSample(inputTex, samp, uv + vec2<f32>(-texel.x, texel.y));
    let b = textureSample(inputTex, samp, uv + vec2<f32>(0.0, texel.y));
    let br = textureSample(inputTex, samp, uv + vec2<f32>(texel.x, texel.y));

    let gx = -tl - 2.0 * l - bl + tr + 2.0 * r + br;
    let gy = -tl - 2.0 * t - tr + bl + 2.0 * b + br;

    return sqrt(gx * gx + gy * gy);
}

// Posterize/levels
fn posterize(color: vec4<f32>, levels: f32) -> vec4<f32> {
    if (levels <= 0.0) {
        return color;
    }

    let numLevels = max(2.0, levels);
    return floor(color * numLevels) / (numLevels - 1.0);
}

@fragment
fn main(@builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4<f32> {
    let dims = vec2<f32>(textureDimensions(inputTex, 0));
    var uv = fragCoord.xy / dims;

    // Apply barrel distortion
    uv = barrel_distort(uv, u.distortion, u.aspectLens != 0);

    // Apply glitch displacement
    let gridSize = vec2<f32>(f32(u.xChonk), f32(u.yChonk));
    uv = glitch_displace(uv, fragCoord.xy, u.time, u.seed, gridSize, u.glitchiness);

    // Sample with aberration
    var color = aberration(uv, u.aberrationAmt);

    // Apply kernel effects
    if (u.kernel > 0) {
        color = sharpen(uv, f32(u.kernel) * 0.1);
    } else if (u.kernel < 0) {
        color = blur(uv, f32(-u.kernel) * 0.5);
    }

    // Apply scanlines
    color = scanlines(color, fragCoord.xy, u.scanlinesAmt);

    // Apply snow
    color = snow(color, fragCoord.xy, u.time, u.snowAmt);

    // Apply vignette
    color = vignette(color, uv, u.vignetteAmt);

    // Apply posterize/levels
    color = posterize(color, u.levels);

    return color;
}
