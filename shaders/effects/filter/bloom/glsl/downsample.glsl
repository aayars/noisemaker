/*
 * Bloom downsample pass
 * Averages pixels into a smaller grid with highlight boost
 */

#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D inputTex;

out vec4 fragColor;

const float BOOST = 4.0;
const ivec2 DOWNSAMPLE_SIZE = ivec2(64, 64);

void main() {
    ivec2 downCoord = ivec2(gl_FragCoord.xy);
    ivec2 fullSize = textureSize(inputTex, 0);
    
    // Early out if outside downsample bounds
    if (downCoord.x >= DOWNSAMPLE_SIZE.x || downCoord.y >= DOWNSAMPLE_SIZE.y) {
        fragColor = vec4(0.0);
        return;
    }
    
    // Calculate kernel size - how many source pixels per downsample cell
    int kernelWidth = max((fullSize.x + DOWNSAMPLE_SIZE.x - 1) / DOWNSAMPLE_SIZE.x, 1);
    int kernelHeight = max((fullSize.y + DOWNSAMPLE_SIZE.y - 1) / DOWNSAMPLE_SIZE.y, 1);
    
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
    
    fragColor = vec4(boosted, sampleCount);
}
