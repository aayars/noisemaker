#version 300 es
precision highp float;

// Bloom upsample pass - bilinear upsamples the downsampled data and blends with original
// Uses 9-tap sampling for smooth results without expensive global mean calculation

uniform sampler2D inputTex;         // Original full-res image
uniform sampler2D downsampleBuffer; // Output from downsample pass
uniform vec2 resolution;            // Full resolution
uniform vec2 downsampleSize;        // Size of downsampled texture
uniform float bloomAlpha;           // Bloom blend amount (0-1)

out vec4 fragColor;

const float BRIGHTNESS_ADJUST = 0.25;

vec3 clamp01(vec3 v) {
    return clamp(v, vec3(0.0), vec3(1.0));
}

void main() {
    ivec2 coord = ivec2(gl_FragCoord.xy);
    vec2 fullSize = vec2(resolution);
    vec2 downSize = vec2(downsampleSize);
    
    // Get original pixel
    vec4 original = texelFetch(inputTex, coord, 0);
    float alpha = clamp(bloomAlpha, 0.0, 1.0);
    
    // Early return if no bloom
    if (alpha <= 0.0) {
        fragColor = vec4(clamp01(original.rgb), original.a);
        return;
    }
    
    // Calculate UV in downsample texture space
    vec2 uv = (vec2(coord) + 0.5) / fullSize;
    
    // 9-tap tent filter for smooth upsampling
    // This samples in a 3x3 pattern with bilinear filtering for a 4x4 effective footprint
    vec2 texelSize = 1.0 / downSize;
    
    vec3 sum = vec3(0.0);
    
    // Center tap (weight 4)
    sum += texture(downsampleBuffer, uv).rgb * 4.0;
    
    // Edge taps (weight 2 each)
    sum += texture(downsampleBuffer, uv + vec2(-texelSize.x, 0.0)).rgb * 2.0;
    sum += texture(downsampleBuffer, uv + vec2( texelSize.x, 0.0)).rgb * 2.0;
    sum += texture(downsampleBuffer, uv + vec2(0.0, -texelSize.y)).rgb * 2.0;
    sum += texture(downsampleBuffer, uv + vec2(0.0,  texelSize.y)).rgb * 2.0;
    
    // Corner taps (weight 1 each)
    sum += texture(downsampleBuffer, uv + vec2(-texelSize.x, -texelSize.y)).rgb;
    sum += texture(downsampleBuffer, uv + vec2( texelSize.x, -texelSize.y)).rgb;
    sum += texture(downsampleBuffer, uv + vec2(-texelSize.x,  texelSize.y)).rgb;
    sum += texture(downsampleBuffer, uv + vec2( texelSize.x,  texelSize.y)).rgb;
    
    // Normalize (4 + 2*4 + 1*4 = 16)
    vec3 bloomSample = sum / 16.0;
    
    // Add brightness boost
    vec3 boosted = clamp01(bloomSample + vec3(BRIGHTNESS_ADJUST));
    
    // Blend with original using additive-style blend
    vec3 sourceClamped = clamp01(original.rgb);
    vec3 mixed = clamp01((sourceClamped + boosted) * 0.5);
    vec3 finalRgb = clamp01(sourceClamped * (1.0 - alpha) + mixed * alpha);
    
    fragColor = vec4(finalRgb, original.a);
}
