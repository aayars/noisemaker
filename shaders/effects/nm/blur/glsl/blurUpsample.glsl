#version 300 es
precision highp float;
precision highp int;

// Blur upsample pass - reads from downsampled texture and interpolates to full resolution
// The downsample size is computed based on amount, matching the downsample pass

uniform sampler2D downsampleTex;
uniform sampler2D inputTex;  // Need original input to get actual resolution
uniform float amount;
uniform float splineOrder;
uniform vec2 resolution;

out vec4 fragColor;

const float PI = 3.14159265358979323846;

float interpolationWeight(float value, int order) {
    if (order == 2) { // Cosine
        float clamped = clamp(value, 0.0, 1.0);
        return (1.0 - cos(clamped * PI)) * 0.5;
    }
    return clamp(value, 0.0, 1.0); // Linear
}

// Cubic interpolation weights (Catmull-Rom)
float cubicWeight(float t, int index) {
    float t2 = t * t;
    float t3 = t2 * t;
    if (index == 0) return -0.5 * t3 + t2 - 0.5 * t;
    if (index == 1) return 1.5 * t3 - 2.5 * t2 + 1.0;
    if (index == 2) return -1.5 * t3 + 2.0 * t2 + 0.5 * t;
    return 0.5 * t3 - 0.5 * t2; // index == 3
}

vec4 readDownsample(ivec2 coord, ivec2 downSize) {
    int safeX = coord.x % downSize.x;
    if (safeX < 0) safeX += downSize.x;
    int safeY = coord.y % downSize.y;
    if (safeY < 0) safeY += downSize.y;
    return texelFetch(downsampleTex, ivec2(safeX, safeY), 0);
}

void main() {
    // Get the actual input size
    ivec2 inputSize = textureSize(inputTex, 0);
    ivec2 outSize = inputSize;
    
    // Compute downsample size based on amount (matching downsample pass)
    float blurAmount = max(amount, 1.0);
    ivec2 downSize = ivec2(
        max(1, int(float(inputSize.x) / blurAmount)),
        max(1, int(float(inputSize.y) / blurAmount))
    );
    
    ivec2 coord = ivec2(gl_FragCoord.xy);
    
    // Map output coordinate to downsample space
    float scaleX = float(downSize.x) / float(outSize.x);
    float scaleY = float(downSize.y) / float(outSize.y);
    
    float srcX = float(coord.x) * scaleX;
    float srcY = float(coord.y) * scaleY;
    
    int baseX = int(floor(srcX));
    int baseY = int(floor(srcY));
    
    float fracX = srcX - float(baseX);
    float fracY = srcY - float(baseY);
    
    int order = int(splineOrder);
    
    if (order == 0) {
        // Constant - nearest neighbor
        fragColor = readDownsample(ivec2(baseX, baseY), downSize);
    } else if (order == 3) {
        // Bicubic interpolation (Catmull-Rom)
        vec4 result = vec4(0.0);
        for (int j = 0; j < 4; j++) {
            for (int i = 0; i < 4; i++) {
                vec4 sample = readDownsample(ivec2(baseX + i - 1, baseY + j - 1), downSize);
                float weight = cubicWeight(fracX, i) * cubicWeight(fracY, j);
                result += sample * weight;
            }
        }
        fragColor = result;
    } else {
        // Linear/Cosine interpolation (order 1 or 2)
        vec4 tl = readDownsample(ivec2(baseX, baseY), downSize);
        vec4 tr = readDownsample(ivec2(baseX + 1, baseY), downSize);
        vec4 bl = readDownsample(ivec2(baseX, baseY + 1), downSize);
        vec4 br = readDownsample(ivec2(baseX + 1, baseY + 1), downSize);
        
        float wx = interpolationWeight(fracX, order);
        float wy = interpolationWeight(fracY, order);
        
        vec4 top = mix(tl, tr, wx);
        vec4 bottom = mix(bl, br, wx);
        fragColor = mix(top, bottom, wy);
    }
}
