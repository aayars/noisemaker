// WGSL version – WebGPU
@group(0) @binding(0) var<uniform> resolution: vec2<f32>;
@group(0) @binding(1) var<uniform> aspect: f32;
@group(0) @binding(2) var<uniform> time: f32;
@group(0) @binding(3) var<uniform> scale: f32;
// binding 4 (offset) intentionally omitted - unused uniforms cause WebGPU bind group mismatch
@group(0) @binding(5) var<uniform> seed: f32;
@group(0) @binding(6) var<uniform> octaves: i32;
@group(0) @binding(7) var<uniform> colorMode: i32;
@group(0) @binding(8) var<uniform> hueRotation: f32;
@group(0) @binding(9) var<uniform> hueRange: f32;
@group(0) @binding(10) var<uniform> ridged: i32;

/* 4D gradient noise with quintic interpolation
   Animated using circular time coordinates for seamless looping */

const TAU: f32 = 6.283185307179586;

// Improved 4D hash using multiple rounds of mixing
// Based on techniques from "Hash Functions for GPU Rendering" (Jarzynski & Olano, 2020)
fn hash4(p: vec4<f32>) -> f32 {
    // Add seed to input to vary the noise pattern
    let ps = p + seed * 0.1;
    
    // Convert to unsigned integer values via large multipliers
    var q = vec4<u32>(vec4<i32>(ps * 1000.0) + 65536);
    
    // Multiple rounds of mixing for thorough decorrelation
    q = q * 1664525u + 1013904223u;  // LCG constants
    q.x = q.x + q.y * q.w;
    q.y = q.y + q.z * q.x;
    q.z = q.z + q.x * q.y;
    q.w = q.w + q.y * q.z;
    
    q = q ^ (q >> vec4<u32>(16u));
    
    q.x = q.x + q.y * q.w;
    q.y = q.y + q.z * q.x;
    q.z = q.z + q.x * q.y;
    q.w = q.w + q.y * q.z;
    
    return f32(q.x ^ q.y ^ q.z ^ q.w) / 4294967295.0;
}

// Gradient from hash - returns normalized 4D vector
fn grad4(p: vec4<f32>) -> vec4<f32> {
    let h1 = hash4(p);
    let h2 = hash4(p + 127.1);
    let h3 = hash4(p + 269.5);
    let h4 = hash4(p + 419.2);
    
    // Generate independent gradient components - each component is [-1, 1]
    // This avoids the spherical coordinate approach which creates correlations
    let g = vec4<f32>(
        h1 * 2.0 - 1.0,
        h2 * 2.0 - 1.0,
        h3 * 2.0 - 1.0,
        h4 * 2.0 - 1.0
    );
    
    return normalize(g);
}

// Quintic interpolation for smooth transitions
fn quintic(t: f32) -> f32 {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// 4D gradient noise - Perlin-style with quintic interpolation
fn noise4D(p: vec4<f32>) -> f32 {
    let i = floor(p);
    let f = fract(p);
    
    let u = vec4<f32>(quintic(f.x), quintic(f.y), quintic(f.z), quintic(f.w));
    
    let n0000 = dot(grad4(i + vec4<f32>(0.0, 0.0, 0.0, 0.0)), f - vec4<f32>(0.0, 0.0, 0.0, 0.0));
    let n1000 = dot(grad4(i + vec4<f32>(1.0, 0.0, 0.0, 0.0)), f - vec4<f32>(1.0, 0.0, 0.0, 0.0));
    let n0100 = dot(grad4(i + vec4<f32>(0.0, 1.0, 0.0, 0.0)), f - vec4<f32>(0.0, 1.0, 0.0, 0.0));
    let n1100 = dot(grad4(i + vec4<f32>(1.0, 1.0, 0.0, 0.0)), f - vec4<f32>(1.0, 1.0, 0.0, 0.0));
    let n0010 = dot(grad4(i + vec4<f32>(0.0, 0.0, 1.0, 0.0)), f - vec4<f32>(0.0, 0.0, 1.0, 0.0));
    let n1010 = dot(grad4(i + vec4<f32>(1.0, 0.0, 1.0, 0.0)), f - vec4<f32>(1.0, 0.0, 1.0, 0.0));
    let n0110 = dot(grad4(i + vec4<f32>(0.0, 1.0, 1.0, 0.0)), f - vec4<f32>(0.0, 1.0, 1.0, 0.0));
    let n1110 = dot(grad4(i + vec4<f32>(1.0, 1.0, 1.0, 0.0)), f - vec4<f32>(1.0, 1.0, 1.0, 0.0));
    let n0001 = dot(grad4(i + vec4<f32>(0.0, 0.0, 0.0, 1.0)), f - vec4<f32>(0.0, 0.0, 0.0, 1.0));
    let n1001 = dot(grad4(i + vec4<f32>(1.0, 0.0, 0.0, 1.0)), f - vec4<f32>(1.0, 0.0, 0.0, 1.0));
    let n0101 = dot(grad4(i + vec4<f32>(0.0, 1.0, 0.0, 1.0)), f - vec4<f32>(0.0, 1.0, 0.0, 1.0));
    let n1101 = dot(grad4(i + vec4<f32>(1.0, 1.0, 0.0, 1.0)), f - vec4<f32>(1.0, 1.0, 0.0, 1.0));
    let n0011 = dot(grad4(i + vec4<f32>(0.0, 0.0, 1.0, 1.0)), f - vec4<f32>(0.0, 0.0, 1.0, 1.0));
    let n1011 = dot(grad4(i + vec4<f32>(1.0, 0.0, 1.0, 1.0)), f - vec4<f32>(1.0, 0.0, 1.0, 1.0));
    let n0111 = dot(grad4(i + vec4<f32>(0.0, 1.0, 1.0, 1.0)), f - vec4<f32>(0.0, 1.0, 1.0, 1.0));
    let n1111 = dot(grad4(i + vec4<f32>(1.0, 1.0, 1.0, 1.0)), f - vec4<f32>(1.0, 1.0, 1.0, 1.0));
    
    let nx000 = mix(n0000, n1000, u.x);
    let nx100 = mix(n0100, n1100, u.x);
    let nx010 = mix(n0010, n1010, u.x);
    let nx110 = mix(n0110, n1110, u.x);
    let nx001 = mix(n0001, n1001, u.x);
    let nx101 = mix(n0101, n1101, u.x);
    let nx011 = mix(n0011, n1011, u.x);
    let nx111 = mix(n0111, n1111, u.x);
    
    let nxy00 = mix(nx000, nx100, u.y);
    let nxy10 = mix(nx010, nx110, u.y);
    let nxy01 = mix(nx001, nx101, u.y);
    let nxy11 = mix(nx011, nx111, u.y);
    
    let nxyz0 = mix(nxy00, nxy10, u.z);
    let nxyz1 = mix(nxy01, nxy11, u.z);
    
    return mix(nxyz0, nxyz1, u.w);
}

fn hsv2rgb(hsv: vec3<f32>) -> vec3<f32> {
    let c = vec3<f32>(hsv.x, hsv.y, hsv.z);
    let K = vec4<f32>(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    let p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, vec3<f32>(0.0), vec3<f32>(1.0)), c.y);
}

