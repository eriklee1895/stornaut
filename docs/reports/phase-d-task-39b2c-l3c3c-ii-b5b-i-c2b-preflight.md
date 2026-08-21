# Phase D Task 39B2c L3c3c-ii-b5b-i-c2b Preflight

> Status: split before validation; i-c2b-i current
> Date: 2026-08-22
> Baseline: `58332ccb9f78da203fb2380ca006c49f0f371c2b`
> Aggregate scope: exactly twelve non-document paths
> Admission: non-admitting; i-c2 aggregate closes only after this checkpoint

## 1. Decision

i-c2a removed the obsolete installed-phase schema, predicate and Machine
collector branch, but intentionally left one physical duplication for this
separate checkpoint: the post-teardown path still rereads installed App, helper
and machine-driver signing state to construct `LifecycleRootTopologyBinding`,
and its Darwin artifact/process readers still contain positive
hash/signing/manifest/executable-path machinery.

i-c2b removes that physical duplication. Post-teardown evidence becomes strictly
absence-only. The only installed physical-evidence owner then remains the
extracted `StornautInvestigationInstalledL2` observer consumed by the i-c1
DriverSupport join.

The first complete implementation tree measured 4,113 changed non-document
lines because deleting the obsolete positive-reader implementation and tests
alone accounts for more than 3,000 lines. This exceeds the preflight's 3,800
changed-line ceiling even though the tree adds only 1,092 lines and remains far
below the repository's roughly 4,000-added-line split threshold. The checkpoint
is therefore split before staged validation rather than raising its frozen
ceiling or retaining dead code:

- **i-c2b-i absence-only implementation/tests** owns paths 1-10 below, with a
  ceiling of ten non-document paths and 3,800 changed lines; and
- **i-c2b-ii verifier closure** owns paths 11-12 below, with a ceiling of two
  non-document paths and 800 changed lines.

The aggregate i-c2b contract closes only after both commits are reviewed and
pushed.

## 2. Frozen Scope

The exact non-document path set is:

1. `Sources/StornautLifecycle/LifecycleRootTopologyObservation.swift`;
2. `Sources/StornautLifecycle/DarwinRootTopologySupport.swift`;
3. `Sources/StornautInvestigationMachine/InvestigationLifecycleTopologyCollector.swift`;
4. `Tests/StornautLifecycleTests/LifecycleRootTopologyObservationTests.swift`;
5. `Tests/StornautLifecycleTests/DarwinRootTopologySupportTests.swift`;
6. `Tests/StornautInvestigationTests/InvestigationLifecycleTopologyCollectorTests.swift`;
7. `Tests/StornautInvestigationTests/InvestigationLifecycleTopologyTestSupport.swift`;
8. `Tests/StornautInvestigationTests/InvestigationMachineDriverHostTests.swift`;
9. `Tests/StornautInvestigationTests/InvestigationMachineScenarioTestSupport.swift`;
10. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
11. `scripts/verify-investigation-boundaries`; and
12. `scripts/verify-contract`.

The aggregate scope is exactly twelve non-document paths. The i-c2b-i and
i-c2b-ii ceilings are frozen above. A thirteenth aggregate non-document path,
any required change to the fixed service probe, or any new responsibility
surface requires another preflight split before coding. `Package.swift`, the production DriverHost and
ScenarioDriver, all `StornautInvestigationInstalledL2` sources, and all
DriverSupport installed-proof sources remain unchanged.

## 3. API and Ownership Contract

Delete the teardown-only positive-evidence model:

- `LifecycleRootTopologyBinding`;
- `LifecycleRootTopologyProcessSnapshot`;
- `LifecycleRootTopologyProcessReadResult`;
- the topology-only identifier/binding validation;
- binding fields from topology requests and observations;
- `InvestigationLifecyclePostTeardownBindingReading`;
- `PostTeardownExpectedTopologyBindingReader`; and
- all collector binding-reader injection and physical binding comparisons.

The artifact observation becomes exactly `absent`, `present` or
`unavailable(reasonKey:)`. The artifact reader receives a fixed role and the
closed installation contract, maps all eight roles to fixed URLs, and performs
one non-following `lstat`. It performs no descriptor opening, hashing, file
reading, manifest parsing, signing check or positive node validation.

The process reader receives one complete captured `LifecycleProcessIdentity`
and performs one kernel identity lookup. It performs no `proc_pidpath` or
code-signing lookup. The post-teardown observer receives only the exact captured
App/helper identities and the observation window.

