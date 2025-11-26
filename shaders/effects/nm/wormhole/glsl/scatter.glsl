#version 300 es

precision highp float;
precision highp int;

// Wormhole - Pass 0: Scatter weighted samples (pixel-parallel)
// Each pixel reads its color and scatters it to a flow-field destination

const float TAU = 6.28318530717958647692;
const float STRIDE_SCALE = 1024.0;
const uint CHANNEL_COUNT = 4u;


uniform sampler2D inputTex;
uniform vec4 size;
uniform vec4 flow;
uniform vec4 motion;

float luminance(vec4 color) {
    return dot(color.xyz, vec3(0.2126, 0.7152, 0.0722));
}

uint wrap_coord(float value, float limit) {
    int limit_i = int(limit);
    int wrapped = int(floor(value)) % limit_i;
    if (wrapped < 0) {
        wrapped = wrapped + limit_i;
    }
    return uint(wrapped);
}


out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);

    uint width_u = uint(size.x);
    uint height_u = uint(size.y);
    
    if (global_id.x >= width_u || global_id.y >= height_u) {
        return;
    }
    
    float width_f = size.x;
    float height_f = size.y;
    float kink = flow.x;
    float stride_pixels = flow.y * STRIDE_SCALE;
    
    // Read source pixel
    uint src_x = global_id.x;
    uint src_y = global_id.y;
    vec4 src_color = textureLoad(inputTex, vec2(int(src_x), int(src_y)), 0);
    
    // Calculate flow field offset based on luminance
    float lum = luminance(src_color);
    float angle = lum * TAU * kink;
    float offset_x = (cos(angle) + 1.0) * stride_pixels;
    float offset_y = (sin(angle) + 1.0) * stride_pixels;
    
    // Calculate destination with wrapping
    uint dest_x = wrap_coord(float(src_x) + offset_x, width_f);
    uint dest_y = wrap_coord(float(src_y) + offset_y, height_f);
    uint dest_pixel = dest_y * width_u + dest_x;
    uint base = dest_pixel * CHANNEL_COUNT;
    
    // Weight by luminance squared (matching Python implementation)
    float weight = lum * lum;
    vec3 weighted_rgb = src_color.xyz * vec3(weight);
    
    // Accumulate weighted color contribution
    
    // Store total weight in w channel for normalization
}