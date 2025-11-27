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
| `testUniformResponsiveness` | Verify uniform controls affect output |
| `checkEffectStructure` | Detect unused files, naming issues, leaked uniforms |
| `test_no_passthrough` | Verify filter effects modify input (not passthrough) |
| `check_alg_equiv` | Compare GLSL/WGSL algorithmic equivalence |

See [Tool Reference](docs/TOOL_REFERENCE.md) for complete input/output schemas.

## Architecture

The implementation follows a three-layer design:

1. **Core Operations** (`core-operations.js`) - Pure library functions for shader testing
2. **Browser Harness** (`browser-harness.js`) - Playwright-based browser session management
3. **MCP Server** (`server.js`) - Thin façade exposing tools over stdio

See [Architecture](docs/ARCHITECTURE.md) for details.

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

3. For AI vision features, create a `.openai` file in the project root containing your API key:
   ```bash
   echo "sk-..." > .openai
   ```

See [VS Code Integration](docs/VSCODE_INTEGRATION.md) for MCP server configuration.

## Test Harness

Run the test harness to verify the setup:

```bash
node test-harness.js [pattern] [flags]
```

See [Tool Reference](docs/TOOL_REFERENCE.md) for complete flag documentation and examples.

## Development Notes

- The browser harness launches a headless Chromium with WebGPU support
- A local HTTP server (`shaders/scripts/serve.js`) is started automatically
- Each tool call reuses the same browser session for efficiency
- Console errors from the browser are captured and included in results
- The core operations are designed to be reusable by the test suite
