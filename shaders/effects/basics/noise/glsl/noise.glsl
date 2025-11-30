#version 300 es
precision highp float;

uniform vec2 resolution;
uniform float aspect;
uniform float time;
uniform float scale;
uniform float seed;
uniform int octaves;
uniform int colorMode;
uniform float hueRotation;
uniform float hueRange;
uniform int ridged;

out vec4 fragColor;

/* Improved 4D noise implementation
   Uses value noise with smooth interpolation
   Animated using circular time coordinates for seamless looping */

const float TAU = 6.283185307179586;

// Improved 4D hash using multiple rounds of mixing
// Based on techniques from "Hash Functions for GPU Rendering" (Jarzynski & Olano, 2020)
float hash4(vec4 p) {
    // Add seed to input to vary the noise pattern
    p = p + seed * 0.1;
    
    // Convert to unsigned integer-like values via large multipliers
    uvec4 q = uvec4(ivec4(p * 1000.0) + 65536);
    
    // Multiple rounds of mixing for thorough decorrelation
    q = q * 1664525u + 1013904223u;  // LCG constants
    q.x += q.y * q.w;
    q.y += q.z * q.x;
    q.z += q.x * q.y;
    q.w += q.y * q.z;
    
    q ^= q >> 16u;
    
    q.x += q.y * q.w;
    q.y += q.z * q.x;
    q.z += q.x * q.y;
    q.w += q.y * q.z;
    
    return float(q.x ^ q.y ^ q.z ^ q.w) / 4294967295.0;
}

// Gradient from hash - returns normalized 4D vector
vec4 grad4(vec4 p) {
    // Generate 4 independent random values
    float h1 = hash4(p);
    float h2 = hash4(p + 127.1);
    float h3 = hash4(p + 269.5);
    float h4 = hash4(p + 419.2);
    
    // Generate independent gradient components - each component is [-1, 1]
    // This avoids the spherical coordinate approach which creates correlations
    vec4 g = vec4(
        h1 * 2.0 - 1.0,
        h2 * 2.0 - 1.0,
        h3 * 2.0 - 1.0,
        h4 * 2.0 - 1.0
    );
    
    return normalize(g);
}

// Quintic interpolation for smooth transitions (no visible seams)
float quintic(float t) {
    return t * t * t * (t * (t * 6.0 - 15.0) + 10.0);
}

// 4D gradient noise - Perlin-style with quintic interpolation
float noise4D(vec4 p) {
    vec4 i = floor(p);
    vec4 f = fract(p);
    
    // Quintic interpolation curves
    vec4 u = vec4(quintic(f.x), quintic(f.y), quintic(f.z), quintic(f.w));
    
    // 16 corners of 4D hypercube (we'll do this in groups)
    float n0000 = dot(grad4(i + vec4(0,0,0,0)), f - vec4(0,0,0,0));
    float n1000 = dot(grad4(i + vec4(1,0,0,0)), f - vec4(1,0,0,0));
    float n0100 = dot(grad4(i + vec4(0,1,0,0)), f - vec4(0,1,0,0));
    float n1100 = dot(grad4(i + vec4(1,1,0,0)), f - vec4(1,1,0,0));
    float n0010 = dot(grad4(i + vec4(0,0,1,0)), f - vec4(0,0,1,0));
    float n1010 = dot(grad4(i + vec4(1,0,1,0)), f - vec4(1,0,1,0));
    float n0110 = dot(grad4(i + vec4(0,1,1,0)), f - vec4(0,1,1,0));
    float n1110 = dot(grad4(i + vec4(1,1,1,0)), f - vec4(1,1,1,0));
    float n0001 = dot(grad4(i + vec4(0,0,0,1)), f - vec4(0,0,0,1));
    float n1001 = dot(grad4(i + vec4(1,0,0,1)), f - vec4(1,0,0,1));
    float n0101 = dot(grad4(i + vec4(0,1,0,1)), f - vec4(0,1,0,1));
    float n1101 = dot(grad4(i + vec4(1,1,0,1)), f - vec4(1,1,0,1));
    float n0011 = dot(grad4(i + vec4(0,0,1,1)), f - vec4(0,0,1,1));
    float n1011 = dot(grad4(i + vec4(1,0,1,1)), f - vec4(1,0,1,1));
    float n0111 = dot(grad4(i + vec4(0,1,1,1)), f - vec4(0,1,1,1));
    float n1111 = dot(grad4(i + vec4(1,1,1,1)), f - vec4(1,1,1,1));
    
    // Trilinear interpolation along x
    float nx000 = mix(n0000, n1000, u.x);
    float nx100 = mix(n0100, n1100, u.x);
    float nx010 = mix(n0010, n1010, u.x);
    float nx110 = mix(n0110, n1110, u.x);
    float nx001 = mix(n0001, n1001, u.x);
    float nx101 = mix(n0101, n1101, u.x);
    float nx011 = mix(n0011, n1011, u.x);
    float nx111 = mix(n0111, n1111, u.x);
    
    // Interpolation along y
    float nxy00 = mix(nx000, nx100, u.y);
    float nxy10 = mix(nx010, nx110, u.y);
    float nxy01 = mix(nx001, nx101, u.y);
    float nxy11 = mix(nx011, nx111, u.y);
    
    // Interpolation along z
    float nxyz0 = mix(nxy00, nxy10, u.z);
    float nxyz1 = mix(nxy01, nxy11, u.z);
    
    // Final interpolation along w
    return mix(nxyz0, nxyz1, u.w);
}

vec3 hsv2rgb(vec3 hsv) {
    vec3 c = vec3(hsv.x, hsv.y, hsv.z);
    vec4 K = vec4(1.0, 2.0/3.0, 1.0/3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// FBM using 4D noise with circular time for seamless looping
float fbm(vec2 st, float timeAngle, float channelOffset, int ridgedMode) {
    const int MAX_OCT = 8;
    float amplitude = 0.5;
    float frequency = 1.0;
    float sum = 0.0;
    float maxVal = 0.0;
    int oct = octaves;
    if (oct < 1) oct = 1;
    
    // Circular time coordinates for seamless looping
    // Radius 0.4, centered at 0.5 so circle stays within [0.1, 0.9] - no cell crossings
    float timeRadius = 0.4;
    float tc = cos(timeAngle) * timeRadius + 0.5 + channelOffset;
    float ts = sin(timeAngle) * timeRadius + 0.5;
    
    for (int i = 0; i < MAX_OCT; i++) {
        if (i >= oct) break;
        vec4 p = vec4(st * frequency, tc, ts);
        float n = noise4D(p);  // -1..1
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
    st *= scale;
    
    // time is 0-1 representing position around circle for seamless looping
    float timeAngle = time * TAU;
    
    float r, g, b;
    if (colorMode == 2 && ridged != 0) {
        r = fbm(st, timeAngle, 0.0, 0);
        g = fbm(st, timeAngle, 100.0, 0);
        b = fbm(st, timeAngle, 200.0, ridged);
    } else {
        r = fbm(st, timeAngle, 0.0, ridged);
        g = fbm(st, timeAngle, 100.0, ridged);
        b = fbm(st, timeAngle, 200.0, ridged);
    }
    
    vec3 col;
    if (colorMode == 0) {
        col = vec3(r);
    } else if (colorMode == 1) {
        col = vec3(r, g, b);
    } else {
        float h = r * (hueRange * 2.0);
        h += 1.0 - (hueRotation / 360.0);
        h = fract(h);
        float s = g;
        float v = b;
        col = hsv2rgb(vec3(h, s, v));
    }
    fragColor = vec4(col, 1.0);
}


