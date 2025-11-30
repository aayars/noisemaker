// WGSL version – WebGPU
@group(0) @binding(0) var<uniform> scale: f32;
@group(0) @binding(1) var<uniform> seed: f32;
@group(0) @binding(2) var<uniform> octaves: i32;
@group(0) @binding(3) var<uniform> ridged: i32;
@group(0) @binding(4) var<uniform> volumeSize: i32;

// Volume dimensions - stored as 2D atlas
// Atlas layout: volumeSize x (volumeSize * volumeSize)

// Improved hash using multiple rounds of mixing
fn hash3(p: vec3<f32>) -> f32 {
    let ps = p + seed * 0.1;
    var q = vec3<u32>(vec3<i32>(ps * 1000.0) + 65536);
    q = q * 1664525u + 1013904223u;
    q.x = q.x + q.y * q.z;
    q.y = q.y + q.z * q.x;
    q.z = q.z + q.x * q.y;
    q = q ^ (q >> vec3<u32>(16u));
    q.x = q.x + q.y * q.z;
    q.y = q.y + q.z * q.x;
    q.z = q.z + q.x * q.y;
    return f32(q.x ^ q.y ^ q.z) / 4294967295.0;
}

// Gradient from hash - returns normalized 3D vector
fn grad3(p: vec3<f32>) -> vec3<f32> {
    let h1 = hash3(p);
    let h2 = hash3(p + 127.1);
    let h3 = hash3(p + 269.5);
    let g = vec3<f32>(
        h1 * 2.0 - 1.0,
        h2 * 2.0 - 1.0,
        h3 * 2.0 - 1.0
    );
    return normalize(g);
}

// Quintic interpolation for smooth transitions
fn quintic(t: f32) -> f32 {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// 3D gradient noise - Perlin-style with quintic interpolation
fn noise3D(p: vec3<f32>) -> f32 {
    let i = floor(p);
    let f = fract(p);
    
    let u = vec3<f32>(quintic(f.x), quintic(f.y), quintic(f.z));
    
    let n000 = dot(grad3(i + vec3<f32>(0.0, 0.0, 0.0)), f - vec3<f32>(0.0, 0.0, 0.0));
    let n100 = dot(grad3(i + vec3<f32>(1.0, 0.0, 0.0)), f - vec3<f32>(1.0, 0.0, 0.0));
    let n010 = dot(grad3(i + vec3<f32>(0.0, 1.0, 0.0)), f - vec3<f32>(0.0, 1.0, 0.0));
    let n110 = dot(grad3(i + vec3<f32>(1.0, 1.0, 0.0)), f - vec3<f32>(1.0, 1.0, 0.0));
    let n001 = dot(grad3(i + vec3<f32>(0.0, 0.0, 1.0)), f - vec3<f32>(0.0, 0.0, 1.0));
    let n101 = dot(grad3(i + vec3<f32>(1.0, 0.0, 1.0)), f - vec3<f32>(1.0, 0.0, 1.0));
    let n011 = dot(grad3(i + vec3<f32>(0.0, 1.0, 1.0)), f - vec3<f32>(0.0, 1.0, 1.0));
    let n111 = dot(grad3(i + vec3<f32>(1.0, 1.0, 1.0)), f - vec3<f32>(1.0, 1.0, 1.0));
    
    let nx00 = mix(n000, n100, u.x);
    let nx10 = mix(n010, n110, u.x);
    let nx01 = mix(n001, n101, u.x);
    let nx11 = mix(n011, n111, u.x);
    
    let nxy0 = mix(nx00, nx10, u.y);
    let nxy1 = mix(nx01, nx11, u.y);
    
    return mix(nxy0, nxy1, u.z);
}

// FBM using 3D noise
fn fbm3D(p: vec3<f32>, ridgedMode: i32) -> f32 {
    let MAX_OCT: i32 = 8;
    var amplitude: f32 = 0.5;
    var frequency: f32 = 1.0;
    var sum: f32 = 0.0;
    var maxVal: f32 = 0.0;
    var oct = octaves;
    if (oct < 1) { oct = 1; }
    
    for (var i: i32 = 0; i < MAX_OCT; i = i + 1) {
        if (i >= oct) { break; }
        let pos = p * frequency;
        var n = noise3D(pos);
        n = clamp(n * 1.5, -1.0, 1.0);
        if (ridgedMode == 1) {
            n = 1.0 - abs(n);
        } else {
            n = (n + 1.0) * 0.5;
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
    // Use uniform for volume size
    let volSize = volumeSize;
    let volSizeF = f32(volSize);
    
    // Atlas is volSize x (volSize * volSize)
    // Pixel (x, y) maps to 3D coordinate (x, y % volSize, y / volSize)
    
    let pixelCoord = vec2<i32>(position.xy);
    
    let x = pixelCoord.x;
    let y = pixelCoord.y % volSize;
    let z = pixelCoord.y / volSize;
    
    // Bounds check
    if (x >= volSize || y >= volSize || z >= volSize) {
        return vec4<f32>(0.0);
    }
    
    // Convert to normalized 3D coordinates in [-1, 1] world space (bounding box)
    let p = vec3<f32>(f32(x), f32(y), f32(z)) / (volSizeF - 1.0) * 2.0 - 1.0;
    
    // Scale for noise density
    let scaledP = p * scale;
    
    // Compute FBM noise at this point
    let noiseVal = fbm3D(scaledP, ridged);
    
    // For RGB color mode, compute 3 different noise channels
    let r = noiseVal;
    let g = fbm3D(scaledP + vec3<f32>(100.0, 0.0, 0.0), ridged);
    let b = fbm3D(scaledP + vec3<f32>(0.0, 100.0, 0.0), ridged);
    
    return vec4<f32>(r, g, b, 1.0);
}