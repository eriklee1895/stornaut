# Phase D Task 39B2c L3c3c-ii-b5b-i-b2b-b Review

> Status: complete / non-admitting
> Date: 2026-08-22
> Next frontier: i-b3 installed-L2 observer composition

## 1. Scope and Result

i-b2b-b added the fixed, non-activating launchd service reader to the
non-product `StornautInvestigationInstalledL2` target. Implementation commit
`8ef5a5c7fc7c35d9889eb9eee5e92205322293f9` has parent
`bad515e43d085a711ad9fdb1127e05fef141bfe7` and tree
`4f613c4ea74f9ed1033053a4070c6efdd279fb99`. The checkpoint changed exactly
the six frozen non-document paths with 708 insertions and three deletions; the
scope gate counts 709 changed lines, below its 1,300-line ceiling.

The six paths are `Package.swift`, the new fixed-service reader and focused
test, `InvestigationMachineTargetBoundaryTests.swift`,
`scripts/verify-investigation-boundaries` and `scripts/verify-contract`. No
Lifecycle, Machine, DriverSupport, App, Xcode or product path changed.

## 2. Implemented Contract

The reader derives the fixed system launchd domain, plist path and
`com.eriklee.stornaut.lifecycle` label internally. Its ServiceManagement surface
is closed to `SMAppService.statusForLegacyPlist`, `SMJobCopyDictionary` and
`kSMDomainSystemLaunchd`; it cannot register, remove, bless, enable or activate
a service and invokes no `launchctl`, bootstrap, bootout or kickstart path.

Two consistent structured missing samples are required for `.absent`, with
registration status limited to `notRegistered` or `notFound`. Loaded evidence
requires an enabled, bounded, exact-label registry record with an exact integer
helper PID, then two complete expected-helper identity samples, then the same
fixed registry sample again. Wrong role, missing or malformed PID, approval or
unknown status, contradictory samples, PID reuse, helper restart, identity
drift and lookup failure all remain `.unavailable`. The output is limited to
`.absent`, `.loaded(identity:)` or `.unavailable`; i-b3 still owns the later
artifact/process/service/clock composition.

The paired samples detect ordinary restart and identity drift but are not an
atomic kernel snapshot. The privileged A-to-B-to-A residual remains outside
ADR 0018's serialized trusted-local-operator threat model and is not described
as race-free evidence.

## 3. Review Repairs

Independent review first found two defects, both repaired tests-first:

1. P1: a finite ServiceManagement denylist could miss other mutating APIs. The
   source gate now requires the exact ServiceManagement symbol/member set, with
   mutations for `SMJobSubmit`, `SMJobRemove`, `SMJobBless` and
   `SMLoginItemSetEnabled` in addition to the existing registration mutation.
2. P2: binary `git diff --numstat` entries could bypass the changed-line budget.
   The staged-scope gate now rejects `-` numstat columns before summing, and the
   contract suite retains a binary-numstat negative fixture.

Post-fix runtime/verifier review and a fresh cross-group review found no
unresolved P0-P2. The bits review artifacts are retained outside the repository
at `/tmp/stornaut_iib2bb_review.QGQEBP/`; its final report records zero P0, P1
and P2 findings across the six-file, 709-line scope.

## 4. Verification

- focused fixed-service reader: 8/8 tests passed;
- affected InstalledL2 regression: 46 tests in five suites passed;
- contract, canonical service and staged-scope gates: exit 0;
- ServiceManagement authority, registry/identity resample, absence, PID typing,
  vacuous-test, exact-path, budget, deletion and binary-numstat mutations passed;
- sole serial run: 1,341 tests in 67 suites passed in 83.034 seconds, with 87.32
  seconds wall time and five maximum benchmarks skipped; and
- the serial passed once without rerun or restart.

No `scripts/verify --full` ran. No App/helper launch, real XPC, install, sudo,
root execution, model/auth or network operation ran in this checkpoint.

## 5. Non-Admission and Remaining Ownership

i-b2b-b is complete and non-admitting. i-b3 is the current frontier and still
owns installed-L2 artifact/process/service/paired-clock observer composition.
i-c remains the exclusive owner of the projection + claim + repeated-App join,
opaque proof minting and legacy-owner closure. Task 39 remains incomplete, ADR
0018 remains Proposed, production Deep Dive remains
`.implementationUnavailable`, and L3c4 alone owns readiness, final admission and
the remaining authoritative full verifier.
