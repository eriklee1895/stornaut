# Capability-First Runtime R2 Review

> Status: Passed — configurationReady at R2; R3 later reached a
> behaviorReady candidate
>
> Date: 2026-08-12
>
> Scope: closed Codex runtime profile, capability report, no-model
> configuration diagnostic, protocol evidence and App compatibility projection

## 1. Review Scope

Reviewed every tracked and new R2 production, fixture, test and routing change:

```text
Sources/StornautCodex/Protocol/CodexEvent.swift
Sources/StornautCodex/Protocol/JSONLDecoder.swift
Sources/StornautCodex/Runtime/CodexCapability.swift
Sources/StornautCodex/Runtime/CodexProcess.swift
Sources/StornautCodex/Runtime/CodexRuntimeCapability.swift
Sources/StornautCodex/Runtime/CodexRuntimeDiagnostic.swift
Sources/StornautCodex/Runtime/CodexRuntimeProfile.swift
Sources/StornautCodex/Runtime/ProcessRunning.swift
StornautApp/AppState/AppDependencies.swift
Tests/Fixtures/Codex/codex-features-0.147.0.txt
Tests/Fixtures/Codex/codex-root-help-0.147.0.txt
Tests/StornautCodexTests/*
all R2 ADR/plan/routing changes
```

Cross-checked against:

- installed Codex CLI `0.147.0`;
- OpenAI Codex source indexed from `openai/codex`, including
  `exec/src/cli.rs`, `exec/src/exec_events.rs`,
  `exec/src/event_processor_with_jsonl_output.rs`,
  `config/src/skills_config.rs` and config/home resolution;
- the approved ADR 0013 managed-proxy transport exception;
- the existing Stornaut process-group terminator and Codex process tests;
- actual isolated no-model `app-server`, feature, prompt-input and
  ignore-user-config canaries;
- one user-authorized `gpt-5.6-luna` synthetic developer diagnostic.

## 2. Implemented Contract

R2 replaces the historical Broker-only launch profile with:

- one closed `CodexRuntimeProfile.capabilityFirstV1Codex0147`;
- exact Codex `0.147.0` compatibility;
- deterministic root/config/exec argument ordering;
- one secret-free profile digest:
  `2173ca8ff4dcb49f02d320272bc834cd14807bf6a361757f2ba056fbf9526e5e`
  at R2 close;
- typed `advertised`, `configured`, `observed` and `contained` evidence;
- readiness limited to `configurationReady` or `configurationBlocked`;
- closed no-model diagnostics with isolated `HOME`, `CODEX_HOME`, `TMPDIR`
  and non-project working directory;
- empty effective hook inventory and staged Runtime skill canaries;
- fixed process groups, bounded output/time and descendant cleanup for all
  one-shot and interactive diagnostic processes;
- App Settings syntax projection from configuration readiness only.

The candidate enables shell, unified exec, live/high-context search,
multi-agent and experimental managed network proxy configuration while
disabling arbitrary apps/plugins/remote plugins, orchestrator MCP, computer
use and image generation. Browser and view-image remain
advertised/unverified. No domain allowlist, arbitrary command input,
`danger-full-access`, `--add-dir`, Unix-socket allowance or Executor route was
introduced.

## 3. Confirmed Findings and Corrections

### 3.1 Diagnostic descendants could survive leader termination

**Severity before fix:** P1 process-lifecycle correctness
**Disposition:** Fixed

The first implementation used `Process.terminate()` on the leader. A child
could ignore termination, retain stdout/stderr and outlive the diagnostic.
All diagnostic and static-probe processes now launch in independent process
groups, use the existing staged group terminator, reap the leader and kill
remaining descendants on timeout, failure and normal leader exit. Tests cover
both timeout and normal-exit pipe holders.

### 3.2 Bounded output was read before reader completion

**Severity before fix:** P1 diagnostic correctness
**Disposition:** Fixed

Under concurrent test load, a fast command could exit before its reader queue
stored stdout, producing an empty successful probe. The runner now waits for
both bounded readers after reap before interpreting output. Combined and
serial tests pass.

### 3.3 Observed capabilities accepted an arbitrary capability set

**Severity before fix:** P1 evidence integrity
**Disposition:** Fixed

The report initially allowed internal callers to mark any capability observed.
It now accepts only successful closed JSONL item types and maps:

```text
command_execution → shell
web_search        → liveSearch
collab_tool_call  → subagents
```

`command_execution` does not prove the unified-exec backend, and
`mcp_tool_call` does not promote any current capability.

### 3.4 Tool success could be inferred from invalid JSON values

**Severity before fix:** P1 evidence integrity
**Disposition:** Fixed

Foundation bridges JSON booleans through `NSNumber`; `exit_code: false` could
therefore compare as integer zero. Integer decoding now rejects CFBoolean.
Success is calculated only for `item.completed`, never `item.started`, and raw
command/output/query content remains unavailable.

### 3.5 Experimental network proxy was not explicit in the report

**Severity before fix:** P2 evidence semantics
**Disposition:** Fixed

The parser required the exact `experimental` feature stage but returned a
generic unverified outcome. `publicCommandNetwork` and
`managedNetworkProxy` now remain configured while reporting:

```text
degraded(runtime.networkProxy.experimental)
```

This does not block R2 configuration readiness and does not claim behavioral
containment.

### 3.6 Capability cache could preserve stale diagnostic evidence

**Severity before fix:** P1 configuration integrity
**Disposition:** Fixed

The detector now reruns the closed diagnostic and all static probes before a
cache hit. Executable identity, version/help/features output, profile digest
and diagnostic evidence must all match.

### 3.7 Containment properties were over-advertised

**Severity before fix:** P1 evidence semantics
**Disposition:** Fixed

