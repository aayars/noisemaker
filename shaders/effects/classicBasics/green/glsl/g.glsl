#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform float scale;
uniform float offset;

out vec4 fragColor;

/* Extracts green channel as grayscale. */
void main(){
  vec2 st = (gl_FragCoord.xy - 0.5) / vec2(textureSize(tex0,0));
  vec4 c = texture(tex0, st);
  float v = fract(c.g * scale + offset);
  fragColor = vec4(vec3(v), 1.0);
}
