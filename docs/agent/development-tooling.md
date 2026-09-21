# Stornaut Development Automation

> 状态：Active
>
> 最近更新：2026-08-16
>
> 适用范围：实现 Stornaut 的本地 Coding Agent；不属于产品运行时

本仓库使用 XcodeBuildMCP 负责原生构建、测试、启动和工程查询，使用 Peekaboo 负责真实 macOS 窗口的只读截图与辅助可访问性检查。两者只增强本地开发反馈；`scripts/verify --full`、XCTest/XCUITest、产物检查和人工判断仍是本机验收真相。普通 GitHub Actions 使用 `scripts/verify --headless`，只承担不依赖图形会话的构建与回归保护。`scripts/doctor-dev-tools` 是独立的本机工具验收，不接入 headless CI，因为安装状态与 TCC 都是 host-local。

## 1. Trust Boundary

```text
Coding Agent
  ├─ XcodeBuildMCP → xcodebuild / SwiftPM / launch local Debug app
  └─ Peekaboo read-only → capture / observe current macOS UI

Stornaut.app
  └─ future capability-first Codex → direct read/Agent tools/public web + Probe Broker; no writes/Executor
```

- XcodeBuildMCP、Peekaboo、`.trae/.mcp.json` 和 `.dev-tools/` 都是仓库开发工具，不得成为 Swift package、App bundle、产品配置或 Deep Dive Codex 的依赖。
- 产品内 Codex 必须使用 Epic 1 定义的隔离配置，不能发现这些 MCP servers，也不能加载本仓库 `AGENTS.md`。
- Peekaboo 读取到的窗口标题、文本、路径和截图属于本机开发证据。不得提交包含凭据、私有路径或用户内容的截图；本地输出放在已忽略的 `.derivedData/`。
- 不自动修改 TCC。Screen Recording、Accessibility 和 Event Synthesizing 都由用户在 System Settings 决定；doctor 只读取并报告状态。
- Peekaboo `3.10.0` 的 CLI capture 会按需启动同一用户会话内、Unix socket 连接的本机 support daemon，并在空闲约 300 秒后退出。实测 `--no-remote` 的纯进程内模式可列出窗口但 capture 报 `No displays available`，因此不作为默认路径；这里不连接远端机器，也不改变五工具白名单。

## 2. Pinned Toolchain

| Tool | Pin | Distribution | Integrity / policy |
| --- | --- | --- | --- |
| XcodeBuildMCP | `2.7.0` | public npm registry, committed `package-lock.json` | MIT; repository-local `npm ci --ignore-scripts`; `sentryDisabled: true` |
| Peekaboo | `3.10.0` | signed GitHub universal tarball | MIT; archive SHA-256 `87af985e9617b9b6bc3f21036b5cc7d42c99293bd2df614b6d4e6872162787b3`; Developer ID Team `FWJYW4S8P8` |

Pinned source:

- XcodeBuildMCP: <https://github.com/getsentry/XcodeBuildMCP/tree/v2.7.0>
- Peekaboo: <https://github.com/openclaw/Peekaboo/tree/v3.10.0>

The tools are installed into ignored repository-local paths:

```text
tools/xcodebuildmcp/node_modules/
.dev-tools/peekaboo/3.10.0/
```

`tools/xcodebuildmcp/package.json` and `package-lock.json` describe a development-only installation. They do not add a Stornaut runtime dependency. `ThirdPartyNotices/README.md` therefore remains accurate for shipped code; if either tool is ever bundled or linked, that is a new dependency and license decision.

## 3. Bootstrap and Doctor

From the repository root:

```sh
scripts/bootstrap-dev-tools
scripts/doctor-dev-tools
scripts/verify-ui-runtime
```

Bootstrap behavior:

1. installs the exact XcodeBuildMCP dependency graph from `package-lock.json` using the public npm registry;
2. downloads the exact Peekaboo release archive;
3. verifies archive and extracted binary checksums;
4. verifies Peekaboo's code signature and Team ID;
5. installs no global package and modifies no macOS permission.

Doctor behavior:

1. validates repository MCP JSON and pinned versions;
2. performs an MCP `initialize` + `tools/list` handshake with both servers;
3. fails if either exact tool catalog drifts;
4. confirms XcodeBuildMCP telemetry opt-out;
5. reads Peekaboo permission state and requires Screen Recording for automated capture.

Doctor 或 capture 后短暂出现 `.dev-tools/.../peekaboo daemon run` 属于上述本机 support daemon。它不由 Stornaut App 启动，不是产品后台监控或登录启动项。

`scripts/verify-ui-runtime` 是 awake/unlocked 本机会话的端到端 smoke：先运行 doctor，再通过 XcodeBuildMCP 构建/启动真实 Debug App，以 PID 精确捕获一个 Stornaut 窗口，并检查 PNG 尺寸、文件大小和像素方差，最后终止该 App。它仍不替代 XCUITest 或 `scripts/verify`。

