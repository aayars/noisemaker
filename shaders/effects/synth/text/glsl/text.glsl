/*
 * Text blit shader.
 * Draws the pre-rendered glyph atlas directly to the framebuffer.
 * The text is rendered to a 2D canvas on the CPU side and uploaded as a texture.
 */

#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D textTex;
uniform vec2 resolution;
uniform float time;
uniform float seed;

out vec4 fragColor;

void main() {
    vec2 st = gl_FragCoord.xy / resolution;
    st.y = 1.0 - st.y;

    fragColor = texture(textTex, st);
}
