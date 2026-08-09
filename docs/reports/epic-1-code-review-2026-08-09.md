# Epic 1 Final Code Review — 2026-08-09

> 状态：All confirmed findings fixed and verified
>
> 范围：`dfbd034..cb89ee0`，Epic 1 Tasks 3–8
>
> 方法：`bits-code-guard` 7 维度 review + 跨模块调用链复核

## Review Scope

- 80 changed files, 53 reviewable text/source files;
- approximately 14,860 changed lines;
- Codex discovery/capability/process/protocol;
- Probe Broker/path policy/denylist;
- Swift Surveyor and benchmark;
- Policy/Trash/Registered Action lifecycle;
- App diagnostics/UI harness and cross-cutting tests.

完整本地可视化报告：

- `file:///tmp/stornaut_epic1_review_20260809/report.html`
- `file:///tmp/stornaut_epic1_review_20260809/report.md`

这些临时 HTML/Markdown 是本机 review artifact，不提交仓库。

## Confirmed Findings and Fixes

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P0 | Immutable denylist omitted PRD-required Keychains/password managers, cloud credentials and common private-key/credential files; parent metadata probes could still reveal denied children | Expanded immutable component/file policy; directory probes now filter denied children; Action Policy uses the same denylist | 25 sensitive-directory cases, 21 credential/private-file cases, Action Policy parameterized rejection, bounded directory probe test |
| P0 | L1 redaction leaked quoted JSON/TOML/YAML secrets and complete/incomplete private-key blocks | Fail-closed value-line redaction, token-prefix redaction, Authorization redaction and private-key block redaction | Structured JSON/TOML, AWS, GitHub, Bearer and truncated PEM fixture |
| P1 | `UInt64(st_dev)` could trap on signed APFS device bit patterns | Shared bit-pattern conversion and descriptor comparison | `dev_t(-1) == UInt64.max` policy regression; Surveyor signed-device regression retained |
| P1 | Directory probes allocated for the full directory before applying limits; timeout cancellation could wait for synchronous enumeration | GCD-backed probe operation, explicit cancellation control, summary stops at `limit + 1`, top-N retains at most N entries, overflow/error checks | call timeout/cancellation suite, 8-entry/limit-4 bounded directory test |
| P1 | Registered Action reaped a normally exiting leader before checking descendants, allowing a pipe-holding child to hang the runner | Moved shared process-group terminator into `StornautCore`; use `waitid(WNOWAIT)`, terminate remaining group members, then reap | normal-exit child fixture plus existing timeout parent/child tests |

## Additional Hardening

- Surveyor now treats a directory identity replacement after scheduling as a
  per-path `.metadataUnavailable` partial result instead of aborting valid
  siblings.
- Process-tree termination blocking sleeps run on a dedicated GCD queue rather
  than Swift's cooperative executor.
- Registered Action propagates launch, output-read and termination failures as
  typed `ActionExecutionError` values.

## Verification

- Focused policy/Broker/process/Surveyor suites passed.
- Full SwiftPM suite passed with 119 discovered entries and no surviving fake
  process.
- Unified `scripts/verify` passed:
  - 119 SwiftPM entries;
  - App contract tests;
  - two XCUITest cases;
  - Light/Dark main and Settings screenshots;
  - local signing, bundle, localization, docs and diff checks.
- Three refreshed synthetic benchmarks produced identical 1,356-entry and byte
  totals in approximately `45.00–48.12 ms`, with peak RSS near 10 MB.
- No fake Codex/Registered Action process, mounted image or review fixture
  residue remained.
- The UI runner completed without restarting `AutomationModeUI` or changing
  TCC/Accessibility/Event Synthesizing state.

## Unchanged Decisions

- Deep Dive remains no-go/paused; this review does not establish Broker-only
  Codex.
- No real destructive Registered Action was added.
- No TCC/FDA/Accessibility/Event Synthesizing state was changed.
- No Rust, telemetry, remote service or third-party product dependency was
  added.
