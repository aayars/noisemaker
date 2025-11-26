#version 300 es

precision highp float;
precision highp int;

// Worms effect - Pass 1: Initialize from previous frame
// Copy prev_texture to output_buffer for temporal accumulation

uniform sampler2D inputTex;
uniform vec4 size;
uniform vec4 behaviorDensityStridePadding;
uniform vec3 strideDeviationAlphaKink;
uniform vec4 quantizeTimePaddingIntensity;
uniform vec4 inputIntensity_lifetime_padding;
uniform sampler2D prevTexture;



out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uvec2 dims = uvec2(textureSize(prev_texture, 0));
    uint width = dims.x;
    uint height = dims.y;
    
    if (global_id.x >= width || global_id.y >= height) {
        return;
    }
    
    uint pixel_idx = global_id.y * width + global_id.x;
    uint base = pixel_idx * 4u;
    
    float intensity_fade = clamp(quantize_time_padding_intensity.w, 0.0, 1.0);
    vec4 prev_color = texelFetch(prev_texture, ivec2(global_id.xy), 0);
    vec4 faded = prev_color * intensity_fade;
    
    fragColor = faded;
    
}