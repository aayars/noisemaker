/*
 * 3D Reaction-Diffusion simulation shader (GLSL)
 * Implements Gray-Scott model in 3D with 6-neighbor Laplacian
 * Self-initializing: detects empty buffer and seeds on first frame
 */

#version 300 es
precision highp float;

uniform float time;
uniform float seed;
uniform int volumeSize;
uniform float feed;
uniform float kill;
uniform float rate1;
uniform float rate2;
uniform float speed;
uniform float weight;
uniform sampler2D stateTex;
uniform sampler2D seedTex;  // 3D input volume atlas (inputTex3d)

out vec4 fragColor;

// Hash for initialization
float hash3(vec3 p) {
    p = p + seed * 0.1;
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.x + p.y) * p.z);
}

// Helper to convert 3D voxel coords to 2D atlas texel coords
ivec2 atlasTexel(ivec3 p, int volSize) {
    // Wrap coordinates for periodic boundary
    ivec3 wrapped = ivec3(
        (p.x + volSize) % volSize,
        (p.y + volSize) % volSize,
        (p.z + volSize) % volSize
    );
    return ivec2(wrapped.x, wrapped.y + wrapped.z * volSize);
}

// Sample state at voxel coordinate with wrapping
vec4 sampleState(ivec3 voxel, int volSize) {
    return texelFetch(stateTex, atlasTexel(voxel, volSize), 0);
}

// Sample seed texture at voxel coordinate (for inputTex3d seeding)
vec4 sampleSeed(ivec3 voxel, int volSize) {
    return texelFetch(seedTex, atlasTexel(voxel, volSize), 0);
}

// 3D Laplacian using 6-neighbor stencil (face neighbors only)
// Normalized to match the 2D behavior for stability
vec2 laplacian3D(ivec3 voxel, int volSize) {
    vec4 center = sampleState(voxel, volSize);
    
    // 6-neighbor stencil (face-adjacent neighbors)
    vec4 xp = sampleState(voxel + ivec3(1, 0, 0), volSize);
    vec4 xn = sampleState(voxel + ivec3(-1, 0, 0), volSize);
    vec4 yp = sampleState(voxel + ivec3(0, 1, 0), volSize);
    vec4 yn = sampleState(voxel + ivec3(0, -1, 0), volSize);
    vec4 zp = sampleState(voxel + ivec3(0, 0, 1), volSize);
    vec4 zn = sampleState(voxel + ivec3(0, 0, -1), volSize);
    
    // Discrete Laplacian for uniform grid, normalized
    // Each neighbor gets weight 1/6, center gets -1, total sums to 0
    vec2 neighborSum = (xp.rg + xn.rg + yp.rg + yn.rg + zp.rg + zn.rg) / 6.0;
    vec2 lap = neighborSum - center.rg;
    
    return lap;
}

void main() {
    int volSize = volumeSize;
    
    // Decode voxel position from atlas
    ivec2 pixelCoord = ivec2(gl_FragCoord.xy);
    int x = pixelCoord.x;
    int y = pixelCoord.y % volSize;
    int z = pixelCoord.y / volSize;
    ivec3 voxel = ivec3(x, y, z);
    
    // Bounds check
    if (x >= volSize || y >= volSize || z >= volSize) {
        fragColor = vec4(0.0);
        return;
    }
    
    // Current state
    vec4 state = sampleState(voxel, volSize);
    float a = state.r;  // Chemical A concentration
    float b = state.g;  // Chemical B concentration
    
    // Self-initialization: detect empty buffer (first frame)
    bool bufferIsEmpty = (state.r == 0.0 && state.g == 0.0 && state.b == 0.0 && state.a == 0.0);
    
    if (bufferIsEmpty) {
        // Check if we have input from seedTex (inputTex3d)
        vec4 seedVal = sampleSeed(voxel, volSize);
        bool hasSeedInput = (seedVal.r > 0.0 || seedVal.g > 0.0 || seedVal.b > 0.0);
        
        float volSizeF = float(volSize);
        vec3 p = vec3(float(x), float(y), float(z));
        
        if (hasSeedInput) {
            // Use seed texture luminance to seed chemical B
            float lum = 0.299 * seedVal.r + 0.587 * seedVal.g + 0.114 * seedVal.b;
            a = 1.0;
            b = lum > 0.5 ? 1.0 : 0.0;
        } else {
            // Initialize: A=1 everywhere, B=1 at sparse random locations
            a = 1.0;
            b = 0.0;
            if (hash3(p) > 0.97) {
                b = 1.0;
            }
            // Also seed some spherical regions
            vec3 center1 = vec3(volSizeF * 0.3, volSizeF * 0.5, volSizeF * 0.5);
            vec3 center2 = vec3(volSizeF * 0.7, volSizeF * 0.4, volSizeF * 0.6);
            vec3 center3 = vec3(volSizeF * 0.5, volSizeF * 0.6, volSizeF * 0.3);
            float radius = volSizeF * 0.08;
            if (length(p - center1) < radius ||
                length(p - center2) < radius ||
                length(p - center3) < radius) {
                b = 1.0;
            }
        }
        fragColor = vec4(a, b, 0.0, 1.0);
        return;
    }
    
    // Compute Laplacian for diffusion
    vec2 lap = laplacian3D(voxel, volSize);
    
    // Gray-Scott parameters (scaled from UI values - matching 2D rd)
    float f = feed * 0.001;      // Feed rate
    float k = kill * 0.001;      // Kill rate
    float r1 = rate1 * 0.01;     // Diffusion rate A (same scale as 2D)
    float r2 = rate2 * 0.01;     // Diffusion rate B (same scale as 2D)
    float s = speed * 0.01;      // Time step (same scale as 2D)
    
    // Gray-Scott reaction-diffusion equations (matching 2D rd form):
    // lap already contains the discrete Laplacian of each chemical
    float newA = a + (r1 * lap.x - a * b * b + f * (1.0 - a)) * s;
    float newB = b + (r2 * lap.y + a * b * b - (k + f) * b) * s;
    
    // Apply input weight blending from seedTex (inputTex3d)
    if (weight > 0.0) {
        vec4 seedVal = sampleSeed(voxel, volSize);
        float seedLum = 0.299 * seedVal.r + 0.587 * seedVal.g + 0.114 * seedVal.b;
        // Seed influences chemical B (the visible one)
        newB = mix(newB, seedLum, weight * 0.01);
    }
    
    // Clamp for numerical stability
    newA = clamp(newA, 0.0, 1.0);
    newB = clamp(newB, 0.0, 1.0);
    
    fragColor = vec4(newA, newB, 0.0, 1.0);
}
