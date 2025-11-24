#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform sampler2D tex1;
uniform float amount;

out vec4 fragColor;

/* Offsets lookup of tex0 using tex1's color data. */
void main(){
  vec2 st = gl_FragCoord.xy / vec2(textureSize(tex0,0));
  vec4 m = texture(tex1, st);
  st += (m.xy * 2.0 - 1.0) * amount;
  fragColor = vec4(texture(tex0, st).rgb, 1.0);
}