// FBM using 4D noise with circular time for seamless looping
fn fbm(st: vec2<f32>, timeAngle: f32, channelOffset: f32, ridgedMode: i32) -> f32 {
    let MAX_OCT: i32 = 8;
    var amplitude: f32 = 0.5;
    var frequency: f32 = 1.0;
    var sum: f32 = 0.0;
    var maxVal: f32 = 0.0;
    var oct = octaves;
    if (oct < 1) { oct = 1; }
    
    // Circular time coordinates for seamless looping
    // Radius 0.4, centered at 0.5 so circle stays within [0.1, 0.9] - no cell crossings
    let timeRadius: f32 = 0.4;
    let tc = cos(timeAngle) * timeRadius + 0.5 + channelOffset;
    let ts = sin(timeAngle) * timeRadius + 0.5;
    
    for (var i: i32 = 0; i < MAX_OCT; i = i + 1) {
        if (i >= oct) { break; }
        let p = vec4<f32>(st * frequency, tc, ts);
        var n = noise4D(p);  // -1..1
        // Scale up by ~1.5 to spread the gaussian-ish distribution
        // Perlin noise rarely hits +-1, so this expands the usable range
        n = clamp(n * 1.5, -1.0, 1.0);
        if (ridgedMode == 1) {
            n = 1.0 - abs(n);  // fold at zero, gives 0..1 with ridges at zero-crossings
        } else {
            n = (n + 1.0) * 0.5;  // normalize to 0..1
        }
        sum = sum + n * amplitude;
        maxVal = maxVal + amplitude;
        frequency = frequency * 2.0;
        amplitude = amplitude * 0.5;
    }
    return sum / maxVal;
}

@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
    var res = resolution;
    if (res.x < 1.0) { res = vec2<f32>(1024.0, 1024.0); }
    var st = position.xy / res;
    st.y = 1.0 - st.y;  // Flip Y to match WebGL coordinate system
    st.x = st.x * aspect;
    st = st * scale;
    
    // time is 0-1 representing position around circle for seamless looping
    let timeAngle = time * TAU;
    
    var r: f32;
    var g: f32;
    var b: f32;
    if (colorMode == 2 && ridged != 0) {
        r = fbm(st, timeAngle, 0.0, 0);
        g = fbm(st, timeAngle, 100.0, 0);
        b = fbm(st, timeAngle, 200.0, ridged);
    } else {
        r = fbm(st, timeAngle, 0.0, ridged);
        g = fbm(st, timeAngle, 100.0, ridged);
        b = fbm(st, timeAngle, 200.0, ridged);
    }
    
    var col: vec3<f32>;
    if (colorMode == 0) {
        col = vec3<f32>(r);
    } else if (colorMode == 1) {
        col = vec3<f32>(r, g, b);
    } else {
        var h = r * (hueRange * 2.0);
        h = h + 1.0 - (hueRotation / 360.0);
        h = fract(h);
        let s = g;
        let v = b;
        col = hsv2rgb(vec3<f32>(h, s, v));
    }
    return vec4<f32>(col, 1.0);
}

