# Phase D Task 39B2c L3c3c-ii-b5b-i-b3 Review

> Status: complete / non-admitting
> Date: 2026-08-22
> Next frontier: i-c1 DriverSupport join/proof, then i-c2 legacy-owner closure

## 1. Scope and Result

i-b3 added the installed-L2 observer composition to the non-product
`StornautInvestigationInstalledL2` target. Implementation commit
`a50dd817adc470fe37e5199c73c686f0976738c6` has parent
`f2332633e50b255c5344c602ae776f00233b22f8` and tree
`7d2e73d4058cd54420ee6de3e296233d3ba34901`. The checkpoint changed exactly
the five frozen non-document paths with 861 insertions and two deletions; the
scope gate counts 863 changed lines, below its 1,600-line ceiling.

The five paths are the new `InstalledL2Observer.swift` and focused test,
`InvestigationMachineTargetBoundaryTests.swift`,
`scripts/verify-investigation-boundaries` and `scripts/verify-contract`. No
Package, App, Xcode, Lifecycle, Machine, DriverSupport or product path changed.

Tests-first RED proved the observer and its injected artifact, process, service
and clock protocols were absent before implementation.

## 2. Implemented Contract

The package-scoped observer composes the already-reviewed fixed readers in one
strict order:

```text
started clock
-> fixed artifacts/static signing
-> exact App process/path/live signing
-> exact helper process/path/live signing
-> current machine-driver live signing
-> fixed service observation
-> observed clock
-> InvestigationInstalledL2SemanticContract.evaluate
```

The App and helper inputs must have the exact roles, distinct identities and
distinct PIDs before any clock or physical read. Every physical reader is
invoked once. App/helper process evidence is rejoined to the fixed executable
path, projection SHA-256 and corresponding static signing evidence; the current
driver's live signing is joined to its static evidence by the semantic
contract. The loaded service must carry the exact expected helper identity.

The observer samples wall UTC and `mach_continuous_time` independently before
and after physical observation. Darwin timebase conversion is overflow-checked
and produces only positive continuous nanoseconds. Physical unavailability,
identity/path drift, static/live signing mismatch, service drift and semantic
clock violations fail closed without producing installed evidence. The
composition remains observer-only: it accepts no claim evidence, performs no
repeated-App join and mints no opaque proof.

## 3. Verification and Review

- focused observer suite: six top-level tests passed, including seven physical
  failure stages, four process-drift cases, nine semantic-drift cases and a
  concrete Darwin clock positive control;
- affected InstalledL2 regression: 52 tests in six suites passed;
- TargetBoundary focused gate: 1/1 passed;
- contract, canonical observer and staged-scope gates: exit 0;
- authority, ordering, reader-cardinality, protocol-surface, canonical-source,
  focused-coverage, path, deletion, budget and binary-numstat controls passed;
- sole serial run: 1,348 tests in 68 suites passed in 84.312 seconds, with 91.11
  seconds wall time and five maximum benchmarks skipped; and
- the serial passed once without rerun or restart.

The bits review artifacts are retained outside the repository at
`/tmp/stornaut_iib3_review.7GhpNH/`. Production, verifier and fresh cross-group
reviews found no unresolved P0-P2.

## 4. Non-Admission and Remaining Ownership

i-b3 is complete and non-admitting. This checkpoint did not run
`scripts/verify --full`, launch the App/helper, invoke real XPC, install an
artifact, use sudo/root, call a model, read auth or access a network.

i-c is split by the fresh
[preflight](phase-d-task-39b2c-l3c3c-ii-b5b-i-c-split-preflight.md): i-c1 owns
the projection + claim + repeated-App join and opaque proof, then i-c2 owns
legacy-owner closure and exactly-one-owner proof. Task 39 remains incomplete, ADR 0018
remains Proposed, production Deep Dive remains `.implementationUnavailable`,
and L3c4 alone owns readiness, final admission and the remaining authoritative
full verifier.
