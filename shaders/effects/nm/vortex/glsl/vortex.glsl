#version 300 es

precision highp float;
precision highp int;

// Vortex effect - creates swirling distortion from center

uniform sampler2D inputTex;
uniform float time;
uniform float speed;
uniform float displacement;

in vec2 v_texCoord;
out vec4 fragColor;

const float TAU = 6.28318530717959;

// Simple noise
float hash21(vec2 p) {
    float h = dot(p, vec2(127.1, 311.7));
    return fract(sin(h) * 43758.5453123);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float simplex_random(float t, float spd) {
    float angle = t * TAU;
    float z = cos(angle) * spd;
    float w = sin(angle) * spd;
    float n = noise(vec2(z + 17.0, w + 29.0));
    return clamp(n, 0.0, 1.0);
}

void main() {
    vec2 dims = vec2(textureSize(inputTex, 0));
    
    // Get centered coordinates
    vec2 center = vec2(0.5);
    vec2 toCenter = v_texCoord - center;
    float dist = length(toCenter);
    float angle = atan(toCenter.y, toCenter.x);
    
    // Fade based on Chebyshev distance from center
    vec2 absOffset = abs(toCenter);
    float fade = 1.0 - max(absOffset.x, absOffset.y) * 2.0;
    fade = clamp(fade, 0.0, 1.0);
    
    // Random factor for displacement amount
    float randomFactor = simplex_random(time * 0.1, speed);
    float warpAmount = randomFactor * displacement * 0.5;
    
    // Create vortex rotation based on distance
    float rotationAmount = warpAmount * (1.0 - dist) * TAU;
    float newAngle = angle + rotationAmount * fade;
    
    // Convert back to UV coordinates
    vec2 sampleCoord = center + vec2(cos(newAngle), sin(newAngle)) * dist;
    
    // Wrap coordinates
    sampleCoord = fract(sampleCoord);
    
    vec4 sampled = texture(inputTex, sampleCoord);
    
    fragColor = sampled;
}
