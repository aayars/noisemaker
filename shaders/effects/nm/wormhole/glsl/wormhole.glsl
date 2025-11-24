#version 300 es

precision highp float;
precision highp int;

// Wormhole effect - per-pixel field flow driven by luminance

uniform sampler2D inputTex;
uniform float time;
uniform float kink;
uniform float stride;
uniform float alpha;
uniform float speed;

in vec2 v_texCoord;
out vec4 fragColor;

const float TAU = 6.28318530717959;

float luminance(vec4 color) {
    return dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));
}

void main() {
    vec2 dims = vec2(textureSize(inputTex, 0));
    
    // Get source pixel
    vec4 src = texture(inputTex, v_texCoord);
    float lum = luminance(src);
    
    // Calculate flow angle based on luminance
    float angle = lum * TAU * kink + time * speed;
    
    // Calculate offset
    float stridePixels = stride * 0.1;
    float offsetX = (cos(angle) + 1.0) * stridePixels;
    float offsetY = (sin(angle) + 1.0) * stridePixels;
    
    // Sample from offset position
    vec2 sampleCoord = v_texCoord + vec2(offsetX, offsetY) / dims;
    sampleCoord = fract(sampleCoord);
    
    vec4 sampled = texture(inputTex, sampleCoord);
    
    // Blend with original
    vec4 result = mix(src, sampled, alpha);
    
    fragColor = result;
}
