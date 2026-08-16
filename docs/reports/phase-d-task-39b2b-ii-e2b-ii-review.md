# Phase D Task 39B2b-ii-E2b-ii Code Review and Completion Audit

> Status: Complete; strict built-artifact gate and authoritative full passed
>
> Date: 2026-08-16
>
> Baseline:
> `5b0468951223916488f23c8bdf2bf74f9aef65a5`
>
> Scope: strict final-Mach-O authority admission and exact Xcode execution
> dependency allowlist

## 1. Current Decision

Task 39B2b-ii-E2b-ii is complete. Its tests-first verifier implementation,
strict Debug/Release/Investigation diagnostic bundle validation, isolated
review and one clean authoritative `scripts/verify --full` all passed.

This checkpoint adds no product source, execution authority or package
dependency. It strengthens the existing Release boundary gate so the
Investigation diagnostic must prove both:

- a real built `StornautExecution.o` positive control contains the concrete
  Trash, Executor and Registered Action process-runner markers;
- no Mach-O anywhere in the built Investigation diagnostic App bundle contains
  any of those same concrete authority markers.

It also requires `StornautExecution` to appear in exactly one Xcode native
target and one Frameworks phase: the ordinary `StornautApp`. Task 39 remains
incomplete, the stashed signed composition remains unapplied and production
Deep Dive remains `.implementationUnavailable`.

## 2. Tests-First Evidence

The verifier contract was changed before the Release gate implementation. Its
first run failed for the expected reason:

```text
scripts/verify-app-release-boundaries is missing verifier contract:
authority_object=
```

The implemented contract now requires:

- the built `StornautExecution.o` Mach-O authority object;
- a non-empty authority-object marker set;
- a separate diagnostic authority-forbidden marker set;
- a reusable Mach-O-only bundle scanner;
- an exact `StornautExecution` Xcode dependency allowlist assertion.

This prevents the binary check from silently degrading back to source scanning
or from passing because its forbidden marker never existed in the current
build.

## 3. Built-Artifact Contract

The strict gate builds:

```text
ordinary Stornaut Debug App
ordinary Stornaut Release App
Investigation diagnostic Debug App
```

The authority positive control is the Debug
`Build/Products/Debug/StornautExecution.o` Mach-O. It must contain:

- `ActionExecutor`;
- `TrashMoving`;
- `FileManagerTrashAdapter`;
- `RecordingFileManagerTrashAdapter`;
- `DenyRegisteredActionRunner`;
- `FoundationRegisteredActionRunner`;
- `spawnRegisteredActionWithPipes`.

The Investigation diagnostic bundle has an independent positive control:
`InvestigationRuntimeDiagnosticAppLeaf` must occur in one of its Mach-O files.
Every Mach-O in the full App bundle is then scanned for the complete authority
marker set; all must be absent.

The scan intentionally covers the complete bundle rather than only the main
executable. Debug Xcode products can place the real Swift implementation in a
`.debug.dylib`, and package or injected framework code can live elsewhere in
the bundle. A source reference check or main-executable-only scan is not
accepted as final-Mach-O evidence.

## 4. Xcode Dependency Admission

The gate parses all six native targets:

- `StornautApp`;
- `StornautAppTests`;
- `StornautAppUITests`;
- `StornautLifecycleHelper`;
- `StornautInvestigationDiagnosticApp`;
- `StornautInvestigationDiagnosticAppTests`.

Exactly `StornautApp` may name the `StornautExecution` package product. Exactly
the ordinary App's Frameworks phase may contain
`StornautExecution in Frameworks`, and it must occur there exactly once.

The dedicated Investigation diagnostic target additionally retains its exact
single-source and single-package-product allowlists and explicitly rejects
`StornautExecution`.

## 5. Layered Validation Evidence

The validation funnel before final acceptance was:

```text
red verifier contract
→ zsh syntax
→ verifier contract
→ cleanup / Investigation / no-Executor source boundaries
→ strict Debug/Release/diagnostic bundle gate
→ isolated review
```

Current evidence:

| Gate | Result |
| --- | ---: |
| Initial verifier contract | failed for expected missing authority-object contract |
| Zsh syntax | passed |
| Verifier mode/CI contract | passed |
| Cleanup execution boundary | passed |
| Investigation boundary | passed |
| Codex no-Executor boundary | passed |
| Strict built-artifact gate, first green | passed in 3:25.97 |
| Strict built-artifact gate after review strengthening | passed in 3:36.79 |
| Frozen strict built-artifact gate | passed in 4:06.33 |
| Non-document path budget | 2 paths, 133 additions / 7 deletions |
| Diff hygiene | passed |

The Xcode test runner emitted a non-fatal parser warning for its injected
`XCUIAutomation.framework`. The gate still scans the complete bundle and exits
successfully; it does not suppress or exclude a bundle region to hide that
warning.

E2b-ii does not run another standalone serialized SwiftPM regression. E2b-i
already owns the E2 checkpoint's 898-test serialized regression, and E2b-ii
changes only the verifier. The final full verifier owns the remaining broad
product acceptance.

## 6. Isolated Review

The post-implementation review found and fixed three verifier-quality issues:

1. authority absence initially lacked a same-build positive control, so a
   misspelled or dead marker could produce an empty proof;
2. the first Xcode allowlist draft depended on a fixed product-reference ID
   rather than the semantic product name and did not enumerate every native
   target;
3. the Mach-O helper name briefly exceeded its implementation by omitting an
   explicit file-type check.

The final gate now binds every forbidden marker to the execution authority
object, enumerates every native target, checks the Frameworks phase separately
and verifies each scanned file is Mach-O.

No unresolved P0–P2 findings remain in the implementation or isolated review.

## 7. Safety Audit

Task 39B2b-ii-E2b-ii does not:

- invoke or replay the sealed Task 35 Trash/recovery mutation;
- add or move product execution authority;
- link `StornautExecution` into any Investigation target;
- restore or apply the stashed signed diagnostic composition;
- launch Codex, invoke a model or create a readiness report;
- change Codex write, localhost, private-network or Unix-socket authority;
- edit `~/.codex/config.toml`;
- coordinate, block or terminate unrelated Node, Chrome, Cursor, Claude or MCP
  processes;
- enable normal-product Deep Dive;
- alter release, signing, notarization, FDA/TCC or distribution claims.

## 8. Final Acceptance

The one clean authoritative full verifier passed 23/23 stages with no restart
or stage rerun. Timed stages totaled 1,046.300 seconds:

| Stage | Seconds |
| --- | ---: |
| XCUITest | 606.868 |
| Strict Debug/Release/diagnostic built-artifact boundary | 165.926 |
| SwiftPM tests | 68.844 |
| App tests and snapshots | 52.904 |
| Investigation benchmarks | 34.249 |
| Debug App build | 33.089 |
| SwiftPM build | 20.396 |
| Rule compiler | 15.932 |
| Clean derived data | 10.517 |
| All remaining stages | 37.575 |
| **Total** | **1,046.300** |

The full run also confirmed:

- XCUITest passed once without a focus retry;
- 893 SwiftPM tests / 37 suites passed;
- the 256 MiB Investigation source benchmark passed in 23.004 seconds;
- the 100,000-row candidate benchmark passed in 8.877 seconds;
- the strict built-artifact gate passed inside full in 165.926 seconds;
- Phase C product passed 73/73 focused tests;
- the sealed Task 35 receipt and historical source snapshot remained valid.

E2b-ii can now be committed and pushed independently. The stashed 39B2b-ii
signed composition may resume only from that pushed baseline. Machine/model
execution remains exclusive to 39B2c.
