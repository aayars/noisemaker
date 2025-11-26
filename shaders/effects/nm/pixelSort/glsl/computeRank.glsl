#version 300 es
precision highp float;
precision highp int;

// GPGPU Pass 3: Compute rank for each pixel
// Input: luminance texture (R = luminance)
// Output: R = rank (normalized), G = luminance, B = original x, A = 1

uniform sampler2D lumTex;

out vec4 fragColor;

void main() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    ivec2 size = textureSize(lumTex, 0);
    int x = coord.x;
    int y = coord.y;
    int width = size.x;
    
    float myLum = texelFetch(lumTex, coord, 0).r;
    
    // Count how many pixels in this row are brighter (have lower rank)
    int rank = 0;
    for (int i = 0; i < width; i++) {
        if (i == x) continue;
        float otherLum = texelFetch(lumTex, ivec2(i, y), 0).r;
        // Brighter = lower rank; tie-breaker: lower index wins
        if (otherLum > myLum || (otherLum == myLum && i < x)) {
            rank++;
        }
    }
    
    // Output: rank (normalized), luminance, original x (normalized)
    fragColor = vec4(float(rank) / float(width - 1), myLum, float(x) / float(width - 1), 1.0);
}
