#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform sampler2D tex1;
uniform float amount;

out vec4 fragColor;

/* Subtracts tex1 from tex0 scaled by amount, clamped to zero. */
void main(){
  vec2 st = gl_FragCoord.xy / vec2(textureSize(tex0,0));
  vec4 a = texture(tex0, st);
  vec3 b = texture(tex1, st).rgb * amount;
  fragColor = vec4(max(a.rgb - b, 0.0), 1.0);
}
