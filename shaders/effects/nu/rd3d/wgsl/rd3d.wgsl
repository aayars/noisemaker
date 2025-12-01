/*
 * Main raymarching shader for nu/rd3d (WGSL)
 * Renders the 3D reaction-diffusion volume with isosurface or voxel filtering
 */

@group(0) @binding(0) var<uniform> resolution: vec2<f32>;
@group(0) @binding(1) var<uniform> time: f32;
@group(0) @binding(2) var<uniform> threshold: f32;
@group(0) @binding(3) var<uniform> invert: i32;
@group(0) @binding(4) var<uniform> colorMode: i32;
@group(0) @binding(5) var<uniform> volumeSize: i32;
@group(0) @binding(6) var<uniform> filtering: i32;
@group(0) @binding(7) var<uniform> orbitSpeed: i32;
@group(0) @binding(8) var<uniform> bgColor: vec3<f32>;
@group(0) @binding(9) var<uniform> bgAlpha: f32;
@group(0) @binding(10) var volumeCache: texture_2d<f32>;

const TAU: f32 = 6.283185307179586;
const PI: f32 = 3.141592653589793;
const MAX_STEPS: i32 = 256;
const MAX_DIST: f32 = 10.0;

// MRT output structure
struct FragmentOutput {
    @location(0) color: vec4<f32>,
    @location(1) geoOut: vec4<f32>,
}

// Convert 3D volume coordinates to 2D atlas texel coordinates
fn atlasTexel(p: vec3<i32>, volSize: i32) -> vec2<i32> {
    return vec2<i32>(p.x, p.y + p.z * volSize);
}

// Sample volume at integer voxel coordinates
fn sampleVoxel(voxel: vec3<i32>) -> vec4<f32> {
    let volSize = volumeSize;
    let clamped = clamp(voxel, vec3<i32>(0), vec3<i32>(volSize - 1));
    return textureLoad(volumeCache, atlasTexel(clamped, volSize), 0);
}

// Sample the cached 3D volume with trilinear interpolation
fn sampleVolume(worldPos: vec3<f32>) -> vec4<f32> {
    let volSize = volumeSize;
    let volSizeF = f32(volSize);
    
    var uvw = worldPos * 0.5 + 0.5;
    uvw = clamp(uvw, vec3<f32>(0.0), vec3<f32>(1.0));
    
    let texelPos = uvw * (volSizeF - 1.0);
    let texelFloor = floor(texelPos);
    let frac = texelPos - texelFloor;
    
    let i0 = vec3<i32>(texelFloor);
    let i1 = min(i0 + 1, vec3<i32>(volSize - 1));
    
    let c000 = textureLoad(volumeCache, atlasTexel(vec3<i32>(i0.x, i0.y, i0.z), volSize), 0);
    let c100 = textureLoad(volumeCache, atlasTexel(vec3<i32>(i1.x, i0.y, i0.z), volSize), 0);
    let c010 = textureLoad(volumeCache, atlasTexel(vec3<i32>(i0.x, i1.y, i0.z), volSize), 0);
    let c110 = textureLoad(volumeCache, atlasTexel(vec3<i32>(i1.x, i1.y, i0.z), volSize), 0);
    let c001 = textureLoad(volumeCache, atlasTexel(vec3<i32>(i0.x, i0.y, i1.z), volSize), 0);
    let c101 = textureLoad(volumeCache, atlasTexel(vec3<i32>(i1.x, i0.y, i1.z), volSize), 0);
    let c011 = textureLoad(volumeCache, atlasTexel(vec3<i32>(i0.x, i1.y, i1.z), volSize), 0);
    let c111 = textureLoad(volumeCache, atlasTexel(vec3<i32>(i1.x, i1.y, i1.z), volSize), 0);
    
    let c00 = mix(c000, c100, frac.x);
    let c10 = mix(c010, c110, frac.x);
    let c01 = mix(c001, c101, frac.x);
    let c11 = mix(c011, c111, frac.x);
    
    let c0 = mix(c00, c10, frac.y);
    let c1 = mix(c01, c11, frac.y);
    
    return mix(c0, c1, frac.z);
}

