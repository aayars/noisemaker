/*
 * Chromatic aberration effect
 * Offsets RGB channels horizontally with radial falloff
 */

struct Uniforms {
    time: f32,
    aberrationDisplacement: f32,
    aberrationSpeed: f32,
    _pad: f32,
}

@group(0) @binding(0) var inputSampler: sampler;
@group(0) @binding(1) var inputTex: texture_2d<f32>;
@group(0) @binding(2) var<uniform> uniforms: Uniforms;

const PI: f32 = 3.14159265359;

fn mod289v3(x: vec3<f32>) -> vec3<f32> { return x - floor(x / 289.0) * 289.0; }
fn mod289v4(x: vec4<f32>) -> vec4<f32> { return x - floor(x / 289.0) * 289.0; }
fn permute(x: vec4<f32>) -> vec4<f32> { return mod289v4(((x * 34.0) + 1.0) * x); }
fn taylorInvSqrt(r: vec4<f32>) -> vec4<f32> { return 1.79284291400159 - 0.85373472095314 * r; }

fn simplex(v: vec3<f32>) -> f32 {
    let C = vec2<f32>(1.0/6.0, 1.0/3.0);
    let D = vec4<f32>(0.0, 0.5, 1.0, 2.0);
    
    let i = floor(v + dot(v, vec3<f32>(C.y)));
    let x0 = v - i + dot(i, vec3<f32>(C.x));
    
    let g = step(x0.yzx, x0.xyz);
    let l = 1.0 - g;
    let i1 = min(g.xyz, l.zxy);
    let i2 = max(g.xyz, l.zxy);
    
    let x1 = x0 - i1 + C.xxx;
    let x2 = x0 - i2 + C.yyy;
    let x3 = x0 - D.yyy;
    
    let im = mod289v3(i);
    let p = permute(permute(permute(
        im.z + vec4<f32>(0.0, i1.z, i2.z, 1.0))
        + im.y + vec4<f32>(0.0, i1.y, i2.y, 1.0))
        + im.x + vec4<f32>(0.0, i1.x, i2.x, 1.0));
    
    let n_: f32 = 0.142857142857;
    let ns = n_ * D.wyz - D.xzx;
    
    let j = p - 49.0 * floor(p * ns.z * ns.z);
    let x_ = floor(j * ns.z);
    let y_ = floor(j - 7.0 * x_);
    
    let x = x_ * ns.x + ns.yyyy;
    let y = y_ * ns.x + ns.yyyy;
    let h = 1.0 - abs(x) - abs(y);
    
    let b0 = vec4<f32>(x.xy, y.xy);
    let b1 = vec4<f32>(x.zw, y.zw);
    
    let s0 = floor(b0) * 2.0 + 1.0;
    let s1 = floor(b1) * 2.0 + 1.0;
    let sh = -step(h, vec4<f32>(0.0));
    
    let a0 = b0.xzyw + s0.xzyw * sh.xxyy;
    let a1 = b1.xzyw + s1.xzyw * sh.zzww;
    
    let p0 = vec3<f32>(a0.xy, h.x);
    let p1 = vec3<f32>(a0.zw, h.y);
    let p2 = vec3<f32>(a1.xy, h.z);
    let p3 = vec3<f32>(a1.zw, h.w);
    
    let norm = taylorInvSqrt(vec4<f32>(dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
    let p0n = p0 * norm.x;
    let p1n = p1 * norm.y;
    let p2n = p2 * norm.z;
    let p3n = p3 * norm.w;
    
    var m = max(0.6 - vec4<f32>(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), vec4<f32>(0.0));
    m = m * m;
    return 42.0 * dot(m * m, vec4<f32>(dot(p0n,x0), dot(p1n,x1), dot(p2n,x2), dot(p3n,x3)));
}

fn aberrationMask(uv: vec2<f32>) -> f32 {
    let delta = uv - 0.5;
    let dist = length(delta) * 2.0;
    return pow(clamp(dist, 0.0, 1.0), 3.0);
}

@fragment
fn main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let texSize = vec2<f32>(textureDimensions(inputTex));
    let uv = pos.xy / texSize;
    
    // Animated displacement
    let noise = simplex(vec3<f32>(17.0, 29.0, uniforms.time * uniforms.aberrationSpeed * 0.2)) * 0.5 + 0.5;
    let offset = uniforms.aberrationDisplacement * noise;
    
    // Radial mask - stronger at edges
    let mask = aberrationMask(uv);
    let displacement = offset * mask;
    
    // Horizontal displacement direction based on position
    let direction = sign(uv.x - 0.5);
    
    // Sample RGB channels with offset
    let r = textureSample(inputTex, inputSampler, uv + vec2<f32>(displacement * direction, 0.0)).r;
    let g = textureSample(inputTex, inputSampler, uv).g;
    let b = textureSample(inputTex, inputSampler, uv - vec2<f32>(displacement * direction, 0.0)).b;
    let a = textureSample(inputTex, inputSampler, uv).a;

    return vec4<f32>(r, g, b, a);
}
