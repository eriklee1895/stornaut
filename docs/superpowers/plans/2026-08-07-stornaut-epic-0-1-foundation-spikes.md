# Stornaut Epic 0–1 Foundation & Risk Spikes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create the smallest native Stornaut foundation that builds and tests locally, then produce executable evidence for the Codex, isolation, scan-performance, Trash, and registered-action assumptions on which the full product depends.

**Architecture:** Use a Swift Package workspace with three production targets—a native SwiftUI executable shell, a platform-agnostic domain/core library, and a Codex process/protocol library—plus two test targets. Spikes must end in tests, benchmark output, and ADRs; they must not grow into the final scanner, Agent workflow, rule base, or branded UI.

**Observed baseline, non-normative:** At plan authoring time the machine reported macOS 26.5.1 arm64, Xcode 26.6, Swift 6.3.3, and user-installed `codex-cli 0.146.0`. At execution time, rediscover and record the installed OS, architecture, Xcode, Swift, Codex path/version, and supported flags. Pin observed values in ADR evidence, not as permanent product requirements. Use Swift 6 strict concurrency, SwiftUI/AppKit/Foundation, XCTest/Swift Testing; defer SQLite until Epic 2.

## Global Constraints

- Product/App name is `Stornaut`; package and configuration prefixes use `stornaut`.
- Target the latest stable macOS and Apple Silicon only; do not add Intel or legacy compatibility work.
- Use the existing MIT `LICENSE`; do not create or publish a GitHub remote without user authorization.
- Quick Scan must never invoke Codex.
- Codex is read-only investigation infrastructure: it receives no arbitrary Shell, direct filesystem tool, Adapter, or cleanup authority.
- Probe Broker is Codex's only authorized disk-evidence interface. Production Deep Dive must technically enforce a Broker-only tool surface; a prompt or read-only filesystem sandbox is not that boundary.
- Executor accepts only `MoveToTrash` and fixed registered actions; Trash failure never falls back to permanent deletion.
- Denylist, Policy Gate, stale-evidence checks, and user approval cannot be weakened by Agent output.
- v1 is an on-demand single-window App with Overview, Scan, Investigations, and History; no MenuBarExtra or background monitor.
- Default UI language is English with `zh-Hans` support; appearance supports System, Light, and Dark.
- Complete the mapped Upstream Study Gate before implementation work in each Epic or technical topic. One study may cover multiple tasks only when its record names those tasks and the relevant source material.
- Do not introduce Rust, telemetry, cloud storage, a remote rule service, or third-party packages during Epic 0–1.

---

## Planned file map

```text
Package.swift                                  SwiftPM products, targets, strict concurrency
Sources/StornautApp/                           Minimal native shell only
Sources/StornautCore/                          Shared domain types and spike-safe interfaces
Sources/StornautCodex/                         Codex discovery, launch, JSONL and schemas
Tests/StornautCoreTests/                       Core and filesystem lifecycle tests
Tests/StornautCodexTests/                      Process, parser, cancellation and fake-runtime tests
Tests/Fixtures/Codex/                          Checked-in JSONL/schema fixtures without private data
Tests/Fixtures/Surveyor/                       Synthetic directory-tree generator inputs
Benchmarks/SurveyorBenchmark/                  Repeatable scanner benchmark executable/support
docs/adr/                                      One decision record per architecture assumption
docs/upstream-studies/                         Reference Study Gate records
scripts/verify                                 One local verification entry point
.github/workflows/ci.yml                       Build/test checks on an arm64-capable current macOS runner
```

Every production Swift file must have one primary responsibility. UI Views consume observable state and must not spawn subprocesses or perform filesystem mutations directly.

### Task 1: Repository, package, and verification skeleton

**Files:**
- Create: `.gitignore`
- Create: `Package.swift`
- Create: `Sources/StornautCore/StornautCore.swift`
- Create: `Sources/StornautCodex/StornautCodex.swift`
- Create: `Tests/StornautCoreTests/StornautCoreSmokeTests.swift`
- Create: `Tests/StornautCodexTests/StornautCodexSmokeTests.swift`
- Create: `scripts/verify`
- Create: `.github/workflows/ci.yml`
- Create: `docs/upstream-studies/epic-0-foundation.md`

**Interfaces:**
- Produces: importable `StornautCore` and `StornautCodex` modules and a `swift test` verification baseline.

