#version 300 es
precision highp float;
precision highp int;

uniform sampler2D blurredTex;
uniform vec4 size;

out vec4 fragColor;

const float SHARPEN_KERNEL[9] = float[9](
    0.0, -1.0, 0.0,
    -1.0, 5.0, -1.0,
    0.0, -1.0, 0.0
);

void main() {
    ivec2 tex_size = textureSize(blurredTex, 0);
    ivec2 coord = ivec2(gl_FragCoord.xy);
    
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
    float alpha = texelFetch(blurredTex, coord, 0).a;
    
    fragColor = vec4(sharpened, alpha);
}
