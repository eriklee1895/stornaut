# Epic 0–1 Validation Report

> **Historical-evidence notice (2026-08-11):** The Broker-only/no-go decision
> below remains valid evidence for the original gate but no longer constrains
> the product. Current policy is the capability-first
> [ADR 0004](../adr/0004-codex-file-read-isolation.md): direct read, Agent tools
> and live public internet are allowed; OS write denial and Swift-only execution
> remain mandatory.

> 状态：Passed with conditional go for deterministic development
>
> 日期：2026-08-09
>
> 验证基线：`67bf83a02ee506829abd92f04d7dbb218e18cc17`
>
> 范围：Epic 0 foundation 与 Epic 1 Tasks 3–7 risk spikes

## 1. Executive Decision

**Epic 2–3 deterministic development is a conditional go.**

Stornaut may proceed with:

- Core domain models and fixture-backed persistence design;
- Quick Scan productionization in Swift;
- deterministic Review, Policy Gate and MoveToTrash foundations;
- result measurement and Cleanup Manifest design.

This is not an unconditional product or release go. The following remain
required gates:

- production space accounting must not derive reclaimable/free-space truth
  from raw APFS entry sums;
- execution must include fresh activity evidence, explicit user confirmation,
  measurement and durable Manifest creation;
- packaged-App full-scope FDA coverage remains unmeasured;
- Developer ID, hardened runtime, Gatekeeper and notarization remain Epic 9.

**Deep Dive remains no-go/paused.** Installed Codex `0.147.0` did not provide a
technically complete tool allowlist, so direct core tools/filesystem reads
cannot be proven absent. Epic 5–6 must not proceed under the current v1
Broker-only claim unless a later gate proves that boundary or the user
separately approves a normative boundary change.

## 2. Validated Environment

| Item | Observed value |
| --- | --- |
| macOS | 26.5.1, build `25F80` |
| Architecture | Apple Silicon `arm64` |
| Hardware | Apple M3 Pro, 12 cores, 36 GB RAM |
| Xcode | 26.6, build `17F113` |
| Swift | Apple Swift 6.3.3 |
| Installed Codex | `codex-cli 0.147.0` |
| App identity | `com.eriklee.stornaut` |
| Local signature | ad-hoc with explicit designated requirement |
| App Sandbox | disabled |
| Repository | `main`, `origin/main`, public MIT repository |

Observed versions are evidence from this machine, not permanent product
requirements.

## 3. Spike Decision Matrix

