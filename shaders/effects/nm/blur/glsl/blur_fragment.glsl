#version 300 es
precision highp float;

uniform sampler2D inputTex;
uniform float amount;
uniform float splineOrder;

out vec4 fragColor;

int wrapIndex(int value, int limit) {
    if (limit <= 0) return 0;
    int wrapped = value % limit;
    if (wrapped < 0) wrapped += limit;
    return wrapped;
}

void main() {
    ivec2 dims = textureSize(inputTex, 0);
    int width = dims.x;
    int height = dims.y;
    
    if (width <= 0 || height <= 0) {
        fragColor = vec4(0.0);
        return;
    }
    
    ivec2 coord = ivec2(gl_FragCoord.xy);
    
    // Calculate blur radius from amount (clamped to reasonable range)
    int radius = max(1, min(int(amount), 32));
    
    // Box blur - average pixels in a square kernel
    vec4 accum = vec4(0.0);
    float count = 0.0;
    
    for (int dy = -radius; dy <= radius; dy++) {
        for (int dx = -radius; dx <= radius; dx++) {
            int sampleX = wrapIndex(coord.x + dx, width);
            int sampleY = wrapIndex(coord.y + dy, height);
            accum += texelFetch(inputTex, ivec2(sampleX, sampleY), 0);
            count += 1.0;
        }
    }
    
    if (count <= 0.0) {
        fragColor = texelFetch(inputTex, coord, 0);
        return;
    }
    
    fragColor = accum / count;
}
