#version 300 es
precision highp float;
precision highp int;

// GPGPU Pass 2: Find brightest pixel x-coordinate per row
// Input: luminance texture (R = luminance)
// Output: R = brightest x (normalized), G = max luminance, B = 0, A = 1
// This pass uses horizontal reduction - each pixel outputs info about its row

uniform sampler2D lumTex;

out vec4 fragColor;

void main() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    ivec2 size = textureSize(lumTex, 0);
    int y = coord.y;
    int width = size.x;
    
    // Find brightest pixel in this row
    float maxLum = -1.0;
    int brightestX = 0;
    
    for (int i = 0; i < width; i++) {
        float lum = texelFetch(lumTex, ivec2(i, y), 0).r;
        if (lum > maxLum) {
            maxLum = lum;
            brightestX = i;
        }
    }
    
    // Output: normalized brightest x, max luminance
    fragColor = vec4(float(brightestX) / float(width - 1), maxLum, 0.0, 1.0);
}
