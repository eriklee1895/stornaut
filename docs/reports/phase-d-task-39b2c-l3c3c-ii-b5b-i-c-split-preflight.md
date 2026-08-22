# Phase D Task 39B2c L3c3c-ii-b5b-i-c Split Preflight

- Status: i-c1, aggregate i-c2 and ii-b5b-ii-a/ii-b complete/non-admitting; ii-b5b-ii-c current
- Date: 2026-08-22
- Order: i-c1 DriverSupport join/proof -> i-c2 legacy-owner closure
- Completion evidence: [i-c1 review](phase-d-task-39b2c-l3c3c-ii-b5b-i-c1-review.md)
  and [i-c2a review](phase-d-task-39b2c-l3c3c-ii-b5b-i-c2a-review.md)

## 1. Decision

The fresh post-i-b3 audit rejects an unsplit i-c checkpoint. Current source
requires a realistic 13-14 non-document paths and about 2,600-3,800 changed
lines across three independent review surfaces: DriverSupport join/proof
semantics, the legacy Machine/Lifecycle installed branch, and exactly-one-owner
structural closure. Combining them would recreate an oversized review surface.

i-c is split before coding into i-c1 and i-c2. i-b3 remains the sole extracted
physical/semantic InstalledL2 observer. Neither checkpoint owns readiness,
report/receipt generation or final admission.

## 2. i-c1 DriverSupport Join and Opaque Proof

Frozen ceiling: at most eight non-document paths and 1,800 changed lines:

1. `Package.swift`;
2. `InvestigationMachineSingleEpoch.swift`;
3. new DriverSupport installed-L2 join source;
4. new focused join tests;
5. `InvestigationMachineSingleEpochTests.swift`;
6. `InvestigationMachineTargetBoundaryTests.swift`; and
7. the two structural verifiers.

DriverSupport gains a one-way dependency on
`StornautInvestigationInstalledL2`; the extracted target never imports back into
DriverSupport, Machine or Lifecycle. i-c1 alone joins the exact typed projection,
claim evidence, one extracted semantic observation and repeated post-drop App
identity. Only that complete join may mint a package-scoped, opaque, `Sendable`,
`Equatable`, non-`Codable` proof with no field, JSON, report, receipt or readiness
surface.

The join requires exact epoch/configuration identities, exact App/helper claim
identities, one observer call and repeated App equality before proof minting. It
cannot accept caller-selected raw path, PID, service, deadline or endpoint; copy
an installed predicate or product schema; perform parallel physical reads; or
change release/retirement ordering. RED and mutation tests cover every
projection/claim/observer/repeated-App mismatch, call cardinality, opaque proof
shape, raw authority and public/`Codable` widening.

## 3. i-c2 Legacy Installed-Owner Closure

The first i-c2 RED and independent semantic review found two separable closure
surfaces. Removing the old phase/schema/predicate owner requires the fourteen
paths below. Removing the remaining legacy physical signing/artifact readers
also requires `DarwinRootTopologySupport.swift` and its focused tests, which
would exceed the repository's fourteen-path checkpoint limit. Therefore i-c2 is
split before final validation:

- **i-c2a semantic-owner closure** removes the old Lifecycle phase schema,
  installed predicate, Machine collector branch, service loaded-state schema
  and ScenarioDriver consumer; and
- **i-c2b physical-owner closure** receives a fresh post-i-c2a preflight and
  converts the remaining Lifecycle teardown path to absence-only reads, deleting
  the legacy pre-transition signing/binding reader before any exactly-one
  physical-owner claim.

The i-c2a ceiling after the pre-implementation call-graph and independent
semantic audits is at most fourteen
non-document paths and 2,200 changed lines. The original ten-path estimate
mistakenly listed the composition-only `InvestigationMachineDriverHost.swift`
while omitting the behavior test that directly asserts the legacy installed
event. The first RED then proved that deleting only the Machine call still left
the old installed schema/predicate owner in `StornautLifecycle`; the corrected
exact set therefore is:

1. `LifecycleRootTopologyObservation.swift`;
2. its Lifecycle tests;
3. `InvestigationLifecycleTopologyCollector.swift`;
4. `FixedLifecycleServiceProbe.swift` or its deletion;
5. `InvestigationMachineScenarioDriver.swift`;
6. host tests;
7. topology-collector tests;
8. fixed-service-probe tests;
9. scenario-driver tests;
10. scenario test support;
11. `InvestigationMachineTargetBoundaryTests.swift`; and
12. shared topology test support; and
13. the two structural verifiers.

`InvestigationMachineDriverHost.swift` remains unchanged: it only constructs
and invokes the collector and does not inspect or validate installed evidence.
The corrected fourteen-path scope is at, but does not exceed, the repository-wide
fourteen-path split threshold and does not add a fourth responsibility surface.
No further non-document path may be added without another split.

i-c2a removes the old Machine/Lifecycle installed-phase semantic branch. The
collector may retain only transition and post-teardown responsibilities; the
old fixed service probe cannot survive as a parallel installed evidence owner.
Existing host, collector, service and scenario support is retargeted rather than
duplicated. i-c2a does not change i-c1 proof or join semantics. Its remaining
`PostTeardownExpectedTopologyBindingReader` is explicitly non-admitting but
still performs physical signing reads; i-c2b must remove it before the combined
i-c2 checkpoint may claim exactly-one physical ownership.

The i-c2a semantic-owner gate rejects remaining authoritative `phase: .installed`
validation in the old collector, live installed use of
`FixedLifecycleServiceProbe`, or copied schema/predicate/physical readers in
Machine or Lifecycle. RED and mutation tests prove the old semantic path fails
before closure and cannot be reintroduced. The final exactly-one physical-owner
gate is reserved for i-c2b.

## 4. Validation and Non-Claims

Each checkpoint independently follows tests-first RED, structural and mutation
gates, focused/affected regression, one staged-only serial and independent
review. Neither checkpoint runs `scripts/verify --full`, installs or invokes the
App/helper, uses sudo/root, invokes real XPC, calls a model, reads auth or
accesses a network. All remain non-admitting. The order is i-c1 -> i-c2a ->
i-c2b; after i-c2b, b5b-ii fixed Darwin runtime is next. ADR 0018 remains
Proposed, production Deep Dive remains unavailable, and L3c4 alone owns
readiness and final admission.
