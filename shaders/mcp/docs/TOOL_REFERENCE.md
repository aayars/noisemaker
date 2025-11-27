# Tool Reference

Complete reference for all MCP shader testing tools.

---

## Test Harness CLI

The test harness provides a command-line interface for running shader tests.

### Usage

```bash
node test-harness.js <pattern> [flags]
```

### Pattern Formats

| Format | Example | Description |
|--------|---------|-------------|
| Exact | `basics/noise` | Single effect by ID |
| Glob | `"basics/*"` | Wildcard match (quote for shell) |
| Regex | `"/^basics\\//` | Regex pattern (starts with /) |

### Flags

| Flag | Description |
|------|-------------|
| `--all` | Run ALL optional tests (benchmark, uniforms, structure, alg-equiv, passthrough) |
| `--benchmark` | Run FPS test (~500ms per effect) |
| `--no-vision` | Skip AI vision validation (vision is ON by default if .openai key exists) |
| `--uniforms` | Test that uniform controls affect output |
| `--structure` | Check for unused files, naming conventions, and leaked internal uniforms |
| `--alg-equiv` | Compare GLSL/WGSL algorithmic equivalence (requires .openai key) |
| `--passthrough` | Test that filter effects do NOT pass through input unchanged |
| `--verbose` | Show additional diagnostic information |
| `--webgpu`, `--wgsl` | Use WebGPU/WGSL backend instead of WebGL2/GLSL |

### Examples

```bash
node test-harness.js basics/noise              # compile + render + vision
node test-harness.js "basics/*" --benchmark    # all basics with FPS
node test-harness.js "basics/*" --all          # all basics with ALL tests
node test-harness.js basics/noise --no-vision  # skip vision check
node test-harness.js nm/worms --uniforms       # test uniform responsiveness
node test-harness.js nm/worms --structure      # test shader organization
node test-harness.js nm/normalize --webgpu     # test WGSL backend
node test-harness.js "nm/*" --alg-equiv        # check GLSL/WGSL algorithmic equivalence
node test-harness.js "nm/*" --passthrough      # test filter effects for passthrough
```

### Default Tests

By default (no flags), the harness runs:
- **Compile**: Verify shader compiles without errors
- **Render**: Check output is not monochrome/blank/transparent
- **Vision**: AI analysis of rendered output (if .openai key exists)

### Pass/Fail Criteria

An effect **passes** only if ALL of the following are true:
- Compilation succeeded
- Rendering succeeded (not monochrome, blank, or transparent)
- Zero console errors or warnings
- Vision analysis passed (if run)
- All optional tests passed (if run)

---

## compile_effect

**Purpose**: Compile a shader effect and verify it compiles without errors.

### Input Schema