macOS TCC 按实际责任进程授予，不按 `peekaboo` 这个命令名保存一份全局状态。
还要区分**调用宿主**与**执行 runtime**：仓库固定的 Peekaboo `3.10.0`
默认可以选择同一用户会话里的 support daemon，此时 JSON 的
`selectedSource` 是 `bridge`；传入 `--no-remote` 后才是进程内的 `local`
runtime。判断权限时必须同时保留调用宿主与 selected runtime source，不能只写
“Terminal/Cursor 已授权”。使用下面的只读命令一次查看两侧：

```sh
scripts/peekaboo-readonly permissions status \
  --all-sources \
  --json-output
```

2026-08-11 的 Cursor-spawned shell spike 在当次 selected source 上观察到
Screen Recording 未授权、Accessibility 与 Event Synthesizing 已授权；原始记录
没有保留 `selectedSource`，因此它只证明当次命令行为，不能升级成机器全局状态或
特定 runtime 的长期权限事实。该次 spike 还观察到：

- `inspect_ui` 与当次实际执行的 `list` 子命令在缺少 Screen Recording 时仍可用；
  `list` 是包含 `apps`、`windows`、`screens`、`menubar` 等操作的命令族，必须按
  具体子命令记录结果，不能把一次成功概括为整个 `list` 只依赖 Accessibility；
- `image` 与 `see` 在当次 selected source 缺少 Screen Recording 时不可用；给
  另一个调用宿主或 runtime 授权不会自动改变该 source 的结论；
- Event Synthesizing 只是在当次 selected source 上报告 granted。无论 TCC 当时
  granted 与否，仓库只读边界始终由 `scripts/peekaboo-readonly` 的五工具白名单
  与 deny list 维持，不把“尚未授权”当作安全控制。

Missing Screen Recording is a local capability failure, not permission to open or automate System Settings.
Peekaboo capture also requires an awake, unlocked graphical session. If `CGGetActiveDisplayList` reports zero displays or native `screencapture` also fails, do not synthesize input to wake the machine; use XCUITest screenshot evidence for the unattended run and repeat Peekaboo capture after the user returns.

## 4. Repository MCP Configuration

TraeX discovers the project configuration at [`.trae/.mcp.json`](../../.trae/.mcp.json). Restart the agent session after bootstrap/config changes, then inspect `/mcp` or `/mcp verbose`.

The checked-in launchers are the canonical entrypoints:

```sh
scripts/xcodebuildmcp mcp
scripts/peekaboo-readonly mcp
```

Do not replace them with `npx ...@latest`, Homebrew state, a global binary, or a user-level MCP entry. Repository launchers enforce the tested version and policy independently of the host's package registry or global configuration.

### XcodeBuildMCP

[`.xcodebuildmcp/config.yaml`](../../.xcodebuildmcp/config.yaml) fixes:

- project `./Stornaut.xcodeproj`;
- scheme `Stornaut`;
- configuration `Debug`;
- architecture `arm64`;
- ignored derived data under `.derivedData/xcodebuildmcp`;
- workflows `macos`, `project-discovery`, `swift-package`, `coverage`;
- Sentry telemetry disabled.

The workflow set intentionally excludes simulator, device, scaffolding, debugging and UI-automation workflows. XcodeBuildMCP may build, test and launch the local macOS Debug app; all source edits still go through normal Coding Agent file tools and review.

### Peekaboo

`scripts/peekaboo-readonly` enforces both an allowlist and an explicit deny list. The MCP server must expose exactly:

```text
image
inspect_ui
list
permissions
see
```

No AI provider is configured. Do not pass analysis questions to `image` or enable `analyze`; screenshots are interpreted by the Coding Agent from returned image evidence. The following capability classes remain unavailable by default:

- clicks, typing, hotkeys, paste and pointer gestures;
- app/window/menu/space mutation;
- clipboard and dialog actions;
- arbitrary shell and agent loops;
- recording/capture sessions that persist video or frame sets.

Although `permissions` can describe permission repair, the repository rule is status-only: never use it to trigger or automate permission changes.

## 5. Validation Funnel

`scripts/verify --full` is an acceptance gate, not a debugging loop. Its UI
automation, committed-golden and standalone Debug/Release artifact stages are
intentionally expensive and often provide no additional signal for a
package-only or non-UI failure.

Every implementation checkpoint must move through the cheapest trustworthy
layers in order:

1. tests-first structural or contract gate that initially fails for the
   intended reason;
2. the narrowest affected unit/App/XCUITest suite;
3. one serialized SwiftPM regression when package code changed; when
   `scripts/verify --headless` is required, its `swiftpm-tests-serialized`
   stage owns this run and must not be duplicated as a standalone command;
4. the applicable source, headless, App-build or final-binary boundary gate;
5. independent review and reruns of only affected gates;
6. one clean uninterrupted `scripts/verify --full` when the checkpoint changes
   product behavior, App/UI, target linkage, signing, final-binary authority or
   makes a security/readiness claim.

Do not launch a full verifier while a cheaper layer is known to fail. If a
focused, headless, binary or full stage fails, diagnose and rerun only that
stage, suite or case until fixed. Then start the checkpoint's single clean
authoritative full from the beginning. Record per-stage durations in the
review report so regressions remain visible.

