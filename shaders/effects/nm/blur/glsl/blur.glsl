#version 300 es
precision highp float;
precision highp int;

// Blur effect: downsample then upsample with interpolation
// This is the downsample pass - averages blocks of input pixels
// The downsample size is resolution/amount, creating a coarse buffer

uniform sampler2D inputTex;
uniform float amount;
uniform float splineOrder;
uniform vec2 resolution;

out vec4 fragColor;

void main() {
    ivec2 inputSize = textureSize(inputTex, 0);
    
    // Compute downsample target size based on amount
    // Higher amount = smaller downsample = more blur
    float blurAmount = max(amount, 1.0);
    ivec2 outputSize = ivec2(
        max(1, int(float(inputSize.x) / blurAmount)),
        max(1, int(float(inputSize.y) / blurAmount))
    );
    
    // But we're rendering to 64x64 viewport, so we need to map our output
    // coordinate to the conceptual downsample grid
    ivec2 viewportSize = ivec2(64, 64);
    ivec2 outCoord = ivec2(gl_FragCoord.xy);
    
    // Early exit if outside the actual downsample region
    if (outCoord.x >= outputSize.x || outCoord.y >= outputSize.y) {
        fragColor = vec4(0.0);
        return;
    }
    
    // Calculate the block size for averaging
    int blockWidth = max(1, int(ceil(float(inputSize.x) / float(outputSize.x))));
    int blockHeight = max(1, int(ceil(float(inputSize.y) / float(outputSize.y))));
    
    // Starting position in input
    int startX = outCoord.x * blockWidth;
    int startY = outCoord.y * blockHeight;
    
    // Average the block
    vec4 sum = vec4(0.0);
    int count = 0;
    
    for (int dy = 0; dy < blockHeight && startY + dy < inputSize.y; dy++) {
        for (int dx = 0; dx < blockWidth && startX + dx < inputSize.x; dx++) {
            ivec2 samplePos = ivec2(startX + dx, startY + dy);
            sum += texelFetch(inputTex, samplePos, 0);
            count++;
        }
    }
    
    if (count > 0) {
        fragColor = sum / float(count);
    } else {
        fragColor = vec4(0.0);
    }
}
