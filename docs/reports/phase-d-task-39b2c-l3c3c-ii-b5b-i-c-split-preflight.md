# Phase D Task 39B2c L3c3c-ii-b5b-i-c Split Preflight

> Status: i-c1 complete/non-admitting; i-c2 current
> Date: 2026-08-22
> Order: i-c1 DriverSupport join/proof -> i-c2 legacy-owner closure
>
> i-c1 completion evidence: [review](phase-d-task-39b2c-l3c3c-ii-b5b-i-c1-review.md)

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

Frozen ceiling: at most ten non-document paths and 2,200 changed lines:

1. `InvestigationMachineDriverHost.swift`;
2. `InvestigationLifecycleTopologyCollector.swift`;
3. `FixedLifecycleServiceProbe.swift` or its deletion;
4. host tests;
5. topology-collector tests;
6. fixed-service-probe tests;
7. scenario test support;
8. `InvestigationMachineTargetBoundaryTests.swift`; and
9. the two structural verifiers.

i-c2 removes or de-owns the old Machine/Lifecycle installed-phase branch. The
collector may retain only transition and post-teardown responsibilities; the
old fixed service probe cannot survive as a parallel installed evidence owner.
Existing host, collector, service and scenario support is retargeted rather than
duplicated. i-c2 does not change i-c1 proof or join semantics.

The exactly-one-owner gate rejects remaining authoritative `phase: .installed`
validation in the old collector, live installed use of
`FixedLifecycleServiceProbe`, or copied schema/predicate/physical readers in
Machine or Lifecycle. RED and mutation tests prove the old path fails before
closure and cannot be reintroduced.

## 4. Validation and Non-Claims

Each checkpoint independently follows tests-first RED, structural and mutation
gates, focused/affected regression, one staged-only serial and independent
review. Neither checkpoint runs `scripts/verify --full`, installs or invokes the
App/helper, uses sudo/root, invokes real XPC, calls a model, reads auth or
accesses a network. Both remain non-admitting. i-c1 precedes i-c2; after i-c2,
b5b-ii fixed Darwin runtime is next. ADR 0018 remains Proposed, production Deep
Dive remains unavailable, and L3c4 alone owns readiness and final admission.
