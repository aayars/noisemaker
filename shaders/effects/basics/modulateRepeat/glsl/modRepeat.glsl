#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform sampler2D tex1;
uniform float repeatX;
uniform float repeatY;
uniform float offsetX;
uniform float offsetY;
uniform float amount;

out vec4 fragColor;

/* Tiles the modulating texture before offsetting the base coordinates. */
void main(){
  vec2 st = gl_FragCoord.xy / vec2(textureSize(tex0,0));
  vec2 rpt = vec2(repeatX, repeatY);
  vec2 offs = vec2(offsetX, offsetY);
  vec2 modUV = fract(st * rpt + offs);
  vec4 m = texture(tex1, modUV);
  st += (m.xy * 2.0 - 1.0) * amount;
  fragColor = vec4(texture(tex0, st).rgb, 1.0);
}

