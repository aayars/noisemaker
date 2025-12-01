/*
 * 3D Reaction-Diffusion initialization shader (WGSL)
 * Initializes the 3D volume with A=1 everywhere, B=1 at sparse random locations
 */

@group(0) @binding(0) var<uniform> seed: f32;
@group(0) @binding(1) var<uniform> volumeSize: i32;

// PCG-based 3D hash for reproducible randomness
fn pcg3d(v_in: vec3<u32>) -> vec3<u32> {
    var v = v_in * 1664525u + 1013904223u;
    v.x = v.x + v.y * v.z;
    v.y = v.y + v.z * v.x;
    v.z = v.z + v.x * v.y;
    v = v ^ (v >> vec3<u32>(16u));
    v.x = v.x + v.y * v.z;
    v.y = v.y + v.z * v.x;
    v.z = v.z + v.x * v.y;
    return v;
}

fn hash3(p: vec3<f32>) -> f32 {
    let ps = p + seed * 0.1;
    var q = vec3<u32>(vec3<i32>(ps * 1000.0) + 65536);
    q = pcg3d(q);
    return f32(q.x) / 4294967295.0;
}

@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
    let volSize = volumeSize;
    let volSizeF = f32(volSize);
    
    // Atlas is volSize x (volSize * volSize)
    let pixelCoord = vec2<i32>(position.xy);
    
    let x = pixelCoord.x;
    let y = pixelCoord.y % volSize;
    let z = pixelCoord.y / volSize;
    
    // Bounds check
    if (x >= volSize || y >= volSize || z >= volSize) {
        return vec4<f32>(0.0);
    }
    
    // Convert to normalized 3D coordinates
    let p = vec3<f32>(f32(x), f32(y), f32(z));
    
    // Initialize: A=1 everywhere, B=1 at sparse random seed points
    var a: f32 = 1.0;
    var b: f32 = 0.0;
    
    // Create seed points - more sparse in 3D
    let h = hash3(p);
    if (h > 0.97) {
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
    
    return vec4<f32>(a, b, 0.0, 1.0);
}
