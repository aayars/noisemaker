#version 300 es
precision highp float;


uniform sampler2D inputTex;
uniform sampler2D trailTex;
uniform float inputIntensity;

out vec4 fragColor;

void main() {
    vec2 uv = (gl_FragCoord.xy - 0.5) / vec2(textureSize(trailTex, 0));
    vec4 inputColor = texture(inputTex, uv);
    vec4 trailColor = texture(trailTex, uv);
    
    float inputScale = clamp(inputIntensity / 100.0, 0.0, 1.0);
    vec3 base = inputColor.rgb * inputScale;
    
    vec3 combined = clamp(trailColor.rgb + base, 0.0, 1.0);
    float alpha = clamp(max(trailColor.a, inputColor.a), 0.0, 1.0);
    
    fragColor = vec4(combined, alpha);
}