// Get the scalar field value (chemical B concentration)
fn getField(p: vec3<f32>) -> f32 {
    let val = sampleVolume(p).g;
    var field = val - threshold;
    if (invert == 1) {
        field = -field;
    }
    return field;
}

// Check if a voxel is solid
fn isVoxelSolid(voxel: vec3<i32>) -> bool {
    let val = sampleVoxel(voxel).g;
    let solid = val > threshold;
    if (invert == 1) {
        return !solid;
    }
    return solid;
}

// Convert world position to voxel coordinates
fn worldToVoxel(worldPos: vec3<f32>) -> vec3<i32> {
    let volSize = volumeSize;
    let uvw = worldPos * 0.5 + 0.5;
    return vec3<i32>(floor(uvw * f32(volSize)));
}

// Convert voxel coordinates to world position
fn voxelToWorld(voxel: vec3<i32>) -> vec3<f32> {
    let volSize = volumeSize;
    let uvw = (vec3<f32>(voxel) + 0.5) / f32(volSize);
    return uvw * 2.0 - 1.0;
}

// Voxel hit result
struct VoxelHit {
    dist: f32,
    normal: vec3<f32>,
    voxel: vec3<i32>,
}

// DDA voxel traversal
fn voxelTrace(ro: vec3<f32>, rd: vec3<f32>) -> VoxelHit {
    var result: VoxelHit;
    result.dist = -1.0;
    result.normal = vec3<f32>(0.0);
    result.voxel = vec3<i32>(0);
    
    let volSize = volumeSize;
    let voxelSize = 2.0 / f32(volSize);
    
    let invRd = 1.0 / rd;
    let t0 = (-1.0 - ro) * invRd;
    let t1 = (1.0 - ro) * invRd;
    let tminV = min(t0, t1);
    let tmaxV = max(t0, t1);
    let tEnter = max(max(tminV.x, tminV.y), tminV.z);
    let tExit = min(min(tmaxV.x, tmaxV.y), tmaxV.z);
    
    if (tEnter > tExit || tExit < 0.0) {
        return result;
    }
    
    var tStart = max(tEnter + 0.001, 0.0);
    let pos = ro + rd * tStart;
    
    var voxel = worldToVoxel(pos);
    voxel = clamp(voxel, vec3<i32>(0), vec3<i32>(volSize - 1));
    
    let step = vec3<i32>(sign(rd));
    
    let voxelBounds = voxelToWorld(voxel + max(step, vec3<i32>(0)));
    var tMaxVec = (voxelBounds - ro) * invRd;
    let tDelta = abs(vec3<f32>(voxelSize) * invRd);
    
    var lastNormal = vec3<f32>(0.0);
    for (var i: i32 = 0; i < MAX_STEPS * 2; i = i + 1) {
        if (voxel.x >= 0 && voxel.x < volSize &&
            voxel.y >= 0 && voxel.y < volSize &&
            voxel.z >= 0 && voxel.z < volSize) {
            
            if (isVoxelSolid(voxel)) {
                result.dist = tStart;
                result.normal = lastNormal;
                result.voxel = voxel;
                
                if (lastNormal.x == 0.0 && lastNormal.y == 0.0 && lastNormal.z == 0.0) {
                    if (tminV.x > tminV.y && tminV.x > tminV.z) {
                        result.normal = vec3<f32>(-sign(rd.x), 0.0, 0.0);
                    } else if (tminV.y > tminV.z) {
                        result.normal = vec3<f32>(0.0, -sign(rd.y), 0.0);
                    } else {
                        result.normal = vec3<f32>(0.0, 0.0, -sign(rd.z));
                    }
                }
                return result;
            }
        }
        
        if (tMaxVec.x < tMaxVec.y) {
            if (tMaxVec.x < tMaxVec.z) {
                tStart = tMaxVec.x;
                tMaxVec.x = tMaxVec.x + tDelta.x;
                voxel.x = voxel.x + step.x;
                lastNormal = vec3<f32>(-f32(step.x), 0.0, 0.0);
            } else {
                tStart = tMaxVec.z;
                tMaxVec.z = tMaxVec.z + tDelta.z;
                voxel.z = voxel.z + step.z;
                lastNormal = vec3<f32>(0.0, 0.0, -f32(step.z));
            }
        } else {
            if (tMaxVec.y < tMaxVec.z) {
                tStart = tMaxVec.y;
                tMaxVec.y = tMaxVec.y + tDelta.y;
                voxel.y = voxel.y + step.y;
                lastNormal = vec3<f32>(0.0, -f32(step.y), 0.0);
            } else {
                tStart = tMaxVec.z;
                tMaxVec.z = tMaxVec.z + tDelta.z;
                voxel.z = voxel.z + step.z;
                lastNormal = vec3<f32>(0.0, 0.0, -f32(step.z));
            }
        }
        
        if (tStart > tExit) { break; }
    }
    
    return result;
}

