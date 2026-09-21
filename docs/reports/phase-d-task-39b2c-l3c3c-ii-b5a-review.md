# Phase D Task 39B2c-L3c3c-ii-b5a Typed Single-Epoch Composer Review

> Status: Complete; package-scoped typed/injected single-epoch semantics,
> terminal uncertainty handling and exact structural gates passed; non-admitting
>
> Date: 2026-08-21
>
> Implementation commit: `43a2c83d3d502f1d6768340fc493065960053a1f`
>
> Parent: `f9e8c802ff9543c1d0d6bdcdcc42a2f2ba0a7a4d`
>
> Validated implementation tree: `a79e3e6ff346edc3e1985eed44fe19257a4f5294`
>
> Staged validation commit: `e1de4b20e7d60ddc543d7669173c21823f7579ed`
>
> Scope: exactly five non-document source/test/script paths; no App/helper
> launch, real XPC, install, sudo/root, model/auth/network use, readiness claim
> or authoritative full verifier

## 1. Outcome

ii-b5a is complete. `InvestigationMachineSingleEpochComposer` now owns one
package-scoped, one-shot semantic epoch over injected typed seams. It derives
the bounded monotonic deadline internally, validates the exact frame order and
commitments, joins the complete observed App identity, performs claim only
after strict peer-write EOF, admits release only after installed-L2 and repeated
App identity, retires/reaps the owned epoch, and accepts only a final installed-
driver observation exactly equal to the initial observation. Its sole success
result is opaque, non-`Codable` and explicitly `completedNonAdmitting`.

The implementation remains unreachable from the native production entry. It
adds no physical spawn, descriptor, XPC, installation, process-signalling,
report, receipt or readiness authority. ii-b5b-i is the next checkpoint and
must supply the separately reviewed authority-free identity projection and
installed-L2 extraction before any Darwin runtime or production composition.

## 2. Scope and Artifact Identity

The implementation changed exactly the five approved non-document paths and
exactly 1,500 lines: 1,470 additions and 30 deletions. This exactly meets the
five-path / 1,500-line ceiling without exceeding it:

1. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineSingleEpoch.swift`;
2. `Tests/StornautInvestigationTests/InvestigationMachineSingleEpochTests.swift`;
3. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
4. `scripts/verify-contract`; and
5. `scripts/verify-investigation-boundaries`.

The implementation commit and staged validation commit share exact tree
`a79e3e6ff346edc3e1985eed44fe19257a4f5294`. Canonical source identities at
that tree include:

- composer: `c6cc195f447dbe660139be5a0bec14c07342bc35bbdd24f737455c7c0a699291`;
- focused tests: `f9dd54bf1c67589dd46c1387ccdc49e77581df275159632f40b7ef0c4d2390a9`;
- boundary tests: `bb574a35d8e9932f7291bba42f615b223be6abe9afa7c962a9c6f5edf99a82c9`;
- `scripts/verify-contract`: `1d9541fce68a43d632cfbeb3a04a1d1fe389025d913fc8c9868ad81b045903f3`; and
- `scripts/verify-investigation-boundaries`: `b11e602911f5d83b8b2a8bdc8b053b18f3f75085bc4fe9b786bb31e04db60ec3`.

## 3. Contract and Review Repairs

Implementation and review closed the material semantic windows in the split
contract:

- the driver sender is snapshotted once from the returned session for every
  outgoing frame, while the post-drop App sender and complete observation are
  joined once and all later inbound frames must match that exact sender;
- session start returns a typed `started` or already-terminal outcome, so a
  failed start cannot leave unrepresented cleanup uncertainty;
- claim and release ambiguity have distinct terminal-uncertainty outcomes, and
  every post-claim failure uses the same retained client to abort and prove
  terminal state before App retirement;
- cancellation is checked after every awaited seam, including claim-abort and
  cleanup paths, while retirement or abort uncertainty overrides the original
  error;
- configuration acknowledgement is validated immediately against the admitted
  epoch before later protocol progress;
- final observation read failure and value mismatch both fail closed after
  successful retirement; and
- exact source seals, dependency/authority restrictions, scope/line ceilings,
  executable mutations and Debug/Release binary projections prevent semantic
  or production-reachability drift.

## 4. Validation Evidence

| Gate | Result |
| --- | --- |
| focused composer suite | 11 top-level tests passed; parameter matrices covered 8 scenarios, 8 protocol/commitment drifts, 20 suspension/cleanup cancellation points and 2 final-observation negatives |
| affected regression | 394 tests in 29 suites ran; 393 initially passed and one boundary suite reported static-marker issues |
| exact boundary repair check | after the test-only marker fix, the exact two affected boundary cases passed; the full affected suite was not rerun |
| `scripts/verify-contract` | exit 0; exact historical parents/trees, source seals, staged scope/budget and executable mutation controls passed |
| full `scripts/verify-investigation-boundaries` | exit 0; package/source/dependency/authority and exact Debug/Release projection gates passed |
| independent review | code-guard covered seven dimensions and the final cross-group review found no unresolved P0-P2; reports remained under `/tmp` only |
| sole clean staged-only serial | 1,290 tests in 62 suites passed in 93.687 seconds; five maximum benchmarks skipped; one run with no retry |

The affected result is deliberately not described as a complete green rerun:
after the static-marker-only test repair, only its exact two boundary cases were
rerun and passed. The sole staged-only serial subsequently provided the one
clean whole-package regression for the validated tree.

## 5. Non-Admission and Next Gate

ii-b5a is complete but non-admitting. It did not launch an App or helper, invoke
real XPC, install or mutate system state, use root, call a model, read auth,
access a network, create a machine report/receipt, claim readiness or run
`scripts/verify --full`. ADR 0018 remains Proposed, Task 39 remains incomplete
and production Deep Dive remains `.implementationUnavailable`.

ii-b5b-i was split by its fresh exact-path preflight into i-a projection/clock
contract, i-b observer extraction and i-c DriverSupport join/legacy closure;
ii-b5b-i-a is the current frontier. ii-c
alone may accept ADR 0018, and L3c4 alone owns machine readiness and Task 39's
remaining authoritative full verifier.
