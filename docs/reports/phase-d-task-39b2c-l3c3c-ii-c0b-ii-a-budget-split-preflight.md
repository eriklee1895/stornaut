# Phase D Task 39B2c L3c3c-ii-c0b-ii-a Budget Split Preflight

> Status: mandatory pre-implementation budget split frozen; ii-c0b-ii-a1 is
> the current frontier
>
> Date: 2026-08-27
>
> Preflight baseline: `53b1db4cbaebac0a093d482365c6f8ec4f630bc9`
>
> ii-c0b-ii-a2 baseline: **TBD — exact pushed ii-c0b-ii-a1 implementation
> commit and tree must be recorded before any a2 non-document change**
>
> Scope: split only the already-frozen seven-path ii-c0b-ii-a kernel-ownership
> checkpoint; preserve its ownership behavior, target boundary, physical
> evidence, validation responsibilities and non-claims

## 1. Split Trigger

The ownership preflight froze ii-c0b-ii-a as an exactly seven-path / 2,600-line
plan. The tests-first source/test implementation plus the four required
structural and mutation surfaces is now estimated at 2,720–2,870
added-or-changed lines. Continuing under the old plan would either exceed the
approved budget or compress behavior, target-boundary and verifier review into
one oversized checkpoint without repair margin.

The split is therefore mandatory before further implementation. It does not add
a path or responsibility. The original seven-path union is preserved exactly
and divided by ownership of evidence:

```text
ii-c0b-ii-a1  behavior, focused tests and physical target evidence
-> ii-c0b-ii-a2  exact structural, component, mutation and replay closure
-> ii-c0b-ii-b  owner-only capsule node
-> c0b-iii  retained-parent launcher / TTY / FD hygiene
-> c0b-iv  zero-argument non-root composition
-> ii-c  unique privileged no-model machine attempt
-> L3c3d  authenticated real Codex App Server attempt
-> L3c4  final machine admission and authoritative full verifier
```

Both children are non-root and non-admitting. Neither may launch an App, helper
or driver, open XPC, invoke sudo/root, call a model or authentication flow,
access a network, accept ADR 0018, enable Deep Dive or claim readiness.

## 2. ii-c0b-ii-a1 — Ownership Behavior and Focused Evidence

### 2.1 Exact Scope and Cost

Exactly three non-document paths and at most 2,000 added-or-changed lines:

