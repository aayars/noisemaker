#version 300 es
precision highp float;
precision highp int;

// Erosion Worms - Final Blend Pass
// Composites the accumulated trail buffer with the input texture

uniform vec2 resolution;
uniform sampler2D input_texture;   // Source image
uniform sampler2D trail_texture;   // Accumulated trails

uniform float inputIntensity;      // Input blending (0-100)

out vec4 fragColor;

void main() {
    vec2 uv = gl_FragCoord.xy / resolution;
    
    // Sample input and trails
    vec4 inputColor = texture(input_texture, uv);
    vec4 trailColor = texture(trail_texture, uv);
    
    // Apply input intensity
    float inputBlend = clamp(inputIntensity / 100.0, 0.0, 1.0);
    vec3 baseRgb = inputColor.rgb * inputBlend;
    
    // Additive blend with trails
    vec3 combined = clamp(baseRgb + trailColor.rgb, vec3(0.0), vec3(1.0));
    float alpha = clamp(max(inputColor.a, trailColor.a), 0.0, 1.0);
    
    fragColor = vec4(combined, alpha);
}
