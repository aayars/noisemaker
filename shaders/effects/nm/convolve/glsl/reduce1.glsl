#version 300 es
precision highp float;
precision highp int;

uniform sampler2D inputTex;
uniform vec4 size; // width, height, channelCount, 0

out vec4 fragColor;

void main() {
    if (gl_FragCoord.x >= 32.0 || gl_FragCoord.y >= 32.0) {
        fragColor = vec4(0.0);
        return;
    }
    
    float width = size.x;
    float height = size.y;
    
    float block_w = width / 32.0;
    float block_h = height / 32.0;
    
    int start_x = int(floor(gl_FragCoord.x * block_w));
    int start_y = int(floor(gl_FragCoord.y * block_h));
    int end_x = int(floor((gl_FragCoord.x + 1.0) * block_w));
    int end_y = int(floor((gl_FragCoord.y + 1.0) * block_h));
    
    // Clamp to texture size
    end_x = min(end_x, int(width));
    end_y = min(end_y, int(height));
    
    float min_val = 1e30;
    float max_val = -1e30;
    
    uint channelCount = uint(size.z);
    
    for (int y = start_y; y < end_y; y++) {
        for (int x = start_x; x < end_x; x++) {
            vec4 texel = texelFetch(inputTex, ivec2(x, y), 0);
            
            min_val = min(min_val, texel.r);
            max_val = max(max_val, texel.r);
            
            if (channelCount >= 2u) {
                min_val = min(min_val, texel.g);
                max_val = max(max_val, texel.g);
            }
            if (channelCount >= 3u) {
                min_val = min(min_val, texel.b);
                max_val = max(max_val, texel.b);
            }
            if (channelCount >= 4u) {
                min_val = min(min_val, texel.a);
                max_val = max(max_val, texel.a);
            }
        }
    }
    
    if (min_val > max_val) {
        min_val = 0.0;
        max_val = 0.0;
    }
    
    fragColor = vec4(min_val, max_val, 0.0, 1.0);
}
