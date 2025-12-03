#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform float a;

out vec4 fragColor;

/* Mixes original color with its inverse. */
void main(){
  vec2 st = gl_FragCoord.xy / vec2(textureSize(tex0,0));
  vec4 c = texture(tex0, st);
  vec3 inv = 1.0 - c.rgb;
  vec3 rgb = mix(c.rgb, inv, a);
  fragColor = vec4(rgb,1.0);
}
