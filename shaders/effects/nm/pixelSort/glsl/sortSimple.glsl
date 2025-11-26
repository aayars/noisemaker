#version 300 es
precision highp float;
precision highp int;

// Pixel sort: For each output pixel, find which input pixel should go here
// after sorting and alignment (brightest pixel stays at its original position).
// O(n) per pixel by caching luminances in first pass, O(n) for rank computation.

uniform sampler2D inputTex;

out vec4 fragColor;

// Oklab luminance for perceptually correct brightness comparison
float srgb_to_lin(float value) {
    if (value <= 0.04045) {
        return value / 12.92;
    }
    return pow((value + 0.055) / 1.055, 2.4);
}

float oklab_l(vec3 rgb) {
    float r = srgb_to_lin(clamp(rgb.r, 0.0, 1.0));
    float g = srgb_to_lin(clamp(rgb.g, 0.0, 1.0));
    float b = srgb_to_lin(clamp(rgb.b, 0.0, 1.0));
    
    float l = 0.4121656120 * r + 0.5362752080 * g + 0.0514575653 * b;
    float m = 0.2118591070 * r + 0.6807189584 * g + 0.1074065790 * b;
    float s = 0.0883097947 * r + 0.2818474174 * g + 0.6302613616 * b;
    
    float l_c = pow(abs(l), 1.0 / 3.0);
    float m_c = pow(abs(m), 1.0 / 3.0);
    float s_c = pow(abs(s), 1.0 / 3.0);
    
    return 0.2104542553 * l_c + 0.7936177850 * m_c - 0.0040720468 * s_c;
}

void main() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    ivec2 size = textureSize(inputTex, 0);
    int x = coord.x;
    int y = coord.y;
    int width = size.x;
    
    // Single pass through row: collect luminances and find brightest
    // We need luminances for rank computation anyway
    float maxLum = -1.0;
    int brightestX = 0;
    
    // Store all luminances for this row - compute ranks from these
    // WebGL2 doesn't allow variable-length arrays, but we can iterate twice
    // First pass: find brightest and compute target sorted index
    for (int i = 0; i < width; i++) {
        vec4 texel = texelFetch(inputTex, ivec2(i, y), 0);
        float lum = oklab_l(texel.rgb);
        if (lum > maxLum) {
            maxLum = lum;
            brightestX = i;
        }
    }
    
    // Target sorted index for output position x
    int sortedIndex = (x - brightestX + width) % width;
    
    // Second pass: find which pixel has rank == sortedIndex
    // Rank = number of pixels brighter than this one
    vec4 result = vec4(0.0);
    
    for (int i = 0; i < width; i++) {
        vec4 texel = texelFetch(inputTex, ivec2(i, y), 0);
        float lum = oklab_l(texel.rgb);
        
        // Count brighter pixels to determine rank
        int rank = 0;
        for (int j = 0; j < width; j++) {
            if (j == i) continue;
            vec4 other = texelFetch(inputTex, ivec2(j, y), 0);
            float otherLum = oklab_l(other.rgb);
            if (otherLum > lum || (otherLum == lum && j < i)) {
                rank++;
            }
        }
        
        if (rank == sortedIndex) {
            result = texel;
            break;
        }
    }
    
    fragColor = result;
}
