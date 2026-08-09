# ADR 0009: Space Accounting Semantics

> Status: Accepted; Task 13 reconciliation validated
>
> Date: 2026-08-10
>
> Decision owners: Stornaut maintainers
>
> Related study:
> [`../upstream-studies/epic-3-quick-scan.md`](../upstream-studies/epic-3-quick-scan.md)

## Context

Surveyor facts are not a volume ledger:

- directory metadata and descendants overlap;
- hard links expose multiple paths for one allocation identity;
- logical bytes differ from allocated bytes for sparse/compressed files;
- APFS clones and purgeable space are not attributable from ordinary metadata;
- permission/mount gaps have no defensible byte estimate;
- live free space can change during scanning;
- reclaim disposition describes policy, not occupancy.

Task 13 must produce immutable, explainable accounting inputs without hiding
residuals or turning missing coverage into `0 B`.

## Decision

### Volume equations

When end capacity and general available capacity are both measurable:

```text
Volume Used = End Total Capacity - End General Available Capacity
Known       = sum(non-overlapping known owner allocated bytes)
Unknown     = Volume Used - Known
Free        = End General Available Capacity
```

If `Known > Volume Used`, Unknown is unavailable and the ledger is
`inconsistent`; it never clamps the residual to zero or creates a negative byte
value.

`Unknown` is the complete volume residual and therefore already includes:

- measured but unclassified entries;
- permission/mount gaps with unavailable size;
- filesystem content outside scanned roots;
- APFS clone/compression/purgeable and live-system effects not represented by
  Known owners.

`Unmeasurable` is a separate coverage/status projection. When a gap has no
defensible estimate it is `unmeasurable` with `bytes=nil`, and
`unknownIncludesUnmeasurable=true`. UI must not add Unknown and Unmeasurable.

### Non-overlapping owners

Accounting iterates measured entry facts, not recursive directory totals:

1. validate one unique snapshot ID and relative path per session/scope;
2. deduplicate regular files by `(device,inode)`;
3. assign each entry to the nearest classified ancestor;
4. sum logical and allocated values once into that owner;
5. leave entries with no owner in the observed-unclassified diagnostic;
6. exclude `unknownLargeConsumers` owners from Known even if they have a
   Classification record.

A directory classification owns its descendant entry facts. A nested
classification overrides its ancestor for that subtree, so parent and child
owner totals stay disjoint.

If one hardlink identity appears under different owners, attribution is
ambiguous: count the allocation once in the unclassified residual, not in an
arbitrary owner selected by path order.

Cross-device boundary metadata is coverage evidence only and is not subtracted
from the root volume. Its coverage gap explicitly sets
`includedInUnknownResidual=false`; in-scope permission/metadata gaps set it to
true. A mismatched device without `mountBoundary` status fails input validation.

### Occupancy versus disposition

`ReclaimDisposition` is copied onto an owner for filtering/explanation but is
not read by the occupancy formula. Changing Ready to Reclaim to Review
Recommended does not change Known, Unknown or Free.

`unknownLargeConsumers` remains in Unknown by category regardless of its
disposition.

### Explainability contract

Every displayed measure is a `SpaceLedgerMeasure` with:

- typed status;
- optional exact bytes;
- one or more `AccountingSource` values with sample time;
- stable `formulaKey`;
- stable `explanationKey`.

Core emits no localized prose or formatted byte strings.

The ledger carries both logical and allocated Known/unclassified diagnostics.
The primary Known/Unknown/Free reconciliation uses allocated bytes only.

Free-space delta is:

```text
End General Available - Start General Available
```

It includes both baseline sources and the fixed explanation key
`accounting.free.deltaNotAttributed`; it is never attributed to an item or scan.
Start free and start capacity are retained so decoding can recompute both the
delta and capacity-drift caveat rather than trusting serialized derived fields.

### Caveats

The ledger emits typed caveats:

- sparse file observed;
- hard link deduplicated;
- clone/compression not attributed;
- purgeable not estimated;
- volume changed during scan;
- known exceeds volume used.

Clone/compression and purgeable caveats are always present because Task 13 has
no trustworthy per-entry API for those semantics.

### Persistence

The existing closed `space_accounting` payload slot can persist either the
legacy Task 10 `SpaceAccounting` fixture or the new `SpaceLedger` through
separate typed APIs. Callers choose the exact type; no generic JSON/blob API is
exposed.

## Evidence

The checked-in `accounting-scenarios.json` and focused tests cover:

- parent/child owner overlap;
- hard-link deduplication;
- sparse logical/allocated divergence;
- unknown and permission-limited scopes;
- free-space drift;
- Ready versus Review occupancy equality;
- classified unknown remaining in Unknown;
- known exceeding volume-used inconsistency;
- duplicate/dangling/scope mismatch and integer overflow rejection;
- closed Codable invariant revalidation;
- real SQLite persist/reopen.

## Consequences

Positive:

- Overview can reconcile Known/Unknown/Free without hidden double counting;
- permission gaps remain visible without invented bytes;
- policy/disposition cannot manipulate occupancy totals;
- all measures retain source, sample time, formula and explanation;
- APFS caveats are explicit instead of guessed.

Costs:

- Unknown is a volume residual, not the sum of visible unclassified rows;
- owner totals require entry-level projections and can be more expensive than
  summing directory aggregates;
- a root-only scan cannot explain volume content outside that scope;
- `unknownIncludesUnmeasurable` must be honored by UI accessibility and charts.

## Residual Risks

- `(device,inode)` deduplication assumes one allocation identity for accounting;
  APFS clones can still share blocks under different inodes.
- Directory metadata allocation is included once as an entry fact but does not
  represent recursive content.
- Free-space samples can drift because of unrelated processes.
- Purgeable, clone and compressed physical allocation remain caveats.
- Task 20 must feed final rule/activity classifications before the product
  ledger is complete; Task 13 only establishes the deterministic formula.

## Acceptance Evidence

Task 13 accepts this ADR because:

1. 11 direct accounting and 60 focused integration tests pass;
2. review verifies parent/child disjointness and conservative cross-owner
   hardlink handling with no open P0–P2 finding;
3. immutable ledger decoding recomputes owner sums, Unknown, free delta, status,
   sources, formulas and mandatory caveats;
4. three Task 12 benchmark regression runs retain exact 1,356-entry counts;
5. full `scripts/verify` passes 180 SwiftPM tests, App tests, 2/2 XCUITest,
   screenshots, signing, localization and docs;
6. the closed ledger payload persists and reopens through Evidence Store.
