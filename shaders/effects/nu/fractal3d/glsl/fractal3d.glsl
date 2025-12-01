/*
 * Main raymarching shader for nu/fractal3d
 * Uses analytic isosurface raymarching with smooth normals from central differences
 */

#version 300 es
precision highp float;

uniform vec2 resolution;
uniform float time;
uniform int colorMode;
uniform float threshold;
uniform int invert;
uniform int volumeSize;
uniform int filtering;
uniform int orbitSpeed;
uniform vec3 bgColor;
uniform float bgAlpha;
uniform sampler2D volumeCache;

// MRT outputs: color and geometry buffer
layout(location = 0) out vec4 fragColor;
layout(location = 1) out vec4 geoOut;

const float TAU = 6.283185307179586;
const float PI = 3.141592653589793;
const int MAX_STEPS = 256;
const float MAX_DIST = 10.0;

// Convert 3D volume coordinates to 2D atlas texel coordinates
ivec2 volumeToAtlas(int x, int y, int z, int volSize) {
    return ivec2(x, y + z * volSize);
}

// Sample volume at integer voxel coordinates
vec4 sampleVoxel(ivec3 voxel) {
    int volSize = volumeSize;
    ivec3 clamped = clamp(voxel, ivec3(0), ivec3(volSize - 1));
    return texelFetch(volumeCache, volumeToAtlas(clamped.x, clamped.y, clamped.z, volSize), 0);
}

// Sample the cached 3D volume with trilinear interpolation
// World position p is in [-1.5, 1.5]^3 (matching precompute bounds)
vec4 sampleVolume(vec3 worldPos) {
    int volSize = volumeSize;
    float volSizeF = float(volSize);
    
    // Convert world position [-1.5, 1.5] to normalized volume coords [0, 1]
    vec3 uvw = worldPos / 3.0 + 0.5;
    uvw = clamp(uvw, 0.0, 1.0);
    
    vec3 texelPos = uvw * (volSizeF - 1.0);
    vec3 texelFloor = floor(texelPos);
    vec3 frac = texelPos - texelFloor;
    
    ivec3 i0 = ivec3(texelFloor);
    ivec3 i1 = min(i0 + 1, volSize - 1);
    
    // Trilinear filtering
    vec4 c000 = texelFetch(volumeCache, volumeToAtlas(i0.x, i0.y, i0.z, volSize), 0);
    vec4 c100 = texelFetch(volumeCache, volumeToAtlas(i1.x, i0.y, i0.z, volSize), 0);
    vec4 c010 = texelFetch(volumeCache, volumeToAtlas(i0.x, i1.y, i0.z, volSize), 0);
    vec4 c110 = texelFetch(volumeCache, volumeToAtlas(i1.x, i1.y, i0.z, volSize), 0);
    vec4 c001 = texelFetch(volumeCache, volumeToAtlas(i0.x, i0.y, i1.z, volSize), 0);
    vec4 c101 = texelFetch(volumeCache, volumeToAtlas(i1.x, i0.y, i1.z, volSize), 0);
    vec4 c011 = texelFetch(volumeCache, volumeToAtlas(i0.x, i1.y, i1.z, volSize), 0);
    vec4 c111 = texelFetch(volumeCache, volumeToAtlas(i1.x, i1.y, i1.z, volSize), 0);
    
    vec4 c00 = mix(c000, c100, frac.x);
    vec4 c10 = mix(c010, c110, frac.x);
    vec4 c01 = mix(c001, c101, frac.x);
    vec4 c11 = mix(c011, c111, frac.x);
    
    vec4 c0 = mix(c00, c10, frac.y);
    vec4 c1 = mix(c01, c11, frac.y);
    
    return mix(c0, c1, frac.z);
}

// Get the scalar field value at a point
float getField(vec3 p) {
    float val = sampleVolume(p).r;
    float field = val - threshold;
    return invert == 1 ? -field : field;
}

// Check if a voxel is solid
bool isVoxelSolid(ivec3 voxel) {
    float val = sampleVoxel(voxel).r;
    bool solid = val < threshold;
    return invert == 1 ? !solid : solid;
}

// Convert world position to voxel coordinates
ivec3 worldToVoxel(vec3 worldPos) {
    int volSize = volumeSize;
    vec3 uvw = worldPos / 3.0 + 0.5;
    return ivec3(floor(uvw * float(volSize)));
}

// Convert voxel coordinates to world position
vec3 voxelToWorld(ivec3 voxel) {
    int volSize = volumeSize;
    vec3 uvw = (vec3(voxel) + 0.5) / float(volSize);
    return (uvw - 0.5) * 3.0;
}

// Voxel hit result
struct VoxelHit {
    float dist;
    vec3 normal;
    ivec3 voxel;
};

