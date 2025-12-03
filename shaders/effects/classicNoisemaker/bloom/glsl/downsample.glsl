#version 300 es
precision highp float;

// Bloom downsample pass - averages pixels into a smaller grid with highlight boost
// This is the first pass of the bloom effect, matching the WGSL downsample_main

uniform sampler2D inputTex;
uniform vec2 resolution;      // Full resolution
uniform vec2 downsampleSize;  // Target downsample resolution

out vec4 fragColor;

const float BOOST = 4.0;

void main() {
    // Current pixel in downsample space
    ivec2 downCoord = ivec2(gl_FragCoord.xy);
    ivec2 downSize = ivec2(downsampleSize);
    ivec2 fullSize = ivec2(resolution);
    
    // Early out if outside downsample bounds
    if (downCoord.x >= downSize.x || downCoord.y >= downSize.y) {
        fragColor = vec4(0.0);
        return;
    }
    
    // Calculate kernel size - how many source pixels per downsample cell
    int kernelWidth = max((fullSize.x + downSize.x - 1) / downSize.x, 1);
    int kernelHeight = max((fullSize.y + downSize.y - 1) / downSize.y, 1);
    
    // Origin in full resolution space
    int originX = downCoord.x * kernelWidth;
    int originY = downCoord.y * kernelHeight;
    
    // Accumulate pixel values
    vec3 accum = vec3(0.0);
    float sampleCount = 0.0;
    
    for (int ky = 0; ky < kernelHeight; ky++) {
        int sampleY = originY + ky;
        if (sampleY >= fullSize.y) break;
        
        for (int kx = 0; kx < kernelWidth; kx++) {
            int sampleX = originX + kx;
            if (sampleX >= fullSize.x) break;
            
            vec3 texel = texelFetch(inputTex, ivec2(sampleX, sampleY), 0).rgb;
            // Extract highlights - clamp and accumulate
            vec3 highlight = clamp(texel, 0.0, 1.0);
            accum += highlight;
            sampleCount += 1.0;
        }
    }
    
    if (sampleCount <= 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    
    // Average and boost
    vec3 average = accum / sampleCount;
    vec3 boosted = average * BOOST;
    
    // Store boosted color and sample count in alpha for later use
    fragColor = vec4(boosted, sampleCount);
}
