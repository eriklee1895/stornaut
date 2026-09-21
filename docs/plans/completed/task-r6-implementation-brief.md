# R6 Implementation Brief: Runtime Status, Final Evidence and Admission

> Status: Complete — runtime foundation `go`; production Deep Dive remains
> implementation unavailable
>
> Prepared: 2026-08-13
>
> Baseline: `8b93852d901cc7bd78bf827c21dc4d85ab9d473f`
>
> Plan:
> [Capability-First Runtime Gate](capability-first-codex-runtime-gate.md)
>
> Previous gate:
> [R5 Review](../../reports/capability-first-runtime-r5-review.md)

## 1. Gate Purpose

R6 closes the capability-first runtime evidence program without enabling
production Deep Dive. It must:

1. replace Broker-only product copy with the accepted integrity-first
   boundary;
2. distinguish current Codex installation, required syntax support, last
   signed evidence, aggregate runtime gate outcome and production feature
   availability;
3. represent the aggregate first-use data-boundary disclosure as a typed,
   localized, non-actionable contract;
4. map every ADR 0004 residual risk and final plan row to implementation,
   deterministic tests, signed-App evidence, adversarial evidence and current
   limitations;
5. produce a final supported admission decision;
6. keep production Deep Dive unavailable and Task 29 untouched.

## 2. Evidence Source and Freshness

The product must not read `/tmp/stornaut-r5-machine-report.json`, leave the R5
LaunchDaemon installed, or make a machine-local diagnostic file a production
dependency.

R6 therefore introduces one typed build evidence receipt containing only the
privacy-safe admitted R5 summary:

```text
schemaVersion=1
runtimeProfile=capability-first-v1
runtimeRevision=8b93852d901cc7bd78bf827c21dc4d85ab9d473f
reportSchemaVersion=2
reportSHA256=08ba7c30373d4736124f0e507fcc9aa972880235251b8bbf636a7b2fabb1d193
verifiedAt=2026-08-13T11:09:07Z
provider=openai
model=gpt-5.6-luna
capabilitiesObserved=9
integrityContained=12
outcome=passed
```

This receipt is product status/provenance, not a security authorization:

- it cannot start Deep Dive;
- it cannot create Policy, authorization, Trash, Registered Action or
  Executor objects;
- it contains no app path, auth material, prompt, raw JSONL or private
  evidence;
- a future runtime/security source change must update the receipt only after a
  new signed gate;
- stale/failed/unverified states remain first-class typed fixtures and UI
  states.

## 3. Product Status Contract

Settings projects five independent dimensions:

| Dimension | States |
| --- | --- |
| Codex installation | installed / unavailable / check failed |
| Required syntax | supported / unsupported / unverified |
| Last signed evidence | passed / stale / failed / unverified |
| Aggregate runtime gate | verified / blocked / unverified |
| Production Deep Dive | implementation unavailable |

The aggregate gate is derived fail-closed:

- missing Codex, unsupported syntax, stale/failed evidence → blocked with one
  bounded typed reason;
- check failure, unverified syntax or missing evidence → unverified with one
  bounded typed reason;
- installed + supported + passed evidence → verified;
- no status combination makes `deepDiveCanStart` true in R6.

The passed copy is exactly:

```text
Runtime boundary verified · Deep Dive implementation not yet available
```

Quick Scan remains unaffected in every state.

## 4. First-Use Disclosure Contract

R6 creates a typed, localized disclosure contract for:

- direct read-only filesystem investigation;
- model-context processing of read content;
- live search and public-internet command/browser/direct-fetch processing;
- no user-data write or cleanup authority;
- Swift revalidation and explicit selection before any future action.

The contract has no button, persistence, acceptance timestamp or bypass while
Deep Dive is unavailable. It exists so Phase D cannot invent a contradictory
disclosure later.

## 5. Tests First

Red tests cover:

- every installation/syntax/evidence combination;
- passed evidence never enables Deep Dive;
- stale/failed/unverified reasons remain typed and bounded;
- the admitted receipt has the exact R5 revision/report hash/counts;
- English and `zh-Hans` localization for all runtime statuses and disclosure
  items;
- Settings rows and accessibility identifiers separate evidence, gate and
  feature availability;
- no Broker-only copy remains in current product strings;
- Overview and Scan describe implementation unavailability rather than an
  unverified Broker boundary;
- no actionable first-use or Deep Dive control appears;
- System/Light/Dark, VoiceOver and keyboard traversal remain valid.

## 6. Implementation Scope

Expected files:

- `StornautApp/AppState/AppDependencies.swift`
- `StornautApp/Settings/SettingsState.swift`
- `StornautApp/Settings/SettingsModel.swift`
- `StornautApp/Settings/GeneralSettingsView.swift`
- `StornautApp/Settings/CodexSettingsView.swift`
- `StornautApp/AppState/DebugAppFixtures.swift`
- `StornautApp/Resources/en.lproj/Localizable.strings`
- `StornautApp/Resources/zh-Hans.lproj/Localizable.strings`
- relevant App/XCUITests
- `scripts/verify-settings-boundaries`
- `scripts/verify`
- final R6 reports and routing docs

R6 does not add a report installer, background monitor, timer, login item,
telemetry, runtime service, Deep Dive action, acceptance persistence or
Executor path.

## 7. Verification

Required sequence:

```text
focused Settings/status/disclosure tests
complete StornautAppTests
complete StornautCodexTests
serial swift test --no-parallel
Xcode App contract tests
actual Debug App launch
Peekaboo read-only Settings screenshot + AX inspection
focused XCUITest for English/zh-Hans and Light/Dark
scripts/verify-settings-boundaries
scripts/verify-app-release-boundaries
scripts/verify --headless
scripts/check-doc-links
git diff --check
independent review with zero unresolved P0–P2
```

The accepted R5 machine report remains the live capability/containment
evidence class. R6 UI verification does not spend model tokens.

## 8. Deliverables and Stop

Create:

- `docs/reports/capability-first-runtime-validation-report.md`
- `docs/reports/capability-first-runtime-r6-review.md`

The validation report must map every final plan matrix row and all nine ADR
0004 residual risks. The final decision may be `go`, `conditional go` or
`no-go`; only a supported `go` closes the runtime foundation. Even on `go`,
production Deep Dive remains unavailable pending Phase D.

R6 ends with one independent commit/push. Stop before Task 29.

## 9. Completion

R6 completed on 2026-08-13:

- the exact R5 receipt is projected as privacy-safe product provenance;
- Settings separates installation, syntax, evidence, aggregate gate and
  production feature availability;
- mismatched or missing passed receipts normalize to `unverified`;
- the first-use disclosure is typed, bilingual and non-actionable;
- current Overview/Scan copy describes implementation unavailability rather
  than the historical Broker-only gate;
- App, Codex, serial SwiftPM, focused XCUITest, machine, Release, source,
  localization, docs and headless gates passed;
- actual Dark Settings window capture and AX inspection passed;
- post-fix independent review has zero unresolved P0–P2.

Final evidence:

- [Runtime Validation](../../reports/capability-first-runtime-validation-report.md)
- [R6 Review](../../reports/capability-first-runtime-r6-review.md)

R6 does not start Task 29 or production Deep Dive.
