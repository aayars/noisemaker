#version 300 es
precision highp float;
precision highp int;

uniform sampler2D inputTex;
out vec4 fragColor;

void main() {
    ivec2 size = textureSize(inputTex, 0);
    float minVal = 100000.0;
    float maxVal = -100000.0;

    // Sample a grid of points to estimate min/max
    // This avoids TDR (Timeout Detection and Recovery) on some drivers
    // We use a fixed number of samples to keep performance predictable
    const int SAMPLES_X = 64;
    const int SAMPLES_Y = 64;
    
    for (int y = 0; y < SAMPLES_Y; y++) {
        for (int x = 0; x < SAMPLES_X; x++) {
            // Map grid to texture coordinates
            int texX = int(float(x) / float(SAMPLES_X - 1) * float(size.x - 1));
            int texY = int(float(y) / float(SAMPLES_Y - 1) * float(size.y - 1));
            
            vec4 color = texelFetch(inputTex, ivec2(texX, texY), 0);
            
            float pixelMin = min(min(color.r, color.g), color.b);
            float pixelMax = max(max(color.r, color.g), color.b);
            
            minVal = min(minVal, pixelMin);
            maxVal = max(maxVal, pixelMax);
        }
    }
    
    fragColor = vec4(minVal, maxVal, 0.0, 1.0);
}