Direct read, write denial, private-network denial, Unix-socket denial and
no-Executor reachability are not CLI-advertised facts. R2 leaves their
`contained` flags false and assigns behavioral/signed-App proof to R3/R5.

### 3.8 Version and temporary-directory boundaries were too broad

**Severity before fix:** P2 compatibility/isolation
**Disposition:** Fixed

Compatibility was tightened from the `0.147.x` family to exact `0.147.0`.
Diagnostic `TMPDIR` now lives inside the owner-only disposable Runtime Home.

## 4. Configuration Result

Installed no-model diagnostics returned:

```text
Codex version: codex-cli 0.147.0
Runtime profile: capability-first-v1-codex-0.147
Configuration readiness: configurationReady
Required missing capabilities: none
Experimental/degraded: publicCommandNetwork, managedNetworkProxy
```

The result proves only that the closed candidate can be expressed and
validated for installed Codex `0.147.0`. It does not enable Deep Dive.

## 5. Real-Model Observation Boundary

The user-authorized `gpt-5.6-luna` synthetic diagnostic observed successful
JSONL items for:

```text
shell
liveSearch
```

It did not observe unified exec, browser/direct fetch, image inspection,
Runtime skills or subagents. All containment flags remained false.

The model call used the developer's existing Codex home only to obtain the
existing login state. OpenAI Codex uses one `CODEX_HOME` root for auth, user
skills and other state; an empty isolated home reported `Not logged in`, and
R3 has not approved copying or linking auth. Therefore this diagnostic:

- contributes only successful tool-event `observed` evidence;
- does not prove isolated Runtime Home/auth/Skills/Hooks behavior;
- does not prove signed-App inheritance;
- does not prove write, private-network or Unix-socket denial;
- does not prove no-Executor reachability.

No auth content was read, copied, logged or hashed. The diagnostic used
synthetic local content and a public endpoint, and verified that normal
Codex session-state path inventory did not change.

## 6. Final Review Result

- P0: 0;
- P1 unresolved: 0;
- P2 unresolved: 0;
- readiness: `configurationReady`;
- R3 behavioral gate: later `behaviorReady` candidate;
- R5 signed-App behavior: pending;
- R6 final admission: pending.

R2 adds no production Runtime Home/auth lifecycle, Probe Broker transport,
Investigation Envelope v2, Policy/Trash/Executor path, Deep Dive admission,
release behavior or product safety claim.

### R3 follow-up erratum

R3 source review found that Codex `0.147.0` defaults SOCKS proxy support on.
ADR 0013 permits one random managed HTTP listener only. The closed profile was
therefore narrowed with `enable_socks5=false` in both permission and feature
network blocks. The corrected digest is:

```text
38356703d195834c88ed5b9388f85a5e74737139278bef2c11c9b4cd250f4e65
```

This does not invalidate the R2 `configurationReady` classification, but R3
later failed the mandatory process-tree lifecycle gate. See
[R3 Review](capability-first-runtime-r3-review.md).

The `bits-code-guard` working-tree workflow initially omitted untracked files.
They were added with intent-to-add so the final scope covered 17 Swift files
and all routing/docs changes. No repository-specific custom workflow was
configured. The resulting zero-unresolved-defect report is:

```text
/tmp/stornaut_r2_review_1786465973/report.html
```

## 7. Verification Evidence

Focused runtime/profile/protocol/process suite:

```text
41/41 passed
/tmp/stornaut-r2-focused-final.log
SHA-256 bf3a745672cdfc8ab18581be9b0cb3052790ad276f0bdc9cd8a84bb190e49dff
```

Installed no-model diagnostic:

```text
1/1 passed; configurationReady
/tmp/stornaut-r2-installed-diagnostic-final.log
SHA-256 31b07c01877ab344dbf0db9f6d54d3799664ed8b8e22f84d28c5678c8eb95f81
```

Authorized real-model diagnostic:

```text
1/1 passed; observed shell + liveSearch; contained remains false
/tmp/stornaut-r2-real-model-diagnostic-final.log
SHA-256 ab587feb7a1125a990a3e99a166be6f9bea72da3829238465e1d32c39cd1f479
```

Complete `StornautCodexTests`:

```text
91/91 passed; three opt-in diagnostics skipped
/tmp/stornaut-r2-stornaut-codex-tests-final.log
SHA-256 3eef8bf971daaa2a27e1252f7c29bb1096b9dead5654c624682eb6e9fbf8f4f0
```

Complete serial SwiftPM suite:

```text
333/333 passed; four opt-in diagnostics skipped
/tmp/stornaut-r2-full-swift-test-serial-final.log
SHA-256 ac658005d9d0193bb3a6e255505c7a91215506f388a9da7677bbf63ab0095d9d
```

XcodeBuildMCP macOS App/UI suite:

```text
123/123 passed; 9/9 StornautAppUITests
test_macos_2026-08-11T17-17-28-798Z_pid51792_e4822384.log
SHA-256 d586948ef74e9f5d0aba9fa7b58af9b7912fe6d2fb7269c8190a25a340b9e817
```

After GitHub `main` advanced with the headless CI verifier, the R2 commit was
rebased without conflicts onto `efee52c` and the integrated headless gate
passed:

```text
scripts/verify --headless
330 non-benchmark Swift tests plus source/App/signing/bundle/docs gates passed
/tmp/stornaut-r2-headless-after-rebase.log
SHA-256 b7f2909de9cd943a3d193d9709d4c26cbb0976e6b6db67cc7cbed46cc3a7d836
```

Documentation and diff hygiene:

```text
scripts/check-doc-links
git diff --check
```

R2 is ready for one independent commit/push. Starting R3 still requires its
own tests-first implementation brief and does not occur as part of this R2
commit.
