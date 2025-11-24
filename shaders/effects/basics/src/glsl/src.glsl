#version 300 es
precision highp float;

uniform vec2 resolution;
uniform sampler2D tex0;

out vec4 fragColor;

/* Pass-through sampler to pull from an existing surface. */
void main() {
  vec2 st = gl_FragCoord.xy / resolution;
  fragColor = texture(tex0, st);
}
