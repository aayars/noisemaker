#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform sampler2D tex1;
uniform float scrollY;
uniform float speed;
uniform float time;
uniform float amount;

out vec4 fragColor;

/* Scrolls the modulator along Y before displacement. */
void main(){
  vec2 st = gl_FragCoord.xy / vec2(textureSize(tex0,0));
  float shift = scrollY + time * speed;
  vec4 m = texture(tex1, st + vec2(0.0, shift));
  st += (m.xy * 2.0 - 1.0) * amount;
  fragColor = vec4(texture(tex0, st).rgb, 1.0);
}

