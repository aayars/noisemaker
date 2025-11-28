#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform float threshold;
uniform float tolerance;

out vec4 fragColor;

float luminance(vec3 c){
  return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

/* Applies luminance-based threshold as a tonal mask. */
void main() {
  vec2 st = gl_FragCoord.xy / vec2(textureSize(tex0, 0));
  vec4 c = texture(tex0, st);
  float a = smoothstep(threshold - (tolerance + 0.0000001), threshold + (tolerance + 0.0000001), luminance(c.rgb));
  fragColor = vec4(c.rgb * a, 1.0);
}
