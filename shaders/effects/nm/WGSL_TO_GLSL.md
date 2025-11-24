# WGSL to GLSL Conversion Guide

This document describes the patterns used to convert WGSL compute shaders to GLSL ES 300 fragment shaders for the nm effects.

## Syntax Conversions

### 1. For Loops

**WGSL:**
```wgsl
for (i : i32 = 0; i < 10; i = i + 1) {
    // loop body
}
```

**GLSL:**
```glsl
for (int i = 0; i < 10; i = i + 1) {
    // loop body
}
```

### 2. Variable Declarations

**WGSL:**
```wgsl
let value : f32 = 1.0;
var mutable : f32 = 2.0;
```

**GLSL:**
```glsl
const float value = 1.0;  // or just: float value = 1.0;
float mutable = 2.0;
```

### 3. Function Signatures

**WGSL:**
```wgsl
fn compute_noise(coord : vec3<f32>, freq : f32) -> f32 {
    return 0.0;
}
```

**GLSL:**
```glsl
float compute_noise(vec3 coord, float freq) {
    return 0.0;
}
```

### 4. Type Annotations

**WGSL:**
```wgsl
let v : vec3<f32> = vec3<f32>(1.0, 2.0, 3.0);
let u : vec3<u32> = vec3<u32>(1u, 2u, 3u);
```

**GLSL:**
```glsl
vec3 v = vec3(1.0, 2.0, 3.0);
uvec3 u = uvec3(1u, 2u, 3u);
```

### 5. Bitcast Operations

**WGSL:**
```wgsl
bitcast<u32>(float_value)
bitcast<f32>(uint_value)
```

**GLSL:**
```glsl
floatBitsToUint(float_value)
uintBitsToFloat(uint_value)
```

### 6. Array Declarations

**WGSL:**
```wgsl
var samples : array<vec3<f32>, 4>;
```

**GLSL:**
```glsl
vec3 samples[4];
```

## Semantic Conversions

### 1. Compute vs Fragment Shader Entry Point

**WGSL (Compute Shader):**
```wgsl
@compute @workgroup_size(8, 8, 1)
fn main(@builtin(global_invocation_id) gid : vec3<u32>) {
    let x = gid.x;
    let y = gid.y;
    // ...
}
```

**GLSL (Fragment Shader):**
```glsl
out vec4 fragColor;

void main() {
    uvec3 global_id = uvec3(uint(gl_FragCoord.x), uint(gl_FragCoord.y), 0u);
    uint x = global_id.x;
    uint y = global_id.y;
    // ...
}
```

### 2. Texture Sampling

**WGSL:**
```wgsl
@group(0) @binding(0) var input_texture : texture_2d<f32>;

let color = textureLoad(input_texture, vec2<i32>(x, y), 0);
```

**GLSL:**
```glsl
uniform sampler2D input_texture;

vec4 color = texelFetch(input_texture, ivec2(x, y), 0);
```

### 3. Output

**WGSL (to storage buffer):**
```wgsl
@group(0) @binding(1) var<storage, read_write> output_buffer : array<f32>;

output_buffer[index + 0u] = red;
output_buffer[index + 1u] = green;
output_buffer[index + 2u] = blue;
output_buffer[index + 3u] = alpha;
```

**GLSL (fragment output):**
```glsl
out vec4 fragColor;

fragColor = vec4(red, green, blue, alpha);
```

### 4. Uniforms

**WGSL:**
```wgsl
struct Params {
    width : f32,
    height : f32,
    amount : f32,
};

@group(0) @binding(2) var<uniform> params : Params;

let w = params.width;
let h = params.height;
```

**GLSL:**
```glsl
uniform float width;
uniform float height;
uniform float amount;

float w = width;
float h = height;
```

## Type Correspondences

| WGSL Type | GLSL Type | Notes |
|-----------|-----------|-------|
| `f32` | `float` | |
| `i32` | `int` | |
| `u32` | `uint` | |
| `vec2<f32>` | `vec2` | |
| `vec3<f32>` | `vec3` | |
| `vec4<f32>` | `vec4` | |
| `vec2<i32>` | `ivec2` | |
| `vec3<i32>` | `ivec3` | |
| `vec4<i32>` | `ivec4` | |
| `vec2<u32>` | `uvec2` | |
| `vec3<u32>` | `uvec3` | |
| `vec4<u32>` | `uvec4` | |
| `mat2x2<f32>` | `mat2` | |
| `mat3x3<f32>` | `mat3` | |
| `mat4x4<f32>` | `mat4` | |

## Common Pitfalls

### 1. Vector Type Mismatches

**Wrong:**
```glsl
vec3 v = input * 1664525u;  // Error: vec3 can't hold uint operations
```

**Correct:**
```glsl
uvec3 v = input * 1664525u;  // uvec3 for uint arithmetic
```

### 2. Texture Coordinates

WGSL and GLSL have different conventions for texture sampling. Make sure to use appropriate functions:
- `textureLoad` (WGSL) → `texelFetch` (GLSL) for integer coords
- `textureSample` (WGSL) → `texture` (GLSL) for normalized coords

### 3. Array Initialization

**WGSL:**
```wgsl
var arr : array<f32, 3> = array<f32, 3>(1.0, 2.0, 3.0);
```

**GLSL:**
```glsl
float arr[3] = float[3](1.0, 2.0, 3.0);
// or
float arr[3];
arr[0] = 1.0;
arr[1] = 2.0;
arr[2] = 3.0;
```

## Verification Checklist

When converting WGSL to GLSL, verify:

- [ ] No WGSL decorators (`@group`, `@binding`, `@compute`, etc.)
- [ ] All for-loops use GLSL syntax
- [ ] All function signatures use GLSL syntax (return type first)
- [ ] All variable declarations use GLSL syntax (type first)
- [ ] Vector types match their usage (vec/ivec/uvec)
- [ ] Proper fragment shader output (`out vec4 fragColor`)
- [ ] Texture sampling uses GLSL built-ins
- [ ] Bitcast operations converted to GLSL equivalents
- [ ] No type annotations in vec constructors (`vec3(...)` not `vec3<f32>(...)`)
- [ ] Proper GLSL ES 300 header (`#version 300 es`)
- [ ] Precision qualifiers included (`precision highp float;`)
