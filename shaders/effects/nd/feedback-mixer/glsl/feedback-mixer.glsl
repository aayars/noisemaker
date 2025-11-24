#version 300 es

/*
 * Feedback mixer shader.
 * Blends the current mixer output with a delayed framebuffer while exposing offset controls for creative smearing.
 * Feedback weighting is clamped to safe ranges so recursive accumulation never overflows.
 */

precision highp float;
precision highp int;

uniform sampler2D tex0;
uniform sampler2D tex1;
uniform sampler2D selfTex;
uniform vec2 resolution;
uniform float time;
uniform float seed;
uniform float mixAmt;
uniform float feedback;
uniform float scaleAmt;
uniform float rotation;
out vec4 fragColor;

#define PI 3.14159265359
#define TAU 6.28318530718
#define aspectRatio resolution.x / resolution.y


float map(float value, float inMin, float inMax, float outMin, float outMax) {
    return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

vec2 rotate2D(vec2 st, float rot) {
    st.x *= aspectRatio;
    rot = map(rot, 0.0, 360.0, 0.0, 2.0);
    float angle = rot * PI;
    st -= vec2(0.5 * aspectRatio, 0.5);
    st = mat2(cos(angle), -sin(angle), sin(angle), cos(angle)) * st;
    st += vec2(0.5 * aspectRatio, 0.5);
    st.x /= aspectRatio;
    return st;
}

void main() {
    vec4 color = vec4(0.0, 0.0, 0.0, 1.0);
    vec2 st = gl_FragCoord.xy / resolution;
    st.y = 1.0 - st.y;

    float scale = 100.0 / scaleAmt; // 25 - 400 maps to 100 / 25 (4) to 100 / 400 (0.25)

    if (scale == 0.0) {
        scale = 1.0;
    }
    st = rotate2D(st, rotation) * scale;

    // no
    vec2 imageSize = resolution;

    // need to subtract 50% of image width and height
    // mid center
    st.x -= (resolution.x / imageSize.x * scale * 0.5) - (0.5 - (1.0 / imageSize.x * scale));
    st.y += (resolution.y / imageSize.y * scale * 0.5) + (0.5 - (1.0 / imageSize.y * scale)) - (scale);

    // nudge by one pixel, otherwise it drifts for reasons unknown
    st += 1.0 / resolution;

    st = fract(st);

    //
    vec4 color1 = texture(tex0, st);
    vec4 color2 = texture(tex1, st);

    color = mix(color1, color2, map(mixAmt, -100.0, 100.0, 0.0, 1.0));
    color.a = max(color1.a, color2.a);

    color = mix(color, texture(selfTex, st), feedback * 0.01);

    fragColor = color;
}
