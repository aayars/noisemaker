#version 300 es
precision highp float;

uniform sampler2D trailTex;
uniform sampler2D inputTex;

out vec4 fragColor;

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5) / vec2(textureSize(trailTex, 0));
    vec4 trail = texture(trailTex, uv);
    vec4 img = texture(inputTex, uv);
    
    // Combine
    fragColor = img + trail;
}