`SignedInvestigationRuntimeBinding` remains in the collection request and
cohort because configuration identity and the claim's configuration digest
still bind the run. It must not be reconstructed into teardown physical
evidence.

## 4. Fail-Closed Absence Semantics

Artifact classification is exact:

- initial `lstat` failure with `ENOENT` means `absent`;
- any successful `lstat`, including a symlink or wrong node type, means
  `present`;
- every other errno, including `EACCES`, `EPERM` and `EIO`, means
  `unavailable`; and
- no second observation may turn present or uncertain evidence into absence.

Process classification is exact:

- initial identity lookup failure with `ESRCH` means `absent`;
- complete identity equality means `sameIdentityAlive`;
- the same PID with any PID-version, audit-session, effective-UID or audit-token
  difference means `identityReused`; and
- every other failure means `unresolved`.

PID reuse proves only that the captured original identity is gone. A process
observed alive is not re-read and reclassified as absent. The driver process is
not checked because it may still be executing while proving that the installed
driver path has been removed.

The fixed service contract is unchanged: only a structured missing registry
result proves absence. Registered, foreign-label and unavailable outcomes do
not. Post-teardown proof still requires all eight artifacts absent, both exact
captured processes absent or identity-reused, and the service absent.

## 5. Identity, Time and One-Shot Invariants

The collector preserves the complete identity and chronology chain:

```text
residue.observedAt
<= claim.recordedAt
<= claim.request.issuedAt
<= claim.claimedAt
<= request.openedAt
<= collector initial observation time
```

It also preserves the bounded request/configuration window, exact App claim
identity, exact claimed root-helper identity and L1 audit-session relationship.
Root authority and deadline are checked before claim work, immediately before
transition and after transition. The transition must return before
`transitionedAt` is sampled; post-teardown observation must start at or after
that barrier and finish by `validBefore`. Success, failure and cancellation all
consume the collector exactly once.

## 6. Tests-First RED and Mutation Matrix

The first implementation action is a focused RED proving the baseline still
contains `PostTeardownExpectedTopologyBindingReader`,
`LifecycleRootTopologyBinding` and the positive topology readers. The RED then
freezes:

- bindless request/observation and collector APIs;
- all-eight-role absence and each-role present/unavailable failures;
- ENOENT-only artifact absence, with success/symlink as present and other errno
  as unavailable;
- ESRCH-only process absence, exact-live, every full-identity reuse axis and
  unresolved failures;
- exact transition-before-observation and identity/time joins;
- root/deadline/cancellation/concurrency/one-shot behavior; and
- exactly one installed physical owner in `StornautInvestigationInstalledL2`.

Add dedicated `--iib5bic2b-absence-only-contract-only` and staged-scope modes.
Mutation controls must reject reintroduced binding readers/fields, copied
installed readers, present or `EACCES` mapped to absence, a missing artifact
role, PID-only comparison, live or non-ESRCH failure mapped to absence, lost
identity-reuse acceptance, registered service mapped to absence, observation
before transition, weakened timestamp/identity joins, boolean/early-return/test
vacuity and a second installed owner. Staged-scope mutations cover the exact
baseline, extra/deleted/binary/over-budget paths and staged semantic drift.

## 7. Validation and Non-Claims

Validation order is:

1. tests-first focused RED;
2. i-c2b-i focused Lifecycle/Darwin and Machine collector/host/scenario tests;
3. i-c2b-i affected Lifecycle and Investigation suites;
4. one i-c2b-i staged-only serialized SwiftPM regression;
5. i-c2b-i independent production/test review and commit;
6. i-c2b-ii structural, mutation, historical-replay and staged-scope gates;
7. applicable Debug/Release diagnostic-driver/final-Mach-O gates; and
8. independent verifier and aggregate cross-group review.

This checkpoint does not run `scripts/verify --full`, install, bootout, invoke
sudo/root or real XPC, call a model, read auth, access a network, or emit
readiness/admission evidence. It does not change the fixed service probe, the
installed observer/join, cleanup authority or product availability. i-c2b is
non-admitting; after it closes aggregate i-c2, ii-b5b-ii fixed Darwin runtime is
next. ADR 0018 remains Proposed, and L3c4 alone owns final readiness and the
remaining authoritative full verifier.
