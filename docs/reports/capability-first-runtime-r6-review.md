# Capability-First Runtime R6 Review

> Status: Complete — final runtime foundation `go`
>
> Date: 2026-08-13
>
> Baseline: `8b93852d901cc7bd78bf827c21dc4d85ab9d473f`
>
> Final decision:
> [Capability-First Runtime Validation](capability-first-runtime-validation-report.md)

## 1. Scope

R6 implemented and reviewed:

- the exact, privacy-safe R5 evidence receipt;
- typed signed-evidence, aggregate-gate and production-availability states;
- fail-closed status precedence and receipt normalization;
- a typed bilingual first-use disclosure with no action or persistence;
- native Settings status hierarchy and stable AX identifiers;
- corrected Overview/Scan implementation-unavailable semantics;
- deterministic passed/missing/unsupported/stale/failed/unverified fixtures;
- English/`zh-Hans` model, localization and XCUITest coverage;
- static Settings, Overview, Scan, Release and no-Executor gates;
- final ADR 0004 residual-risk and prompt-to-evidence mapping.

R6 did not add production Deep Dive, Candidate Planner, cleanup execution,
acceptance persistence, runtime services, telemetry, login items, Developer ID
or notarization work.

## 2. Tests-First Evidence

The initial R6 tests failed at compile time because the repository had no
typed runtime evidence or aggregate gate. After the core state contract was
implemented, the complete App test run failed on the new bilingual
localization keys. That second red state anchored the UI/localization
implementation.

The final App suite has:

- a complete installation × syntax × evidence matrix;
- exact R5 revision/hash/timestamp/provider/model/count assertions;
- missing and altered receipt anti-forgery tests;
- proof that passed evidence never enables Deep Dive;
- typed bounded reasons for blocked and unverified states;
- exact English and Chinese verified copy;
- typed, ordered and non-actionable disclosure assertions;
- deterministic runtime-state debug fixture projections.

Final result: `120/120` App tests passed.

## 3. Independent Review

`bits-code-guard` was applied to the complete worktree:

- all final tracked and untracked R6 product, test, script and documentation
  files;
- 36 files total;
- about 1,391 changed lines;
- runtime/provenance, UI/accessibility/localization, tests/scripts and docs
  groups;
- seven general review dimensions;
- no repository custom workflow was configured.

The first review confirmed two P1 findings:

| Finding | Correction | Regression |
| --- | --- | --- |
| A passed evidence status with a missing or changed receipt produced an unverified aggregate gate but could still display a green Passed evidence row | Normalize any unadmitted passed receipt to `.unverified` before projecting evidence or gate | Missing-receipt and changed-hash tests assert both evidence and gate are unverified |
| Failed fixture evidence could carry the admitted passed receipt, creating a contradictory object even though the gate blocked it | Make the evidence initializer private and expose closed admitted/stale/failed/unverified factories; failed carries no passed receipt | Full matrix and debug fixture projection tests |

Post-fix review found:

```text
P0: 0
P1: 0
P2: 0
```

Review artifacts:

```text
/tmp/stornaut_r6_review/report.html
/tmp/stornaut_r6_review/report.md
report.html SHA-256:
  81c81a6bbedf50a554326eddc800ba5979b50294b8b11c3e7e890a8a4440921d
report.md SHA-256:
  7471fb812f75efa5548588c39dbeae162689b6e3f31663dd1e7546ed8bd68e76
```

## 4. Product and UI Review

The product now shows five independent dimensions:

1. Codex installation;
2. required syntax;
3. last signed evidence;
4. aggregate runtime gate;
5. production Deep Dive availability.

The Runtime Status section is first on the Codex page. Installation details
remain visible below it. This places Evidence, Runtime Gate, Production Deep
Dive and the First-Use Data Boundary in the default 900×648 Settings viewport.

The actual Dark Settings window was launched from the built Debug App and
captured read-only:

```text
.derivedData/peekaboo/r6-final-codex-settings-dark.png
1800 × 1296 Retina PNG
SHA-256 5848f9fc8ba12b72a09973c4f09dd1acdb05c8a9863f5cd4e12a2c062160bad4
```

Peekaboo AX inspection observed:

- `settings.codex.evidence`;
- `settings.codex.runtimeGate`;
- `settings.codex.deepDiveAvailability`;
- `settings.codex.disclosure`;
- the exact verified-boundary copy;
- no Start Deep Dive, Trust Codex or Accept action.

OCR of the same window showed all three status rows and disclosure in the
default viewport without overlap. A separate Peekaboo ScreenCaptureKit
analysis call timed out; the CG Retina capture and AX inspection succeeded, so
the tool timeout was not classified as a product defect.

One combined XCUITest run lost focus to System Settings between runtime
fixtures. The unchanged variants test passed when rerun alone. This follows
the repository's documented external-focus interference policy.

## 5. Verification

Passed on post-fix R6 source:

```text
StornautAppTests
  120 passed

StornautCodexTests
  227 passed
  8 explicit opt-in/live diagnostics skipped
  0 failed

swift test --no-parallel
  537 passed

focused XCUITest
  canonical Light/Dark Settings: passed
  installed/missing/unsupported/passed/stale/failed/unverified: passed
  zh-Hans runtime status: passed

scripts/verify-settings-boundaries
  passed

scripts/verify-app-release-boundaries
  passed

scripts/verify-codex-runtime-gate /tmp/stornaut-r5-machine-report.json
  passed

scripts/verify --headless
  passed

scripts/check-doc-links
  passed

git diff --check
  passed
```

The machine report remained external and privacy-sensitive. Only its admitted
summary and SHA-256 are checked in.

## 6. Limitations

- The build receipt is provenance/status, not runtime authorization.
- A future security-relevant runtime change requires a new signed gate and
  receipt update.
- Production Deep Dive remains unimplemented.
- The aggregate disclosure has no acceptance UI or persisted timestamp in R6.
- Developer ID, notarization, distribution and FDA/TCC product flow are not
  admitted.
- Accepted direct-read/model/public-internet confidentiality and licensing
  risks remain documented product trade-offs.

## 7. Review Verdict

- runtime foundation: `go`;
- final matrix: complete;
- ADR 0004 residual risks: mapped;
- unresolved P0/P1/P2: `0/0/0`;
- production Deep Dive: implementation unavailable;
- Task 29: not started by R6;
- commit readiness: ready after final docs/link/diff verification.
