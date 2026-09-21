# Phase D Task 39B2c ii-c persistent evidence P2 preflight

> Status: frozen for implementation / non-admitting
>
> Date: 2026-09-14
>
> Baseline: `8a28c5b0ea36d13ae279c2f804b0a528603ddb23`

## Problem

The v13 campaign wrote raw evidence below Darwin's purgeable per-user temporary
directory. A low-disk event was strongly time-correlated with the later loss of
all nine v13 raw artifacts. In addition, the production fixed-Gate profile
preserves only v13 even though the live persistent Gate now contains both the
consumed v13 and v16 attempts and their exact capsules. A future publication
would therefore classify v16 as stale and remove it.

## Frozen repair

1. Future production raw evidence is rooted in an owner-private sibling below
   the account's existing physical `Library/Application Support` directory:
   `stornaut-iic-evidence-<campaign UUID>`. Tests retain explicit injected
   parents; product code does not consult `TMPDIR`.
2. The production handoff profile preserves exactly `retainedV13()` and
   `retainedV16()` before any stale cleanup or fresh publication. The generic
   publisher remains array-based and unchanged in authority.
3. The persistent Gate observer holds, verifies and revalidates both attempt
   directories and both capsule files. Its typed result carries an ordered
   identity for each historical capsule.
4. New campaign teardown uses strict schema v5 with an exact two-element
   `preservedGateCapsules` array ordered v13 then v16. Historical schemas v1-v4
   remain decodable but cannot satisfy the new production admission profile.
5. The independent machine verifier binds the exact campaign-named production
   evidence parent, its owner-private metadata and inventory, schema-v5 fields,
   both live Gate capsules and their physical identities.
6. Evidence-parent publication synchronizes the containing Application Support
   directory. Pre-writer failures remove only the exact proven-empty inode and
   synchronize again; partial writer initialization is retained and reported as
   a typed residue.

No existing v13/v16 raw bytes or persistent Gate entry is mutated by this
checkpoint. It does not authorize a campaign, sudo, root launch, L3c3d, L3c4 or
the final full verifier.

## Scope and budget

Expected non-document paths (maximum 11, below the 14-path split threshold):

- `Sources/StornautInvestigationHandoffContract/InvestigationProjectedCohortInput.swift`
- `Sources/StornautInvestigationMachineLaunchSupport/DarwinInvestigationFixedGateHandoffSystem.swift`
- `Sources/StornautInvestigationMachineCampaign/main.swift`
- `Sources/StornautInvestigationMachineCampaignSupport/InvestigationMachineCampaignEvidenceContract.swift`
- `Sources/StornautInvestigationMachineGateCoordinatorSupport/InvestigationMachineGateCoordinatorComposition.swift`
- `Tests/StornautInvestigationTests/InvestigationMachineCampaignEvidenceTests.swift`
- `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
- `Tests/StornautInvestigationTests/InvestigationOwnerOnlyCapsuleTests.swift`
- `scripts/verify-investigation-runtime-machine-report`
- `scripts/verify-investigation-boundaries`
- `scripts/verify-contract`

The eleventh path is test-only coverage for preserving two exact historical
capsules while removing an unrelated stale entry; it does not expand the
production surface. Expected non-document changed lines: at most 2,500, below
the 4,000-line split
threshold. Any additional production path requires a new preflight.

## Validation funnel

1. Swift parse and structural source gate.
2. Focused evidence/preservation tests and exact live read-only Gate observer.
3. Dedicated source/mutation/scope contracts, including TMPDIR regression and
   missing/extra/reordered/substituted v13/v16 capsule negatives.
4. One clean staged-only `StornautInvestigationTests` serial run if the focused
   and structural gates are green.
5. Two independent read-only reviews.
6. Commit and push. A fresh privileged campaign still requires a new explicit
   authorization bound to that pushed commit.