// Compute smooth normal using central differences
fn calcNormal(p: vec3<f32>) -> vec3<f32> {
    let eps = 2.0 / f32(volumeSize);
    
    let dx = getField(p + vec3<f32>(eps, 0.0, 0.0)) - getField(p - vec3<f32>(eps, 0.0, 0.0));
    let dy = getField(p + vec3<f32>(0.0, eps, 0.0)) - getField(p - vec3<f32>(0.0, eps, 0.0));
    let dz = getField(p + vec3<f32>(0.0, 0.0, eps)) - getField(p - vec3<f32>(0.0, 0.0, eps));
    
    var n = vec3<f32>(dx, dy, dz);
    let len = length(n);
    if (len < 0.0001) { return vec3<f32>(0.0, 1.0, 0.0); }
    
    return n / len;
}

// Isosurface hit result
struct IsoHit {
    dist: f32,
    pos: vec3<f32>,
    hit: bool,
}

// Analytic isosurface raymarching with bisection
fn isosurfaceTrace(ro: vec3<f32>, rd: vec3<f32>) -> IsoHit {
    var result: IsoHit;
    result.hit = false;
    result.dist = -1.0;
    result.pos = vec3<f32>(0.0);
    
    let invRd = 1.0 / rd;
    let t0 = (-1.0 - ro) * invRd;
    let t1 = (1.0 - ro) * invRd;
    let tminV = min(t0, t1);
    let tmaxV = max(t0, t1);
    let tEnter = max(max(tminV.x, tminV.y), tminV.z);
    let tExit = min(min(tmaxV.x, tmaxV.y), tmaxV.z);
    
    if (tEnter > tExit || tExit < 0.0) { return result; }
    
    let tStart = max(tEnter, 0.0);
    let stepSize = 1.5 / f32(volumeSize);
    
    var t = tStart;
    var prevField = getField(ro + rd * t);
    
    for (var i: i32 = 0; i < MAX_STEPS; i = i + 1) {
        t = t + stepSize;
        if (t > tExit) { break; }
        
        let p = ro + rd * t;
        let field = getField(p);
        
        if (prevField * field < 0.0) {
            var tLo = t - stepSize;
            var tHi = t;
            var pf = prevField;
            
            for (var j: i32 = 0; j < 8; j = j + 1) {
                let tMid = (tLo + tHi) * 0.5;
                let fMid = getField(ro + rd * tMid);
                
                if (pf * fMid < 0.0) {
                    tHi = tMid;
                } else {
                    tLo = tMid;
                    pf = fMid;
                }
            }
            
            result.hit = true;
            result.dist = (tLo + tHi) * 0.5;
            result.pos = ro + rd * result.dist;
            return result;
        }
        
        prevField = field;
    }
    
    return result;
}

