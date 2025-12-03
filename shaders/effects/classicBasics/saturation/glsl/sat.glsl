#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform float a;

out vec4 fragColor;

/* Adjusts sat by mixing with luminance. */
void main(){
  vec2 st = gl_FragCoord.xy / vec2(textureSize(tex0,0));
  vec4 c = texture(tex0, st);
  float l = dot(c.rgb, vec3(0.2126,0.7152,0.0722));
  vec3 rgb = mix(vec3(l), c.rgb, a);
  fragColor = vec4(rgb,1.0);
}
