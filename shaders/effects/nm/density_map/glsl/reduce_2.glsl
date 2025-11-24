#version 300 es
precision highp float;
precision highp int;

uniform sampler2D input_texture;

out vec4 fragColor;

void main() {
    if (gl_FragCoord.x >= 1.0 || gl_FragCoord.y >= 1.0) {
        fragColor = vec4(0.0);
        return;
    }
    
    float min_val = 1e30;
    float max_val = -1e30;
    
    for (int y = 0; y < 32; y++) {
        for (int x = 0; x < 32; x++) {
            vec4 texel = texelFetch(input_texture, ivec2(x, y), 0);
            // texel.r is min, texel.g is max
            min_val = min(min_val, texel.r);
            max_val = max(max_val, texel.g);
        }
    }
    
    if (min_val > max_val) {
        min_val = 0.0;
        max_val = 0.0;
    }
    
    fragColor = vec4(min_val, max_val, 0.0, 1.0);
}
