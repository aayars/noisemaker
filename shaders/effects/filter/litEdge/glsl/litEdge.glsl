/*
 * Lit edge detection effect
 * Combines edge detection with original image for lit edges
 */

#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D inputTex;
uniform float amount;

out vec4 fragColor;

void main() {
    ivec2 texSize = textureSize(inputTex, 0);
    vec2 resolution = vec2(texSize);
    vec2 uv = gl_FragCoord.xy / resolution;
    vec2 texelSize = 1.0 / resolution;
    
    vec4 origColor = texture(inputTex, uv);
    
    // Edge detection kernel (edge2)
    // -1  0 -1
    //  0  4  0
    // -1  0 -1
    float kernel[9];
    kernel[0] = -1.0; kernel[1] = 0.0; kernel[2] = -1.0;
    kernel[3] = 0.0;  kernel[4] = 4.0; kernel[5] = 0.0;
    kernel[6] = -1.0; kernel[7] = 0.0; kernel[8] = -1.0;
    
    vec2 offsets[9];
    offsets[0] = vec2(-texelSize.x, -texelSize.y);
    offsets[1] = vec2(0.0, -texelSize.y);
    offsets[2] = vec2(texelSize.x, -texelSize.y);
    offsets[3] = vec2(-texelSize.x, 0.0);
    offsets[4] = vec2(0.0, 0.0);
    offsets[5] = vec2(texelSize.x, 0.0);
    offsets[6] = vec2(-texelSize.x, texelSize.y);
    offsets[7] = vec2(0.0, texelSize.y);
    offsets[8] = vec2(texelSize.x, texelSize.y);
    
    vec3 conv = vec3(0.0);
    float kernelWeight = 0.0;
    
    for (int i = 0; i < 9; i++) {
        vec3 texSample = texture(inputTex, uv + offsets[i] * amount).rgb;
        conv += texSample * kernel[i];
        kernelWeight += kernel[i];
    }
    
    if (kernelWeight != 0.0) {
        conv /= kernelWeight;
    }
    
    // Lit edge: max of original and edge
    vec3 result = max(origColor.rgb, clamp(conv, 0.0, 1.0));
    
    fragColor = vec4(result, origColor.a);
}