// DDA voxel traversal
VoxelHit voxelTrace(vec3 ro, vec3 rd) {
    VoxelHit result;
    result.dist = -1.0;
    result.normal = vec3(0.0);
    result.voxel = ivec3(0);
    
    int volSize = volumeSize;
    float voxelSize = 3.0 / float(volSize);
    
    vec3 invRd = 1.0 / rd;
    vec3 t0 = (-1.5 - ro) * invRd;
    vec3 t1 = (1.5 - ro) * invRd;
    vec3 tmin = min(t0, t1);
    vec3 tmax = max(t0, t1);
    float tEnter = max(max(tmin.x, tmin.y), tmin.z);
    float tExit = min(min(tmax.x, tmax.y), tmax.z);
    
    if (tEnter > tExit || tExit < 0.0) return result;
    
    float tStart = max(tEnter + 0.001, 0.0);
    vec3 pos = ro + rd * tStart;
    
    ivec3 voxel = worldToVoxel(pos);
    voxel = clamp(voxel, ivec3(0), ivec3(volSize - 1));
    
    ivec3 step = ivec3(sign(rd));
    vec3 voxelBounds = voxelToWorld(voxel + max(step, ivec3(0)));
    vec3 tMaxVec = (voxelBounds - ro) * invRd;
    vec3 tDelta = abs(voxelSize * invRd);
    
    vec3 lastNormal = vec3(0.0);
    for (int i = 0; i < MAX_STEPS; i++) {
        if (voxel.x >= 0 && voxel.x < volSize &&
            voxel.y >= 0 && voxel.y < volSize &&
            voxel.z >= 0 && voxel.z < volSize) {
            
            if (isVoxelSolid(voxel)) {
                result.dist = tStart;
                result.normal = lastNormal;
                result.voxel = voxel;
                
                if (lastNormal == vec3(0.0)) {
                    if (tmin.x > tmin.y && tmin.x > tmin.z) {
                        result.normal = vec3(-sign(rd.x), 0.0, 0.0);
                    } else if (tmin.y > tmin.z) {
                        result.normal = vec3(0.0, -sign(rd.y), 0.0);
                    } else {
                        result.normal = vec3(0.0, 0.0, -sign(rd.z));
                    }
                }
                return result;
            }
        }
        
        if (tMaxVec.x < tMaxVec.y) {
            if (tMaxVec.x < tMaxVec.z) {
                tStart = tMaxVec.x;
                tMaxVec.x += tDelta.x;
                voxel.x += step.x;
                lastNormal = vec3(-float(step.x), 0.0, 0.0);
            } else {
                tStart = tMaxVec.z;
                tMaxVec.z += tDelta.z;
                voxel.z += step.z;
                lastNormal = vec3(0.0, 0.0, -float(step.z));
            }
        } else {
            if (tMaxVec.y < tMaxVec.z) {
                tStart = tMaxVec.y;
                tMaxVec.y += tDelta.y;
                voxel.y += step.y;
                lastNormal = vec3(0.0, -float(step.y), 0.0);
            } else {
                tStart = tMaxVec.z;
                tMaxVec.z += tDelta.z;
                voxel.z += step.z;
                lastNormal = vec3(0.0, 0.0, -float(step.z));
            }
        }
        
        if (tStart > tExit) break;
    }
    
    return result;
}

// Compute smooth normal using central differences on the SDF field
// Uses getField() which properly incorporates threshold and invert
vec3 calcNormal(vec3 p) {
    float eps = 3.0 / float(volumeSize);
    
    // Central differences on the actual SDF field (includes threshold and invert)
    float dx = getField(p + vec3(eps, 0.0, 0.0)) - getField(p - vec3(eps, 0.0, 0.0));
    float dy = getField(p + vec3(0.0, eps, 0.0)) - getField(p - vec3(0.0, eps, 0.0));
    float dz = getField(p + vec3(0.0, 0.0, eps)) - getField(p - vec3(0.0, 0.0, eps));
    
    vec3 n = vec3(dx, dy, dz);
    
    float len = length(n);
    if (len < 0.0001) return vec3(0.0, 1.0, 0.0);
    
    return n / len;
}

// Isosurface hit result
struct IsoHit {
    float dist;
    vec3 pos;
    bool hit;
};