| Assumption | Evidence | Result | Residual risk | Owner module | Release gate |
| --- | --- | --- | --- | --- | --- |
| A real native App/Test host can provide a stable local identity | Checked-in Xcode project; SwiftPM products; App/App/UI tests; LaunchServices; bundle/signature audit; Light/Dark main and Settings screenshots | **Go for development host** | Ad-hoc identity is not Developer ID, hardened runtime or notarization; full FDA App coverage is not proven | `StornautApp`, Xcode project | Epic 9 release signing/notarization and App-context permission validation |
| GUI code can discover and characterize user Codex without a shell | Configured URL → bounded GUI `PATH` → bounded known candidates; direct `--version`/`exec --help`; generated `0.146.0`/`0.147.0` fixtures; opt-in installed diagnostic | **Go for discovery/capability reporting** | Publisher/runtime attestation absent; help proves syntax only; npm launcher can dispatch another binary | `StornautCodex/CodexLocator`, capability detector | Re-probe every runtime identity/version; do not promote syntax to behavior |
| Structured Codex process, JSONL and descendant cancellation are controllable | Fixed argv/stdin/environment; exact Schema + Swift validation; bounded JSONL/event queue; atomic process group; WNOWAIT cleanup; real static-envelope turn; concurrent spawn tests | **Go for process/protocol seam** | Ephemeral mode may initialize local state; credential/provider behavior can vary; no Broker-only claim | `StornautCodex/CodexProcess`, protocol types | Keep raw JSONL transient; revalidate Codex updates; Broker-only gate remains separate |
| Codex can be restricted to Probe Broker as its only disk evidence surface | Four bounded probes; canonical path and immutable denylist; fake typed bridge; signed-App synthetic canaries; source/help/tool-surface study | **No-go: protocol-only, direct tools/read still possible** | No complete tool allowlist; read-only sandbox is not confidentiality; one negative canary turn is insufficient | `StornautCore/ProbeBroker`, `StornautCodex/ProbeBridge` | Deep Dive stays paused until technical Broker-only enforcement or separately approved boundary change |
| Swift can scan a 460 GiB-class developer Mac within performance/memory/cancellation goals | 11 Surveyor contracts; deterministic fixture; three real root runs median ~96.2 s; post-hardening run 98.52 s; peak RSS <28 MB; producer cancellation <1 ms | **Go: continue Swift; no Rust evaluation** | APFS clone/compression/dataless/purgeable semantics make raw sums non-reclaimable; App FDA coverage unmeasured | `StornautCore/Surveyor` | Epic 3 production aggregation and App coverage; Epic 8 reconciled space accounting |
| Policy → Trash/fixed action → postflight can remain typed and fail closed | Identity/activity revalidation; native Trash receipt; no permanent-delete surface; fixed fake action; bounded output; process-group timeout; real same-volume and temporary APFS-volume probes | **Go for deterministic lifecycle foundation** | URL-based Trash has a narrow TOCTOU window; synchronous Trash has no mid-call cancellation; Undo is best effort; no real registered action approved | `StornautCore/Policy`, `StornautCore/Actions` | Epic 8 user confirmation, current activity, Manifest and measurement; per-tool ADR before any real action |

## 4. Verification Evidence

### Unified verifier

`scripts/verify` passed from a clean build after Task 7:

- SwiftPM build and 113 discovered test entries passed, with three explicit
  opt-in diagnostics skipped by default;
- Xcode App contract tests passed;
- two real XCUITest cases passed;
- independent main and Settings windows were captured in Light and Dark;
- screenshot luminance checks passed:
  - shell Light `244.95`;
  - Settings Light `244.52`;
  - shell Dark `3.61`;
  - Settings Dark `29.97`;
- App build, local signing and bundle audit passed;
- English/`zh-Hans` resources and local Markdown links passed;
- `git diff --check` passed.

During earlier Task 7 integration, full parallel tests exposed cross-runtime
pipe inheritance and cooperative-executor starvation. Both Codex and Registered
Action spawning now use `POSIX_SPAWN_CLOEXEC_DEFAULT`, explicitly mapped
standard descriptors and async timeout polling. The existing eight-way spawn
regression now includes one Registered Action alongside seven fake Codex
processes without increasing total process load.

The UI verifier completed without restarting `AutomationModeUI` or changing
TCC, Screen Recording, Accessibility or Event Synthesizing state. The
initialization phase can take about 31 seconds and emitted non-fatal LLDB
version-store warnings; this run still completed normally.

### Synthetic Surveyor refresh

Task 8 ran:

```text
swift run SurveyorBenchmark --fixture synthetic --repeat 3
```

All three runs produced identical filesystem observations:

- 1,356 entries;
- 804 regular files, 551 directories and one symlink;
- 68,167,269 logical file bytes;
- 4,349,952 allocated file bytes;
- zero permission failures and zero errors.

Elapsed times were `84.70`, `45.17` and `49.42 ms`; median was approximately
`49.42 ms`. Peak RSS remained about `9.99–10.31 MB`. The slower first run is
consistent with process/build/cache warm-up and does not change the real-machine
decision in ADR 0005.

### Platform action refresh

The opt-in Foundation Trash diagnostic passed with uniquely named disposable
fixtures:

- same-volume resulting URL and identity;
- collision-safe rename;
- controlled permission denial;
- 2,000-file synchronous move behavior;
- temporary 32 MiB APFS image using a volume-specific `.Trashes` destination;
- best-effort restore and complete temporary image cleanup.

