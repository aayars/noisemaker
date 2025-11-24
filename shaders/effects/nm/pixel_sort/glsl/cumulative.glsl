#version 300 es
precision highp float;

uniform sampler2D inputTex; // histogram

out vec4 fragColor;

void main() {
    int y = int(gl_FragCoord.y);
    int bucket = int(gl_FragCoord.x);
    
    vec4 sum = vec4(0.0);
    
    // Sum from 0 to bucket-1 (exclusive prefix sum)
    for (int i = 0; i < bucket; i++) {
        vec4 count = texelFetch(inputTex, ivec2(i, y), 0);
        sum += count;
    }
    
    fragColor = sum;
}