// Analytic isosurface raymarching
IsoHit isosurfaceTrace(vec3 ro, vec3 rd) {
    IsoHit result;
    result.hit = false;
    result.dist = -1.0;
    result.pos = vec3(0.0);
    
    vec3 invRd = 1.0 / rd;
    vec3 t0 = (-1.5 - ro) * invRd;
    vec3 t1 = (1.5 - ro) * invRd;
    vec3 tmin = min(t0, t1);
    vec3 tmax = max(t0, t1);
    float tEnter = max(max(tmin.x, tmin.y), tmin.z);
    float tExit = min(min(tmax.x, tmax.y), tmax.z);
    
    if (tEnter > tExit || tExit < 0.0) return result;
    
    float tStart = max(tEnter, 0.0);
    float stepSize = 2.25 / float(volumeSize);
    
    float t = tStart;
    float prevField = getField(ro + rd * t);
    
    for (int i = 0; i < MAX_STEPS; i++) {
        t += stepSize;
        if (t > tExit) break;
        
        vec3 p = ro + rd * t;
        float field = getField(p);
        
        if (prevField * field < 0.0) {
            float tLo = t - stepSize;
            float tHi = t;
            
            for (int j = 0; j < 8; j++) {
                float tMid = (tLo + tHi) * 0.5;
                float fMid = getField(ro + rd * tMid);
                
                if (prevField * fMid < 0.0) {
                    tHi = tMid;
                } else {
                    tLo = tMid;
                    prevField = fMid;
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

// Shading with fractal coloring
vec3 shade(vec3 p, vec3 rd) {
    vec3 n = calcNormal(p);
    vec3 lightDir = normalize(vec3(1.0, 1.0, -1.0));
    
    float diff = max(dot(n, lightDir), 0.0);
    float amb = 0.12;
    
    vec3 halfVec = normalize(lightDir - rd);
    float spec = pow(max(dot(n, halfVec), 0.0), 32.0);
    
    float rim = pow(1.0 - max(dot(n, -rd), 0.0), 3.0);
    
    vec4 volData = sampleVolume(p);
    float trap = volData.g;
    float iterRatio = volData.b;
    
    vec3 baseColor;
    if (colorMode == 0) {
        baseColor = vec3(0.8);
    } else if (colorMode == 1) {
        baseColor = vec3(
            0.5 + 0.5 * cos(trap * 6.28 + 0.0),
            0.5 + 0.5 * cos(trap * 6.28 + 2.1),
            0.5 + 0.5 * cos(trap * 6.28 + 4.2)
        );
    } else {
        baseColor = vec3(
            0.5 + 0.5 * cos(iterRatio * 6.28 + 1.0),
            0.5 + 0.5 * cos(iterRatio * 6.28 + 2.5),
            0.5 + 0.5 * cos(iterRatio * 6.28 + 4.0)
        );
    }
    
    return baseColor * (amb + diff * 0.75) + spec * 0.2 + rim * 0.15;
}

// Voxel shading
vec3 shadeVoxel(vec3 p, vec3 rd, vec3 n, ivec3 voxel) {
    vec3 lightDir = normalize(vec3(1.0, 1.0, -1.0));
    
    float diff = max(dot(n, lightDir), 0.0);
    float amb = 0.25;
    
    vec4 volData = sampleVoxel(voxel);
    float trap = volData.g;
    float iterRatio = volData.b;
    
    vec3 baseColor;
    if (colorMode == 0) {
        float faceShade = abs(n.x) * 0.9 + abs(n.y) * 1.0 + abs(n.z) * 0.85;
        baseColor = vec3(0.75 * faceShade);
    } else if (colorMode == 1) {
        baseColor = vec3(
            0.5 + 0.5 * cos(trap * 6.28 + 0.0),
            0.5 + 0.5 * cos(trap * 6.28 + 2.1),
            0.5 + 0.5 * cos(trap * 6.28 + 4.2)
        );
    } else {
        baseColor = vec3(
            0.5 + 0.5 * cos(iterRatio * 6.28 + 1.0),
            0.5 + 0.5 * cos(iterRatio * 6.28 + 2.5),
            0.5 + 0.5 * cos(iterRatio * 6.28 + 4.0)
        );
    }
    
    return baseColor * (amb + diff * 0.75);
}

void main() {
    vec2 res = resolution;
    if (res.x < 1.0) res = vec2(1024.0, 1024.0);
    
    vec2 uv = (gl_FragCoord.xy - 0.5 * res) / res.y;
    
    float camAngle = time * TAU * float(orbitSpeed);
    float camDist = 4.0;
    vec3 ro = vec3(sin(camAngle) * camDist, 0.5, cos(camAngle) * camDist);
    vec3 target = vec3(0.0);
    
    vec3 forward = normalize(target - ro);
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
    vec3 up = cross(forward, right);
    
    vec3 rd = normalize(forward + uv.x * right + uv.y * up);
    
    vec3 col;
    vec3 normal = vec3(0.0, 0.0, 1.0);  // Default normal (facing camera)
    float depth = 1.0;  // Default depth (far)
    float alpha = 1.0;
    
    if (filtering == 1) {
        VoxelHit hit = voxelTrace(ro, rd);
        if (hit.dist > 0.0) {
            vec3 p = ro + rd * hit.dist;
            col = shadeVoxel(p, rd, hit.normal, hit.voxel);
            normal = hit.normal;
            depth = hit.dist / MAX_DIST;
        } else {
            col = bgColor;
            alpha = bgAlpha;
        }
    } else {
        IsoHit hit = isosurfaceTrace(ro, rd);
        if (hit.hit) {
            col = shade(hit.pos, rd);
            normal = calcNormal(hit.pos);
            depth = hit.dist / MAX_DIST;
        } else {
            col = bgColor;
            alpha = bgAlpha;
        }
    }
    
    col = pow(col, vec3(1.0 / 2.2));
    
    fragColor = vec4(col, alpha);
    // Geometry buffer: RGB = normal (remapped to 0-1), A = depth
    geoOut = vec4(normal * 0.5 + 0.5, depth);
}
