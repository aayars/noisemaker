#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform sampler2D tex1;
uniform float multiple;
uniform float offset;
uniform float amount;

out vec4 fragColor;

/* Samples modulator at scaled coordinates. */
void main(){
  vec2 st = gl_FragCoord.xy / vec2(textureSize(tex0,0));
  vec2 center = vec2(0.5);
  vec2 uv = (st - center) * multiple + center + vec2(offset);
  vec4 m = texture(tex1, uv);
  st += (m.xy * 2.0 - 1.0) * amount;
  fragColor = vec4(texture(tex0, st).rgb, 1.0);
}

