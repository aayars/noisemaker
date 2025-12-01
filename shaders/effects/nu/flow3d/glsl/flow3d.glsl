/*
 * Flow3D volumetric rendering shader - renders colored flow trails in 3D
 * Uses ray accumulation (not isosurface) since flow trails are sparse colored data
 */

#version 300 es
precision highp float;

uniform vec2 resolution;
uniform float time;
uniform float threshold;
uniform int invert;
uniform int volumeSize;
uniform int orbitSpeed;
uniform vec3 bgColor;
uniform float bgAlpha;
uniform sampler2D volumeCache;  // The blended volume (input + trail)

out vec4 fragColor;

const float TAU = 6.283185307179586;
const float PI = 3.141592653589793;
const int MAX_STEPS = 128;

// Helper to convert 3D texel coords to 2D atlas texel coords
ivec2 atlasTexel(ivec3 p, int volSize) {
    return ivec2(p.x, p.y + p.z * volSize);
}

// Sample the cached 3D volume with trilinear interpolation
// World position p is in [-1, 1]^3 (bounding box coordinates)
vec4 sampleVolume(vec3 worldPos) {
    int volSize = volumeSize;
    float volSizeF = float(volSize);
    
    // Convert world position [-1, 1] to normalized volume coords [0, 1]
    vec3 uvw = worldPos * 0.5 + 0.5;
    uvw = clamp(uvw, 0.0, 1.0);
    
    // Convert to texel coordinates
    vec3 texelPos = uvw * (volSizeF - 1.0);
    vec3 texelFloor = floor(texelPos);
    vec3 frac = texelPos - texelFloor;
    
    ivec3 i0 = ivec3(texelFloor);
    ivec3 i1 = min(i0 + 1, volSize - 1);
    
    // Trilinear filtering - sample all 8 corners
    vec4 c000 = texelFetch(volumeCache, atlasTexel(ivec3(i0.x, i0.y, i0.z), volSize), 0);
    vec4 c100 = texelFetch(volumeCache, atlasTexel(ivec3(i1.x, i0.y, i0.z), volSize), 0);
    vec4 c010 = texelFetch(volumeCache, atlasTexel(ivec3(i0.x, i1.y, i0.z), volSize), 0);
    vec4 c110 = texelFetch(volumeCache, atlasTexel(ivec3(i1.x, i1.y, i0.z), volSize), 0);
    vec4 c001 = texelFetch(volumeCache, atlasTexel(ivec3(i0.x, i0.y, i1.z), volSize), 0);
    vec4 c101 = texelFetch(volumeCache, atlasTexel(ivec3(i1.x, i0.y, i1.z), volSize), 0);
    vec4 c011 = texelFetch(volumeCache, atlasTexel(ivec3(i0.x, i1.y, i1.z), volSize), 0);
    vec4 c111 = texelFetch(volumeCache, atlasTexel(ivec3(i1.x, i1.y, i1.z), volSize), 0);
    
    // Trilinear interpolation
    vec4 c00 = mix(c000, c100, frac.x);
    vec4 c10 = mix(c010, c110, frac.x);
    vec4 c01 = mix(c001, c101, frac.x);
    vec4 c11 = mix(c011, c111, frac.x);
    
    vec4 c0 = mix(c00, c10, frac.y);
    vec4 c1 = mix(c01, c11, frac.y);
    
    return mix(c0, c1, frac.z);
}

// Ray-box intersection for volume bounds [-1, 1]^3
vec2 boxIntersect(vec3 ro, vec3 rd) {
    vec3 invRd = 1.0 / rd;
    vec3 t0 = (-1.0 - ro) * invRd;
    vec3 t1 = (1.0 - ro) * invRd;
    vec3 tmin = min(t0, t1);
    vec3 tmax = max(t0, t1);
    float tEnter = max(max(tmin.x, tmin.y), tmin.z);
    float tExit = min(min(tmax.x, tmax.y), tmax.z);
    return vec2(tEnter, tExit);
}

void main() {
    vec2 res = resolution;
    if (res.x < 1.0) res = vec2(1024.0, 1024.0);
    
    vec2 uv = (gl_FragCoord.xy - 0.5 * res) / res.y;
    
    // Camera setup - orbiting view
    float camDist = 3.0;
    float angle = time * TAU * float(orbitSpeed) * 0.1;
    vec3 ro = vec3(sin(angle) * camDist, 0.8, cos(angle) * camDist);
    vec3 lookAt = vec3(0.0);
    
    vec3 forward = normalize(lookAt - ro);
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
    vec3 up = cross(forward, right);
    
    vec3 rd = normalize(forward + uv.x * right + uv.y * up);
    
    // Ray-volume intersection
    vec2 tRange = boxIntersect(ro, rd);
    
    if (tRange.x > tRange.y || tRange.y < 0.0) {
        // Miss - background
        fragColor = vec4(bgColor, bgAlpha);
        return;
    }
    
    float tStart = max(tRange.x, 0.0);
    float tEnd = tRange.y;
    float stepSize = (tEnd - tStart) / float(MAX_STEPS);
    
    // Front-to-back compositing for volumetric rendering
    vec3 accColor = vec3(0.0);
    float accAlpha = 0.0;
    
    for (int i = 0; i < MAX_STEPS; i++) {
        if (accAlpha > 0.99) break;
        
        float t = tStart + (float(i) + 0.5) * stepSize;
        vec3 p = ro + rd * t;
        
        vec4 sample4 = sampleVolume(p);
        vec3 sampleColor = sample4.rgb;
        float sampleDensity = length(sampleColor);  // Use color intensity as density
        
        // Apply threshold
        float thresholdVal = threshold;
        if (invert == 1) {
            sampleDensity = 1.0 - sampleDensity;
        }
        
        if (sampleDensity > thresholdVal) {
            // Scale density for accumulation
            float density = (sampleDensity - thresholdVal) * 2.0;
            density = clamp(density * stepSize * 10.0, 0.0, 1.0);
            
            // Front-to-back blending
            vec3 c = sampleColor * density;
            accColor += (1.0 - accAlpha) * c;
            accAlpha += (1.0 - accAlpha) * density;
        }
    }
    
    // Blend with background
    vec3 finalColor = accColor + (1.0 - accAlpha) * bgColor;
    float finalAlpha = accAlpha + (1.0 - accAlpha) * bgAlpha;
    
    // Gamma correction
    finalColor = pow(finalColor, vec3(1.0 / 2.2));
    
    fragColor = vec4(finalColor, finalAlpha);
}