These are CLI API observations, not packaged-App FDA/TCC evidence.

## 5. Global Constraint Audit

| Constraint | Audit result |
| --- | --- |
| Quick Scan does not call Codex | Passed; Surveyor has no `StornautCodex` dependency or model invocation |
| Codex has no write/cleanup authority | Passed at Stornaut protocol boundary; bridge rejects write/Trash/registered-action names |
| Probe Broker is the claimed only Deep Dive disk interface | **Release gate failed for current Codex runtime**; feature remains paused rather than weakening the claim |
| Denylist and Policy fail closed | Passed focused path, Unicode/case, symlink, mount, active and identity tests |
| Executor accepts only Trash or registered definitions | Passed; request serializes only path identity or registered ID + enum mode |
| Trash failure never permanently deletes | Passed structurally; no production permanent-delete API or fallback exists |
| No real destructive registered action | Passed; only `fixture.fake-cleaner` exists |
| No Rust product dependency | Passed; Swift met the measured gate |
| No telemetry/remote rule service/background/MenuBar/login item | Passed product-source search; repository XcodeBuildMCP dependency telemetry is explicitly disabled and is development tooling only |
| No raw Codex JSONL persistence | Passed source audit; JSONL is bounded in memory and normal App state receives typed/redacted events |
| No unapproved CI/release side effect | Passed; GitHub workflow remains `workflow_dispatch` only; no release/notarization action was run |
| License/dependency boundary | Passed; MIT `LICENSE` unchanged; Swift package has no external package dependency; upstream code was not copied |

Search hits for `rm -rf`, raw command fields and `history.jsonl` are adversarial
tests or marker-bound fixture cleanup, not production cleanup surfaces.

## 6. Documentation Reconciliation

Measured findings require only factual updates:

- root `README.md` still described Epic 1 Task 3 as the next task;
- PRD and architecture headers predated completion of the risk spikes;
- the handoff and roadmap need to point to this evidence gate and preserve the
  Deep Dive no-go;
- current process topology should name `POSIX_SPAWN_CLOEXEC_DEFAULT` rather
  than a historical process-local spawn mutex.

None of these corrections weakens a security, permission, privacy or Agent-tool
boundary. No user approval is required for the factual wording.

## 7. Next Development Boundary

Proceed next with a new active plan for the **deterministic subset**:

1. Epic 2 domain models and fixture-backed storage contracts;
2. Epic 3 production Surveyor aggregation and Quick Scan flow;
3. Epic 4 rules/activity protection;
4. the deterministic Epic 8 subset: Review, fresh Policy revalidation,
   MoveToTrash, measurement and Cleanup Manifest.

Do not start production Deep Dive orchestration, expose the Probe Bridge to real
Codex disk investigation, or register real destructive external actions under
this report.

## 8. Final Gate

Epic 0–1 succeeds as a risk-validation milestone:

- foundation: **go**;
- deterministic scan/action architecture: **conditional go**;
- Deep Dive under the approved Broker-only boundary: **no-go/paused**;
- release/distribution: **not evaluated**.

The correct response to the failed Codex isolation assumption is to preserve
the boundary and continue deterministic work, not to reinterpret the negative
evidence as success.

## 9. Post-Gate Documentation Lifecycle

After this report passed:

- the Epic 0–1 plan moved from `plans/active/` to `plans/completed/`;
- the active-plan index was intentionally left empty;
- `AGENTS.md`, the handoff, roadmap and document map now require a newly
  approved Epic 2–4 deterministic plan before further product implementation.

## 10. Post-Gate Code Review Correction

The final Epic 1 cross-module review found and fixed five concrete issues:
denylist coverage, structured-secret/private-key redaction, signed device
identity conversion, bounded directory probes and normal-exit Registered
Action descendant cleanup. Surveyor directory replacement now remains a
partial failure. See
[Epic 1 Final Code Review](epic-1-code-review-2026-08-09.md).

These corrections strengthen existing boundaries. They do not change the
conditional-go/no-go decision in this report.
