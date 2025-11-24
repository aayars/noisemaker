#version 300 es
precision highp float;

uniform sampler2D inputTex; // prepared (for width)
uniform sampler2D statsTex;
uniform sampler2D cumulativeTex;

out vec4 fragColor;

void main() {
    ivec2 texSize = textureSize(inputTex, 0);
    int width = texSize.x;
    int y = int(gl_FragCoord.y);
    int x = int(gl_FragCoord.x);
    
    // 1. Get shift
    vec4 stats = texelFetch(statsTex, ivec2(0, y), 0);
    int brightestIndex = int(stats.r * float(width));
    int shift = width - brightestIndex;
    if (shift == width) shift = 0;
    
    // 2. Calculate rank k
    // The pixel at 'x' in the sorted buffer comes from rank 'k'
    int k = (x - shift + width) % width;
    
    // 3. Find bucket for rank k
    vec4 resultColor = vec4(0.0);
    
    // For each channel
    for (int c = 0; c < 4; c++) {
        int foundBucket = 255;
        for (int i = 0; i < 256; i++) {
            vec4 startPos = texelFetch(cumulativeTex, ivec2(i, y), 0);
            float start = (c==0) ? startPos.r : (c==1) ? startPos.g : (c==2) ? startPos.b : startPos.a;
            
            float end;
            if (i < 255) {
                vec4 nextStart = texelFetch(cumulativeTex, ivec2(i+1, y), 0);
                end = (c==0) ? nextStart.r : (c==1) ? nextStart.g : (c==2) ? nextStart.b : nextStart.a;
            } else {
                end = float(width);
            }
            
            if (float(k) >= start && float(k) < end) {
                foundBucket = i;
                break;
            }
        }
        
        float val = float(foundBucket) / 255.0;
        if (c==0) resultColor.r = val;
        else if (c==1) resultColor.g = val;
        else if (c==2) resultColor.b = val;
        else resultColor.a = val;
    }
    
    fragColor = resultColor;
}
