#version 300 es

precision highp float;
precision highp int;

// Sobel edge detection shader
// Computes gradient magnitude using Sobel kernels

uniform sampler2D inputTex;
uniform float distMetric;
uniform float alpha;
uniform float time;

in vec2 v_texCoord;
out vec4 fragColor;

float distance_metric(float gx, float gy, int metric) {
    float abs_gx = abs(gx);
    float abs_gy = abs(gy);
    
    if (metric == 2) {
        // Manhattan
        return abs_gx + abs_gy;
    } else if (metric == 3) {
        // Chebyshev
        return max(abs_gx, abs_gy);
    } else if (metric == 4) {
        // Octagram
        float cross = (abs_gx + abs_gy) / 1.414;
        return max(cross, max(abs_gx, abs_gy));
    } else {
        // Euclidean (default)
        return sqrt(gx * gx + gy * gy);
    }
}

void main() {
    vec2 dims = vec2(textureSize(inputTex, 0));
    vec2 texel = 1.0 / dims;
    
    // Sample 3x3 neighborhood
    vec4 tl = texture(inputTex, v_texCoord + vec2(-texel.x, -texel.y));
    vec4 tc = texture(inputTex, v_texCoord + vec2(0.0, -texel.y));
    vec4 tr = texture(inputTex, v_texCoord + vec2(texel.x, -texel.y));
    vec4 ml = texture(inputTex, v_texCoord + vec2(-texel.x, 0.0));
    vec4 mr = texture(inputTex, v_texCoord + vec2(texel.x, 0.0));
    vec4 bl = texture(inputTex, v_texCoord + vec2(-texel.x, texel.y));
    vec4 bc = texture(inputTex, v_texCoord + vec2(0.0, texel.y));
    vec4 br = texture(inputTex, v_texCoord + vec2(texel.x, texel.y));
    
    // Sobel X kernel: [-1 0 1; -2 0 2; -1 0 1]
    vec4 gx = -tl - 2.0*ml - bl + tr + 2.0*mr + br;
    
    // Sobel Y kernel: [-1 -2 -1; 0 0 0; 1 2 1]
    vec4 gy = -tl - 2.0*tc - tr + bl + 2.0*bc + br;
    
    int metric = int(distMetric);
    
    vec4 result;
    result.r = distance_metric(gx.r, gy.r, metric);
    result.g = distance_metric(gx.g, gy.g, metric);
    result.b = distance_metric(gx.b, gy.b, metric);
    result.a = 1.0;
    
    // Normalize to reasonable range (Sobel max is about 4*sqrt(2) ≈ 5.66 per channel)
    result.rgb = clamp(result.rgb / 4.0, 0.0, 1.0);
    
    fragColor = result;
}
