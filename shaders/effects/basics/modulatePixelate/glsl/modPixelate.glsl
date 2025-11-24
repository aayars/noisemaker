#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform sampler2D tex1;
uniform float pixelX;
uniform float pixelY;
uniform float amount;

out vec4 fragColor;

/* Pixelates the modulator before displacement. */
void main(){
  vec2 size = vec2(textureSize(tex0,0));
  vec2 st = gl_FragCoord.xy / size;
  vec2 pSize = vec2(pixelX, pixelY);
  vec2 uv = floor(st * pSize) / pSize;
  vec4 m = texture(tex1, uv);
  st += (m.xy * 2.0 - 1.0) * amount;
  fragColor = vec4(texture(tex0, st).rgb, 1.0);
}

