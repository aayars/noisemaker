# Agent Workflow Guide

This guide shows how a coding agent should use the MCP shader tools during development.

## Typical Workflow

### 1. After Modifying a Shader

```
Agent: [edits shaders/effects/basics/noise.js]

Agent: Let me verify the shader compiles...
→ compile_effect({ effect_id: "basics/noise" })

Response:
{
  "status": "ok",
  "backend": "webgl2",
  "passes": [{ "id": "basics/noise", "status": "ok" }]
}

Agent: Compilation successful. Let me check the visual output...
→ render_effect_frame({ effect_id: "basics/noise" })

Response:
{
  "status": "ok",
  "metrics": {
    "is_monochrome": false,
    "unique_sampled_colors": 847,
    "luma_variance": 0.042
  }
}

Agent: The shader produces varied visual output. Done.
```

### 2. Debugging a Broken Shader

```
Agent: [edits shader, introduces syntax error]
→ compile_effect({ effect_id: "basics/noise" })

Response:
{
  "status": "error",
  "message": "Compilation failed: unexpected token at line 42"
}

Agent: Syntax error on line 42. Let me fix that...
[fixes the error]
→ compile_effect({ effect_id: "basics/noise" })

Response:
{
  "status": "ok"
}
```

### 3. Investigating Visual Issues

```
Agent: The shader compiles but something looks wrong...
→ describe_effect_frame({
    effect_id: "basics/noise",
    prompt: "Does this look like smooth gradient noise? Are there any artifacts?"
  })

Response:
{
  "status": "ok",
  "vision": {
    "description": "The image shows blocky, pixelated noise rather than smooth gradients. There appear to be banding artifacts in the color transitions.",
    "tags": ["noise", "pixelated", "banding", "artifact"],
    "notes": "The noise appears to be using nearest-neighbor sampling instead of linear interpolation."
  }
}

Agent: Ah, I need to fix the texture sampling mode...
```

### 4. Performance Verification

```
Agent: Let me verify performance on this complex effect...
→ benchmark_effect_fps({
    effect_id: "nd/physarum",
    target_fps: 60,
    duration_seconds: 3
  })

Response:
{
  "status": "ok",
  "achieved_fps": 58.5,
  "meets_target": false,
  "stats": {
    "frame_count": 175,
    "avg_frame_time_ms": 17.1,
    "p95_frame_time_ms": 19.2
  }
}

Agent: Slightly below 60fps. The p95 shows some frame spikes. 
       Let me optimize the inner loop...
```

### 5. Verifying Uniform Controls Work

```
Agent: The controls don't seem to be affecting the output...
→ testUniformResponsiveness({ effect_id: "nm/worms" })

Response:
{
  "status": "error",
  "tested_uniforms": ["stride:✗", "kink:✗", "lifetime:✗"],
  "details": "No uniforms affected output"
}

Agent: None of the uniforms are working. Let me check if the 
       effect definition has `uniform:` mappings in the globals...
[checks definition.js, finds missing uniform: properties]

Agent: I need to add uniform: "uniformName" to each global...
[fixes definition.js]
→ testUniformResponsiveness({ effect_id: "nm/worms" })

Response:
{
  "status": "ok",
  "tested_uniforms": ["stride:✓", "kink:✓", "lifetime:✓"],
  "details": "Uniforms affect output"
}

Agent: All uniforms now affect the output correctly.
```

### 6. Checking Shader Organization

```
Agent: Let me verify the effect structure follows conventions...
→ checkEffectStructure({ effect_id: "nm/worms" })

Response:
{
  "status": "ok",
  "hasInlineShaders": false,
  "namingIssues": [],
  "unusedFiles": [],
  "leakedInternalUniforms": []
}

Agent: Structure looks good - no inline shaders, proper naming, 
       no unused files.
```

### 7. Verifying GLSL/WGSL Equivalence

