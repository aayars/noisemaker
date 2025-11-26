#version 300 es
precision highp float;
precision highp int;

// GPGPU Pass 4: Gather sorted pixels with alignment
// Input: prepared texture (original colors), rank texture, brightest texture
// Output: Sorted row with brightest pixel aligned to its original position

uniform sampler2D preparedTex;  // Original rotated/prepared image
uniform sampler2D rankTex;      // R = rank, B = original x
uniform sampler2D brightestTex; // R = brightest x per row

out vec4 fragColor;

void main() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    ivec2 size = textureSize(preparedTex, 0);
    int x = coord.x;
    int y = coord.y;
    int width = size.x;
    
    // Get brightest x for this row
    float brightestXNorm = texelFetch(brightestTex, ivec2(0, y), 0).r;
    int brightestX = int(round(brightestXNorm * float(width - 1)));
    
    // Python algorithm:
    // sortedIndex = (x - brightestX + width) % width
    // Output position x gets the pixel whose rank == sortedIndex
    int sortedIndex = (x - brightestX + width) % width;
    
    // Find the pixel in this row whose rank matches sortedIndex
    vec4 result = vec4(0.0);
    
    for (int i = 0; i < width; i++) {
        vec4 rankData = texelFetch(rankTex, ivec2(i, y), 0);
        int pixelRank = int(round(rankData.r * float(width - 1)));
        
        if (pixelRank == sortedIndex) {
            // Found it - fetch the original color
            result = texelFetch(preparedTex, ivec2(i, y), 0);
            break;
        }
    }
    
    fragColor = result;
}