A prerequisite-only seam may omit full/XCUITest only when its approved
implementation brief explicitly records the substitution and the change:

- moves no concrete authority;
- changes no App/UI behavior;
- changes no Xcode target linkage or final Mach-O;
- makes no capability, containment or readiness claim;
- still passes focused gates, `scripts/verify --headless` (including its one
  serialized SwiftPM regression), the applicable targeted App build and
  independent review.

The enclosing product/security checkpoint remains responsible for the final
binary, Release, XCUITest where applicable and exactly one authoritative full.
This substitution reduces redundant host-state work; it does not weaken
no-Executor, no-Trash, Codex containment or product admission.

### UI Verification Loop

For every App/UI change, use the smallest trustworthy loop:

1. run the narrowest affected unit/XCUITest or XcodeBuildMCP build/test tool;
2. build the real `Stornaut.app` from the checked-in Xcode project;
3. launch that Debug app, not a SwiftUI preview;
4. use Peekaboo `list` to identify the actual Stornaut process/window;
5. capture the target window with `image` at native/retina scale;
6. use `see` or `inspect_ui` only when read-only accessibility structure adds useful evidence;
7. inspect the returned screenshot for layout, clipping, state, theme and requested interaction result;
8. add or update XCUITest assertions and screenshot attachments for behavior that must remain deterministic;
9. finish the product/UI checkpoint with the one clean
   `scripts/verify --full` acceptance run required by the funnel (bare
   `scripts/verify` remains an alias for compatibility).

Example local CLI checks:

```sh
scripts/xcodebuildmcp macos build-and-run
scripts/peekaboo-readonly list apps
scripts/peekaboo-readonly image --pid <build-and-run returned process ID> --mode window --retina \
  --path .derivedData/peekaboo/stornaut-window.png
```

CLI syntax can change between versions; use `scripts/xcodebuildmcp <workflow> --help` or `scripts/peekaboo-readonly <command> --help` before relying on an example.

### Evidence hierarchy

| Evidence | What it proves | What it does not prove |
| --- | --- | --- |
| XCTest / Swift Testing | domain and view-model contracts | rendered macOS window quality |
| App tests | deterministic App/view-model and snapshot-harness algorithm contracts | pixel-stable component/page rendering or live window quality |
| Committed view snapshots (full local) | component/page rendering on the recorded baseline host | cross-machine/macOS-patch portability, window chrome or navigation |
| XCUITest + `.xcresult` screenshots | repeatable interaction and Light/Dark window sanity on a live local host | headless CI portability or every desktop/TCC condition |
| Peekaboo real-window capture | what the currently launched App actually renders | CI portability or behavior assertions |
| source inspection | implementation intent | runtime visual correctness |

Peekaboo and XCUITest are local/full-verifier evidence because Screen Recording,
Automation Mode and the active desktop are host state. Ordinary GitHub-hosted CI
must not claim it ran either layer. Its portable contract is
`scripts/verify --headless`: all non-benchmark SwiftPM tests, all non-golden App
contracts, source boundaries, rule compiler, localization and
documentation/verifier checks. SwiftPM and App test actions each own their
required compilation; standalone Debug/Release, signing and bundle evidence
remain in `scripts/verify --full`. The committed pixel goldens remain in
`scripts/verify --full`: a real hosted run found broad drift between macOS
26.5.1 and 26.5.2 despite the same Xcode 26.6. Headless Swift Testing functions
run with `--no-parallel` because many cases independently exercise processes,
pipes, cancellation and workers; the full local verifier retains parallel
execution as concurrency stress. A future dedicated UI lab is a separate
security and operations decision; see
[ADR 0015](../adr/0015-headless-ci-verification.md).

The Phase C signed-App mutation is complete and sealed. `scripts/verify --full`
now ends with a non-mutating checked-receipt gate. It verifies safety-critical
source hashes and, when `STORNAUT_PHASE_C_TRASH_EVIDENCE_ROOT` is supplied,
the retained original/recovery reports, final Evidence Store and restored
residual. It never launches the Trash or recovery harness.

The former global same-user Node safe-window was deleted. Repository
verification must not enumerate, suspend, signal or terminate Chrome, Cursor,
Claude, MCP servers or other user Apps merely because they contain Node
processes. `scripts/verify-contract` rejects reintroduction of global
`pkill`/`killall`/`pgrep`/same-UID `ps` coordination. This does not weaken
ordinary product Activity policy for real cache candidates.

## 6. Upgrades and Failure Policy

Before upgrading either tool:

1. read the upstream changelog/security notes and license;
2. change one pin at a time;
3. update lockfile or release archive/binary checksums and signing identity;
4. inspect the exact MCP tool catalog;
5. preserve the Peekaboo five-tool allowlist and XcodeBuildMCP telemetry opt-out;
6. run `scripts/doctor-dev-tools` and `scripts/verify`;
7. update this document with measured behavior.

If an upstream version cannot enforce the allowlist, fails signature/integrity checks, silently enables telemetry, or requires Accessibility/Event Synthesizing for simple capture, stop and keep the prior pin. Do not weaken the repository boundary to make an upgrade pass.
