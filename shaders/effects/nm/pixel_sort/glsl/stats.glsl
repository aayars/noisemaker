#version 300 es
precision highp float;

uniform sampler2D inputTex;

out vec4 fragColor;

float srgb_to_lin(float value) {
    if (value <= 0.04045) {
        return value / 12.92;
    }
    return pow((value + 0.055) / 1.055, 2.4);
}

float oklab_l_component(vec3 rgb) {
    float r_lin = srgb_to_lin(rgb.x);
    float g_lin = srgb_to_lin(rgb.y);
    float b_lin = srgb_to_lin(rgb.z);

    float l_val = 0.4121656120 * r_lin + 0.5362752080 * g_lin + 0.0514575653 * b_lin;
    float m_val = 0.2118591070 * r_lin + 0.6807189584 * g_lin + 0.1074065790 * b_lin;
    float s_val = 0.0883097947 * r_lin + 0.2818474174 * g_lin + 0.6302613616 * b_lin;

    float l_cbrt = pow(l_val, 1.0 / 3.0);
    float m_cbrt = pow(m_val, 1.0 / 3.0);
    float s_cbrt = pow(s_val, 1.0 / 3.0);

    return 0.2104542553 * l_cbrt + 0.7936177850 * m_cbrt - 0.0040720468 * s_cbrt;
}

void main() {
    ivec2 texSize = textureSize(inputTex, 0);
    int width = texSize.x;
    int y = int(gl_FragCoord.y);
    
    float maxBrightness = -1.0;
    int brightestIndex = 0;
    
    for (int i = 0; i < width; i++) {
        vec4 c = texelFetch(inputTex, ivec2(i, y), 0);
        float b = oklab_l_component(c.rgb);
        if (b > maxBrightness) {
            maxBrightness = b;
            brightestIndex = i;
        }
    }
    
    fragColor = vec4(float(brightestIndex) / float(width), maxBrightness, 0.0, 1.0);
}
