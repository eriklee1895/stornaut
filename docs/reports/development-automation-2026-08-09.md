# Development Automation Validation — 2026-08-09

> 状态：Passed with documented host prerequisites
>
> 范围：仓库级 XcodeBuildMCP + Peekaboo read-only Coding Agent harness

## Configuration Under Test

- XcodeBuildMCP `2.7.0`, public npm lockfile install;
- Peekaboo `3.10.0`, GitHub release archive SHA-256
  `87af985e9617b9b6bc3f21036b5cc7d42c99293bd2df614b6d4e6872162787b3`;
- Peekaboo Developer ID Team `FWJYW4S8P8`;
- project `Stornaut.xcodeproj`, scheme `Stornaut`, `Debug`, `arm64`;
- XcodeBuildMCP workflows: `macos`, `project-discovery`, `swift-package`, `coverage`;
- XcodeBuildMCP Sentry disabled;
- Peekaboo MCP allowlist: `image`, `see`, `inspect_ui`, `list`, `permissions`;
- no Peekaboo AI provider;
- Screen Recording granted; Accessibility and Event Synthesizing not granted.

## Results

| Check | Result |
| --- | --- |
| Pinned installation and checksum/signature verification | Passed |
| TraeX repository MCP discovery and server startup | Passed |
| XcodeBuildMCP MCP initialize + tools/list | Passed, exact 24-tool catalog |
| Peekaboo MCP initialize + tools/list | Passed, exact 5-tool catalog |
| XcodeBuildMCP project defaults | Passed |
| macOS Debug build-and-run | Passed |
| Bundle identifier | `com.eriklee.stornaut` |
| Peekaboo App inventory without Accessibility | Passed |
| Peekaboo PID-targeted window capture without Accessibility | Passed |
| Runtime screenshot | `2360×1520`, Retina PNG |
| Blank/uniform-image guard | Passed, luminance standard deviation `9.01` |
| App process cleanup | Passed |

The runtime screenshot remained under ignored `.derivedData/peekaboo/` and was
not added to Git because it is host-local validation evidence.

## Failure Evidence and Boundaries

During validation, both displays temporarily reported asleep. In that state:

- `CGGetActiveDisplayList` returned zero active displays;
- native `screencapture` failed;
- Peekaboo returned `No displays available for window capture`;
- XCUITest could launch Stornaut only as `Running Background` and both UI tests
  failed activation.

After the graphical session became awake/unlocked, active display count returned
to two and PID-targeted Peekaboo capture passed. No synthetic input, Accessibility
grant, Event Synthesizing grant or TCC reset was used.

Peekaboo `list windows` also returned an Accessibility permission error in one
run. The accepted default loop therefore uses:

1. XcodeBuildMCP's returned process ID;
2. Peekaboo `list apps` for launch readiness;
3. Peekaboo `image --pid ... --mode window` for capture.

This path requires only Screen Recording. `see`, `inspect_ui` and `list windows`
remain optional read-only tools and are not prerequisites.

## Conclusion

The developer harness is suitable for local Stornaut UI iteration, subject to an
awake/unlocked graphical session and user-granted Screen Recording. It does not
change product architecture, does not belong to Deep Dive Codex, and does not
replace XCUITest or `scripts/verify`.