- [ ] **Step 1: Complete the Epic 0 Upstream Study Gate**

Read the current ClearDisk and PureMac repository structure plus Apple Swift Package/XCTest documentation. Record exact URL, commit, license, files read, reusable ideas, non-reusable code, and the decision to keep this spike dependency-free in `docs/upstream-studies/epic-0-foundation.md` using the template from `docs/upstream-reference-matrix.md`.

- [ ] **Step 2: Initialize local version control without publishing**

Run:

```bash
git init
git branch -M main
git status --short
```

Expected: a local `main` branch, no remote, and the existing docs/LICENSE shown as untracked.

- [ ] **Step 3: Create the minimal manifest and empty targets**

Define the three production targets and two test targets so `swift test` can discover and compile tests. Set the deployment target to the latest stable macOS observed at execution time; record that value in the Epic 0 study rather than treating `macOS 26` as permanent.

- [ ] **Step 4: Write smoke tests and verify a behavioral failure**

Create tests importing `StornautCore` and `StornautCodex`, each asserting its module marker equals its public name:

```swift
import Testing
@testable import StornautCore

@Test func coreModuleIsLoadable() {
    #expect(StornautCoreModule.name == "StornautCore")
}
```

Use the corresponding `StornautCodexModule.name == "StornautCodex"` assertion in its test target.

Run: `swift test`

Expected: FAIL with an undefined or incorrect module marker, not because the manifest or test target is missing.

- [ ] **Step 5: Add the minimal Swift package**

Add public marker enums matching the smoke tests and rerun `swift test`; expected: PASS. Keep package dependencies empty and Swift 6 language mode enabled.

- [ ] **Step 6: Add one verification command and CI**

Make `scripts/verify` run, in order:

```bash
#!/bin/zsh
set -euo pipefail
swift package clean
swift build
swift test
```

Configure a dormant CI workflow for the newest available macOS runner matching the execution-time deployment target. If no matching arm64 runner exists, record that fact and keep CI manual/disabled rather than lowering the target silently. Creating this local workflow file does not authorize a remote, push, or GitHub-hosted run; local `scripts/verify` is the Epic 0 acceptance gate until the user explicitly authorizes publication.

- [ ] **Step 7: Verify and commit**

Run: `scripts/verify`

Expected: PASS with both smoke tests.

Commit:

```bash
git add .gitignore Package.swift Sources Tests scripts .github docs LICENSE README.md
git commit -m "chore: establish Stornaut foundation"
```

### Task 2: Minimal native App shell and localization seam

**Files:**
- Create: `Sources/StornautApp/StornautApp.swift`
- Create: `Sources/StornautApp/AppShell/AppDestination.swift`
- Create: `Sources/StornautApp/AppShell/RootView.swift`
- Create: `Sources/StornautApp/Settings/StornautSettingsView.swift`
- Create: `Sources/StornautApp/Resources/en.lproj/Localizable.strings`
- Create: `Sources/StornautApp/Resources/zh-Hans.lproj/Localizable.strings`
- Create: `Tests/StornautCoreTests/AppDestinationTests.swift`
- Create: `docs/adr/0001-package-first-native-shell.md`

**Interfaces:**
- Consumes: `StornautCore` module from Task 1.
- Produces: `enum AppDestination: String, CaseIterable, Identifiable, Sendable` with exactly `.overview`, `.scan`, `.investigations`, `.history`.

- [ ] **Step 1: Write the navigation contract test**

Assert the destination raw values are exactly:

```swift
["overview", "scan", "investigations", "history"]
```

and that no settings/menu-bar destination exists.

- [ ] **Step 2: Run the focused test and confirm failure**

Run: `swift test --filter AppDestinationTests`

Expected: FAIL because `AppDestination` does not exist.

- [ ] **Step 3: Implement the minimal native shell**

Create `@main struct StornautApp: App` with one uniquely identified `Window("Stornaut", id: "main")` scene and one independent `Settings` scene. The App must not expose creation of additional main windows. `RootView` uses `NavigationSplitView`, four labeled SF Symbol sidebar items, and plain placeholder content. Do not add MenuBarExtra, timers, background tasks, scan simulation, visual branding, or Agent chat.

- [ ] **Step 4: Add localization resources**

Provide English and `zh-Hans` values for the four destinations plus `Settings`, `Quick Scan`, and `Deep Dive`. Use localization keys from SwiftUI rather than user-visible literals in the view.

