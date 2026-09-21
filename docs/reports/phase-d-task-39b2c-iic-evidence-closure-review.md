# Phase D Task 39B2c ii-c-c evidence-closure review

> Status: complete / non-admitting / fresh authorization required
>
> Date: 2026-09-13
>
> Candidate parent: `03daf8c919bad654143f03b976e74b152d5cd3ea`

## Result

The v15 pre-arm review found two evidence defects before any privileged launch:
the aggregate verifier did not admit the real staged candidate scope, and the
tree no-mutation snapshot did not bind extended attributes. The campaign was
not launched or consumed. There is no v15 campaign UUID, attempt UUID, launch
claim, sudo invocation, installation or root action. The v15 authorization is
therefore superseded and cannot be reused.

This checkpoint closes both defects without changing product, runtime,
lifecycle or campaign implementation source. It remains non-admitting and does
not authorize a replacement campaign.

## Evidence closure

- The aggregate contract first admits the current real staged candidate against
  exact parent `03daf8c919bad654143f03b976e74b152d5cd3ea`, including index/worktree
  identity and the exact four non-document paths.
- The immutable preservation replay binds commit
  `facf3eae2fbee83056189e2cfd54cf974ae1421b`, parent
  `e717b586cb430d1866249ddb13ac2d04e81e6519` and tree
  `a25134f6bcd37852b8ce38502301f95cc7b55d34`. Its exact committed blobs are
  loaded into an isolated index/worktree; current source cannot substitute for
  the historical candidate.
- Preservation and evidence-closure scopes each have one canonical case plus
  nine negative controls: extra path, missing path, binary content, wrong mode,
  per-path over-budget, aggregate over-budget, staged/worktree divergence,
  wrong baseline and untracked content.
- `treeSnapshot` now includes every enumerated node's xattr name as lossless
  hexadecimal bytes, value byte count and value SHA-256. Both enumeration and
  reads use `XATTR_NOFOLLOW` and fail closed on size or read drift.
- The aggregate mutation corpus includes `snapshot-xattr-drop`, preventing the
  xattr no-mutation assertion from becoming vacuous again.
- Seventeen active-status records bind the superseded/unconsumed v15 state and
  reject the prior pending/authorized wording.

## Scope

The non-document candidate is exactly four paths and 675 changed lines against
the candidate parent:

- `Tests/StornautInvestigationTests/InvestigationMachineCampaignEvidenceTests.swift`: 52 lines;
- `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`: 97 lines;
- `scripts/verify-contract`: 369 lines;
- `scripts/verify-investigation-boundaries`: 157 lines.

The per-path ceilings are 100, 120, 420 and 180 lines respectively, with a
700-line aggregate ceiling. An initial standalone scope run correctly rejected
the old 80-line TargetBoundary ceiling after the final status pins were added.
The ceiling was corrected to the already planned 120-line bound, while the
aggregate ceiling was tightened from the provisional 760 to 700. The aggregate
negative fixture was synchronized to reject 701/700 without violating an
individual path ceiling.

## Validation

- `iiCCFailureDispositionVerifierRemainsReadOnlyAndNonAdmitting`: 1/1 passed;
- `iiCCPreservedHistoricalGateCapsuleContractIsClosed`: 1/1 passed;
- complete `InvestigationMachineTargetBoundaryTests`: 64/64 passed;
- live Evidence suite with the exact retained v13 Application Support Gate:
  104/104 passed, including the xattr mutation case;
- standalone evidence-closure staged-scope contract: exit 0;
- final `scripts/verify-contract --iic-c-contract-only`: exit 0 after all source
  and test synchronization;
- `scripts/verify-contract` self-seal:
  `015b4dda68e3a540e9d8f9eb75eb01cb043e1ee3f4cd9ac9ab7c4e58c07bcea8`;
- final clean serialized SwiftPM regression: 1,969 tests in 100 suites, zero
  failures, 187.563 seconds. The five maximum benchmarks and explicit opt-in
  live/privileged diagnostics remained skipped as required.

The runtime/evidence reviewer and verifier/scope reviewer independently reported
no unresolved P0-P2. Review was read-only; neither reviewer modified files or
ran sudo, a campaign or the full verifier.

## Preserved state and next gate

The exact retained v13 Gate remains under owner-private Application Support and
is unchanged. Historical v8-v13 evidence and v14/v15 authorization records were
not rewritten, deleted or reused. The fixed App, plist, service, runtime and
lease remain absent. Production Deep Dive and Task 40 remain blocked.

After this checkpoint is pushed, the next action is a new explicit user
authorization bound to that pushed commit, followed by exactly one privileged
replacement machine campaign. Only a green campaign may proceed to L3c3d and
then L3c4. `scripts/verify --full` remains reserved for L3c4.
