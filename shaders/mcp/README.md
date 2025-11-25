# Noisemaker Shader MCP Tools

MCP (Model Context Protocol) server exposing shader testing tools for VS Code Copilot coding agents.

## Quick Start

```bash
# Install dependencies
npm install

# Test the harness
node shaders/mcp/test-harness.js basics/noise
```

## Documentation

| Document | Description |
|----------|-------------|
| [Architecture](docs/ARCHITECTURE.md) | System design and data flow |
| [VS Code Integration](docs/VSCODE_INTEGRATION.md) | Setup and configuration |
| [Agent Workflow](docs/AGENT_WORKFLOW.md) | How agents should use the tools |
| [Tool Reference](docs/TOOL_REFERENCE.md) | Complete API documentation |

## Tools

| Tool | Purpose |
|------|---------|
| `compile_effect` | Verify shader compiles cleanly |
| `render_effect_frame` | Render frame, check for monochrome output |
| `describe_effect_frame` | AI vision analysis of rendered output |
| `benchmark_effect_fps` | Measure sustained framerate |

## Architecture

The implementation follows a three-layer design:

1. **Core Operations** (`core-operations.js`) - Pure library functions for shader testing
2. **Browser Harness** (`browser-harness.js`) - Playwright-based browser session management
3. **MCP Server** (`server.js`) - Thin façade exposing tools over stdio

## Tool Examples

### `compile_effect`

Compile a shader effect and verify it compiles cleanly.

**Input:**
```json
{
  "effect_id": "basics/noise",
  "backend": "webgl2"
}
```

**Output:**
```json
{
  "status": "ok",
  "backend": "webgl2",
  "passes": [
    { "id": "basics/noise", "status": "ok" }
  ]
}
```

### `render_effect_frame`

Render a single frame and analyze if output is monochrome/blank.

**Input:**
```json
{
  "effect_id": "basics/noise",
  "test_case": {
    "time": 0,
    "resolution": [512, 512],
    "seed": 42,
    "uniforms": {}
  }
}
```

**Output:**
```json
{
  "status": "ok",
  "frame": {
    "image_uri": "data:image/png;base64,...",
    "width": 512,
    "height": 512
  },
  "metrics": {
    "mean_rgb": [0.5, 0.5, 0.5],
    "std_rgb": [0.2, 0.2, 0.2],
    "luma_variance": 0.04,
    "unique_sampled_colors": 847,
    "is_all_zero": false,
    "is_monochrome": false
  }
}
```

### `describe_effect_frame`

Render a frame and get an AI vision description.

**Input:**
```json
{
  "effect_id": "basics/noise",
  "prompt": "Describe the visual pattern and color distribution",
  "test_case": {}
}
```

**Output:**
```json
{
  "status": "ok",
  "frame": { "image_uri": "data:image/png;base64,..." },
  "vision": {
    "description": "A procedural noise pattern with smooth gradients...",
    "tags": ["noise", "gradient", "abstract", "grayscale"],
    "notes": "Pattern appears to be simplex noise with good coverage"
  }
}
```

### `benchmark_effect_fps`

Verify a shader can sustain a target framerate.

**Input:**
```json
{
  "effect_id": "basics/noise",
  "target_fps": 60,
  "duration_seconds": 5,
  "resolution": [1920, 1080],
  "backend": "webgl2"
}
```

**Output:**
```json
{
  "status": "ok",
  "backend": "webgl2",
  "achieved_fps": 58.5,
  "meets_target": false,
  "stats": {
    "frame_count": 293,
    "avg_frame_time_ms": 17.1,
    "p95_frame_time_ms": 19.2
  }
}
```

## Installation

1. Install dependencies from the project root:
   ```bash
   npm install
   cd shaders/mcp && npm install
   ```

2. Install Playwright browsers (if not already installed):
   ```bash
   npx playwright install chromium
   ```

3. For AI vision features, set your OpenAI API key:
   ```bash
   export OPENAI_API_KEY="sk-..."
   ```

## VS Code Integration

The MCP server is configured in `.vscode/settings.json`:

```json
{
  "mcp": {
    "servers": {
      "noisemaker-shader-tools": {
        "command": "node",
        "args": ["${workspaceFolder}/shaders/mcp/server.js"],
        "env": {
          "OPENAI_API_KEY": "${env:OPENAI_API_KEY}"
        }
      }
    }
  }
}
```

Once configured, the coding agent will have access to the shader testing tools. Example agent workflow:

1. Agent modifies a shader effect
2. Agent calls `compile_effect` to verify compilation
3. Agent calls `render_effect_frame` to check for visual output
4. If issues found, agent iterates on fixes
5. Agent calls `benchmark_effect_fps` to verify performance

## Testing

Run the test harness to verify the setup:

```bash
cd shaders/mcp
node test-harness.js [effect_id]
```

Example:
```bash
node test-harness.js basics/noise
node test-harness.js nd/physarum
```

## Manual Server Testing

Start the server directly:
```bash
node shaders/mcp/server.js
```

Then send JSON-RPC messages over stdin. Example:
```json
{"jsonrpc":"2.0","id":1,"method":"tools/list"}
```

## Development Notes

- The browser harness launches a headless Chromium with WebGPU support
- A local HTTP server (`shaders/scripts/serve.js`) is started automatically
- Each tool call reuses the same browser session for efficiency
- Console errors from the browser are captured and included in results
- The core operations are designed to be reusable by the test suite
