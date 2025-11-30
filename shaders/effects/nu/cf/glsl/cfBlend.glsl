/*
 * Convolution Feedback - Blend Pass
 * Blends processed feedback texture with input based on intensity
 */

#ifdef GL_ES
precision highp float;
precision highp int;
#endif

uniform sampler2D inputTex;
uniform sampler2D feedbackTex;
uniform float intensity;

out vec4 fragColor;

void main() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    
    vec4 inputColor = texelFetch(inputTex, coord, 0);
    vec4 feedback = texelFetch(feedbackTex, coord, 0);
    
    // Blend input with processed feedback based on intensity
    vec3 result = mix(inputColor.rgb, feedback.rgb, intensity);
    
    fragColor = vec4(result, inputColor.a);
}
