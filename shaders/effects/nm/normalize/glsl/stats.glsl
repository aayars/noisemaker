#version 300 es
precision highp float;
precision highp int;

uniform sampler2D inputTex;
out vec4 fragColor;

void main() {
    ivec2 size = textureSize(inputTex, 0);
    float minVal = 100000.0;
    float maxVal = -100000.0;

    // Sample a 24x24 grid of points to estimate min/max
    // 576 samples is a good balance between accuracy and performance
    const int SAMPLES = 24;
    
    for (int y = 0; y < SAMPLES; y++) {
        for (int x = 0; x < SAMPLES; x++) {
            // Map grid to texture coordinates
            int texX = (x * (size.x - 1)) / (SAMPLES - 1);
            int texY = (y * (size.y - 1)) / (SAMPLES - 1);
            
            vec4 color = texelFetch(inputTex, ivec2(texX, texY), 0);
            
            float pixelMin = min(min(color.r, color.g), color.b);
            float pixelMax = max(max(color.r, color.g), color.b);
            
            minVal = min(minVal, pixelMin);
            maxVal = max(maxVal, pixelMax);
        }
    }
    
    fragColor = vec4(minVal, maxVal, 0.0, 1.0);
}
