# Phase D Task 39B2c ii-c preserved-capsule recovery preflight

> Status: frozen / non-privileged prerequisite
>
> Baseline: `4fd9c539dbc2a7d9c659147c041712b945fa3b00`
>
> Trigger: v12 authorization review found that the existing stale-recovery path
> would delete the retained v11 Gate capsule before publishing a fresh attempt.

## Decision

The v12 campaign remains unstarted and unconsumed. The original authorization
was suspended because production source had to change; after the repair was
reviewed and pushed, the user explicitly rebound it to `0a17726`.

The repair adds an exact, closed preservation contract for a consumed historical
Gate capsule. A preserved node is identified by all of: outer attempt UUID,
canonical projected-cohort filename/whole-input digest, byte count and raw file
SHA-256. While holding the existing exclusive base ownership lock, stale
recovery must descriptor-relatively open and validate every preserved node using
the existing no-follow metadata/content decoder. Missing, extra, aliased,
malformed or byte-drifted preserved evidence fails closed before any stale
unlink or fresh publication. Valid non-preserved stale nodes retain the existing
exact cleanup behavior.

No path/name heuristic, mtime, PID or broad keep-all policy is admitted. The
production DEBUG handoff supplies only the exact v11 consumed-capsule identity
already bound by the checked disposition. No Codex, network, process-control,
sudo, install, cleanup or product authority is added.

## Scope and cost

The initial five-path estimate covered publication only. A downstream audit
found that final global teardown and the independent machine verifier also
encoded an empty Gate base. The corrected maximum non-document scope is thirteen
paths and 2,400 changed lines, still below the repository split threshold:

- `Sources/StornautInvestigationHandoffContract/InvestigationProjectedCohortInput.swift`
- `Sources/StornautInvestigationMachineLaunchSupport/InvestigationOwnerOnlyCapsule.swift`
- `Sources/StornautInvestigationMachineLaunchSupport/InvestigationMachineGateOwnership.swift`
- `Sources/StornautInvestigationMachineLaunchSupport/DarwinInvestigationFixedGateHandoffSystem.swift`
- `Sources/StornautInvestigationMachineGateCoordinatorSupport/InvestigationMachineGateCoordinatorComposition.swift`
- `Sources/StornautInvestigationMachineCampaign/main.swift`
- `Sources/StornautInvestigationMachineCampaignSupport/InvestigationMachineCampaignEvidenceContract.swift`
- `Tests/StornautInvestigationTests/InvestigationOwnerOnlyCapsuleTests.swift`
- `Tests/StornautInvestigationTests/InvestigationMachineCampaignEvidenceTests.swift`
- `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
- `scripts/verify-investigation-runtime-machine-report`
- `scripts/verify-investigation-boundaries`
- `scripts/verify-contract`

## Validation funnel

1. RED focused preservation, mismatch and coexistence cases.
2. Exact capsule/source structural and mutation gates.
3. Focused plus directly affected Investigation tests.
4. One serialized SwiftPM regression.
5. Targeted Debug/Release component and final-artifact boundaries.
6. Independent grouped and cross-boundary review.

The repair is non-admitting. It does not run the v12 campaign or the
authoritative full verifier.

## Validation record

- The exact preservation, mismatch-before-mutation, missing/duplicate contract,
  schema-v2 and real read-only v11 Gate verifier cases passed.
- The directly affected Investigation selection passed 209 tests in 4 suites.
- The ii-c aggregate contract, including seven preservation-specific source
  mutations, passed; the targeted Debug/Release campaign component boundary
  passed.
- The checkpoint's sole full serialized SwiftPM run executed 1,946 tests in 99
  suites and recorded four unrelated load-sensitive process timing failures.
  The four exact cases passed on the required isolated rerun; the original
  serial run is not represented as green and was not repeated.
- Independent runtime review found one P1: an admitting eight-epoch corpus could
  still use legacy schema v1 and bypass the live preserved-capsule proof. The
  verifier now requires schema v2 for every admitting cohort, and a dedicated
  negative regression proves schema-v1 admission is rejected.