- [ ] **Step 5: Build and manually inspect both appearances**

Run:

```bash
swift build
swift run StornautApp
```

Expected: one native window, four sidebar destinations, Settings opened with `⌘,`, no menu-bar icon, and readable System Light/Dark appearances. Reopening or activating Stornaut reuses the single main window; File → New Window or equivalent cannot create another workspace window. Record screenshots and observed limitations in ADR 0001.

- [ ] **Step 6: Run tests and commit**

Run: `scripts/verify`

Expected: PASS.

Commit:

```bash
git add Sources/StornautApp Tests/StornautCoreTests docs/adr/0001-package-first-native-shell.md Package.swift
git commit -m "feat: add native Stornaut app shell"
```

### Task 3: Codex discovery and capability report

**Files:**
- Create: `Sources/StornautCodex/Runtime/CodexLocator.swift`
- Create: `Sources/StornautCodex/Runtime/CodexCapability.swift`
- Create: `Sources/StornautCodex/Runtime/ProcessRunning.swift`
- Create: `Tests/StornautCodexTests/CodexLocatorTests.swift`
- Create: `Tests/StornautCodexTests/CodexCapabilityTests.swift`
- Create: `Tests/Fixtures/Codex/codex-exec-help-0.146.0.txt`
- Create: `docs/upstream-studies/epic-1-codex-runtime.md`
- Create: `docs/adr/0002-codex-discovery-and-capabilities.md`

**Interfaces:**
- Produces: `CodexLocator.locate(configuredURL:environment:) async -> CodexAvailability`.
- Produces: `CodexCapabilityReport` containing executable URL, version string, and booleans for `json`, `outputSchema`, `ephemeral`, `readOnlySandbox`, `ignoreUserConfig`, and `ignoreRules`.
- Produces: injectable `ProcessRunning` protocol so tests never depend on a real Codex login.

- [ ] **Step 1: Complete the Codex Runtime Upstream Study Gate**

Read the current official Codex CLI implementation/docs for `exec`, configuration loading, JSONL events, schemas, sandbox, local tool/MCP exposure, tool-surface restriction, and cancellation. This one study explicitly covers Tasks 3–5. Re-probe and record the execution-time Codex path, version, and `codex exec --help`; `/Users/eriklee/.npm-global/bin/codex` and `0.146.0` are historical planning evidence only.

- [ ] **Step 2: Write failing locator tests**

Cover this precedence: explicit configured executable, direct Swift search of a sanitized GUI environment `PATH`, and bounded known user-local candidates. Do not launch a login shell or source user startup files. Reject directories and non-executable files; canonicalize every result. Tests use temporary fake executables and injected process output.

- [ ] **Step 3: Implement discovery without invoking a shell**

Use `FileManager.isExecutableFile(atPath:)` for explicit, PATH, and known candidates. Resolve aliases/symlinks to a canonical regular executable URL. Do not invoke any shell to discover Codex.

- [ ] **Step 4: Write failing capability parser tests**

Parse checked-in historical and execution-time `--version`/`exec --help` fixtures. The `0.146.0` fixture documents one observed baseline only. Capability decisions derive from parsed flags and proven behavior, never version equality; malformed/unknown output produces `.unsupported(reason:)` rather than optimistic defaults.

- [ ] **Step 5: Implement capability detection and cache only for the App session**

Launch fixed arguments `--version` and `exec --help`, cap stdout/stderr, and return a typed report. Do not persist compatibility forever; a changed executable identity/version triggers a new probe.

- [ ] **Step 6: Verify against fake and installed Codex**

Run unit tests, then a read-only local diagnostic executable/test that prints the typed report for the installed Codex. Do not start an Agent session. Record actual output and limitations in ADR 0002.

- [ ] **Step 7: Commit**

Run `scripts/verify`, then:

```bash
git add Sources/StornautCodex Tests/StornautCodexTests Tests/Fixtures/Codex docs
git commit -m "feat: detect user-installed Codex capabilities"
```

### Task 4: Structured Codex process, JSONL, schema, and cancellation spike