```
Agent: Let me verify GLSL and WGSL produce equivalent results...
→ check_alg_equiv({ effect_id: "nm/worms" })

Response:
{
  "status": "ok",
  "pairs": [
    { "program": "agent", "parity": "equivalent" },
    { "program": "deposit", "parity": "equivalent" }
  ],
  "summary": "2 shader pairs checked, all equivalent"
}

Agent: Both GLSL and WGSL implementations are algorithmically equivalent.
```

### 8. Verifying Filter Effects Modify Input

```
Agent: Let me verify this filter actually modifies its input...
→ test_no_passthrough({ effect_id: "nm/sobel" })

Response:
{
  "status": "ok",
  "isFilterEffect": true,
  "similarity": 0.23,
  "details": "Filter modifies input: similarity=23.45%, diff=76.55%"
}

Agent: Good - the filter produces 76% difference from input.
```

## Decision Tree

```
Start: Agent modifies a shader file
          │
          ▼
    ┌─────────────┐
    │ compile_    │───── error ────▶ Fix syntax/semantic errors
    │ effect      │                         │
    └─────────────┘                         │
          │ ok                              │
          ▼                                 │
    ┌─────────────┐                         │
    │ render_     │───── monochrome ──▶ Fix rendering logic
    │ effect_frame│                         │
    └─────────────┘                         │
          │ varied output                   │
          ▼                                 │
    ┌─────────────┐                         │
    │ Visual      │───── issues ──────▶ describe_effect_frame
    │ OK?         │                    then fix based on feedback
    └─────────────┘                         │
          │ yes                             │
          ▼                                 │
    ┌─────────────┐                         │
    │ Performance │───── too slow ────▶ Optimize, then
    │ critical?   │                    benchmark_effect_fps
    └─────────────┘                         │
          │ no/ok                           │
          ▼                                 │
        Done ◀───────────────────────────────
```

## Tool Selection Guide

| Situation | Tool to Use |
|-----------|-------------|
| Just edited shader code | `compile_effect` |
| Shader compiles, need to verify output | `render_effect_frame` |
| Output looks wrong, need diagnosis | `describe_effect_frame` |
| Complex effect, need perf check | `benchmark_effect_fps` |
| Controls not affecting output | `testUniformResponsiveness` |
| Check file organization & naming | `checkEffectStructure` |
| Verify GLSL/WGSL produce same results | `check_alg_equiv` |
| Verify filter modifies input | `test_no_passthrough` |
| Run ALL validation tests | Test harness with `--all` flag |
| Quick sanity check | `compile_effect` only |

## Best Practices

1. **Always compile first** - Don't render if it won't compile
2. **Check metrics** - `is_monochrome: true` usually means a bug
3. **Use vision sparingly** - It's slower and costs API credits
4. **Benchmark at the end** - Only after correctness is verified
5. **Trust the numbers** - `unique_sampled_colors < 10` is suspicious

## When to Use Vision

The `describe_effect_frame` tool calls OpenAI's GPT-4o vision model. Use it when:

- **Metrics look OK but you're unsure about quality** - "Is this actually noise or just random garbage?"
- **Debugging subtle visual bugs** - "Are there banding artifacts in the gradients?"
- **Verifying expected patterns** - "Does this look like a Voronoi diagram?"
- **Checking for regressions** - "Does this match what the effect should produce?"

**Don't use it for:**
- Compilation errors (use `compile_effect`)
- Blank/monochrome detection (use `render_effect_frame` metrics)
- Performance issues (use `benchmark_effect_fps`)

**Cost consideration:** Each vision call costs ~$0.01-0.03 depending on image size. The tool is conditional on having an API key in `.openai` file.

## Effect ID Format

Effect IDs match the directory structure under `shaders/effects/`:

```
basics/noise      → shaders/effects/basics/noise.js
basics/solid      → shaders/effects/basics/solid.js
nd/physarum       → shaders/effects/nd/physarum.js
distort/warp      → shaders/effects/distort/warp.js
```
