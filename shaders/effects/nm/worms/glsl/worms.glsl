#version 300 es
precision highp float;

uniform sampler2D mixerTex;
uniform sampler2D wormsTex;
uniform vec2 resolution;
uniform float inputIntensity;

out vec4 fragColor;

void main() {
    vec2 uv = gl_FragCoord.xy / resolution;

    vec4 baseColor = texture(mixerTex, uv);
    vec4 wormsColor = texture(wormsTex, uv);

    float intensity = clamp(inputIntensity / 100.0, 0.0, 1.0);
    
    // Combine like erosion_worms: input scaled by intensity + trails
    fragColor = vec4(baseColor.rgb * intensity, baseColor.a) + wormsColor;
}
