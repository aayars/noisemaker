#version 300 es
precision highp float;

// Bloom upsample pass - bicubic interpolates the downsampled data and blends with original
// This is the second pass of the bloom effect, matching the WGSL upsample_main

uniform sampler2D inputTex;      // Original full-res image
uniform sampler2D downsampleBuffer; // Output from downsample pass
uniform vec2 resolution;          // Full resolution
uniform vec2 downsampleSize;      // Size of downsampled texture
uniform float bloomAlpha;         // Bloom blend amount (0-1)

out vec4 fragColor;

const float BRIGHTNESS_ADJUST = 0.25;
const float CONTRAST_SCALE = 1.5;

vec3 clamp01(vec3 v) {
    return clamp(v, vec3(0.0), vec3(1.0));
}

vec3 clamp11(vec3 v) {
    return clamp(v, vec3(-1.0), vec3(1.0));
}

int wrapIndex(int value, int limit) {
    if (limit <= 0) return 0;
    int wrapped = value - (value / limit) * limit;
    if (wrapped < 0) wrapped += limit;
    return wrapped;
}

// Sample downsampled texture with wrap
vec4 readCompressedCell(ivec2 coord, ivec2 downSize) {
    int safeX = wrapIndex(coord.x, downSize.x);
    int safeY = wrapIndex(coord.y, downSize.y);
    return texelFetch(downsampleBuffer, ivec2(safeX, safeY), 0);
}

// Cubic interpolation for vec3
vec3 cubicInterpolateVec3(vec3 a, vec3 b, vec3 c, vec3 d, float t) {
    float t2 = t * t;
    float t3 = t2 * t;
    vec3 a0 = d - c - a + b;
    vec3 a1 = a - b - a0;
    vec3 a2 = c - a;
    vec3 a3 = b;
    return ((a0 * t3) + (a1 * t2)) + (a2 * t) + a3;
}

void main() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    ivec2 fullSize = ivec2(resolution);
    ivec2 downSize = ivec2(downsampleSize);
    
    // Get original pixel
    vec4 original = texelFetch(inputTex, coord, 0);
    float alpha = clamp(bloomAlpha, 0.0, 1.0);
    
    // Early return if no bloom
    if (alpha <= 0.0) {
        fragColor = vec4(clamp01(original.rgb), original.a);
        return;
    }
    
    // Calculate sample position in downsample space
    vec2 samplePos = vec2(
        (float(coord.x) + 0.5) / float(fullSize.x) * float(downSize.x),
        (float(coord.y) + 0.5) / float(fullSize.y) * float(downSize.y)
    );
    
    ivec2 baseFloor = ivec2(
        clamp(int(floor(samplePos.x)), 0, downSize.x - 1),
        clamp(int(floor(samplePos.y)), 0, downSize.y - 1)
    );
    vec2 frac = vec2(
        clamp(samplePos.x - float(baseFloor.x), 0.0, 1.0),
        clamp(samplePos.y - float(baseFloor.y), 0.0, 1.0)
    );
    
    // Sample 4x4 grid for bicubic interpolation
    int sampleX[4];
    sampleX[0] = wrapIndex(baseFloor.x - 1, downSize.x);
    sampleX[1] = baseFloor.x;
    sampleX[2] = wrapIndex(baseFloor.x + 1, downSize.x);
    sampleX[3] = wrapIndex(baseFloor.x + 2, downSize.x);
    
    int sampleY[4];
    sampleY[0] = wrapIndex(baseFloor.y - 1, downSize.y);
    sampleY[1] = baseFloor.y;
    sampleY[2] = wrapIndex(baseFloor.y + 1, downSize.y);
    sampleY[3] = wrapIndex(baseFloor.y + 2, downSize.y);
    
    vec3 rows[4];
    for (int j = 0; j < 4; j++) {
        vec3 samples[4];
        for (int i = 0; i < 4; i++) {
            vec4 cell = readCompressedCell(ivec2(sampleX[i], sampleY[j]), downSize);
            samples[i] = cell.rgb;
        }
        rows[j] = cubicInterpolateVec3(samples[0], samples[1], samples[2], samples[3], frac.x);
    }
    
    vec3 boostedSample = cubicInterpolateVec3(rows[0], rows[1], rows[2], rows[3], frac.y);
    vec3 brightenedPixel = clamp11(boostedSample + vec3(BRIGHTNESS_ADJUST));
    
    // Calculate global mean for contrast adjustment (matching WGSL)
    vec3 brightSum = vec3(0.0);
    float totalWeight = 0.0;
    for (int y = 0; y < downSize.y; y++) {
        for (int x = 0; x < downSize.x; x++) {
            vec4 cell = readCompressedCell(ivec2(x, y), downSize);
            if (cell.a <= 0.0) continue;
            vec3 brightenedCell = clamp11(cell.rgb + vec3(BRIGHTNESS_ADJUST));
            brightSum += brightenedCell * cell.a;
            totalWeight += cell.a;
        }
    }
    
    vec3 globalMean = brightenedPixel;
    if (totalWeight > 0.0) {
        globalMean = brightSum / totalWeight;
    }
    
    // Apply contrast adjustment
    vec3 contrasted = (brightenedPixel - globalMean) * CONTRAST_SCALE + globalMean;
    vec3 blurred = clamp01(contrasted);
    
    // Blend with original
    vec3 sourceClamped = clamp01(original.rgb);
    vec3 mixed = clamp01((sourceClamped + blurred) * 0.5);
    vec3 finalRgb = clamp01(sourceClamped * (1.0 - alpha) + mixed * alpha);
    
    fragColor = vec4(finalRgb, original.a);
}