**Files:**
- Create: `Sources/StornautCodex/Runtime/CodexProcess.swift`
- Create: `Sources/StornautCodex/Runtime/ProcessTreeTerminator.swift`
- Create: `Sources/StornautCodex/Protocol/CodexEvent.swift`
- Create: `Sources/StornautCodex/Protocol/JSONLDecoder.swift`
- Create: `Sources/StornautCodex/Protocol/InvestigationEnvelope.swift`
- Create: `Sources/StornautCodex/Schemas/investigation-envelope.schema.json`
- Create: `Tests/StornautCodexTests/JSONLDecoderTests.swift`
- Create: `Tests/StornautCodexTests/CodexProcessTests.swift`
- Create: `Tests/Fixtures/Codex/success.jsonl`
- Create: `Tests/Fixtures/Codex/malformed.jsonl`
- Create: `Tests/Fixtures/Codex/fake-codex.sh`
- Create: `docs/adr/0003-codex-process-protocol.md`

**Interfaces:**
- Produces: `CodexProcess.run(_ request: CodexRunRequest) -> AsyncThrowingStream<CodexProcessEvent, Error>`.
- Produces: `CodexRunRequest` with executable, isolated working directory, schema URL, prompt data, timeout, stdout/stderr byte limits, and environment allowlist.
- Produces: `InvestigationEnvelope` with `summary`, `findings`, `unresolvedTargetIDs`, and no executable command field.

- [ ] **Step 1: Write JSONL fixture tests**

Verify fragmented lines, multiple events per chunk, UTF-8 boundary splits, unknown event preservation, malformed JSON failure, output limit failure, and final envelope decoding. No test may call the network or real Codex.

- [ ] **Step 2: Implement an incremental bounded JSONL decoder**

Buffer only the unfinished line, enforce per-line and session byte limits, and keep unknown events as bounded metadata. Never forward unbounded raw model text to UI state.

- [ ] **Step 3: Write process lifecycle tests with fake Codex**

The fake executable must support: successful JSONL, stderr noise, invalid schema output, timeout, ignored SIGTERM, and one child process. Assert cancellation closes pipes and no child PID remains after the escalation deadline.

- [ ] **Step 4: Implement a protocol-only fixed-argument launch**

Construct arguments as an array using supported capabilities:

```text
exec --ephemeral --json --output-schema <schema>
--sandbox read-only --ignore-user-config --ignore-rules
--skip-git-repo-check -C <isolated-directory> -
```

Send the prompt through stdin. Use an allowlisted environment containing only required locale, temporary-directory, authentication/config location, and executable lookup values established by the spike. Never use `sh -c`, shell interpolation, `--dangerously-bypass-approvals-and-sandbox`, or inherited project instructions. `--sandbox read-only` is necessary but insufficient: it may still expose model-generated Shell and direct reads. This Task proves process/JSONL behavior only and must not be described as a production Deep Dive sandbox.

- [ ] **Step 5: Implement cancellation escalation**

On task cancellation or timeout: close stdin, send interrupt/terminate to the process group, wait a bounded grace period, kill the process group if still alive, drain/close pipes, and return `.cancelled` or `.timedOut`. Record all transitions as typed audit events.

- [ ] **Step 6: Run one minimal real Codex schema probe**

Use an isolated temporary directory and a prompt that only returns a static schema-valid envelope without reading target files or invoking tools. Confirm JSONL parsing, final schema validation, ephemeral behavior, timeout, and cancellation. Redact identifiers from the ADR and delete raw JSONL after the run. This disposable schema probe is not evidence of Broker-only isolation.

- [ ] **Step 7: Verify and commit**

Run `scripts/verify`; expected: fake process tests pass and no orphan process remains.

Commit:

```bash
git add Sources/StornautCodex Tests/StornautCodexTests Tests/Fixtures/Codex docs/adr/0003-codex-process-protocol.md
git commit -m "feat: validate structured Codex process lifecycle"
```

### Task 5: Probe Broker and file-read isolation spike

**Files:**
- Create: `Sources/StornautCore/ProbeBroker/ProbeCapability.swift`
- Create: `Sources/StornautCore/ProbeBroker/ProbeRequest.swift`
- Create: `Sources/StornautCore/ProbeBroker/ProbeBroker.swift`
- Create: `Sources/StornautCore/Policy/CanonicalPathPolicy.swift`
- Create: `Sources/StornautCore/Policy/SensitivePathDenylist.swift`
- Create: `Sources/StornautCodex/ProbeBridge/ProbeBridge.swift`
- Create: `Sources/StornautCodex/ProbeBridge/ProbeToolSchema.swift`
- Create: `Tests/StornautCoreTests/ProbeBrokerTests.swift`
- Create: `Tests/StornautCoreTests/CanonicalPathPolicyTests.swift`
- Create: `Tests/StornautCoreTests/SensitivePathDenylistTests.swift`
- Create: `Tests/StornautCodexTests/ProbeBridgeIntegrationTests.swift`
- Create: `Tests/Fixtures/Codex/prompt-injection-readme.md`
- Create: `docs/adr/0004-codex-file-read-isolation.md`

