#version 300 es
precision highp float;

uniform vec2 resolution;
uniform float aspect;
uniform float time;
uniform float scale;
uniform float seed;
uniform int octaves;
uniform int colorMode;
uniform int ridges;

out vec4 fragColor;

/* 3D gradient noise with quintic interpolation
   Animated using circular time coordinate for seamless looping
   2D output is a cross-section through 3D noise volume */

const float TAU = 6.283185307179586;

// 3D hash using multiple rounds of mixing
// Based on techniques from "Hash Functions for GPU Rendering" (Jarzynski & Olano, 2020)
float hash3(vec3 p) {
    // Add seed to input to vary the noise pattern
    p = p + seed * 0.1;
    
    // Convert to unsigned integer-like values via large multipliers
    uvec3 q = uvec3(ivec3(p * 1000.0) + 65536);
    
    // Multiple rounds of mixing for thorough decorrelation
    q = q * 1664525u + 1013904223u;  // LCG constants
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
    // Generate 3 independent random values
    float h1 = hash3(p);
    float h2 = hash3(p + 127.1);
    float h3 = hash3(p + 269.5);
    
    // Generate independent gradient components - each component is [-1, 1]
    vec3 g = vec3(
        h1 * 2.0 - 1.0,
        h2 * 2.0 - 1.0,
        h3 * 2.0 - 1.0
    );
    
    return normalize(g);
}

// Quintic interpolation for smooth transitions (no visible seams)
float quintic(float t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// 3D gradient noise - Perlin-style with quintic interpolation
float noise3D(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    
    // Quintic interpolation curves
    vec3 u = vec3(quintic(f.x), quintic(f.y), quintic(f.z));
    
    // 8 corners of 3D cube
    float n000 = dot(grad3(i + vec3(0,0,0)), f - vec3(0,0,0));
    float n100 = dot(grad3(i + vec3(1,0,0)), f - vec3(1,0,0));
    float n010 = dot(grad3(i + vec3(0,1,0)), f - vec3(0,1,0));
    float n110 = dot(grad3(i + vec3(1,1,0)), f - vec3(1,1,0));
    float n001 = dot(grad3(i + vec3(0,0,1)), f - vec3(0,0,1));
    float n101 = dot(grad3(i + vec3(1,0,1)), f - vec3(1,0,1));
    float n011 = dot(grad3(i + vec3(0,1,1)), f - vec3(0,1,1));
    float n111 = dot(grad3(i + vec3(1,1,1)), f - vec3(1,1,1));
    
    // Trilinear interpolation along x
    float nx00 = mix(n000, n100, u.x);
    float nx10 = mix(n010, n110, u.x);
    float nx01 = mix(n001, n101, u.x);
    float nx11 = mix(n011, n111, u.x);
    
    // Interpolation along y
    float nxy0 = mix(nx00, nx10, u.y);
    float nxy1 = mix(nx01, nx11, u.y);
    
    // Final interpolation along z
    return mix(nxy0, nxy1, u.z);
}

// FBM using 3D noise with circular time for seamless looping
// 2D cross-section moves through 3D noise as time varies
float fbm(vec2 st, float timeAngle, float channelOffset, int ridgedMode) {
    const int MAX_OCT = 8;
    float amplitude = 0.5;
    float frequency = 1.0;
    float sum = 0.0;
    float maxVal = 0.0;
    int oct = octaves;
    if (oct < 1) oct = 1;
    
    // Circular time coordinate for seamless looping
    // z = cos(timeAngle) traces a circle in z, giving seamless loop
    // Radius 0.4, centered at 0.5 so circle stays within [0.1, 0.9] - no cell crossings
    float timeRadius = 0.4;
    float z = cos(timeAngle) * timeRadius + 0.5 + channelOffset;
    
    for (int i = 0; i < MAX_OCT; i++) {
        if (i >= oct) break;
        vec3 p = vec3(st * frequency, z);
        float n = noise3D(p);  // -1..1
        // Scale up by ~1.5 to spread the gaussian-ish distribution
        // Perlin noise rarely hits +-1, so this expands the usable range
        n = clamp(n * 1.5, -1.0, 1.0);
        if (ridgedMode == 1) {
            n = 1.0 - abs(n);  // fold at zero, gives 0..1 with ridges at zero-crossings
        } else {
            n = (n + 1.0) * 0.5;  // normalize to 0..1
        }
        sum += n * amplitude;
        maxVal += amplitude;
        frequency *= 2.0;
        amplitude *= 0.5;
    }
    return sum / maxVal;
}

void main() {
    vec2 res = resolution;
    if (res.x < 1.0) res = vec2(1024.0, 1024.0);
    vec2 st = gl_FragCoord.xy / res;
    st.x *= aspect;
    // Invert scale to match vnoise convention: higher scale = fewer cells (zoomed in)
    float freq = max(0.1, 100.0 / max(scale, 0.01));
    st *= freq;
    
    // time is 0-1 representing position around circle for seamless looping
    float timeAngle = time * TAU;
    
    float r = fbm(st, timeAngle, 0.0, ridges);
    float g = fbm(st, timeAngle, 100.0, ridges);
    float b = fbm(st, timeAngle, 200.0, ridges);
    
    vec3 col;
    if (colorMode == 0) {
        // Mono mode
        col = vec3(r);
    } else {
        // RGB mode
        col = vec3(r, g, b);
    }
    
    fragColor = vec4(col, 1.0);
}
