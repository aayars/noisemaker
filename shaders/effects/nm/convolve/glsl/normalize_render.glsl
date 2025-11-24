#version 300 es
precision highp float;
precision highp int;

uniform sampler2D convolved_texture;
uniform sampler2D minmax_texture;
uniform sampler2D input_texture;
uniform vec4 control; // x: normalize (bool), y: alpha
uniform vec4 size; // w: kernel_id

out vec4 fragColor;

const int KERNEL_CONV2D_EDGES = 803;

void main() {
    vec4 minmax = texelFetch(minmax_texture, ivec2(0, 0), 0);
    float min_val = minmax.x;
    float max_val = minmax.y;
    
    ivec2 coord = ivec2(gl_FragCoord.xy);
    vec4 processed = texelFetch(convolved_texture, coord, 0);
    
    bool do_normalize = control.x > 0.5;
    float alpha = clamp(control.y, 0.0, 1.0);
    int kernel_id = int(round(size.w));
    
    if (min_val > max_val) {
        min_val = 0.0;
        max_val = 0.0;
    }
    
    if (do_normalize && max_val > min_val) {
        float inv_range = 1.0 / (max_val - min_val);
        processed = (processed - min_val) * inv_range;
    }
    
    if (kernel_id == KERNEL_CONV2D_EDGES) {
        // abs(value - 0.5) * 2.0
        processed = abs(processed - 0.5) * 2.0;
    }
    
    vec4 original = texelFetch(input_texture, coord, 0);
    vec4 result = mix(original, processed, alpha);
    result.a = original.a;
    
    fragColor = result;
}
