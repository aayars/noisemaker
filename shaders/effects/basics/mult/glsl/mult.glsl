#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform sampler2D tex1;
uniform float amount;

out vec4 fragColor;

/* Multiplies tex0 by tex1 scaled by amount. */
void main(){
  vec2 st = gl_FragCoord.xy / vec2(textureSize(tex0,0));
  vec4 a = texture(tex0, st);
  vec3 mask = texture(tex1, st).rgb;
  float mixAmount = clamp(amount, 0.0, 1.0);
  vec3 blended = mix(vec3(1.0), mask, mixAmount);
  fragColor = vec4(a.rgb * blended, a.a);
}