**Interfaces:**
- Produces: `ProbeBroker.execute(_ request: ProbeRequest, in context: ProbeContext) async -> ProbeResult`.
- Produces: initial capabilities `diskSnapshot`, `directorySummary`, `largestChildren`, and `safeTextSnippet`.
- Produces: `CanonicalPathPolicy.evaluate(requestedURL:allowedRoots:) -> PathDecision` and immutable v1 denylist decisions.
- Produces: `ProbeBridge` typed local transport through which Codex can invoke only allowlisted `ProbeBroker` capabilities.

- [ ] **Step 1: Write fail-closed path-policy tests**

Cover relative traversal, symlinks leaving allowed roots, mount/root/home protection, nonexistent path parents, `.ssh`, `.gnupg`, `.env`, browser profiles, Mail, Messages, Photos Library, and case/Unicode normalization. Expected default for ambiguity is denied or unknown.

- [ ] **Step 2: Implement canonicalization and immutable denylist**

Resolve file identity without following unsafe symlinks, compare canonical path components rather than prefixes, and return typed reasons. Do not add a settings override.

- [ ] **Step 3: Write Broker budget and audit tests**

Assert capability allowlisting, root scope, per-call timeout, output bytes, session call count, L0/L1 read level, cancellation, and redacted audit summaries. A README containing prompt injection text is data and cannot alter Broker policy.

- [ ] **Step 4: Implement four in-process read-only probes**

Keep request/response schemas bounded and Codable. `safeTextSnippet` permits only approved filenames/types, reads a fixed maximum byte count, applies secret-pattern redaction, and returns no raw content to persistent audit records.

- [ ] **Step 5: Implement and test the Codex-to-Broker bridge**

Expose only the four allowlisted Probe schemas through the locally isolated transport proven available by the Codex capability study. Prove end to end with fake Codex that a typed request reaches `ProbeBroker`, returns a bounded typed result, and rejects arbitrary Shell, direct filesystem requests, unregistered tools, malformed arguments, writes, and cleanup actions. Run the same test with real Codex only if the tool surface can be safely constrained; otherwise record a no-go rather than exposing the real disk.

- [ ] **Step 6: Run the Codex isolation experiment**

Create three canary files: inside the isolated working directory, inside an allowed Broker fixture root, and outside both in a non-sensitive temporary sibling. Determine separately whether Codex can read each directly and whether macOS FDA/TCC privileges are inherited when launched from the App context. Do not use real private files as canaries. Do not grant, revoke, reset, or automate FDA/TCC permissions; record the current state, and run an alternate state only after explicit user approval and user-performed System Settings changes.

- [ ] **Step 7: Write ADR 0004 with an explicit release outcome**

Record `Broker-only technically enforced`, `protocol-only but direct tools/read still possible`, or `unsafe for claimed v1 boundary`, with exact commands, OS/Codex versions, evidence, and required PRD wording. Only the first is a go under the current design. Either other result pauses Deep Dive; present evidence and design options to the user, and continue only after a separately approved boundary change or a stronger XPC/sandbox design is proven.

- [ ] **Step 8: Verify and commit**

Run safety tests and `scripts/verify`, then:

```bash
git add Sources/StornautCore Sources/StornautCodex Tests/StornautCoreTests Tests/StornautCodexTests Tests/Fixtures/Codex docs/adr/0004-codex-file-read-isolation.md
git commit -m "feat: prove Probe Broker policy boundaries"
```

### Task 6: Swift Surveyor performance and cancellation spike

**Files:**
- Create: `Sources/StornautCore/Surveyor/ScanRequest.swift`
- Create: `Sources/StornautCore/Surveyor/PathSnapshot.swift`
- Create: `Sources/StornautCore/Surveyor/SurveyorSpike.swift`
- Create: `Benchmarks/SurveyorBenchmark/main.swift`
- Create: `Tests/StornautCoreTests/SurveyorSpikeTests.swift`
- Create: `Tests/Fixtures/Surveyor/generate-fixture.sh`
- Create: `docs/upstream-studies/epic-1-surveyor.md`
- Create: `docs/adr/0005-swift-surveyor-performance.md`