// Shading for smooth isosurface
fn shade(p: vec3<f32>, rd: vec3<f32>) -> vec3<f32> {
    let n = calcNormal(p);
    let lightDir = normalize(vec3<f32>(1.0, 1.0, -1.0));
    
    let diff = max(dot(n, lightDir), 0.0);
    let amb: f32 = 0.15;
    
    let halfVec = normalize(lightDir - rd);
    let spec = pow(max(dot(n, halfVec), 0.0), 32.0);
    
    let rim = pow(1.0 - max(dot(n, -rd), 0.0), 3.0);
    
    var baseColor: vec3<f32>;
    if (colorMode == 0) {
        baseColor = vec3<f32>(0.75);
    } else {
        let b = sampleVolume(p).g;
        baseColor = mix(vec3<f32>(0.2, 0.4, 0.8), vec3<f32>(1.0, 0.6, 0.2), b);
    }
    
    return baseColor * (amb + diff * 0.7) + spec * 0.2 + rim * 0.15;
}

// Voxel shading
fn shadeVoxel(p: vec3<f32>, rd: vec3<f32>, n: vec3<f32>, voxel: vec3<i32>) -> vec3<f32> {
    let lightDir = normalize(vec3<f32>(1.0, 1.0, -1.0));
    
    let diff = max(dot(n, lightDir), 0.0);
    let amb: f32 = 0.3;
    
    var baseColor: vec3<f32>;
    if (colorMode == 0) {
        let faceShade = abs(n.x) * 0.9 + abs(n.y) * 1.0 + abs(n.z) * 0.85;
        baseColor = vec3<f32>(0.7 * faceShade);
    } else {
        let b = sampleVoxel(voxel).g;
        baseColor = mix(vec3<f32>(0.2, 0.4, 0.8), vec3<f32>(1.0, 0.6, 0.2), b);
    }
    
    return baseColor * (amb + diff * 0.7);
}

@fragment
fn main(@builtin(position) position: vec4<f32>) -> FragmentOutput {
    var res = resolution;
    if (res.x < 1.0) { res = vec2<f32>(1024.0, 1024.0); }
    
    let uv = (position.xy - 0.5 * res) / res.y;
    let uvFlipped = vec2<f32>(uv.x, -uv.y);
    
    let camAngle = time * TAU * f32(orbitSpeed);
    let camDist: f32 = 3.5;
    let ro = vec3<f32>(sin(camAngle) * camDist, 0.5, cos(camAngle) * camDist);
    let lookAt = vec3<f32>(0.0);
    
    let forward = normalize(lookAt - ro);
    let right = normalize(cross(vec3<f32>(0.0, 1.0, 0.0), forward));
    let up = cross(forward, right);
    
    let rd = normalize(forward + uvFlipped.x * right + uvFlipped.y * up);
    
    var color: vec3<f32>;
    var normal = vec3<f32>(0.0, 0.0, 1.0);
    var depth: f32 = 1.0;
    var alpha: f32 = 1.0;
    
    if (filtering == 1) {
        let hit = voxelTrace(ro, rd);
        if (hit.dist > 0.0) {
            let p = ro + rd * hit.dist;
            color = shadeVoxel(p, rd, hit.normal, hit.voxel);
            normal = hit.normal;
            depth = hit.dist / MAX_DIST;
        } else {
            color = bgColor;
            alpha = bgAlpha;
        }
    } else {
        let hit = isosurfaceTrace(ro, rd);
        if (hit.hit) {
            color = shade(hit.pos, rd);
            normal = calcNormal(hit.pos);
            depth = hit.dist / MAX_DIST;
        } else {
            color = bgColor;
            alpha = bgAlpha;
        }
    }
    
    color = pow(color, vec3<f32>(1.0 / 2.2));
    
    var output: FragmentOutput;
    output.color = vec4<f32>(color, alpha);
    output.geoOut = vec4<f32>(normal * 0.5 + 0.5, depth);
    return output;
}
