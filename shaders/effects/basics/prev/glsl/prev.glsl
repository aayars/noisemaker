#version 300 es
precision highp float;

uniform vec2 resolution;
uniform sampler2D tex0;

out vec4 fragColor;

/* Samples the previous frame of the target output. */
void main() {
  vec2 st = gl_FragCoord.xy / resolution;
  fragColor = texture(tex0, st);
}
