#version 300 es
precision highp float;
precision highp int;

uniform sampler2D inputTex;
uniform sampler2D feedbackTex;
uniform float alpha;

out vec4 fragColor;

void main() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    ivec2 texSize = textureSize(feedbackTex, 0);
    
    vec4 input_val = texelFetch(inputTex, coord, 0);
    vec4 feedback_val = texelFetch(feedbackTex, coord, 0);
    
    // Normalize feedback values - find local min/max
    // (Simplified: assume we've converged to a reasonable range)
    vec3 convolved = feedback_val.rgb;
    
    // Apply the up/down contrast expansion from Python reference
    // up = max((convolved - 0.5) * 2, 0.0)
    vec3 up = max((convolved - 0.5) * 2.0, vec3(0.0));
    
    // down = min(convolved * 2, 1.0)
    vec3 down = min(convolved * 2.0, vec3(1.0));
    
    // Combined: up + (1 - down)
    vec3 processed = up + (vec3(1.0) - down);
    
    // Normalize to 0-1 range
    processed = clamp(processed, vec3(0.0), vec3(1.0));
    
    // Blend processed with input based on alpha
    vec3 blended = mix(input_val.rgb, processed, alpha);
    
    fragColor = vec4(blended, input_val.a);
}
