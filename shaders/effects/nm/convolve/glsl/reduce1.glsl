#version 300 es
precision highp float;
precision highp int;

uniform sampler2D inputTex;

out vec4 fragColor;

void main() {
    if (gl_FragCoord.x >= 32.0 || gl_FragCoord.y >= 32.0) {
        fragColor = vec4(0.0);
        return;
    }
    
    ivec2 texSize = textureSize(inputTex, 0);
    float width = float(texSize.x);
    float height = float(texSize.y);
    
    float block_w = width / 32.0;
    float block_h = height / 32.0;
    
    int start_x = int(floor(gl_FragCoord.x * block_w));
    int start_y = int(floor(gl_FragCoord.y * block_h));
    int end_x = int(floor((gl_FragCoord.x + 1.0) * block_w));
    int end_y = int(floor((gl_FragCoord.y + 1.0) * block_h));
    
    // Clamp to texture size
    end_x = min(end_x, texSize.x);
    end_y = min(end_y, texSize.y);
    
    float min_val = 1e30;
    float max_val = -1e30;
    
    // Always process RGB channels (textures are always RGBA per AGENTS.md)
    
    for (int y = start_y; y < end_y; y++) {
        for (int x = start_x; x < end_x; x++) {
            vec4 texel = texelFetch(inputTex, ivec2(x, y), 0);
            
            // Process RGB channels
            min_val = min(min_val, texel.r);
            max_val = max(max_val, texel.r);
            min_val = min(min_val, texel.g);
            max_val = max(max_val, texel.g);
            min_val = min(min_val, texel.b);
            max_val = max(max_val, texel.b);
        }
    }
    
    if (min_val > max_val) {
        min_val = 0.0;
        max_val = 0.0;
    }
    
    fragColor = vec4(min_val, max_val, 0.0, 1.0);
}
