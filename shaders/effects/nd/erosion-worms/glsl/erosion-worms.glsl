#version 300 es
precision highp float;

uniform sampler2D inputTex;
uniform sampler2D erosionTex;
uniform vec2 resolution;
uniform float inputIntensity;

out vec4 fragColor;

vec4 sampleTextureOrFallback(sampler2D tex, vec2 uv) {
    ivec2 dims = textureSize(tex, 0);
    if (dims.x == 0 || dims.y == 0) {
        return vec4(-1.0, -1.0, -1.0, -1.0);
    }
    return texture(tex, uv);
}

void main() {
    vec2 size = vec2(max(resolution.x, 1.0), max(resolution.y, 1.0));
    vec2 uv = gl_FragCoord.xy / size;
    uv.y = 1.0 - uv.y;

    float inputIntensityValue = clamp(inputIntensity / 100.0, 0.0, 1.0);
    vec4 baseSample = texture(inputTex, uv);
    vec4 baseColor = vec4(baseSample.xyz * inputIntensityValue, baseSample.w);

    vec4 erosionColor = sampleTextureOrFallback(erosionTex, uv);
    if (erosionColor.w < 0.0) {
        fragColor = baseColor;
        return;
    }

    vec3 combinedRgb = clamp(baseColor.xyz + erosionColor.xyz, vec3(0.0), vec3(1.0));
    float finalAlpha = clamp(max(baseColor.w, erosionColor.w), 0.0, 1.0);

    fragColor = vec4(combinedRgb, finalAlpha);
}
