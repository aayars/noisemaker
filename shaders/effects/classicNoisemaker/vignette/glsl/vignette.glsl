#version 300 es

precision highp float;
precision highp int;

// Vignette: normalize input and blend edges toward constant brightness

uniform sampler2D inputTex;
uniform float brightness;
uniform float alpha;
uniform float time;

in vec2 v_texCoord;
out vec4 fragColor;

float computeVignetteMask(vec2 uv, vec2 dims) {
    if (dims.x <= 0.0 || dims.y <= 0.0) {
        return 0.0;
    }
    
    vec2 delta = abs(uv - vec2(0.5));
    float aspect = dims.x / max(dims.y, 1.0);
    vec2 scaled = vec2(delta.x * aspect, delta.y);
    float maxRadius = length(vec2(aspect * 0.5, 0.5));
    
    if (maxRadius <= 0.0) {
        return 0.0;
    }
    
    float normalizedDist = clamp(length(scaled) / maxRadius, 0.0, 1.0);
    return normalizedDist * normalizedDist;
}

vec4 normalizeColor(vec4 color) {
    float minVal = min(min(color.r, color.g), color.b);
    float maxVal = max(max(color.r, color.g), color.b);
    float range = maxVal - minVal;
    
    if (range <= 0.0) {
        return color;
    }
    
    return vec4((color.rgb - vec3(minVal)) / vec3(range), color.a);
}

void main() {
    vec2 dims = vec2(textureSize(inputTex, 0));
    vec4 texel = texture(inputTex, v_texCoord);
    
    // Normalize per-pixel
    vec4 normalized = normalizeColor(texel);
    
    float b = brightness;
    float a = alpha;
    
    float mask = computeVignetteMask(v_texCoord, dims);
    
    // Apply brightness to RGB only, preserve alpha
    vec3 brightnessRgb = vec3(b);
    vec3 edgeBlend = mix(normalized.rgb, brightnessRgb, mask);
    vec3 finalRgb = mix(normalized.rgb, edgeBlend, a);
    
    fragColor = vec4(finalRgb, normalized.a);
}
