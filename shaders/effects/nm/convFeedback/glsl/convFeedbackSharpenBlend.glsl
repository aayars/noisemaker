#version 300 es
precision highp float;
precision highp int;

uniform sampler2D blurredTex;
uniform sampler2D inputTex;
uniform sampler2D selfTex;
uniform float alpha;

out vec4 fragColor;

const float SHARPEN_KERNEL[9] = float[9](
    0.0, -1.0, 0.0,
    -1.0, 5.0, -1.0,
    0.0, -1.0, 0.0
);

void main() {
    ivec2 tex_size = textureSize(blurredTex, 0);
    ivec2 coord = ivec2(gl_FragCoord.xy);
    
    vec4 input_val = texelFetch(inputTex, coord, 0);
    vec4 self_val = texelFetch(selfTex, coord, 0);
    
    // Check if self (previous frame) is empty - use input as base
    float self_luma = dot(self_val.rgb, vec3(0.299, 0.587, 0.114));
    bool is_first_frame = self_luma < 0.001 && self_val.a < 0.001;
    
    if (is_first_frame) {
        // First frame: just output the input
        fragColor = input_val;
        return;
    }
    
    // Apply 3x3 sharpen to blurred texture
    vec3 sum = vec3(0.0);
    
    for (int ky = -1; ky <= 1; ky++) {
        for (int kx = -1; kx <= 1; kx++) {
            ivec2 sample_pos = coord + ivec2(kx, ky);
            sample_pos = clamp(sample_pos, ivec2(0), tex_size - 1);
            
            vec4 sample_val = texelFetch(blurredTex, sample_pos, 0);
            
            int idx = (ky + 1) * 3 + (kx + 1);
            float weight = SHARPEN_KERNEL[idx];
            sum += sample_val.rgb * weight;
        }
    }
    
    vec3 sharpened = clamp(sum, 0.0, 1.0);
    
    // Apply the up/down contrast expansion from Python reference
    // up = max((sharpened - 0.5) * 2, 0.0)
    vec3 up = max((sharpened - 0.5) * 2.0, vec3(0.0));
    
    // down = min(sharpened * 2, 1.0)
    vec3 down = min(sharpened * 2.0, vec3(1.0));
    
    // Combined: up + (1 - down)
    vec3 processed = up + (vec3(1.0) - down);
    processed = clamp(processed, vec3(0.0), vec3(1.0));
    
    // Blend processed with input based on alpha
    vec3 blended = mix(input_val.rgb, processed, alpha);
    
    fragColor = vec4(blended, input_val.a);
}