```json
{
  "effect_id": "basics/noise",
  "backend": "webgl2"
}
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `effect_id` | string | ✓ | - | Effect identifier (e.g., "basics/noise") |
| `backend` | string | | "webgl2" | "webgl2" or "webgpu" |

### Output Schema

```json
{
  "status": "ok",
  "backend": "webgl2",
  "passes": [
    { "id": "basics/noise", "status": "ok" }
  ],
  "message": "Compiled successfully"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `status` | "ok" \| "error" | Overall compilation result |
| `backend` | string | Backend used for compilation |
| `passes` | array | Per-pass compilation status |
| `message` | string | Human-readable status message |
| `console_errors` | string[] | Any console errors captured (optional) |

### Error Response

```json
{
  "status": "error",
  "backend": "webgl2",
  "passes": [
    { "id": "basics/noise", "status": "error" }
  ],
  "message": "Compilation failed: unexpected token at line 42"
}
```

---

## render_effect_frame

**Purpose**: Render a single frame and compute image metrics to detect blank/monochrome output.

### Input Schema

```json
{
  "effect_id": "basics/noise",
  "test_case": {
    "time": 0.5,
    "resolution": [512, 512],
    "seed": 42,
    "uniforms": {
      "scale": 2.0
    }
  }
}
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `effect_id` | string | ✓ | - | Effect identifier |
| `test_case.time` | number | | 0 | Time value for animation |
| `test_case.resolution` | [w, h] | | [1024, 1024] | Render resolution |
| `test_case.seed` | number | | - | Random seed |
| `test_case.uniforms` | object | | {} | Uniform value overrides |

### Output Schema

```json
{
  "status": "ok",
  "frame": {
    "image_uri": "data:image/png;base64,iVBORw0KGgo...",
    "width": 512,
    "height": 512
  },
  "metrics": {
    "mean_rgb": [0.52, 0.48, 0.51],
    "mean_alpha": 1.0,
    "std_rgb": [0.18, 0.17, 0.19],
    "luma_variance": 0.042,
    "unique_sampled_colors": 847,
    "is_all_zero": false,
    "is_all_transparent": false,
    "is_essentially_blank": false,
    "is_monochrome": false
  }
}
```

| Metric | Type | Description |
|--------|------|-------------|
| `mean_rgb` | [r, g, b] | Average color (0-1 range) |
| `mean_alpha` | number | Average alpha (0-1 range) |
| `std_rgb` | [r, g, b] | Color standard deviation |
| `luma_variance` | number | Brightness variation (0-1) |
| `unique_sampled_colors` | number | Distinct colors sampled |
| `is_all_zero` | boolean | True if image is pure black |
| `is_all_transparent` | boolean | True if alpha is 0 everywhere |
| `is_essentially_blank` | boolean | True if mean RGB < 0.01 and colors <= 10 |
| `is_monochrome` | boolean | True if single solid color |

### Interpreting Metrics

| Condition | Likely Cause |
|-----------|--------------|
| `is_monochrome: true` | Shader outputs constant color |
| `is_all_zero: true` | Shader outputs black (no output) |
| `is_all_transparent: true` | Shader outputs fully transparent pixels |
| `is_essentially_blank: true` | Shader outputs near-black with minimal variation |
| `unique_sampled_colors < 10` | Very low color diversity |
| `luma_variance < 0.001` | Nearly flat brightness |

---

## describe_effect_frame

**Purpose**: Render a frame and analyze it with AI vision for qualitative feedback.

### How It Works

1. **Render**: Calls `renderEffectFrame` to compile the shader and capture a PNG
2. **Encode**: The canvas is exported as a base64 data URI (`data:image/png;base64,...`)
3. **API Call**: Sends the image to OpenAI's GPT-4o vision model via REST API
4. **Prompt**: Combines a system prompt (requesting JSON output with description/tags/notes) with the user's custom prompt
5. **Parse**: Extracts the structured JSON response and returns it

### API Key Setup

The tool looks for an API key in this order:
1. `options.apiKey` parameter (if passed directly)
2. `.openai` file in project root (one line, just the key)

To set up:
```bash
# Create key file (already in .gitignore)
echo "sk-proj-..." > .openai
```

### Input Schema

```json
{
  "effect_id": "basics/noise",
  "prompt": "Does this look like smooth Perlin noise? Are there any visual artifacts?",
  "test_case": {
    "time": 0,
    "resolution": [512, 512]
  }
}
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `effect_id` | string | ✓ | - | Effect identifier |
| `prompt` | string | ✓ | - | Question/instruction for vision model |
| `test_case` | object | | {} | Same as render_effect_frame |

### Output Schema

```json
{
  "status": "ok",
  "frame": {
    "image_uri": "data:image/png;base64,..."
  },
  "vision": {
    "description": "The image shows smooth, organic noise patterns with gradual color transitions typical of Perlin noise.",
    "tags": ["noise", "smooth", "gradient", "organic"],
    "notes": "No visible artifacts or banding detected."
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `vision.description` | string | Detailed description of the image |
| `vision.tags` | string[] | Relevant visual tags |
| `vision.notes` | string | Additional observations (optional) |

### Effective Prompts

```
"Does this look like [expected visual]?"
"Are there any artifacts, banding, or glitches?"
"Describe the color palette and distribution."
"Is the pattern symmetric/tiled correctly?"
"Compare to typical [effect type] output."
```

### Requirements

- Requires `.openai` file in project root with API key
- Uses GPT-4o vision model by default
- Costs API credits per call

---

## benchmark_effect_fps

**Purpose**: Measure sustained framerate over a duration to verify performance.

### Input Schema

```json
{
  "effect_id": "nd/physarum",
  "target_fps": 60,
  "duration_seconds": 5,
  "resolution": [1920, 1080],
  "backend": "webgpu"
}
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `effect_id` | string | ✓ | - | Effect identifier |
| `target_fps` | number | ✓ | - | FPS threshold to meet |
| `duration_seconds` | number | | 5 | Benchmark duration |
| `resolution` | [w, h] | | current | Render resolution |
| `backend` | string | | "webgl2" | "webgl2" or "webgpu" |

### Output Schema

```json
{
  "status": "ok",
  "backend": "webgpu",
  "achieved_fps": 72.5,
  "meets_target": true,
  "stats": {
    "frame_count": 362,
    "avg_frame_time_ms": 13.8,
    "p95_frame_time_ms": 15.2
  }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `achieved_fps` | number | Actual FPS achieved |
| `meets_target` | boolean | True if achieved >= target |
| `stats.frame_count` | number | Total frames rendered |
| `stats.avg_frame_time_ms` | number | Mean frame time |
| `stats.p95_frame_time_ms` | number | 95th percentile frame time |

### Performance Thresholds

| Target | Use Case |
|--------|----------|
| 60 fps | Real-time interactive |
| 30 fps | Acceptable for complex effects |
| 10 fps | Minimum for preview |

---

## testUniformResponsiveness

**Purpose**: Verify that effect uniform controls actually affect the rendered output.

### How It Works

1. **Compile**: Loads and compiles the effect
2. **Get Globals**: Retrieves the effect's parameter definitions
3. **Baseline Render**: Renders with default uniform values
4. **Test Each Uniform**: For each numeric uniform with a range:
   - Sets the uniform to an extreme value (min or max)
   - Renders again
   - Compares output metrics to baseline
5. **Report**: Returns which uniforms affected output (✓) vs didn't (✗)

### Input Schema

```json
{
  "effect_id": "nm/worms",
  "backend": "webgl2"
}
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `effect_id` | string | ✓ | - | Effect identifier |
| `backend` | string | | "webgl2" | "webgl2" or "webgpu" |

### Output Schema

```json
{
  "status": "ok",
  "tested_uniforms": ["stride:✓", "kink:✓", "lifetime:✗"],
  "details": "Uniforms affect output"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `status` | "ok" \| "error" \| "skipped" | Test result |
| `tested_uniforms` | string[] | List of tested uniforms with pass/fail |
| `details` | string | Human-readable explanation |

### Status Values

| Status | Meaning |
|--------|---------|
| `ok` | At least one uniform affected output |
| `error` | No uniforms affected output (likely bug) |
| `skipped` | Effect has no testable numeric uniforms |

### CLI Usage

```bash
node test-harness.js nm/worms --uniforms
```

Output:
```
[nm/worms]
  ✓ compile
  ✓ render (887 colors)
  ✓ uniforms: stride:✓, kink:✓, lifetime:✓
```

---

## checkEffectStructure

**Purpose**: Analyze effect structure for naming conventions, unused shader files, leaked internal uniforms, and structural parity between GLSL and WGSL.

This tool helps enforce best practices for shader effect organization:
- Validates camelCase naming conventions across the entire effect definition
- Detects unused shader files that should be removed or integrated
- Verifies that internal uniforms (channels, time) are not exposed as UI controls
- **Enforces 1:1 structural parity between GLSL and WGSL shader programs**

### Input Schema

```json
{
  "effect_id": "nm/worms",
  "backend": "webgpu"
}
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `effect_id` | string | ✓ | - | Effect identifier |
| `backend` | string | | "webgpu" | "webgl2" or "webgpu" (determines which shader dir to scan) |

### Output Schema

```json
{
  "namingIssues": [
    { "type": "effectName", "name": "Worms", "reason": "must start with lowercase" }
  ],
  "unusedFiles": ["old_shader.wgsl", "deprecated.wgsl"],
  "leakedInternalUniforms": [],
  "splitShaderIssues": [],
  "structuralParityIssues": [
    { "type": "missing_wgsl", "program": "reduce1", "message": "GLSL program \"reduce1\" has no corresponding WGSL shader" }
  ]
}
```

| Field | Type | Description |
|-------|------|-------------|
| `namingIssues` | array | Names that violate camelCase conventions |
| `unusedFiles` | string[] | Shader files not referenced by any pass |
| `leakedInternalUniforms` | string[] | Internal uniforms (channels, time) exposed as controls |
| `splitShaderIssues` | array | Issues with .vert/.frag shader pairs (GLSL only) |
| `structuralParityIssues` | array | Missing GLSL ↔ WGSL shader pairs |

### Structural Parity Validation

Every GLSL shader program **must** have a corresponding WGSL shader file and vice versa. This enforces exact 1:1 structural parity across shader languages.

| Issue Type | Description |
|------------|-------------|
| `missing_wgsl` | GLSL program exists but corresponding WGSL shader is missing |
| `missing_glsl` | WGSL program exists but corresponding GLSL shader is missing |

**Example failure:**
```
nm/convolve:
  glsl/: convolveRender.glsl, normalizeRender.glsl, reduce1.glsl, reduce2.glsl
  wgsl/: convolve.wgsl

  ❌ structural parity issues (5):
     GLSL program "convolveRender" has no corresponding WGSL shader
     GLSL program "normalizeRender" has no corresponding WGSL shader
     GLSL program "reduce1" has no corresponding WGSL shader
     GLSL program "reduce2" has no corresponding WGSL shader
     WGSL program "convolve" has no corresponding GLSL shader
```

### Naming Convention Validation

All names must follow camelCase convention (start with lowercase, no underscores or hyphens):

| Type | Validates | Valid Example | Invalid Example |
|------|-----------|---------------|-----------------|
| `diskName` | Directory name | `erosionWorms` | `erosion_worms` (snake_case) |
| `func` | `func` property (DSL name) | `erosionWorms` | `erosion_worms` (snake_case) |
| `uniform` | `uniform` values | `wormLifetime` | `worm_lifetime` |
| `globalKey` | `globals` keys | `strideDeviation` | `stride_deviation` |
| `passInputKey` | `inputs` keys | `inputTex` | `input_texture` |
| `passOutputKey` | `outputs` keys | `fragColor` | `output_buffer` |
| `passName` | Pass `name` | `reduce1` | `reduce_1` |
| `programName` | Pass `program` | `agentMove` | `agent_move` |
| `textureName` | Texture refs | `trailTex` | `trail_tex` |

**Note**: The class `name` property (e.g., `"Worms"`) correctly uses StudlyCaps/PascalCase and is not validated.

**Special cases for texture names:**
- `global_` prefix allowed (e.g., `global_worms_state1`)
- `_` prefix allowed for internals (e.g., `_bloomDownsample`)
- Reserved: `inputTex`, `outputColor`, `fragColor`, etc.

### Internal Uniform Leaks

Internal uniforms are system-managed values that should NOT be exposed as user controls:

| Uniform | Description |
|---------|-------------|
| `channels` | Number of color channels (system-managed) |
| `time` | Animation time (system-managed) |

Note: `speed` is allowed as a user-exposed uniform since it controls animation speed.

### CLI Usage

```bash
node test-harness.js nm/worms --structure --webgpu
```

Output:
```
[nm/worms]
  ✓ no inline shaders
  ✓ naming conventions (camelCase)
  ✓ no unused shader files
  ✓ no leaked internal uniforms
  ✓ split shaders consistent
  ✓ required uniforms declared
  ✓ GLSL ↔ WGSL structural parity
  ✓ compile
  ✓ render (887 colors)
```

Summary output for multiple effects:
```
✗ Effects with naming convention issues: 15
  effectName: 12 issues
    nm/worms: "Worms" - must start with lowercase letter (not StudlyCaps/PascalCase)
    nm/blur: "Blur" - must start with lowercase letter (not StudlyCaps/PascalCase)
    ... and 10 more
  uniform: 3 issues
    nm/erosion_worms: "worm_lifetime" - contains underscore (snake_case)
    ... and 2 more

⚠ Effects with unused shader files: 3
  nm/worms: buffer_to_texture.wgsl, final_blend.wgsl
  nm/dla: dla.wgsl, init_seeds.wgsl
  nm/erosion_worms: erosion_worms.wgsl, fade_trails.wgsl

⚠ Effects with leaked internal uniforms: 1
  nm/bad_effect: channels, time

❌ EFFECTS WITH STRUCTURAL PARITY ISSUES: 1
  nm/convolve:
    GLSL program "convolveRender" has no corresponding WGSL shader
    WGSL program "convolve" has no corresponding GLSL shader
```

---

## test_no_passthrough

**Purpose**: Verify that filter effects actually modify their input rather than passing it through unchanged. Passthrough/no-op/placeholder shaders are STRICTLY FORBIDDEN.

### Input Schema

```json
{
  "effect_id": "nm/sobel",
  "backend": "webgl2"
}
```

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `effect_id` | string | ✓ | - | Effect identifier |
| `backend` | string | | "webgl2" | "webgl2" or "webgpu" |

### Output Schema

```json
{
  "status": "ok",
  "isFilterEffect": true,
  "similarity": 0.42,
  "meanDiff": 0.58,
  "details": "Filter modifies input: similarity=42.00%, diff=58.00%"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `status` | "ok" \| "error" \| "skipped" \| "passthrough" | Test result |
| `isFilterEffect` | boolean | True if effect uses inputTex |
| `similarity` | number | 0-1 similarity between input and output (1 = identical) |
| `meanDiff` | number | Mean absolute difference (0 = identical) |
| `details` | string | Human-readable result description |

### Status Values

| Status | Meaning |
|--------|---------|
| `ok` | Filter properly modifies its input |
| `passthrough` | FAIL - Output is >99% similar to input |
| `skipped` | Not a filter effect (no inputTex) |
| `error` | Test failed to execute |

### How It Works

1. Detects filter effects by looking for `inputTex` in pass inputs
2. Applies non-default uniform values to ensure effect is active
3. Captures both input texture and output texture on same frame
4. Computes similarity metric between textures
5. FAILS if similarity > 99% (indicating passthrough)

### CLI Usage

```bash
node test-harness.js "nm/*" --passthrough
```

Output:
```
[nm/sobel]
  ✓ compile
  ✓ render (512 colors)
  ✓ passthrough: Filter modifies input: similarity=23.45%, diff=76.55%

[nm/bad_filter]
  ✓ compile
  ✓ render (64 colors)
  ❌ PASSTHROUGH DETECTED: similarity=99.87% (threshold: 99%)
```

Summary:
```
=== Passthrough Test Summary ===
15 filter effects tested
✓ All filter effects modify their input
```

Or on failure:
```
❌ PASSTHROUGH EFFECTS DETECTED: 2
  nm/bad_filter: output identical to input - FORBIDDEN
  nm/placeholder: output identical to input - FORBIDDEN
```

---

## Error Responses

All tools return errors in this format:

```json
{
  "status": "error",
  "error": "Description of what went wrong"
}
```

Common errors:

| Error | Cause |
|-------|-------|
| "Effect not found" | Invalid effect_id |
| "Compilation failed" | Shader syntax/semantic error |
| "Timeout" | Operation exceeded 1 second |
| "Pipeline not available" | Demo page failed to initialize |
| "No OpenAI API key" | Missing .openai file for vision |
