#version 300 es

precision highp float;

uniform sampler2D gridTex;
uniform sampler2D inputTex;
uniform float alpha;
uniform vec2 resolution;

layout(location = 0) out vec4 dlaOutColor;

vec3 palette(float t) {
    return mix(vec3(0.05, 0.0, 0.08), vec3(1.0, 0.25, 0.9), clamp(t, 0.0, 1.0));
}

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5) / resolution;
    vec4 inputColor = texture(inputTex, uv);
    vec4 cluster = texture(gridTex, uv);

    float intensity = clamp(cluster.a, 0.0, 1.0);
    vec3 clusterColor = cluster.rgb;
    if (dot(clusterColor, clusterColor) < 1e-4) {
        clusterColor = palette(intensity) * intensity;
    }

    vec3 emission = clusterColor * (0.35 + intensity * 0.8);
    vec3 combined = mix(inputColor.rgb, clamp(inputColor.rgb + emission, 0.0, 1.0), clamp(alpha, 0.0, 1.0));
    float outAlpha = max(inputColor.a, intensity);

    dlaOutColor = vec4(combined, outAlpha);
}
