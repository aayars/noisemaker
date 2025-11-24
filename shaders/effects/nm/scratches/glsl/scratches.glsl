#version 300 es

precision highp float;
precision highp int;

// Scratches final combine pass.
// Uses the generated scratch mask to lift the highlights of the source image
// without washing out the mid-tones entirely.

uniform sampler2D input_texture;
uniform sampler2D mask_texture;
uniform bool enabled;

out vec4 fragColor;

void main() {
    ivec2 dims = textureSize(input_texture, 0);
    ivec2 coord = ivec2(int(gl_FragCoord.x), int(gl_FragCoord.y));

    if (coord.x < 0 || coord.y < 0 || coord.x >= dims.x || coord.y >= dims.y) {
        fragColor = vec4(0.0);
        return;
    }

    vec4 base_color = texelFetch(input_texture, coord, 0);

    if (!enabled) {
        fragColor = base_color;
        return;
    }

    vec4 mask_color = texelFetch(mask_texture, coord, 0);
    float scratch_mask = mask_color.r;

    vec3 scratch_rgb = max(base_color.rgb, vec3(scratch_mask * 4.0));
    fragColor = vec4(clamp(scratch_rgb, 0.0, 1.0), base_color.a);
}