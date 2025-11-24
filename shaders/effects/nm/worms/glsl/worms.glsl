#version 300 es
precision highp float;

uniform sampler2D mixerTex;
uniform sampler2D wormsTex;
uniform vec2 resolution;
uniform float inputIntensity;

out vec4 fragColor;

void main() {
    vec2 uv = gl_FragCoord.xy / resolution;
    uv.y = 1.0 - uv.y;

    vec4 baseColor = texture(mixerTex, uv);
    vec4 wormsColor = texture(wormsTex, uv);

    float intensity = clamp(inputIntensity / 100.0, 0.0, 1.0);
    vec3 combined = clamp(baseColor.rgb * intensity + wormsColor.rgb, 0.0, 1.0);
    float alpha = max(baseColor.a, wormsColor.a);

    fragColor = vec4(combined, alpha);
}
