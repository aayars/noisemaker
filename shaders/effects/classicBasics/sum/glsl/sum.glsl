#version 300 es
precision highp float;

uniform sampler2D tex0;
uniform float scale;

out vec4 fragColor;

/* Sums all channels, wrapping the magnitude to preserve variation. */
void main(){
  vec2 st = gl_FragCoord.xy / vec2(textureSize(tex0,0));
  vec4 inputColor = texture(tex0, st);
  float summed = dot(inputColor, vec4(1.0));
  float scaled = summed * scale;

  float wrapped;
  if (scaled >= 0.0) {
    wrapped = fract(scaled);
  } else {
    wrapped = 1.0 - fract(abs(scaled));
  }

  fragColor = vec4(vec3(wrapped), 1.0);
}
