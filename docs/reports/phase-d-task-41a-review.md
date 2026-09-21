# Phase D Task 41A Review

> Status: Complete as the Core disclosure/admission checkpoint; Task 41 remains
> active until 41B Settings/App/UI and actual-window evidence complete
>
> Date: 2026-09-20
>
> Baseline: `5c9e085f323f893d5cb8b663175dd5e1fc875a36`
>
> Scope: versioned disclosure semantics, bounded local acceptance persistence,
> seven-dimensional availability and pure first-use decisions; no App workflow,
> production admission, Investigation start, privileged campaign or cleanup

## 1. Decision

Task 41A is complete. Core now owns one fixed
`deep-dive-disclosure-v1` semantic descriptor and fingerprint, an explicit
accepted/declined record, obsolete-state evaluation, a dedicated local-only
preference store, all seven independent admission dimensions, presentation
precedence and a first-use decision owner.

This is not Task 41 completion. Settings/App dependency wiring, bilingual
native disclosure UI, accessibility, Light/Dark actual-window evidence and
focused XCUITest remain in 41B. Normal Deep Dive remains hard-disabled until
Task 44; Task 39 machine admission is unchanged and unproven.

## 2. Safety and Persistence

- Consent and runtime containment are independent typed dimensions. Neither can
  substitute for the other.
- Acceptance binds the exact disclosure version, canonical semantic fingerprint
  and data-boundary profile. Locale selection does not change semantics.
- The record contains only schema/version/decision/time/fingerprint/profile. It
  has no generic trust, bypass, provider, tool, path or execution field.
- The dedicated `DeepDiveDisclosure.json` is separate from Settings, Evidence
  and Local Knowledge, owner-private and excluded from backup. Writes and exact
  forget use atomic replacement.
- Filesystem reads open with no-follow semantics, validate regular-file owner,
  mode and size before allocating, read exactly within the 16 KiB bound, reject
  trailing growth and revalidate physical identity/size/timestamps.
- First-use presentation and persistence are independently single-flight. A
  decision cannot be submitted without a current presentation. Accept persists
  consent and returns only `acceptedRequiresFreshAdmission`; it cannot start an
  Investigation.
- The availability projection always keeps Quick Scan available and always
  reports `normalProductStartEnabled == false` in Task 41.

## 3. Tests First

The required `bits-unit-test-gen` workflow completed Steps 1–7. Four Swift
Testing files were first generated against missing 41A APIs; the recorded RED
was a compile error consisting only of those missing types. The skill correctly
did not modify production source. Coverage collection was skipped because the
request/repository defines no CI incremental-coverage threshold and the current
coverage parser does not support Swift. The mandatory `utree flush` completed.

The final tests cover semantic parity and exact fingerprint; accepted, declined,
missing and obsolete records; unknown/missing fields and unsupported schemas;
memory and private-file round trips; atomic save/forget failure; sparse oversized
and non-regular disk nodes; every source/disclosure/Codex/runtime/dependency/
workflow/budget state; mismatched preset limits; consent/runtime independence;
presentation precedence; presentation and persistence single-flight; direct
submission rejection; decline and persistence failure.

## 4. Validation

| Gate | Result |
| --- | --- |
| Task 41A + adjacent SettingsPreferences focused selection | 32 tests / 4 suites passed |
| Task 41 structural and mutation gate | passed |
| Existing Settings UI/service boundary | passed |
| Final unified `source-boundaries` | passed in 63.694 seconds |
| Post-fix independent acceptance-store rerun | 6/6 passed |
| Diff hygiene | passed |

This checkpoint changes ten non-document source/test/script paths and remains
below both the 14-path and approximately 4,000-line preflight ceilings. No
serial regression or full verifier was run: the sprint rules assign at most one
stable-tree serial across Tasks 40–43 and the integrated final full to Task 44.
No sudo, live model, privileged campaign, Trash or cleanup action ran.

## 5. Independent Review

Runtime review found one P1: filesystem load originally allocated the complete
file before applying the 16 KiB bound. The store now validates through a
no-follow descriptor before allocation and performs bounded exact read plus
post-read revalidation. Sparse oversized and non-regular-node regressions pass.
A post-fix independent review found no remaining P0–P2.

Verifier review found and closed six gate/API weaknesses: comment/string
decoys, function-type aliases and parameters, incomplete authority scanning,
public raw acceptance persistence, vacuous required-test checks and cross-file
Core extensions. The final gate now strips comments/strings where appropriate,
seals its own source plus the owned sources/tests, recursively inventories the
Settings directory, scans the full Core module for exact Task 41 type ownership
and exercises a synthetic cross-file extension escape. A post-fix independent
review ran the gate from the checkpoint archive and found no remaining P0–P2.

## 6. Next Gate

41B may now consume only these Core types to replace the Settings placeholders,
wire the dedicated store, present the bilingual native sheet and capture real
App evidence. It must not add Task 42 workflow state or remove the Task 44
normal-product gate.
