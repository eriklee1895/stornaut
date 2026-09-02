# Phase D Task 39B2c ii-c Evidence Verification Prerequisite Preflight

> Status: frozen / implementation in progress / non-admitting
>
> Date: 2026-09-01
>
> Baseline: `3e49956f6f8e44d5d191d47c9e86856dd00d6966`
>
> Remaining order: evidence-verification prerequisite -> resolved root-driver
> lineage prerequisite -> ii-c-c unique machine campaign -> L3c3d -> L3c4

## Decision

Post-candidate review found that the persisted epoch bundle did not retain enough
canonical material for an independent consumer to recompute the outer admission
transcript and that the campaign/verifier did not join the claim, helper and
completion digests back to their authoritative binary evidence. Folding those
repairs into the already oversized ii-c-c candidate would violate the repository
scope discipline. They are therefore one bounded non-privileged prerequisite,
not another product Task.

The producer wire change and all consumers must land atomically. The checkpoint
must not commit a state where DriverSupport emits nine-field epoch evidence while
the Swift campaign, Python verifier or fixtures still accept only the historical
eight-field form. The wire remains internal and has never been admitted by a real
ii-c campaign, so no persisted production evidence requires migration.

## Exact Scope and Budget

Relative to the baseline, this checkpoint may change exactly these thirteen
non-document paths and at most 4,000 changed non-document lines:

1. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinOuterInnerProtocol.swift` — 610;
2. `Tests/StornautInvestigationTests/InvestigationMachineDarwinOuterInnerProtocolTests.swift` — 530;
3. `Sources/StornautInvestigationMachineCampaign/main.swift` — 90;
4. `Sources/StornautInvestigationMachineCampaignSupport/InvestigationMachineCampaignEvidenceContract.swift` — 770;
5. `Tests/StornautInvestigationTests/InvestigationMachineCampaignEvidenceTests.swift` — 850;
6. `scripts/verify-investigation-runtime-machine-report` — 340;
7. `scripts/verify-investigation-boundaries` — 400;
8. `scripts/verify-contract` — 150;
9. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineZeroArgumentEntry.swift` — 5;
10. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinOuterInnerComposition.swift` — 5;
11. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineHelperEpochContinuity.swift` — 35;
12. `scripts/verify-app-release-boundaries` — 80, limited to repairing the
    already-accepted ii-c-b1 source/self-seal projection after later b2b2
    additions; and
13. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
    — 20, limited to the new Installed-L2 import and independent semantic
    validation consumer assertions exposed by the staged-only serial run.

A fourteenth non-document path, a per-path overflow or line 4,001 stops coding for
scope reduction. `Package.swift`, the Gate transport schema, final coordinator
receipt schema, product targets and Xcode graph remain unchanged.

## Required Closure

- Each epoch retains canonical ownership/acknowledgement/decision/owner material
  and independently recomputes the admission transcript digest.
- Offline decoding revalidates terminal EOF, identities, absence/reap facts, mode,
  deadline and normal-result driver observation semantics.
- The eight-row bundle reconstructs the canonical cohort and projected input and
  validates successor continuity against the preceding admitted epoch.
- The Swift campaign and independent Python verifier accept only the new exact
  wire and independently derive `claimEvidenceSHA256`, `helperIdentitySHA256` and
  `completionBindingSHA256` from authoritative bytes.
- The independent verifier parses every field of the fixed 410-byte raw Gate
  payload and revalidates all constructor invariants before joining its output to
  the reconstructed driver completion and final coordinator receipt.
- The diagnostic writer admits the canonical Base64 envelope for the bounded
  three-MiB binary bundle without weakening the sixteen-MiB campaign harness cap.
- Self-consistent rewrap mutations for every join fail closed.

## Explicit Non-Claim and Required Successor

This checkpoint proves that all eight epoch records name one stable
`outerDriverProcessID`. It does **not** prove that this process is the exact
signed root outer driver descended from this Gate's `/usr/bin/sudo` invocation.
Stock macOS `sudo` may insert a PTY monitor or other session descendants, so the
raw Gate direct-child PID must not be equated with the driver parent PID.

Before the unique privileged campaign, a separate bounded prerequisite must add
authenticated resolved lineage evidence binding the root outer driver's PID,
pidversion/start identity, PGID, SID, audit session and fixed executable/signing
identity to this Gate/sudo descendant cohort, every epoch's driver-child parent,
and final retirement of the whole monitor/driver descendant cohort. The invalid
assertion `Gate direct sudo child == driver parent` must not be restored.

## Validation Boundary

Run structural/mutation checks, one combined focused/affected test command, one
new staged-only serialized Investigation regression, the existing component/final
image gate and independent review. This checkpoint runs no root operation, sudo,
install/uninstall, launchd mutation, real campaign, model call or authoritative
`scripts/verify --full`. The unique privileged attempt remains unconsumed.
