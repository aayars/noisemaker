#version 300 es

precision highp float;
precision highp int;

// Kaleido - creates kaleidoscope mirror effect by reflecting the source texture into wedge slices.

const float PI = 3.14159265358979323846;
const float TAU = 6.28318530717958647692;

uniform sampler2D inputTex;
uniform float sides;
uniform float blendEdges;
uniform float sdfSides;

out vec4 fragColor;

float positive_mod(float value, float modulus) {
    if (modulus == 0.0) {
        return 0.0;
    }
    float result = value - floor(value / modulus) * modulus;
    if (result < 0.0) {
        result = result + modulus;
    }
    return result;
}

void main() {
    ivec2 dimensions = textureSize(inputTex, 0);
    vec2 uv = gl_FragCoord.xy / vec2(dimensions);
    
    // Convert to centered coordinates (-0.5 to 0.5)
    vec2 centered = uv - 0.5;
    
    // Compute polar coordinates
    float radius = length(centered) * 2.0;  // Scale so edge is at 1.0
    float angle = atan(centered.y, centered.x) + PI;  // 0 to TAU
    
    // Number of sides for the kaleidoscope
    float numSides = max(sides, 2.0);
    float angleStep = TAU / numSides;
    
    // Fold the angle into one wedge
    float wedgeAngle = mod(angle, angleStep);
    
    // Mirror within the wedge (reflect at half-wedge boundary)
    if (wedgeAngle > angleStep * 0.5) {
        wedgeAngle = angleStep - wedgeAngle;
    }
    
    // Reconstruct UV from modified polar coordinates
    float newAngle = wedgeAngle - angleStep * 0.5;
    vec2 newCentered = vec2(cos(newAngle), sin(newAngle)) * radius * 0.5;
    vec2 newUV = newCentered + 0.5;
    
    // Optional edge blending
    if (blendEdges > 0.5) {
        float edge = max(abs(centered.x), abs(centered.y)) * 2.0;
        float fade = pow(clamp(edge, 0.0, 1.0), 5.0);
        newUV = mix(newUV, uv, fade);
    }
    
    // Clamp UV to valid range
    newUV = clamp(newUV, 0.0, 1.0);
    
    vec4 color = texture(inputTex, newUV);
    fragColor = color;
}
