#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform sampler2D tex1;
uniform float n;
uniform float amount;

out vec4 fragColor;

/* Mirrors the modulator into n segments before displacement. */
const float PI = 3.141592653589793;
void main(){
  vec2 st = gl_FragCoord.xy / vec2(textureSize(tex0,0));
  vec2 p = st - 0.5;
  float r = length(p);
  float a = atan(p.y, p.x);
  float sector = 2.0 * PI / n;
  a = mod(a, sector);
  vec2 uv = vec2(cos(a), sin(a)) * r + 0.5;
  vec4 m = texture(tex1, uv);
  st += (m.xy * 2.0 - 1.0) * amount;
  fragColor = vec4(texture(tex0, st).rgb, 1.0);
}

