# Tool Reference

Complete reference for all MCP shader testing tools.

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
    "std_rgb": [0.18, 0.17, 0.19],
    "luma_variance": 0.042,
    "unique_sampled_colors": 847,
    "is_all_zero": false,
    "is_monochrome": false
  }
}
```

| Metric | Type | Description |
|--------|------|-------------|
| `mean_rgb` | [r, g, b] | Average color (0-1 range) |
| `std_rgb` | [r, g, b] | Color standard deviation |
| `luma_variance` | number | Brightness variation (0-1) |
| `unique_sampled_colors` | number | Distinct colors sampled |
| `is_all_zero` | boolean | True if image is pure black |
| `is_monochrome` | boolean | True if single solid color |

### Interpreting Metrics

| Condition | Likely Cause |
|-----------|--------------|
| `is_monochrome: true` | Shader outputs constant color |
| `is_all_zero: true` | Shader outputs black (no output) |
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
3. `OPENAI_API_KEY` environment variable

To set up:
```bash
# Create key file (recommended - already in .gitignore)
echo "sk-proj-..." > .openai

# Or use environment variable
export OPENAI_API_KEY="sk-proj-..."
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

- Requires `OPENAI_API_KEY` environment variable
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
| "No OpenAI API key" | Missing OPENAI_API_KEY for vision |
