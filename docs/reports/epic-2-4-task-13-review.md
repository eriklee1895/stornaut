# Epic 2–4 Task 13 Code Review — 2026-08-10

> 状态：All confirmed findings fixed; post-fix review has no open P0–P2
> finding
>
> 范围：Space Ledger contracts、non-overlapping owner projection、volume
> reconciliation、persistence 与 accounting fixtures
>
> 方法：`bits-code-guard` diff scope + 7-dimension accounting/manual fallback
> + adversarial fixture tests + benchmark regression + full verification

## 1. Review Scope

- 16 files in the final Task 13 scope, including routing/ADR/report updates;
- six Swift/JSON review files and 2,330 reviewed changed lines;
- immutable ledger contracts and nested Codable validation;
- entry-to-owner projection, hardlinks, mount boundaries and overflow;
- Known/Unknown/Unmeasurable/Free formulas and source/formula keys;
- closed Evidence Store persist/reopen path;
- no repository custom workflow.

The post-fix automatic report is retained in the Task 13 `/tmp` review
workspace and reports no open P0–P2 finding.

## 2. Confirmed Findings and Fixes

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P0 | Persisted ledger validation did not recompute `Unknown = capacity - free - known`, so altered Unknown bytes could decode as trusted | Persist start/end capacity/free and recompute Used, Unknown, free delta, status and drift caveat in the throwing initializer | JSON mutations of Unknown, Known, start-free, status and formula fail closed |
| P1 | A hardlink crossing Known/Unknown owners was assigned to the first path lexically, making Known path-name dependent | Group hardlinks first; same-owner links deduplicate there, cross-owner links are counted once in unclassified residual with `hardLinkOwnershipAmbiguous` | known/unknown owner hardlink fixture |
| P1 | Mount-boundary bytes were described as included in the root Unknown residual even though the boundary is another volume | Add per-gap `includedInUnknownResidual`; mount boundaries are coverage-only and their metadata bytes are excluded | mount-boundary residual test |
| P1 | `unknownLargeConsumers` with a Classification could enter Known | Exclude that category from Known logical/allocated totals while retaining the owner projection | classified-unknown occupancy test |
| P1 | Logical totals were only derivable by UI reducing owners | Add first-class Known logical and unclassified logical measures with formula/source keys | fixture expected logical totals |
| P1 | Owners carried only classifier source although bytes came from Surveyor | Require both Surveyor and Classifier sources for every owner | Codable/source invariant tests |
| P1 | Synthesized nested decoding could bypass measure/owner/gap/ledger invariants | Add throwing custom decoding and aggregate-sum/status/caveat/source/formula validation | adversarial JSON mutations |
| P1 | Free delta stored only a delta and sources, so its equation could not be revalidated | Persist start free/capacity measures and require `delta=end-start` plus exact non-attribution keys | start-free mutation test |
| P1 | Classified-but-unmeasurable owners appeared as `0 B` | Owner bytes stay nil until at least one measurable entry is assigned | coverage/unmeasurable contracts |
| P1 | Cross-device metadata without mount-boundary status could enter root accounting | Reject device mismatch unless it is a mount-boundary observation; never count boundary bytes | scope/mount tests |
| P1 | Output status and caveats could be changed independently | Recompute reconciled/partial/inconsistent conditions and require clone/purgeable/known-exceeds/drift caveat consistency | status/caveat mutation tests |
| P2 | One implementation file mixed large immutable contracts and the reconciliation engine | Split into `SpaceLedger.swift` and `SpaceLedgerReconciler.swift` | build and focused suite |

## 3. Formula and Safety Result

### Volume reconciliation

```text
Used    = End Capacity - End Free
Known   = non-overlapping non-Unknown owner allocated bytes
Unknown = Used - Known
Free    = End Free
```

- `Known > Used` produces unavailable Unknown and `inconsistent`; it is never
  clamped to zero.
- Unknown is the complete root-volume residual and already includes
  unquantified in-scope gaps.
- Unmeasurable is a coverage projection with unavailable bytes; UI must not add
  it to Unknown.
- Mount-boundary gaps are outside the root volume and explicitly are not
  included in Unknown.

### Owner projection

- Measured entry facts are assigned to the nearest classified ancestor.
- Nested owners override ancestors, so owner totals are disjoint.
- Recursive directory plus child totals are never combined as a directory
  aggregate.
- Same-owner hardlinks count once.
- Cross-owner hardlinks count once in unclassified residual, not arbitrarily in
  Known.
- `ReclaimDisposition` is not read by occupancy formulas.
- `unknownLargeConsumers` remains in Unknown by category.

### Explainability

- Every displayed measure has typed status, bytes, sources/sample times,
  formula key and explanation key.
- Logical and allocated diagnostics remain separate.
- Free-space delta uses two volume sources and fixed “not attributed” semantics.
- Clone/compression and purgeable caveats are mandatory because no estimate is
  invented.
- Core stores keys and bytes only; it emits no localized prose/formatting.

## 4. Verification

Focused post-review result:

- 60 domain, Surveyor, lifecycle, store and accounting tests passed;
- 11 direct Space Accounting tests passed;
- closed ledger payload survived real SQLite store reopen.

Task 12 production benchmark regression:

| Run | Entries | First useful | Elapsed | Peak RSS |
| --- | ---: | ---: | ---: | ---: |
| 1 | 1,356 | 29.53 ms | 107.51 ms | 16,695,296 B |
| 2 | 1,356 | 17.46 ms | 108.20 ms | 17,154,048 B |
| 3 | 1,356 | 18.15 ms | 130.07 ms | 17,334,272 B |

Counts and logical/allocated bytes remained exact.

Final `scripts/verify` passed:

- 180 SwiftPM tests (3 opt-in diagnostics skipped by design);
- Xcode App contract tests;
- 2/2 XCUITest cases;
- four Light/Dark screenshots and image checks;
- App signing and bundle verification;
- localization parity, docs links and diff checks.

## 5. Remaining Boundaries

- Task 13 defines deterministic formula semantics; Task 20 supplies final
  multi-root/rule/activity projections.
- Unknown can remain large because content outside scan roots is intentionally
  part of the volume residual.
- APFS clones, compression and purgeable bytes remain caveats.
- Task 21–23 UI must honor `unknownIncludesUnmeasurable` and never stack the two
  values.
- Execution accounting remains Phase C and cannot reuse scan occupancy as
  reclaimed/free-space proof.
- Deep Dive remains no-go/paused.