1. `Package.swift`;
2. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationMachineGateOwnership.swift` (new); and
3. `Tests/StornautInvestigationTests/InvestigationMachineGateOwnershipTests.swift` (new).

No fourth non-document path and no line above the ceiling is permitted without
a fresh split. The implementation baseline is the pushed ownership-preflight
commit above.

### 2.2 Owned Deliverables

ii-c0b-ii-a1 owns only:

- the non-product `StornautInvestigationMachineLaunchSupport` target and its
  one-way dependency on `StornautInvestigationHandoffContract`;
- the internal acquirer/final owner, permanent fixed-inode `flock` behavior,
  exact identity/metadata checks, contention-only `activeAttempt`,
  `FD_CLOEXEC`, explicit one-shot close and fail-closed uncertainty semantics
  frozen by the parent ownership preflight;
- tests-first RED and the complete focused/affected ownership behavior suite;
- targeted Debug and Release SwiftPM target builds;
- one execution of the committed non-root APFS physical probe from the
  preflight baseline; and
- independent source/test review with no unresolved P0–P2.

The existing physical probe is evidence input, not an a1 implementation path:
a1 must not modify it. Target builds and the probe do not admit a product or
prove the final component graph.

### 2.3 a1 Exit Contract

a1 may be committed and pushed only when its exact three-path scope, line
ceiling, focused/affected tests, target builds, physical probe and independent
source/test review are green. Its completion report must record the exact
commit and tree. That pushed commit becomes the immutable a2 baseline and must
replace the `TBD` marker in this report before a2 changes begin.

a1 does not run a staged serial, `scripts/verify --full`, the shared verifiers,
an App/Xcode build, a live driver/helper, XPC, sudo/root, model/auth or network.
It does not complete aggregate ii-a.

## 3. ii-c0b-ii-a2 — Structural and Mutation Closure

### 3.1 Exact Scope and Cost

Exactly four non-document paths and at most 1,200 added-or-changed lines:

1. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
2. `scripts/verify-contract`;
3. `scripts/verify-investigation-boundaries`; and
4. `scripts/verify-app-release-boundaries`.

No fifth non-document path and no line above the ceiling is permitted without a
fresh split. a2 starts only from the exact pushed a1 commit/tree recorded above;
there may be no unstaged non-document drift.

### 3.2 Owned Deliverables

ii-c0b-ii-a2 owns the aggregate ii-a proof surface:

- exact a1 source/test and aggregate seven-path scope admission;
- target dependency, package-only surface and source-inventory gates;
- Debug SwiftPM component positive controls and Release/ordinary App/helper/
  driver/Machine/closed-diagnostic negative controls;
- executable mutation controls for permanent-lock, contention narrowing,
  close-on-exec, no-follow/beneath/unique, identity revalidation and explicit
  close-reporting requirements;
- fail-closed verifier command handling; and
- immutable c0b-i historical replay against implementation commit
  `2493e0f28e0c8d406b4efcdbf17713bde3633449`, including its own verifier, tree,
  exact scope and source seals.

The exact modes remain those frozen by the parent preflight:

- `verify-investigation-boundaries --iic0b-ii-a-ownership-contract-only`;
- `verify-investigation-boundaries --iic0b-ii-a-staged-scope-contract-only`;
- `verify-app-release-boundaries --iic0b-ii-a-source-contract-only`; and
- `verify-app-release-boundaries --iic0b-ii-a-component-boundary-only`.

`verify-contract` owns mutation and c0b-i replay but must not duplicate the
component build owned by the component-boundary mode. Independent verifier and
cross-boundary review must finish with no unresolved P0–P2.

### 3.3 Aggregate ii-a Exit Contract

ii-c0b-ii-a completes only when a2 has proven the pushed a1 implementation plus
the exact four a2 paths as one seven-path aggregate. a2 reuses a1's recorded
behavior tests, target builds and physical-probe evidence unless a2 changes a
contract that invalidates them; any invalidation requires a fresh preflight, not
an implicit rerun.

Neither a2 nor aggregate ii-a runs a staged serial or authoritative full
verifier. c0b-iv retains the sole aggregate c0b staged-only serial and L3c4
retains Task 39's remaining authoritative full verifier.

## 4. Preserved Requirements and Non-Claims

This split supersedes only the parent ii-a 2,600-line planning envelope and its
single-checkpoint validation packaging. The per-child ceilings are 2,000 lines
for a1 and 1,200 lines for a2, while the exact original seven-path union has the
stricter 2,870-line aggregate ceiling from the accepted 2,720–2,870 estimate.
Exceeding either a child ceiling or the aggregate ceiling requires another
preflight. Every API, syscall order, metadata rule, permanent-lock
prohibition, cleanup prohibition, physical-probe constraint, target-graph rule
and stop condition in the ownership preflight remains normative.

The split proves neither capsule publication nor stale recovery; those remain
ii-c0b-ii-b. It proves no TTY/FD transfer, installed L2 freshness, root topology,
model success, containment, zero global residue or machine readiness. Task 39
remains incomplete, ADR 0018 remains Proposed and production Deep Dive remains
unavailable.

## 5. Prompt-to-Artifact Checklist

| Requirement | Concrete artifact/evidence | Owner/status |
| --- | --- | --- |
| record the budget trigger | former 7-path / 2,600-line plan versus accepted 2,720–2,870 estimate and 2,870 aggregate ceiling | frozen here |
| ownership behavior and target declaration | `Package.swift` + ownership source | ii-c0b-ii-a1 current |
| tests-first behavioral evidence | focused ownership test file and affected selection | ii-c0b-ii-a1 current |
| Darwin/APFS semantics | unchanged committed physical probe, run once from a1 | ii-c0b-ii-a1 current |
| source/test review | independent no-unresolved-P0–P2 review | ii-c0b-ii-a1 pending |
| immutable child baseline | exact pushed a1 commit/tree replaces `TBD` before a2 | pending |
| exact source and seven-path scope | target-boundary tests plus Investigation verifier | ii-c0b-ii-a2 pending |
| component/final-image boundary | App/Release verifier positive and negative controls | ii-c0b-ii-a2 pending |
| mutation and c0b-i replay | `verify-contract` fixtures and immutable historical replay | ii-c0b-ii-a2 pending |
| aggregate ii-a completion | exact a1 baseline + four a2 paths + independent reviews | ii-c0b-ii-a2 pending |
| no serial/full in either child | validation logs and review reports | preserved |
| later capsule and machine admission | ii-b/c0b-iii/c0b-iv/ii-c/L3c3d/L3c4 | later |
