/*
 * WGSL fractal explorer shader (mono-only variant).
 * Removed: palette colorization, hsv colorMode, all palette uniforms
 * Output: grayscale intensity based on escape iteration
 */

struct Uniforms {
    // Contiguous vec4 packing for mono-only:
    // 0: resolution.xy, time, seed
    // 1: fractalType, symmetry, offsetX, offsetY
    // 2: centerX, centerY, zoomAmt, speed
    // 3: rotation, iterations, mode, levels
    // 4: backgroundColor.xyz, backgroundOpacity
    // 5: cutoff, (unused), (unused), (unused)
    data: array<vec4<f32>, 6>,
};

@group(0) @binding(0) var<uniform> uniforms: Uniforms;

const PI: f32 = 3.14159265359;
const TAU: f32 = 6.28318530718;

fn modulo(a: f32, b: f32) -> f32 {
    return a - b * floor(a / b);
}

fn map(value: f32, inMin: f32, inMax: f32, outMin: f32, outMax: f32) -> f32 {
    return outMin + (outMax - outMin) * (value - inMin) / (inMax - inMin);
}

fn rotate2D(st0: vec2<f32>, rot: f32, aspect: f32) -> vec2<f32> {
    var st = st0;
    let r = map(rot, 0.0, 360.0, 0.0, 2.0);
    let angle = r * PI;
    st = st - vec2<f32>(0.5 * aspect, 0.5);
    let s = sin(angle);
    let c = cos(angle);
    st = mat2x2<f32>(c, s, -s, c) * st;
    st = st + vec2<f32>(0.5 * aspect, 0.5);
    return st;
}

fn fx(z: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(pow(z.x, 3.0) - 3.0 * z.x * pow(z.y, 2.0) - 1.0, 3.0 * pow(z.x, 2.0) * z.y - pow(z.y, 3.0));
}

fn fpx(z: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(3.0 * pow(z.x, 2.0) - 3.0 * pow(z.y, 2.0), 6.0 * z.x * z.y);
}

fn divide(z1: vec2<f32>, z2: vec2<f32>) -> vec2<f32> {
    return vec2<f32>(
        (z1.x * z2.x + z1.y * z2.y) / (pow(z2.x, 2.0) + pow(z2.y, 2.0)),
        (z1.y * z2.x - z1.x * z2.y) / (pow(z2.x, 2.0) + pow(z2.y, 2.0))
    );
}

fn newton(st0: vec2<f32>, maxIter: i32, offsetX: f32, offsetY: f32, speed: f32, centerX: f32, centerY: f32, zoomAmt: f32, rotation: f32, time: f32, mode: i32, aspect: f32) -> f32 {
    var st = rotate2D(st0, rotation + 90.0, aspect);
    st = st - vec2<f32>(0.5 * aspect, 0.5);
    st = st * map(zoomAmt, 0.0, 130.0, 1.0, 0.01);
    let s = map(speed, 0.0, 100.0, 0.0, 1.0);
    let offX = map(offsetX, -100.0, 100.0, -0.25, 0.25);
    let offY = map(offsetY, -100.0, 100.0, -0.25, 0.25);
    st.x = st.x + centerY * 0.01;
    st.y = st.y + centerX * 0.01;
    var n = st;
    var iterCount = 0.0;
    var tst = vec2<f32>(0.0, 0.0);
    for (var i: i32 = 0; i < maxIter; i = i + 1) {
        tst = divide(fx(n), fpx(n));
        tst = tst + vec2<f32>(sin(time * TAU), cos(time * TAU)) * 0.1 * s;
        tst = tst + vec2<f32>(offX, offY);
        if (length(tst) < 0.001) {
            break;
        }
        n = n - tst;
        iterCount = iterCount + 1.0;
    }
    if (mode == 0) {
        if (maxIter == 0) {
            return 0.0;
        }
        return iterCount / f32(maxIter);
    } else {
        return length(n);
    }
}

