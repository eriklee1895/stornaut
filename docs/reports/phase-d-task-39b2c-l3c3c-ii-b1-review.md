# Phase D Task 39B2c-L3c3c-ii-b1 Authority-Free App Leaf Review

> Status: Complete; authority-free inherited-FD App leaf, corrected Debug-only /
> dependency-free Release-shell topology, focused/affected/structural gates, one
> staged-only serial and independent post-fix review passed; non-admitting
>
> Date: 2026-08-19
>
> Implementation commit: `d944ac7bf5251ea542579bdd8c3d7beff16265d5`
>
> Implementation tree: `fa56cda6faf78b813f05b3db35a0336826da22ae`
>
> Validation snapshot commit: `61a99acad007ee6f928aa2a81b76e5a461827fd9`
>
> Validation snapshot tree: `fa56cda6faf78b813f05b3db35a0336826da22ae`
>
> Scope: package-scoped pure handoff state machine, one no-argument fail-closed
> public entry, fixed-FD native admission and exact Debug/Release artifact
> boundary; no concrete drop/configuration/retirement adapter, helper claim,
> install, privilege, model/auth, real App launch, readiness or full verifier

## 1. Outcome

L3c3c-ii-b1 is complete. The checkpoint adds the authority-free App side of the
frozen inherited-FD handoff without claiming that the handoff can yet run. The
package leaf owns the exact STNP/STNH transition order and joins only injected,
already-admitted values. Its sole public entry takes no arguments and returns
`concreteAdapterUnavailable` status `78`; concrete identity drop, configuration
decoding, retirement handle production and transport I/O remain ii-b3 work.

The dedicated native Debug harness now selects the zero-argument inherited
handoff separately from the existing exact config-path diagnostic, admits only
fixed descriptor 7 as a duplex connected Unix stream distinct from every open
stdio file node, and accepts a closed stdio descriptor only on exact `EBADF`. It
still consumes no handoff bytes in ii-b1.

The final topology is deliberately asymmetric: the diagnostic target is
Debug-only and links the static Diagnostic package product, while a separate
dependency-free Release-shell target compiles the same physical harness source
without that package graph. This is a source, resolved graph and final-Mach-O
boundary, not a dead-stripping assumption. ii-b2, the handle-free helper
response checkpoint, is now the implementation frontier.

## 2. Post-RED Topology Correction

The initial RED work exposed that a source guard cannot prevent an
unconditionally linked static package product from entering the final Release
Mach-O. Two targeted Release artifact runs reproduced the leak. SwiftPM target
dependency conditions do not provide an Xcode build-configuration condition,
and manual object linking was rejected. The preflight was therefore corrected
before implementation:

- `e889b39d180c5dfd373eabfbc31eb7227635220d` froze the Debug-only diagnostic
  target plus dependency-free Release-shell topology;
- `7d63be65887a03cceb82b8b85b8633c63f369ecd` added the exact native topology
  contract path after the existing structural test correctly rejected the
  target-count change; and
- the ceiling remained 1,900 changed non-document lines, with the corrected
  surface limited to ten non-document paths.

This correction is part of the accepted contract. A future source-only guard,
dead-strip result or merged Debug/Release native target would reopen the leak.

## 3. Scope and Cost Audit

The accepted implementation changes exactly these ten non-document paths:

1. `Package.swift`
2. `Sources/StornautInvestigationDiagnostic/InvestigationHandoffAppLeaf.swift`
3. `Stornaut.xcodeproj/project.pbxproj`
4. `StornautApp/Diagnostics/InvestigationRuntimeDiagnosticHarness.swift`
5. `StornautAppTests/InvestigationRuntimeDiagnosticTests.swift`
6. `Tests/StornautInvestigationTests/InvestigationHandoffAppLeafTests.swift`
7. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
8. `scripts/verify-app-release-boundaries`
9. `scripts/verify-contract`
10. `scripts/verify-investigation-boundaries`

The exact diff is 1,724 additions and 17 deletions, a 1,741-line changed
surface. It remains below the corrected 1,900-line ceiling and the repository's
14-path mandatory split threshold. Documentation is excluded from this
implementation budget.

## 4. Prompt-to-Artifact Checklist

No row below is accepted from a proxy. Focused tests prove transition behavior,
native tests prove descriptor/activation behavior, structural gates prove
source and resolved topology, and the targeted artifact gate proves the final
Mach-O/bundle boundary. The serial is regression evidence only.