**Interfaces:**
- Produces: `SurveyorSpike.scan(_ request: ScanRequest) -> AsyncThrowingStream<PathSnapshot, Error>`.
- Produces: benchmark JSON containing OS/hardware, root description, entry count, logical/allocated bytes, elapsed time, peak memory, cancellation latency, permission failures, and error count.

- [ ] **Step 1: Complete the Surveyor Upstream Study Gate**

Study Mole, ClearDisk, kondo, and npkill for scan roots, pruning, progress, concurrency, and fixture ideas. Treat Mole as behavior-only GPL reference. Record exact snapshots and the independent Swift approach.

- [ ] **Step 2: Write correctness and cancellation tests**

Use temporary trees containing regular files, sparse files, symlinks, unreadable directories, package directories, and a nested mount-boundary simulation. Assert no symlink following, bounded concurrency, partial results, allocated/logical distinction, and cancellation completion within one second for the synthetic fixture.

- [ ] **Step 3: Implement the narrow spike scanner**

Use Foundation/POSIX metadata APIs, an explicit work queue, cooperative cancellation, and streamed snapshots. Do not implement Knowledge Base classification, Git enrichment, Spotlight, SQLite, or production resume logic in this task.

- [ ] **Step 4: Add a repeatable synthetic benchmark**

The fixture generator creates deterministic shallow, deep, and high-fanout trees under a caller-provided temporary directory. It must refuse `/`, `$HOME`, a workspace root, or an existing non-fixture directory. Benchmark cleanup removes only its validated temporary fixture.

- [ ] **Step 5: Benchmark the real Mac read-only**

Run synthetic benchmarks three times, then run a cancellable full-scope read-only benchmark on the 460GB-class machine under the current FDA/TCC state. Capture median wall time, peak memory, permission gaps, and cancellation latency. Do not persist individual private paths in the ADR. Do not grant, revoke, reset, or automate FDA/TCC; an alternate permission-state run requires explicit user approval and user-performed System Settings changes.

- [ ] **Step 6: Make the architecture decision**

ADR 0005 must choose one outcome: Swift meets the `<5 min`/memory/cancellation goal; Swift needs targeted optimization; or measured evidence justifies a separate Rust evaluation ADR. Do not introduce Rust inside this task.

- [ ] **Step 7: Verify and commit**

Run unit tests, synthetic benchmark, and `scripts/verify`, then:

```bash
git add Sources/StornautCore Benchmarks Tests/StornautCoreTests Tests/Fixtures/Surveyor docs
git commit -m "perf: validate Swift surveyor approach"
```

### Task 7: Trash and registered-action lifecycle spike

**Files:**
- Create: `Sources/StornautCore/Actions/CleanupAction.swift`
- Create: `Sources/StornautCore/Actions/ActionRegistry.swift`
- Create: `Sources/StornautCore/Actions/ActionExecutor.swift`
- Create: `Sources/StornautCore/Actions/TrashMoving.swift`
- Create: `Sources/StornautCore/Policy/ActionPolicyGate.swift`
- Create: `Tests/StornautCoreTests/ActionPolicyGateTests.swift`
- Create: `Tests/StornautCoreTests/TrashMovingTests.swift`
- Create: `Tests/StornautCoreTests/RegisteredActionTests.swift`
- Create: `Tests/Fixtures/Actions/fake-cleaner.sh`
- Create: `docs/upstream-studies/epic-1-actions.md`
- Create: `docs/adr/0006-trash-and-registered-actions.md`

**Interfaces:**
- Produces: `enum CleanupAction { case moveToTrash(PathAction); case runRegisteredAction(RegisteredActionRequest) }`.
- Produces: `ActionExecutor.preflight`, `execute`, and `postflight` lifecycle with typed results.
- Produces: `TrashMoving.trashItem(at:) async throws -> TrashedItemReceipt` backed by `FileManager.trashItem`.

- [ ] **Step 1: Complete the Actions Upstream Study Gate**

Study PureMac, ClearDisk, devklean, Pearcleaner, and Apple documentation for FDA, Trash, undo/receipts, process protection, and error handling. Observe Pearcleaner under its source-available license; do not copy restricted code.

- [ ] **Step 2: Write Policy Gate rejection tests**

