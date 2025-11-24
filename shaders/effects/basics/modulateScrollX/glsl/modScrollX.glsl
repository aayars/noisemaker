#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform sampler2D tex1;
uniform float scrollX;
uniform float speed;
uniform float time;
uniform float amount;

out vec4 fragColor;

/* Scrolls the modulator along X before displacement. */
void main(){
  vec2 st = gl_FragCoord.xy / vec2(textureSize(tex0,0));
  float shift = scrollX + time * speed;
  vec4 m = texture(tex1, st + vec2(shift,0.0));
  st += (m.xy * 2.0 - 1.0) * amount;
  fragColor = vec4(texture(tex0, st).rgb, 1.0);
}

