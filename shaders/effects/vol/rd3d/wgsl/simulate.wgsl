/*
 * 3D Reaction-Diffusion simulation shader (WGSL)
 * Implements Gray-Scott model in 3D with 6-neighbor Laplacian
 * Self-initializing: detects empty buffer and seeds on first frame
 */

@group(0) @binding(0) var<uniform> volumeSize: i32;
@group(0) @binding(1) var<uniform> seed: f32;
@group(0) @binding(2) var<uniform> feed: f32;
@group(0) @binding(3) var<uniform> kill: f32;
@group(0) @binding(4) var<uniform> rate1: f32;
@group(0) @binding(5) var<uniform> rate2: f32;
@group(0) @binding(6) var<uniform> speed: f32;
@group(0) @binding(7) var<uniform> weight: f32;
@group(0) @binding(8) var stateTex: texture_2d<f32>;
@group(0) @binding(9) var seedTex: texture_2d<f32>;  // 3D input volume atlas (inputTex3d)

// Hash for initialization
fn hash3(p: vec3<f32>, s: f32) -> f32 {
    var pp = p + s * 0.1;
    pp = fract(pp * vec3<f32>(0.1031, 0.1030, 0.0973));
    pp = pp + dot(pp, pp.yxz + 33.33);
    return fract((pp.x + pp.y) * pp.z);
}

// Helper to convert 3D voxel coords to 2D atlas texel coords with wrapping
fn atlasTexel(p: vec3<i32>, volSize: i32) -> vec2<i32> {
    // Wrap coordinates for periodic boundary
    let wrapped = vec3<i32>(
        (p.x + volSize) % volSize,
        (p.y + volSize) % volSize,
        (p.z + volSize) % volSize
    );
    return vec2<i32>(wrapped.x, wrapped.y + wrapped.z * volSize);
}

// Sample state at voxel coordinate with wrapping
fn sampleState(voxel: vec3<i32>, volSize: i32) -> vec4<f32> {
    return textureLoad(stateTex, atlasTexel(voxel, volSize), 0);
}

// Sample seed texture at voxel coordinate (for inputTex3d seeding)
fn sampleSeed(voxel: vec3<i32>, volSize: i32) -> vec4<f32> {
    return textureLoad(seedTex, atlasTexel(voxel, volSize), 0);
}

// 3D Laplacian using 6-neighbor stencil, normalized
fn laplacian3D(voxel: vec3<i32>, volSize: i32) -> vec2<f32> {
    let center = sampleState(voxel, volSize);
    
    // 6-neighbor stencil (face-adjacent neighbors)
    let xp = sampleState(voxel + vec3<i32>(1, 0, 0), volSize);
    let xn = sampleState(voxel + vec3<i32>(-1, 0, 0), volSize);
    let yp = sampleState(voxel + vec3<i32>(0, 1, 0), volSize);
    let yn = sampleState(voxel + vec3<i32>(0, -1, 0), volSize);
    let zp = sampleState(voxel + vec3<i32>(0, 0, 1), volSize);
    let zn = sampleState(voxel + vec3<i32>(0, 0, -1), volSize);
    
    // Discrete Laplacian for uniform grid, normalized
    let neighborSum = (xp.rg + xn.rg + yp.rg + yn.rg + zp.rg + zn.rg) / 6.0;
    let lap = neighborSum - center.rg;
    
    return lap;
}

@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
    let volSize = volumeSize;
    let volSizeF = f32(volSize);
    
    // Decode voxel position from atlas
    let pixelCoord = vec2<i32>(position.xy);
    let x = pixelCoord.x;
    let y = pixelCoord.y % volSize;
    let z = pixelCoord.y / volSize;
    let voxel = vec3<i32>(x, y, z);
    
    // Bounds check
    if (x >= volSize || y >= volSize || z >= volSize) {
        return vec4<f32>(0.0);
    }
    
    // Current state
    let state = sampleState(voxel, volSize);
    var a = state.r;  // Chemical A concentration
    var b = state.g;  // Chemical B concentration
    
    // Self-initialization: detect empty buffer (first frame)
    let bufferIsEmpty = (state.r == 0.0 && state.g == 0.0 && state.b == 0.0 && state.a == 0.0);
    
    if (bufferIsEmpty) {
        // Check if we have input from seedTex (inputTex3d)
        let seedVal = sampleSeed(voxel, volSize);
        let hasSeedInput = (seedVal.r > 0.0 || seedVal.g > 0.0 || seedVal.b > 0.0);
        
        let p = vec3<f32>(f32(x), f32(y), f32(z));
        
        if (hasSeedInput) {
            // Use seed texture luminance to seed chemical B
            let lum = 0.299 * seedVal.r + 0.587 * seedVal.g + 0.114 * seedVal.b;
            a = 1.0;
            if (lum > 0.5) {
                b = 1.0;
            } else {
                b = 0.0;
            }
        } else {
            // Initialize: A=1 everywhere, B=1 at sparse random locations
            a = 1.0;
            b = 0.0;
            if (hash3(p, seed) > 0.97) {
                b = 1.0;
            }
            // Also seed some spherical regions
            let center1 = vec3<f32>(volSizeF * 0.3, volSizeF * 0.5, volSizeF * 0.5);
            let center2 = vec3<f32>(volSizeF * 0.7, volSizeF * 0.4, volSizeF * 0.6);
            let center3 = vec3<f32>(volSizeF * 0.5, volSizeF * 0.6, volSizeF * 0.3);
            let radius = volSizeF * 0.08;
            if (length(p - center1) < radius ||
                length(p - center2) < radius ||
                length(p - center3) < radius) {
                b = 1.0;
            }
        }
        return vec4<f32>(a, b, 0.0, 1.0);
    }
    
    // Compute Laplacian for diffusion
    let lap = laplacian3D(voxel, volSize);
    
    // Gray-Scott parameters (scaled from UI values - matching 2D rd)
    let f = feed * 0.001;       // Feed rate
    let k = kill * 0.001;       // Kill rate
    let r1 = rate1 * 0.01;      // Diffusion rate A (same scale as 2D)
    let r2 = rate2 * 0.01;      // Diffusion rate B (same scale as 2D)
    let s = speed * 0.01;       // Time step (same scale as 2D)
    
    // Gray-Scott reaction-diffusion equations (matching 2D rd form)
    var newA = clamp(a + (r1 * lap.x - a * b * b + f * (1.0 - a)) * s, 0.0, 1.0);
    var newB = clamp(b + (r2 * lap.y + a * b * b - (k + f) * b) * s, 0.0, 1.0);
    
    // Apply input weight blending from seedTex (inputTex3d)
    if (weight > 0.0) {
        let seedVal = sampleSeed(voxel, volSize);
        let seedLum = 0.299 * seedVal.r + 0.587 * seedVal.g + 0.114 * seedVal.b;
        // Seed influences chemical B (the visible one)
        newB = mix(newB, seedLum, weight * 0.01);
    }
    
    return vec4<f32>(newA, newB, 0.0, 1.0);
}
