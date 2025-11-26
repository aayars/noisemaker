#version 300 es
precision highp float;
uniform float depositAmount;
uniform float weight;
uniform int source;
uniform sampler2D inputTex;
in vec2 vUV;
out vec4 fragColor;

float luminance(vec3 color) {
    return dot(color, vec3(0.2126, 0.7152, 0.0722));
}

vec3 sampleInputColor(vec2 uv) {
    vec2 flippedUV = vec2(uv.x, 1.0 - uv.y);
    vec3 sampleColor = vec3(0.0);
  if (source == 1) {
        sampleColor = texture(inputTex, flippedUV).rgb;
    }
    return sampleColor;
}

float sampleInputLuminance(vec2 uv) {
    if (source <= 0) {
        return 0.0;
    }
    return luminance(sampleInputColor(uv));
}

void main() {
    float blend = clamp(weight * 0.01, 0.0, 1.0);
    float deposit = depositAmount;
    if (source > 0 && blend > 0.0) {
        float inputValue = sampleInputLuminance(vUV);
        float gain = mix(1.0, mix(0.25, 2.0, inputValue), blend);
        deposit *= gain;
    }
    fragColor = vec4(deposit, 0.0, 0.0, 1.0);
}
