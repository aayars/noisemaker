/*
 * Flow3D volumetric rendering shader (WGSL) - renders colored flow trails in 3D
 * Uses ray accumulation (not isosurface) since flow trails are sparse colored data
 */

@group(0) @binding(0) var<uniform> resolution: vec2<f32>;
@group(0) @binding(1) var<uniform> time: f32;
@group(0) @binding(2) var<uniform> threshold: f32;
@group(0) @binding(3) var<uniform> invert: i32;
@group(0) @binding(4) var<uniform> volumeSize: i32;
@group(0) @binding(5) var<uniform> orbitSpeed: i32;
@group(0) @binding(6) var<uniform> bgColor: vec3<f32>;
@group(0) @binding(7) var<uniform> bgAlpha: f32;
@group(0) @binding(8) var volumeCache: texture_2d<f32>;

const TAU: f32 = 6.283185307179586;
const PI: f32 = 3.141592653589793;
const MAX_STEPS: i32 = 128;

// Helper to convert 3D texel coords to 2D atlas texel coords
fn atlasTexel(p: vec3<i32>, volSize: i32) -> vec2<i32> {
    return vec2<i32>(p.x, p.y + p.z * volSize);
}

// Sample the cached 3D volume with trilinear interpolation
// World position p is in [-1, 1]^3 (bounding box coordinates)
fn sampleVolume(worldPos: vec3<f32>) -> vec4<f32> {
    let volSize = volumeSize;
    let volSizeF = f32(volSize);
    
    // Convert world position [-1, 1] to normalized volume coords [0, 1]
    var uvw = worldPos * 0.5 + 0.5;
    uvw = clamp(uvw, vec3<f32>(0.0), vec3<f32>(1.0));
    
    // Convert to texel coordinates
    let texelPos = uvw * (volSizeF - 1.0);
    let texelFloor = floor(texelPos);
    let frac = texelPos - texelFloor;
    
    let i0 = vec3<i32>(texelFloor);
    let i1 = min(i0 + 1, vec3<i32>(volSize - 1));
    
    // Trilinear filtering - sample all 8 corners
    let c000 = textureLoad(volumeCache, atlasTexel(vec3<i32>(i0.x, i0.y, i0.z), volSize), 0);
    let c100 = textureLoad(volumeCache, atlasTexel(vec3<i32>(i1.x, i0.y, i0.z), volSize), 0);
    let c010 = textureLoad(volumeCache, atlasTexel(vec3<i32>(i0.x, i1.y, i0.z), volSize), 0);
    let c110 = textureLoad(volumeCache, atlasTexel(vec3<i32>(i1.x, i1.y, i0.z), volSize), 0);
    let c001 = textureLoad(volumeCache, atlasTexel(vec3<i32>(i0.x, i0.y, i1.z), volSize), 0);
    let c101 = textureLoad(volumeCache, atlasTexel(vec3<i32>(i1.x, i0.y, i1.z), volSize), 0);
    let c011 = textureLoad(volumeCache, atlasTexel(vec3<i32>(i0.x, i1.y, i1.z), volSize), 0);
    let c111 = textureLoad(volumeCache, atlasTexel(vec3<i32>(i1.x, i1.y, i1.z), volSize), 0);
    
    // Trilinear interpolation
    let c00 = mix(c000, c100, frac.x);
    let c10 = mix(c010, c110, frac.x);
    let c01 = mix(c001, c101, frac.x);
    let c11 = mix(c011, c111, frac.x);
    
    let c0 = mix(c00, c10, frac.y);
    let c1 = mix(c01, c11, frac.y);
    
    return mix(c0, c1, frac.z);
}

// Ray-box intersection for volume bounds [-1, 1]^3
fn boxIntersect(ro: vec3<f32>, rd: vec3<f32>) -> vec2<f32> {
    let invRd = 1.0 / rd;
    let t0 = (-1.0 - ro) * invRd;
    let t1 = (1.0 - ro) * invRd;
    let tmin = min(t0, t1);
    let tmax = max(t0, t1);
    let tEnter = max(max(tmin.x, tmin.y), tmin.z);
    let tExit = min(min(tmax.x, tmax.y), tmax.z);
    return vec2<f32>(tEnter, tExit);
}

@fragment
fn main(@builtin(position) position: vec4<f32>) -> @location(0) vec4<f32> {
    var res = resolution;
    if (res.x < 1.0) { res = vec2<f32>(1024.0, 1024.0); }
    
    let uv = (position.xy - 0.5 * res) / res.y;
    
    // Camera setup - orbiting view
    let camDist = 3.0;
    let angle = time * TAU * f32(orbitSpeed) * 0.1;
    let ro = vec3<f32>(sin(angle) * camDist, 0.8, cos(angle) * camDist);
    let lookAt = vec3<f32>(0.0);
    
    let forward = normalize(lookAt - ro);
    let right = normalize(cross(vec3<f32>(0.0, 1.0, 0.0), forward));
    let up = cross(forward, right);
    
    let rd = normalize(forward + uv.x * right + uv.y * up);
    
    // Ray-volume intersection
    let tRange = boxIntersect(ro, rd);
    
    if (tRange.x > tRange.y || tRange.y < 0.0) {
        // Miss - background
        return vec4<f32>(bgColor, bgAlpha);
    }
    
    let tStart = max(tRange.x, 0.0);
    let tEnd = tRange.y;
    let stepSize = (tEnd - tStart) / f32(MAX_STEPS);
    
    // Front-to-back compositing for volumetric rendering
    var accColor = vec3<f32>(0.0);
    var accAlpha = 0.0;
    
    for (var i = 0; i < MAX_STEPS; i++) {
        if (accAlpha > 0.99) { break; }
        
        let t = tStart + (f32(i) + 0.5) * stepSize;
        let p = ro + rd * t;
        
        let sample4 = sampleVolume(p);
        let sampleColor = sample4.rgb;
        var sampleDensity = length(sampleColor);  // Use color intensity as density
        
        // Apply threshold
        let thresholdVal = threshold;
        if (invert == 1) {
            sampleDensity = 1.0 - sampleDensity;
        }
        
        if (sampleDensity > thresholdVal) {
            // Scale density for accumulation
            var density = (sampleDensity - thresholdVal) * 2.0;
            density = clamp(density * stepSize * 10.0, 0.0, 1.0);
            
            // Front-to-back blending
            let c = sampleColor * density;
            accColor += (1.0 - accAlpha) * c;
            accAlpha += (1.0 - accAlpha) * density;
        }
    }
    
    // Blend with background
    let finalColor = accColor + (1.0 - accAlpha) * bgColor;
    let finalAlpha = accAlpha + (1.0 - accAlpha) * bgAlpha;
    
    // Gamma correction
    let gammaCorrected = pow(finalColor, vec3<f32>(1.0 / 2.2));
    
    return vec4<f32>(gammaCorrected, finalAlpha);
}
