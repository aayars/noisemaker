#version 300 es

/*
 * Feedback post-processing shader.
 * Offers the mixer blend modes alongside hue, distortion, and brightness controls for the accumulated feedback buffer.
 * Mix factors are normalized to avoid runaway amplification when combining the live mixer with the recirculated image.
 */


precision highp float;
precision highp int;

uniform sampler2D inputTex;
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
uniform int blendMode;
uniform float mixAmt;
uniform float refractAAmt;
uniform float refractBAmt;
uniform float refractADir;
uniform float refractBDir;
out vec4 fragColor;

#define PI 3.14159265359
#define TAU 6.28318530718
#define aspectRatio resolution.x / resolution.y

float map(float value, float inMin, float inMax, float outMin, float outMax) {
    return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

float blendOverlay(float a, float b) {
    return a < 0.5 ? (2.0 * a * b) : (1.0 - 2.0 * (1.0 - a) * (1.0 - b));
}

float blendSoftLight(float base, float blend) {
    return (blend<0.5)?(2.0*base*blend+base*base*(1.0-2.0*blend)):(sqrt(base)*(2.0*blend-1.0)+2.0*base*(1.0-blend));
}

vec4 cloak(vec2 st) {
    float m = map(mixAmt, 0.0, 100.0, 0.0, 1.0);
    float ra = map(refractAAmt, 0.0, 100.0, 0.0, 0.125);
    float rb = map(refractBAmt, 0.0, 100.0, 0.0, 0.125);

    vec4 leftColor = texture(inputTex, st);
    vec4 rightColor = texture(selfTex, st);

    // When the mixer is all the way to the left, we see left refracted by right
    vec2 leftUV = vec2(st);
    float rightLen = length(rightColor.rgb);
    leftUV.x += cos(rightLen * TAU) * ra;
    leftUV.y += sin(rightLen * TAU) * ra;

    vec4 leftRefracted = texture(inputTex, fract(leftUV));

    // When the mixer is all the way to the right, we see right refracted by left
    vec2 rightUV = vec2(st);
    float leftLen = length(leftColor.rgb);
    rightUV.x += cos(leftLen * TAU) * rb;
    rightUV.y += sin(leftLen * TAU) * rb;

    vec4 rightRefracted = texture(selfTex, fract(rightUV));

    // As the mixer approaches midpoint, mix the two refracted outputs using the same
    // logic as the "reflect" mode in coalesce.
    vec4 leftReflected = min(rightRefracted * rightColor / (1.0 - leftRefracted * leftColor), vec4(1.0));
    vec4 rightReflected = min(leftRefracted * leftColor / (1.0 - rightRefracted * rightColor), vec4(1.0));

    vec4 left = vec4(1.0);
    vec4 right = vec4(1.0);
    if (mixAmt < 50.0) {
        left = mix(leftRefracted, leftReflected, map(mixAmt, 0.0, 50.0, 0.0, 1.0));
        right = rightReflected;
    } else {
        left = leftReflected;
        right = mix(rightReflected, rightRefracted, map(mixAmt, 50.0, 100.0, 0.0, 1.0));
    }

    return mix(left, right, m);
}

vec4 blend(vec4 color1, vec4 color2, int mode, float factor) {
    // if only one noise is enabled, return that noise

    vec4 color;
    vec4 middle;

    float amt = map(mixAmt, 0.0, 100.0, 0.0, 1.0);

    if (mode == 0) {
        // add
        middle = min(color1 + color2, 1.0);
    } else if (mode == 2) {
        // color burn
        middle = (color2 == vec4(0.0)) ? color2 : max((1.0 - ((1.0 - color1) / color2)),  vec4(0.0));
    } else if (mode == 3) {
        // color dodge
        middle = (color2 == vec4(1.0)) ? color2 : min(color1 / (1.0 - color2), vec4(1.0));
    } else if (mode == 4) {
        // darken
        middle = min(color1, color2);
    } else if (mode == 5) {
        // difference
        middle = abs(color1 - color2);
        middle.a = max(color1.a, color2.a);
    } else if (mode == 6) {
        // exclusion
        middle = color1 + color2 - 2.0 * color1 * color2;
        middle.a = max(color1.a, color2.a);
    } else if (mode == 7) {
        // glow
        middle = (color2 == vec4(1.0)) ? color2 : min(color1 * color1 / (1.0 - color2), vec4(1.0));
    } else if (mode == 8) {
        // hard light
        middle = vec4(blendOverlay(color2.r, color1.r), blendOverlay(color2.g, color1.g), blendOverlay(color2.b, color1.b), mix(color1.a, color2.a, 0.5));
    } else if (mode == 9) {
        // lighten
        middle = max(color1, color2);
    } else if (mode == 10) {
        // mix
        middle = mix(color1, color2, 0.5);
    } else if (mode == 11) {
        // multiply
        middle = color1 * color2;
    } else if (mode == 12) {
        // negation
        middle = vec4(1.0) - abs(vec4(1.0) - color1 - color2);
        middle.a = max(color1.a, color2.a);
    } else if (mode == 13) {
        // overlay
        middle = vec4(blendOverlay(color1.r, color2.r), blendOverlay(color1.g, color2.g), blendOverlay(color1.b, color2.b), mix(color1.a, color2.a, 0.5));
    } else if (mode == 14) {
        // phoenix
        middle = min(color1, color2) - max(color1, color2) + vec4(1.0);
    } else if (mode == 15) {
        // reflect
        middle = (color1 == vec4(1.0)) ? color1 : min(color2 * color2 / (1.0 - color1), vec4(1.0));
    } else if (mode == 16) {
        // screen
        middle = 1.0 - ((1.0 - color1) * (1.0 - color2));
    } else if (mode == 17) {
        // soft light
        middle = vec4(blendSoftLight(color1.r, color2.r), blendSoftLight(color1.g, color2.g), blendSoftLight(color1.b, color2.b), mix(color1.a, color2.a, 0.5));
    } else if (mode == 18) {
        // subtract
        middle = max(color1 + color2 - 1.0, 0.0);
    }

    

    if (factor == 0.5) {
        color = middle;
    } else if (factor < 0.5) {
        factor = map(amt, 0.0, 0.5, 0.0, 1.0);
        color = mix(color1, middle, factor);
    } else if (factor > 0.5) {
        factor = map(amt, 0.5, 1.0, 0.0, 1.0);
        color = mix(middle, color2, factor);
    }

    return color;
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

vec4 getImage(vec2 st) {
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

    //st = fract((st - diff * zoom) - diff * centerDist * centerDist * distort);
    st = (st - diff * zoom) - diff * centerDist * centerDist * distort;

    //
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
    vec4 red = texture(inputTex, vec2(redOffset, st.y));

    vec4 green = texture(inputTex, st);

    float blueOffset = mix(st.x, clamp(st.x - aberrationOffset, 0.0, 1.0), st.x);
    vec4 blue = texture(inputTex, vec2(blueOffset, st.y));

    vec4 text = vec4(red.r, green.g, blue.b, 1.0);
    
    // premultiply texture alpha
    text.rgb = text.rgb * text.a;
    
    return text;
}

void main() {
    vec2 uv = gl_FragCoord.xy / resolution;
    uv.y = 1.0 - uv.y;

    vec4 color = vec4(0.0);

    if (blendMode == 100) {
        color = cloak(uv);
    } else {
        float ra = map(refractAAmt, 0.0, 100.0, 0.0, 0.125);
        float rb = map(refractBAmt, 0.0, 100.0, 0.0, 0.125);

        vec4 leftColor = texture(inputTex, uv);
        vec4 rightColor = texture(selfTex, uv);

        // refract a->b
        vec2 leftUV = vec2(uv);
        float rightLen = length(rightColor.rgb) + refractADir / 360.0;;
        leftUV.x += cos(rightLen * TAU) * ra;
        leftUV.y += sin(rightLen * TAU) * ra;

        // refract b->a
        vec2 rightUV = vec2(uv);
        float leftLen = length(leftColor.rgb) + refractBDir / 360.0;;
        rightUV.x += cos(leftLen * TAU) * rb;
        rightUV.y += sin(leftLen * TAU) * rb;

        color = blend(texture(inputTex, leftUV), getImage(rightUV), blendMode, mixAmt * 0.01);
    }

    vec3 hsv = rgb2hsv(color.rgb);
    hsv[0] = mod(hsv[0] + map(hueRotation, -180.0, 180.0, -0.05, 0.05), 1.0);
    color.rgb = hsv2rgb(hsv);

    color.rgb = brightnessContrast(color.rgb);

	fragColor = color;
}
