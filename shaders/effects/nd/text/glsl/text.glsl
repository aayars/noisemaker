#version 300 es

/*
 * Text blit shader.
 * Draws the pre-rendered glyph atlas directly to the framebuffer so layout matches the CPU text engine.
 * Normalized coordinates ensure upstream transforms can reposition text without introducing GPU drift.
 */


precision highp float;
precision highp int;

uniform sampler2D textTex;
uniform vec2 resolution;
uniform float time;
uniform float seed;
out vec4 fragColor;

#define PI 3.14159265359
#define TAU 6.28318530718


void main() {
    vec2 st = gl_FragCoord.xy / resolution;
	st.y = 1.0 - st.y;

	fragColor = texture(textTex, st);
}