fn julia(st0: vec2<f32>, zoomAmt: f32, speed: f32, offsetX: f32, offsetY: f32, rotation: f32, centerX: f32, centerY: f32, maxIter: i32, cutoff: f32, time: f32, mode: i32, aspect: f32) -> f32 {
    let zoom = map(zoomAmt, 0.0, 100.0, 2.0, 0.5);
    let speedy = map(speed, 0.0, 100.0, 0.0, 1.0);
    let s = mix(speedy * 0.05, speedy * 0.125, speedy);
    let _offsetX = map(offsetX, -100.0, 100.0, -0.5, 0.5);
    let _offsetY = map(offsetY, -100.0, 100.0, -1.0, 1.0);
    let c = vec2<f32>(sin(time * TAU) * s + _offsetX, cos(time * TAU) * s + _offsetY);
    var st = rotate2D(st0, rotation, aspect);
    st = (st - vec2<f32>(0.5 * aspect, 0.5)) * zoom;
    var z = vec2<f32>(
        st.x + map(centerX, -100.0, 100.0, 1.0, -1.0),
        st.y + map(centerY, -100.0, 100.0, 1.0, -1.0)
    );
    var iterCount = 0;
    let iterScaled = maxIter * 2;
    for (var i: i32 = 0; i < iterScaled; i = i + 1) {
        iterCount = i;
        let x = (z.x * z.x - z.y * z.y) + c.x;
        let y = (z.y * z.x + z.x * z.y) + c.y;
        if ((x * x + y * y) > 4.0) {
            break;
        }
        z.x = x;
        z.y = y;
    }
    if ((iterScaled - iterCount) < i32(cutoff)) {
        return 1.0;
    }
    if (mode == 0) {
        if (iterScaled == 0) {
            return 0.0;
        }
        return f32(iterCount) / f32(iterScaled);
    } else {
        return length(z);
    }
}

fn mandelbrot(st0: vec2<f32>, zoomAmt: f32, speed: f32, rotation: f32, centerX: f32, centerY: f32, iter: i32, time: f32, mode: i32, aspect: f32) -> f32 {
    let zoom = map(zoomAmt, 0.0, 100.0, 2.0, 0.5);
    let speedy = map(speed, 0.0, 100.0, 0.0, 1.0);
    let s = mix(speedy * 0.05, speedy * 0.125, speedy);
    var st = rotate2D(st0, rotation, aspect);
    st.y = st.y * 2.0 - 1.0;
    st.x = st.x * 2.0 - aspect;
    var z = vec2<f32>(0.0, 0.0);
    var c = zoom * st - vec2<f32>(centerX + 50.0, centerY) * 0.01;
    z = z + vec2<f32>(sin(time * TAU), cos(time * TAU)) * s;
    var i = 0.0;
    for (i = 0.0; i < f32(iter); i = i + 1.0) {
        let m = mat2x2<f32>(z.x, z.y, -z.y, z.x);
        z = m * z + c;
        if (dot(z, z) > 16.0) {
            break;
        }
    }
    if (i == f32(iter)) {
        return 1.0;
    }
    if (mode == 0) {
        return i / f32(iter);
    } else {
        return length(z) / f32(iter);
    }
}

@fragment
fn main(@builtin(position) pos: vec4<f32>) -> @location(0) vec4<f32> {
    let resolution = uniforms.data[0].xy;
    let time = uniforms.data[0].z;
    let seed = uniforms.data[0].w; // unused
    let fractalType = i32(uniforms.data[1].x);
    let symmetry = i32(uniforms.data[1].y); // unused
    let offsetX = uniforms.data[1].z;
    let offsetY = uniforms.data[1].w;
    let centerX = uniforms.data[2].x;
    let centerY = uniforms.data[2].y;
    let zoomAmt = uniforms.data[2].z;
    let speed = uniforms.data[2].w;
    let rotation = uniforms.data[3].x;
    let iterations = i32(uniforms.data[3].y);
    let mode = i32(uniforms.data[3].z);
    let levels = uniforms.data[3].w;

    let backgroundColor = uniforms.data[4].xyz;
    let backgroundOpacity = uniforms.data[4].w;
    let cutoff = uniforms.data[5].x;

    let aspect = resolution.x / resolution.y;

    var color = vec4<f32>(0.0, 0.0, 0.0, 1.0);
    var st = pos.xy / resolution.y;
    var d = 0.0;
    if (fractalType == 0) {
        d = julia(st, zoomAmt, speed, offsetX, offsetY, rotation, centerX, centerY, iterations, cutoff, time, mode, aspect);
    } else if (fractalType == 1) {
        d = newton(st, iterations, offsetX, offsetY, speed, centerX, centerY, zoomAmt, rotation, time, mode, aspect);
    } else {
        d = mandelbrot(st, zoomAmt, speed, rotation, centerX, centerY, iterations, time, mode, aspect);
    }
    if (d == 1.0) {
        color = vec4<f32>(backgroundColor, backgroundOpacity * 0.01);
    } else {
        var dd = fract(d);
        if (levels > 0.0) {
            let lev = levels + 1.0;
            dd = floor(dd * lev) / lev;
        }
        // Mono output: grayscale intensity
        color = vec4<f32>(vec3<f32>(dd), 1.0);
    }

    return color;
}
