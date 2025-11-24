#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform sampler2D tex1;
uniform float multiple;
uniform float offset;

out vec4 fragColor;

/* Rotates coordinates by an angle derived from the modulator. */
void main(){
  vec2 size = vec2(textureSize(tex0,0));
  vec2 st = gl_FragCoord.xy / size - 0.5;
  vec4 m = texture(tex1, st + 0.5);
  float angle = (m.r - 0.5) * multiple + offset;
  mat2 rot = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
  st = rot * st;
  st += 0.5;
  fragColor = vec4(texture(tex0, st).rgb, 1.0);
}