Reject root, home, mount roots, symlinks, denylisted paths, changed inode/mtime/size, active paths, unregistered action IDs, and arguments not produced by a registered template. Assert Agent text cannot introduce executable or argument values.

- [ ] **Step 3: Write Trash lifecycle tests**

Use only uniquely named temporary fixtures. Cover successful move, name collision, missing item, permission error, cancellation before execution, and revalidation failure. Assert failure leaves the original item in place and never invokes a permanent-delete function.

- [ ] **Step 4: Implement Trash through an injectable adapter**

Production uses `FileManager.trashItem`; tests use a fake adapter where platform Trash is unsuitable. Return original identity, resulting Trash URL when available, timestamps, and measured bytes without claiming free space was released.

- [ ] **Step 5: Write and implement one fake registered action**

Register only a test action with fixed executable `Tests/Fixtures/Actions/fake-cleaner.sh` and enum-controlled mode arguments. Exercise preflight, dry-run, execute, timeout, postflight measurement, and partial failure. Do not register a real Homebrew/uv/pnpm destructive action in Epic 1.

- [ ] **Step 6: Perform platform behavior probes**

Using disposable temporary files only, observe same-volume Trash, a mounted disposable volume if available, large directory cancellation semantics, and permission denial. Record what can and cannot be undone in ADR 0006.

- [ ] **Step 7: Verify and commit**

Run action/safety tests and `scripts/verify`, then:

```bash
git add Sources/StornautCore Tests/StornautCoreTests Tests/Fixtures/Actions docs
git commit -m "feat: validate safe cleanup action lifecycle"
```

### Task 8: Epic 0–1 evidence gate and handoff

**Files:**
- Create: `docs/reports/epic-0-1-validation-report.md`
- Modify: `docs/architecture.md`
- Modify: `docs/PRD.md`
- Modify: `docs/coding-agent-handoff.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: ADRs 0001–0006, all tests, real benchmark outputs, and the current approved specifications.
- Produces: a go/conditional-go/no-go decision for Epic 2–3 without silently changing safety claims.

- [ ] **Step 1: Run the full verification suite from a clean build**

Run:

```bash
scripts/verify
swift run SurveyorBenchmark --fixture synthetic --repeat 3
git status --short
```

Expected: build/tests pass, benchmark emits machine-readable results, and only the intended report/doc changes remain.

- [ ] **Step 2: Audit the six spike decisions**

The report must contain a table with assumption, evidence, result, residual risk, owner module, and release gate for: App shell, Codex discovery, Codex process lifecycle, file-read isolation, Swift Surveyor performance, and Action lifecycle.

- [ ] **Step 3: Reconcile documentation with measured facts**

First write measured findings and exact proposed corrections in the validation report. If a correction weakens any security, permission, privacy, or Agent-tool boundary, stop and obtain explicit user approval before modifying PRD, architecture, or approved specifications. After approval, apply only the approved wording. Purely factual updates that do not change an approved boundary may proceed.

- [ ] **Step 4: Perform plan self-review**

Confirm every Global Constraint has a test, ADR, or explicitly deferred Epic. Search for accidental MenuBarExtra, arbitrary shell execution, raw JSONL persistence, denylist override, real destructive registered action, Rust dependency, telemetry, and remote publication.

- [ ] **Step 5: Commit the validation gate**

Commit only the validation report and non-normative factual updates until all required design decisions are approved. Commit approved specification changes separately after approval:

```bash
git add docs/reports README.md
git commit -m "docs: record Epic 0 and 1 validation results"
```

Expected final state: local commits only, no remote side effects, all tests passing, and a documented user decision requested for any failed architecture boundary.

## Plan self-review result

- Spec coverage: Epic 0 repository/app shell and all seven required Epic 1 spikes are mapped to tasks and evidence artifacts.
- Scope control: no production Knowledge Base, SQLite Evidence Store, full Quick Scan UI, Deep Dive orchestration, adapters, or real cleanup command is implemented early.
- Safety coverage: canonical paths, denylist, prompt injection, schema failure, process cancellation, stale evidence, Trash fallback, and fixed action arguments each have explicit tests.
- Type consistency: Task outputs are consumed by later tasks under the same names; UI remains separated from process/filesystem work.
- Placeholder scan: the plan contains no unspecified implementation placeholders; unavailable CI/volume conditions have explicit fail/report behavior.
