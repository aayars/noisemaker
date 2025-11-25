# VS Code Integration Guide

## Prerequisites

1. **Node.js 18+** installed
2. **Playwright** with Chromium browser
3. **MCP SDK** installed in project

```bash
# From project root
npm install
npx playwright install chromium
```

## Configuration

### VS Code Settings

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

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `OPENAI_API_KEY` | For vision | OpenAI API key for `describe_effect_frame` |

Set in your shell profile:
```bash
export OPENAI_API_KEY="sk-..."
```

## How It Works

1. **On first tool call**: MCP server starts, launches headless browser, loads demo page
2. **On subsequent calls**: Reuses existing browser session (fast)
3. **On VS Code shutdown**: Browser and server are cleaned up

## Verifying Setup

### Test the harness manually:

```bash
cd /path/to/py-noisemaker
node shaders/mcp/test-harness.js basics/noise
```

Expected output:
```
Starting browser harness...

=== Available Effects ===
Found 42 effects
First 10: basics/noise, basics/solid, ...

=== Testing compile_effect("basics/noise") ===
{
  "status": "ok",
  "backend": "webgl2",
  "passes": [...]
}

=== Testing render_effect_frame("basics/noise") ===
Status: ok
Metrics: { "is_monochrome": false, ... }
...
```

### Test the MCP server directly:

```bash
# Start server (blocks on stdio)
node shaders/mcp/server.js

# In another terminal, send a test request:
echo '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | node shaders/mcp/server.js
```

## Troubleshooting

### "Browser failed to launch"

Install Playwright browsers:
```bash
npx playwright install chromium
```

### "Timeout waiting for compilation"

- Check that the shader effect exists
- Verify the demo page loads at http://localhost:4173/demo/shaders/

### "OPENAI_API_KEY not set"

Only needed for `describe_effect_frame`. Other tools work without it.

### Server won't start

Check for port conflicts:
```bash
lsof -i :4173
```

Kill any existing process and retry.
