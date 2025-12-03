#version 300 es
precision highp float;
precision highp int;

// Blur effect: downsample pass
// Renders to a 64x64 buffer, averaging blocks from the input
// Higher amount = more blur by averaging larger blocks

uniform sampler2D inputTex;
uniform float amount;
uniform float splineOrder;
uniform vec2 resolution;

out vec4 fragColor;

void main() {
    ivec2 inputSize = textureSize(inputTex, 0);
    ivec2 outputSize = ivec2(64, 64); // Fixed downsample buffer size
    
    ivec2 outCoord = ivec2(gl_FragCoord.xy);
    
    // Each output pixel represents a region of input pixels
    // Map output coord to input space center
    float inputX = (float(outCoord.x) + 0.5) / float(outputSize.x) * float(inputSize.x);
    float inputY = (float(outCoord.y) + 0.5) / float(outputSize.y) * float(inputSize.y);
    
    // Block size determines how much we average (blur radius)
    // amount=10 should give visible blur
    int blockRadius = max(1, int(amount * 0.5));
    
    // Average the block around this position
    vec4 sum = vec4(0.0);
    int count = 0;
    
    int centerX = int(inputX);
    int centerY = int(inputY);
    
    for (int dy = -blockRadius; dy <= blockRadius; dy++) {
        for (int dx = -blockRadius; dx <= blockRadius; dx++) {
            int sampleX = clamp(centerX + dx, 0, inputSize.x - 1);
            int sampleY = clamp(centerY + dy, 0, inputSize.y - 1);
            sum += texelFetch(inputTex, ivec2(sampleX, sampleY), 0);
            count++;
        }
    }
    
    fragColor = sum / float(count);
}
