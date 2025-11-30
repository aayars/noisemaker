#version 300 es
precision highp float;

uniform float scale;
uniform float seed;
uniform int octaves;
uniform int ridged;
uniform int volumeSize;

out vec4 fragColor;

// Volume dimensions - stored as 2D atlas
// Atlas layout: volumeSize x (volumeSize * volumeSize)
// Pixel (x, y) maps to 3D coordinate (x, y % volumeSize, y / volumeSize)

// Improved hash using multiple rounds of mixing
float hash3(vec3 p) {
    vec3 ps = p + seed * 0.1;
    uvec3 q = uvec3(ivec3(ps * 1000.0) + 65536);
    q = q * 1664525u + 1013904223u;
    q.x += q.y * q.z;
    q.y += q.z * q.x;
    q.z += q.x * q.y;
    q ^= q >> 16u;
    q.x += q.y * q.z;
    q.y += q.z * q.x;
    q.z += q.x * q.y;
    return float(q.x ^ q.y ^ q.z) / 4294967295.0;
}

// Gradient from hash - returns normalized 3D vector
vec3 grad3(vec3 p) {
    float h1 = hash3(p);
    float h2 = hash3(p + 127.1);
    float h3 = hash3(p + 269.5);
    vec3 g = vec3(
        h1 * 2.0 - 1.0,
        h2 * 2.0 - 1.0,
        h3 * 2.0 - 1.0
    );
    return normalize(g);
}

// Quintic interpolation for smooth transitions
float quintic(float t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// 3D gradient noise - Perlin-style with quintic interpolation
float noise3D(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    
    vec3 u = vec3(quintic(f.x), quintic(f.y), quintic(f.z));
    
    float n000 = dot(grad3(i + vec3(0,0,0)), f - vec3(0,0,0));
    float n100 = dot(grad3(i + vec3(1,0,0)), f - vec3(1,0,0));
    float n010 = dot(grad3(i + vec3(0,1,0)), f - vec3(0,1,0));
    float n110 = dot(grad3(i + vec3(1,1,0)), f - vec3(1,1,0));
    float n001 = dot(grad3(i + vec3(0,0,1)), f - vec3(0,0,1));
    float n101 = dot(grad3(i + vec3(1,0,1)), f - vec3(1,0,1));
    float n011 = dot(grad3(i + vec3(0,1,1)), f - vec3(0,1,1));
    float n111 = dot(grad3(i + vec3(1,1,1)), f - vec3(1,1,1));
    
    float nx00 = mix(n000, n100, u.x);
    float nx10 = mix(n010, n110, u.x);
    float nx01 = mix(n001, n101, u.x);
    float nx11 = mix(n011, n111, u.x);
    
    float nxy0 = mix(nx00, nx10, u.y);
    float nxy1 = mix(nx01, nx11, u.y);
    
    return mix(nxy0, nxy1, u.z);
}

// FBM using 3D noise
float fbm3D(vec3 p, int ridgedMode) {
    const int MAX_OCT = 8;
    float amplitude = 0.5;
    float frequency = 1.0;
    float sum = 0.0;
    float maxVal = 0.0;
    int oct = octaves;
    if (oct < 1) oct = 1;
    
    for (int i = 0; i < MAX_OCT; i++) {
        if (i >= oct) break;
        vec3 pos = p * frequency;
        float n = noise3D(pos);
        n = clamp(n * 1.5, -1.0, 1.0);
        if (ridgedMode == 1) {
            n = 1.0 - abs(n);
        } else {
            n = (n + 1.0) * 0.5;
        }
        sum += n * amplitude;
        maxVal += amplitude;
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return sum / maxVal;
}

void main() {
    // Use uniform for volume size
    int volSize = volumeSize;
    float volSizeF = float(volSize);
    
    // Atlas is volSize x (volSize * volSize)
    // Pixel (x, y) maps to 3D coordinate (x, y % volSize, y / volSize)
    
    ivec2 pixelCoord = ivec2(gl_FragCoord.xy);
    
    int x = pixelCoord.x;
    int y = pixelCoord.y % volSize;
    int z = pixelCoord.y / volSize;
    
    // Bounds check
    if (x >= volSize || y >= volSize || z >= volSize) {
        fragColor = vec4(0.0);
        return;
    }
    
    // Convert to normalized 3D coordinates in [-1, 1] world space (bounding box)
    // This matches the bounding box used in the main raymarching shader
    vec3 p = vec3(float(x), float(y), float(z)) / (volSizeF - 1.0) * 2.0 - 1.0;
    
    // Scale for noise density (same as main shader)
    vec3 scaledP = p * scale;
    
    // Compute FBM noise at this point
    float noiseVal = fbm3D(scaledP, ridged);
    
    // Store noise value in R channel
    // G, B, A can store additional data if needed (e.g., for RGB mode)
    // For RGB color mode, we compute 3 different noise channels
    float r = noiseVal;
    float g = fbm3D(scaledP + vec3(100.0, 0.0, 0.0), ridged);
    float b = fbm3D(scaledP + vec3(0.0, 100.0, 0.0), ridged);
    
    fragColor = vec4(r, g, b, 1.0);
}
