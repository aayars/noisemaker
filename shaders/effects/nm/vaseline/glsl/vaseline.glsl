#version 300 es

precision highp float;
precision highp int;

// Vaseline effect: soft blur/glow toward edges using Chebyshev mask

uniform sampler2D inputTex;
uniform float alpha;
uniform float time;

in vec2 v_texCoord;
out vec4 fragColor;

float chebyshev_mask(vec2 uv, vec2 dims) {
    vec2 centered = abs(uv - vec2(0.5));
    float px = centered.x * dims.x;
    float py = centered.y * dims.y;
    float dist = max(px, py);
    float maxDim = max(dims.x, dims.y) * 0.5;
    return clamp(dist / max(maxDim, 1.0), 0.0, 1.0);
}

// Simple box blur for bloom approximation
vec4 blur(sampler2D tex, vec2 uv, vec2 texelSize) {
    vec4 sum = vec4(0.0);
    float count = 0.0;
    
    for (int y = -2; y <= 2; y++) {
        for (int x = -2; x <= 2; x++) {
            vec2 offset = vec2(float(x), float(y)) * texelSize * 2.0;
            sum += texture(tex, uv + offset);
            count += 1.0;
        }
    }
    return sum / count;
}

void main() {
    vec2 dims = vec2(textureSize(inputTex, 0));
    vec2 texelSize = 1.0 / dims;
    
    vec4 original = texture(inputTex, v_texCoord);
    
    float a = clamp(alpha, 0.0, 1.0);
    if (a <= 0.0) {
        fragColor = original;
        return;
    }
    
    // Create bloom effect: blur + blend with original
    vec4 blurred = blur(inputTex, v_texCoord, texelSize);
    vec4 bloom = mix(original, blurred, 0.5);
    
    // Calculate edge mask (stronger at edges)
    float maskBase = chebyshev_mask(v_texCoord, dims);
    float mask = maskBase * maskBase;
    
    // Blend from original (center) to bloom (edges)
    vec3 centerMasked = mix(original.rgb, bloom.rgb, mask);
    
    // Apply alpha blend
    vec3 finalRgb = mix(original.rgb, centerMasked, a);
    
    fragColor = vec4(clamp(finalRgb, 0.0, 1.0), original.a);
}