| Prompt obligation | Direct artifact and direct evidence | Result |
| --- | --- | --- |
| Exact closed STNP/STNH sequence | `InvestigationHandoffAppLeaf.swift` actor plus `successfulRunUsesTheExactClosedSequenceAndJoins` | satisfied |
| Replay/order/sender/epoch/deadline/payload failure is terminal | package leaf validation plus wrong-stage/sender/epoch/deadline/payload and one-shot tests | satisfied |
| Pre/post-drop identity and drop evidence join | package leaf PID/PID-version/ASID/EUID/audit-token checks plus claim/evidence mutation tests | satisfied |
| Configuration, nonce, digest, handle and complete-handle acknowledgement join | package leaf digest checks plus configuration/handle/ack mutation tests | satisfied |
| Every injected operation failure is sanitized and terminal | operations seam plus all-operation failure test and post-ALIVE transport-loss test | satisfied |
| State machine remains package-scoped and authority-free | package declarations and Foundation/HandoffContract imports plus recursive authority/source denylist in `verify-investigation-boundaries` | satisfied |
| Public surface is exactly one no-argument fail-closed entry | `InvestigationHandoffAppLeafEntryPoint.run()` plus focused status-78 test and token-aware public-whitespace structural count | satisfied |
| Existing config-path diagnostic remains distinct | activation parser and dedicated App activation tests cover exact config path, zero arguments and malformed/mixed inputs | satisfied |
| Native shell admits only fixed duplex Unix FD 7 | harness adapter plus dedicated App positives/negatives for `F_GETFD`, `F_GETFL`, `O_RDWR`, stream type, local/peer `AF_UNIX` and peer presence | satisfied |
| FD 7 cannot alias open stdin/stdout/stderr | file-node comparison plus three alias negatives | satisfied |
| Closed stdin/stdout/stderr is accepted only on exact `EBADF` | post-review dedicated App positives for each of FD 0, 1 and 2 plus lookup/node error negatives | satisfied |
| Debug diagnostic owns the leaf; Release contains no static package graph | exact `project.pbxproj` Debug-only target and dependency-free Release-shell target plus boundary test and structural script | satisfied |
| Release shell is an independent final artifact, not a source-intent claim | targeted release-boundary mode proves ordinary Debug/Release absence, diagnostic Debug presence, one dependency-free Release-shell Mach-O/LinkFileList and absence of the old Release product | satisfied |
| No ordinary product or execution authority gained the handoff | package/native allowlists plus `verify-investigation-boundaries`, `verify-contract` and targeted App release boundary | satisfied |
| Frozen cost boundary | Git path/numstat audit: 10 non-document paths, 1,724 additions, 17 deletions, surface 1,741 | satisfied |
| Commit identity binds implementation and validation | implementation and staged validation commits both resolve to tree `fa56cda6faf78b813f05b3db35a0336826da22ae` | satisfied |

## 5. Tests-First, Validation and Coverage

| Gate | Result |
| --- | --- |
| tests-first RED | expected missing App-leaf APIs |
| focused package leaf | 9/9 passed |
| dedicated App target | 13/13 passed; post-fix run includes closed FD 0/1/2 positives |
| exact boundary | 1/1 passed |
| affected regression | 277 tests in 24 suites passed |
| focused coverage | 33/33 functions; 237/241 lines, 98.34%; 90/93 regions, 96.77% |
| `scripts/verify-investigation-boundaries` | exit 0 |
| `scripts/verify-contract` | exit 0 |
| `scripts/verify-app-release-boundaries --investigation-handoff-only` | exit 0 |
| sole accepted staged-only serial | 1,138 tests in 56 suites passed |
| serial test / stage time | 86.830 / 136.506 seconds |
| independent post-fix review | no unresolved P0-P2 |

The targeted App boundary built and inspected only the relevant artifacts. It
proved the inherited-handoff surface absent from ordinary Debug and Release App
artifacts, the dedicated diagnostic Debug artifact present, and the
dependency-free Release shell present as one Mach-O with one harness
LinkFileList while the old diagnostic Release product remained absent. It did
not launch a real App.

The accepted staged-only serial ran exactly once and passed without retry. One
earlier non-staged `--specifier` invocation accidentally ran the full repository
because its selector did not take effect; although 1,143 tests in 56 suites
passed, that run is explicitly rejected as serial evidence and is not used in
the completion decision.

## 6. Independent Review and Repair

The initial independent P0-P2 review found two P2 gaps:

1. closed stdio was permitted by implementation but lacked a positive test for
   each of descriptors 0, 1 and 2; and
2. the public-surface structural gate could be evaded by non-space whitespace.

The dedicated App test now proves all three exact closed-stdio positives, and
the structural verifier counts `public` declarations with a whitespace-aware
token pattern. The post-fix independent review reported no unresolved P0-P2.
Review is review evidence only; the direct tests and structural/artifact gates
above remain the acceptance evidence.

## 7. Safety Boundary and Next Gate

This checkpoint did not run `scripts/verify --headless`,
`scripts/verify --full`, sudo, install/uninstall, model/auth, a privileged
machine gate or a real App launch.
It did not implement concrete identity drop, strict configuration adaptation,
retirement-handle production, helper claim/release, installed-L2 collection,
single-epoch composition or readiness.

ADR 0018 remains Proposed, Task 39 remains incomplete, production Deep Dive
remains unavailable and real Trash remains closed. L3c4 exclusively owns the
machine-readiness claim and the remaining authoritative full verifier. ii-b2 is
the current frontier.
