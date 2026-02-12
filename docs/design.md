# ios-mitm Swift Proxy Design

## Problem Statement
Build a Swift command-line application that immediately starts an HTTP/HTTPS MITM proxy and exposes REST endpoints for listing iOS simulators and connecting them to the proxy. The app should be ready for future TLS interception, traffic capture, and UI integration but currently operates entirely in-memory (no database).

## Goals
- Provide a single binary that launches the proxy and REST API on startup (default command).
- Offer CLI utilities to inspect and control simulators (`devices list`, `devices connect`).
- Maintain an in-memory registry of simulator metadata and active proxy sessions.
- Implement a REST API for device listing, connect/disconnect, and proxy status.
- Keep architecture modular for future features: CA management, persistence, traffic replay, UI streaming.

## Non-Goals
- Persisting captured flows or metadata to disk/database.
- Implementing full TLS interception (stubs only).
- Supporting physical devices beyond basic abstraction hooks.
- Building a Web UI.

## High-Level Architecture

```
┌─────────┐   ┌─────────────┐   ┌──────────────┐
│  CLI    │ → │   App Core   │ → │   SwiftNIO    │
└─────────┘   │(config, deps)│   │ services      │
               ├─────────────┤   ├──────────────┤
               │ DeviceMgr    │   │ Proxy Server  │
               │ SessionMgr   │   │ REST API      │
               │ CA stubs     │   │ (NIO HTTP)    │
               └─────────────┘   └──────────────┘
```

Components communicate through async/await and actors to avoid data races.

## Packages & Dependencies
- Swift Package Manager (`Package.swift`).
- Dependencies: Swift Argument Parser, SwiftNIO (NIOCore, NIOPosix, NIOHTTP1), SwiftLog, Swift Collections (optional for ordered sets).

## Module Breakdown

### CLI Layer (`Sources/App/CLI`)
- Uses Argument Parser to define root command `ios-mitm`. Running without subcommands executes `RunCommand` (proxy + API).
- Subcommands:
  - `devices list`: pretty-prints current registry.
  - `devices connect <udid>`: triggers session manager (direct call) or HTTP client call to REST API for remote control.
- Shared options: `--config`, `--log-level`, `--proxy-port`, `--api-port`.

### Config (`Sources/App/Config`)
- `AppConfig` struct with defaults (proxy port 8081, API port 8080, simulator poll interval, certificates path placeholders).
- Loads from JSON/YAML if provided, merges environment overrides (`IOS_MITM_*`).
- Validates port ranges and intervals on startup; failure aborts launch.

### Logging (`Sources/App/Logging`)
- Simple wrapper around SwiftLog using `LoggingSystem.bootstrap`. Converts CLI log-level string to `Logger.Level`.
- Provides contextual logger injection to other services.

### Device Management (`Sources/App/Devices`)
- `Device` struct: `id`, `name`, `runtime`, `state`, `connected`, `proxyPort`, `lastSeen`.
- `SimulatorDiscoverer`: spawns `xcrun simctl list --json devices`, decodes JSON with `Codable`.
- `DeviceRegistry` actor:
  - Maintains `[String: Device]` map.
  - Poll loop task refreshes records every `pollInterval` seconds, emitting change notifications via `AsyncStream`.
  - Provides `list()` async method for API/CLI, `markConnected(id, port)` for session manager.

### Session Management (`Sources/App/Sessions`)
- `ProxySession` struct: `id`, `deviceID`, `port`, `state`, `startedAt`.
- `SessionManager` actor:
  - Tracks active sessions per device.
  - Allocates proxy ports (configurable base + increment or ephemeral via `NWEndpoint.Port.allocate`).
  - Interfaces with simulator helper to set proxy settings (future stub hooking into `simctl` commands).
  - Provides `connect(deviceID, options)`, `disconnect(deviceID)`.

### Proxy Service (`Sources/App/Proxy`)
- Built with SwiftNIO `ServerBootstrap` on configured port.
- Handles HTTP proxy semantics: request parsing, CONNECT tunneling, simple forwarding for now.
- Exposes `start()`/`stop()` methods; accepts `SessionTap` closures for future recording.
- Associates incoming sockets with device sessions via connection metadata (e.g., per-port mapping from `SessionManager`).

### REST API (`Sources/App/API`)
- NIO HTTP server (can use `NIOHTTP1Server`).
- Routes:
  - `GET /devices`: respond with registry list JSON.
  - `POST /devices/{id}/connect`: parse options, invoke session manager.
  - `POST /devices/{id}/disconnect`.
  - `GET /proxy/status`: includes uptime, listener ports, counts.
- JSON encoding via `JSONEncoder` (SnakeCase to keep API consistent).

### CA Placeholder (`Sources/App/CA`)
- `CertificateAuthority` protocol with stub methods (`ensureRootCA()`, `issueCert(hostname)`), returning placeholder data until TLS MITM implemented.

## Runtime Workflows

### Startup
1. CLI parses args, loads config, initializes logger.
2. Build `AppContext` (device registry, session manager, proxy server, API server, CA stub).
3. Launch proxy server immediately.
4. Start REST API server.
5. Start simulator poller task and session cleanup task.
6. Await `SIGINT`/`SIGTERM`; on signal cancel child tasks and close servers.

### Device Connect Flow
1. REST POST or CLI command calls `SessionManager.connect(deviceID)`.
2. Session manager checks registry, ensures device available, assigns proxy port, updates `DeviceRegistry`.
3. (Future) Invokes simulator helper to configure HTTP/HTTPS proxy settings on that simulator.
4. Returns session info; REST responds with JSON.

### Shutdown
1. Cancel poller and session tasks (actors handle deinit).
2. Close API server channel and proxy listener gracefully (drain existing connections within timeout).
3. Log summary of active sessions shut down.

## Data Models (initial)

```
struct Device {
    let id: String
    let name: String
    let runtime: String
    let state: SimulatorState
    var connected: Bool
    var proxyPort: Int?
    var lastSeen: Date
}

struct ProxySession {
    let id: UUID
    let deviceID: String
    let port: Int
    var state: SessionState
    let startedAt: Date
}
```

Enums `SimulatorState` and `SessionState` describe lifecycle (e.g., `.booted`, `.shutdown`, `.connecting`).

## Concurrency & Error Handling
- `DeviceRegistry` and `SessionManager` defined as actors to synchronize shared state.
- Proxy and API servers run on their own `MultiThreadedEventLoopGroup` (shared where possible). Use structured tasks `Task { await proxy.start() }` etc.
- Errors bubble to root via `async let`/`await`; fatal server errors trigger shutdown.
- Provide clear error types (`DeviceError`, `SessionError`) for API responses.

## Observability
- Structured logs include subsystem labels (`proxy`, `api`, `devices`).
- `/proxy/status` surfaces metrics without full telemetry yet.
- Hooks for future tracing/metrics exporters.

## Future Extensions
- Implement real TLS MITM with custom CA + per-host cert caching.
- Persist flows to disk or SQLite, exposing queries.
- Add WebSocket stream for live UI.
- Support physical devices (USB) once `libimobiledevice` bindings integrated.
- Add rule engine for breakpoints, rewrites, scripting.

This design keeps the initial scope lightweight while ensuring clean seams for the heavier features planned later.
