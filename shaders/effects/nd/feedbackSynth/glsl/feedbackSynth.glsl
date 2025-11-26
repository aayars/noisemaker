#version 300 es

/*
 * Feedback synthesizer shader.
 * Resamples the prior frame with rotation, aberration, and hue adjustments to build evolving feedback textures.
 * Distortion and scale ranges are clamped so the sampling coordinates stay within the framebuffer over long sessions.
 */


precision highp float;
precision highp int;

uniform sampler2D selfTex;
uniform vec2 resolution;
uniform float time;
uniform float seed;
uniform bool aspectLens;
uniform float scaleAmt;
uniform float rotation;
uniform float hueRotation;
uniform float intensity;
uniform float distortion;
uniform float aberrationAmt;
uniform int frame;

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

out vec4 fragColor;

#define PI 3.14159265359
#define TAU 6.28318530718
#define aspectRatio resolution.x / resolution.y


float map(float value, float inMin, float inMax, float outMin, float outMax) {
    return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

vec3 brightnessContrast(vec3 color) {
	float bright = map(intensity * 0.1, -100.0, 100.0, -0.5, 0.5);
	float cont = map(intensity * 0.1, -100.0, 100.0, 0.5, 1.5);
    color = (color - 0.5) * cont + 0.5 + bright;
    return color;
}

vec2 rotate2D(vec2 st, float rot) {
    st.x *= aspectRatio;
    rot = map(rot, 0.0, 360.0, 0.0, 2.0);
    float angle = rot * PI;
    st -= vec2(0.5 * aspectRatio, 0.5);
    st = mat2(cos(angle), -sin(angle), sin(angle), cos(angle)) * st;
    st += vec2(0.5 * aspectRatio, 0.5);
    st.x /= aspectRatio;
    return st;
}

vec3 hsv2rgb(vec3 hsv) {
    float h = fract(hsv.x);
    float s = hsv.y;
    float v = hsv.z;
    
    float c = v * s; // Chroma
    float x = c * (1.0 - abs(mod(h * 6.0, 2.0) - 1.0));
    float m = v - c;

    vec3 rgb;

    if (0.0 <= h && h < 1.0/6.0) {
        rgb = vec3(c, x, 0.0);
    } else if (1.0/6.0 <= h && h < 2.0/6.0) {
        rgb = vec3(x, c, 0.0);
    } else if (2.0/6.0 <= h && h < 3.0/6.0) {
        rgb = vec3(0.0, c, x);
    } else if (3.0/6.0 <= h && h < 4.0/6.0) {
        rgb = vec3(0.0, x, c);
    } else if (4.0/6.0 <= h && h < 5.0/6.0) {
        rgb = vec3(x, 0.0, c);
    } else if (5.0/6.0 <= h && h < 1.0) {
        rgb = vec3(c, 0.0, x);
    } else {
        rgb = vec3(0.0, 0.0, 0.0);
    }

    return rgb + vec3(m, m, m);
}

vec3 rgb2hsv(vec3 rgb) {
    float r = rgb.r;
    float g = rgb.g;
    float b = rgb.b;
    
    float max = max(r, max(g, b));
    float min = min(r, min(g, b));
    float delta = max - min;

    float h = 0.0;
    if (delta != 0.0) {
        if (max == r) {
            h = mod((g - b) / delta, 6.0) / 6.0;
        } else if (max == g) {
            h = ((b - r) / delta + 2.0) / 6.0;
        } else if (max == b) {
            h = ((r - g) / delta + 4.0) / 6.0;
        }
    }
    
    float s = (max == 0.0) ? 0.0 : delta / max;
    float v = max;

    return vec3(h, s, v);
}

vec4 getImage() {
    vec2 st = gl_FragCoord.xy / resolution;   
	st.y = 1.0 - st.y;
    
    st = rotate2D(st, rotation);

    // aberration and lensing
    vec2 diff = 0.5 - st;
    if (aspectLens) {
        diff = vec2(0.5 * aspectRatio, 0.5) - vec2(st.x * aspectRatio, st.y);
    }
    float centerDist = length(diff);

    float distort = 0.0;
    float zoom = 1.0;
    if (distortion < 0.0) {
        distort = map(distortion, -100.0, 0.0, -2.0, 0.0);
        zoom = map(distortion, -100.0, 0.0, 0.04, 0.0);
    } else {
        distort = map(distortion, 0.0, 100.0, 0.0, 2.0);
        zoom = map(distortion, 0.0, 100.0, 0.0, -1.0);
    }

    st = fract((st - diff * zoom) - diff * centerDist * centerDist * distort);

    float scale = 100.0 / scaleAmt; // 25 - 400 maps to 100 / 25 (4) to 100 / 400 (0.25)
    
    if (scale == 0.0) {
        scale = 1.0;
    }
    st *= scale;
    
    // mid center
    st.x -= (scale * 0.5) - (0.5 - (1.0 / resolution.x * scale));
    st.y += (scale * 0.5) + (0.5 - (1.0 / resolution.y * scale)) - (scale);

    // nudge by one pixel, otherwise it drifts for reasons unknown
    st += 1.0 / resolution;

    // tile
    st = fract(st);

    //
    float aberrationOffset = map(aberrationAmt, 0.0, 100.0, 0.0, 0.1) * centerDist * PI * 0.5;

    float redOffset = mix(clamp(st.x + aberrationOffset, 0.0, 1.0), st.x, st.x);
    vec4 red = texture(selfTex, vec2(redOffset, st.y));

    vec4 green = texture(selfTex, st);

    float blueOffset = mix(st.x, clamp(st.x - aberrationOffset, 0.0, 1.0), st.x);
    vec4 blue = texture(selfTex, vec2(blueOffset, st.y));

    vec4 text = vec4(red.r, green.g, blue.b, 1.0);
    
    // premultiply texture alpha
    text.rgb = text.rgb * text.a;
    
    return text;
}


void main() {
    if (frame < 60) {
        vec2 uv = gl_FragCoord.xy / resolution;
        float r = random(uv + seed);
        fragColor = vec4(vec3(r), 1.0);
        return;
    }

    vec4 color = getImage();

    vec3 hsv = rgb2hsv(color.rgb);
    hsv[0] = mod(hsv[0] + map(hueRotation, -180.0, 180.0, -0.05, 0.05), 1.0);
    color.rgb = hsv2rgb(hsv);

    color.rgb = brightnessContrast(color.rgb);

	fragColor = color;
}
