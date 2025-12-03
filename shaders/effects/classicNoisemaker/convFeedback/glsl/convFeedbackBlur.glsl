#version 300 es
precision highp float;
precision highp int;

uniform sampler2D inputTex;

out vec4 fragColor;

const float BLUR_KERNEL[25] = float[25](
    1.0, 4.0, 6.0, 4.0, 1.0,
    4.0, 16.0, 24.0, 16.0, 4.0,
    6.0, 24.0, 36.0, 24.0, 6.0,
    4.0, 16.0, 24.0, 16.0, 4.0,
    1.0, 4.0, 6.0, 4.0, 1.0
);
const float BLUR_KERNEL_SUM = 256.0;

void main() {
    ivec2 tex_size = textureSize(inputTex, 0);
    ivec2 coord = ivec2(gl_FragCoord.xy);
    
    vec3 sum = vec3(0.0);
    
    for (int ky = -2; ky <= 2; ky++) {
        for (int kx = -2; kx <= 2; kx++) {
            ivec2 sample_pos = coord + ivec2(kx, ky);
            sample_pos = clamp(sample_pos, ivec2(0), tex_size - 1);
            
            vec4 sample_val = texelFetch(inputTex, sample_pos, 0);
            
            int idx = (ky + 2) * 5 + (kx + 2);
            float weight = BLUR_KERNEL[idx];
            sum += sample_val.rgb * weight;
        }
    }
    
    vec3 blurred = sum / BLUR_KERNEL_SUM;
    float alpha = texelFetch(inputTex, coord, 0).a;
    
    fragColor = vec4(blurred, alpha);
}
