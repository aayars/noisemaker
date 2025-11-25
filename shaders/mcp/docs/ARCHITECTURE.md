# MCP Shader Tools Architecture

## Overview

The MCP shader tools system enables VS Code Copilot coding agents to test shader effects in a real browser environment. It follows a three-layer architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                    VS Code Copilot Agent                    │
│                                                             │
│  "Fix the noise shader" → compile_effect → render_effect    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼ MCP Protocol (stdio)
┌─────────────────────────────────────────────────────────────┐
│                      MCP Server Layer                       │
│                       (server.js)                           │
│                                                             │
│  - Exposes tools via JSON-RPC over stdio                    │
│  - Stateless: one request = one effect = one result         │
│  - Manages browser harness lifecycle                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Browser Harness Layer                    │
│                    (browser-harness.js)                     │
│                                                             │
│  - Launches headless Chromium with WebGPU support           │
│  - Starts local HTTP server for demo page                   │
│  - Maintains persistent browser session                     │
│  - Captures console errors                                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Core Operations Layer                     │
│                   (core-operations.js)                      │
│                                                             │
│  - compileEffect(): Compile shader, return diagnostics      │
│  - renderEffectFrame(): Render frame, compute metrics       │
│  - benchmarkEffectFps(): Measure sustained framerate        │
│  - describeEffectFrame(): AI vision analysis                │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Demo Page (Browser)                      │
│                   /demo/shaders/index.html                  │
│                                                             │
│  - Real WebGL2/WebGPU rendering context                     │
│  - Effect registry with all available effects               │
│  - Pipeline runtime with frame timing                       │
└─────────────────────────────────────────────────────────────┘
```

## Data Flow

### Tool Call Flow

1. Agent invokes tool (e.g., `compile_effect({ effect_id: "basics/noise" })`)
2. MCP server receives JSON-RPC request over stdio
3. Server delegates to browser harness
4. Harness calls core operation with Playwright page
5. Core operation interacts with demo page via `page.evaluate()`
6. Results flow back up: page → core → harness → server → agent

### Timeout Budget

All shader operations must complete within **1 second**:
- Shader compilation: < 100ms typical
- Frame render: < 16ms at 60fps
- Pixel readback: < 50ms
- Total buffer: 1000ms

## File Responsibilities

| File | Responsibility |
|------|----------------|
| `server.js` | MCP protocol handling, tool definitions, JSON-RPC |
| `browser-harness.js` | Browser lifecycle, HTTP server, session management |
| `core-operations.js` | Shader testing logic, image metrics, API calls |
| `index.js` | Public exports for external consumers |

## Design Principles

1. **Effect-centric**: One tool call tests one effect
2. **Stateless**: No state persists between tool calls (except browser session)
3. **Fast**: 1-second timeout for all operations
4. **Honest**: Return raw results; let caller decide pass/fail thresholds
5. **Reusable**: Core operations work with any Playwright page
