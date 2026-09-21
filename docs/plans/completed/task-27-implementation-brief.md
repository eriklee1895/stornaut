# Task 27 Implementation Brief — Safe Execution Study and Decisions

> Status: Completed — study, baseline audit and ADR decisions are ready for
> Task 28; final unified verifier exit `0`
>
> Date: 2026-08-11
>
> Parent plan:
> [Epic 8 Safe Execution Vertical Slice](epic-8-safe-execution-vertical-slice.md)
>
> Study gate:
> [Epic 8 Safe Execution](../../upstream-studies/epic-8-safe-execution.md)

## 1. Objective

Freeze the Phase C safety architecture before adding persistence or connecting
the existing action Spike to product state:

```text
retained Quick Scan truth
→ current execution-profile evidence
→ non-authoritative Plan and selection
→ pure Policy decisions
→ explicit confirmation
→ one-shot authorization
→ fresh ActionPolicy revalidation
→ write-ahead journal
→ native Trash
→ immutable Manifest
```

Task 27 changes no product behavior and performs no real Trash action. It is
complete only when:

- current machine, SDK, Store, Catalog and signed-App baselines are recorded;
- upstream behavior and licenses are pinned to exact commits/files;
- the proposed cache profile is accepted or narrowed from evidence;
- authorization/stale/cancellation semantics are decided in ADR 0011;
- crash/journal/Manifest/accounting semantics are decided in ADR 0012;
- active plan and document routers agree;
- the current unified verifier, document links and diff checks pass;
- the documentation diff receives an explicit safety/design review.

Task 27 may harden the existing verification harness when the final gate proves
that it captured the wrong application window. Such a change must not alter
product behavior and requires its own focused repetition plus the full
verifier.

## 2. Evidence-Driven Plan Correction

The approved plan proposed:

- Ready: npm `_cacache`, pip cache and uv cache;
- Review: Go build cache.

Task 27 narrows this to:

| Rule | Phase C execution status | Reason |
| --- | --- | --- |
| `cache-npm-content` | Ready after complete current evidence | npm calls `_cacache` a strict content-addressable cache and states that missing/corrupt data is refetched |
| `cache-pip` | Ready after exact default-location and current-evidence checks | pip documents HTTP/wheel caches and `pip cache purge`; internal sub-layout is not inspected |
| `cache-go-build` | Review after complete current evidence | Go documents reconstructible build/test/fuzz cache, but `GOCACHE` is configurable and rebuild cost can be material |
| `cache-uv` | no execution profile | uv explicitly says direct cache modification/removal is never safe and cleanup must use its lock-aware commands |

No replacement rule is added. uv remains visible as ordinary
`reviewRecommended` classification evidence; a future fixed `uv cache`
Registered Action belongs to Phase E.

## 3. Binding Decisions

### 3.1 Evidence and activity

- Execution profiles are checked-in, closed and exact-path only.
- Compiler-attested evidence is limited to pinned provenance and exact
  default-layout/recovery facts.
- Current owner, kind, identity, volume, root and activity are runtime facts.
- A profile may not invoke a tool merely to discover its configured cache path.
- npm/pip/Go profiles apply only to the exact built-in default paths. They do
  not follow environment/configuration overrides to make another path
  executable.
- `activity.process.inactive` requires one bounded whole-snapshot query against
  a checked-in process-family set. A single wrapper-name check is insufficient.
- Process enumeration failure, truncation or an incomplete subject mapping
  yields Unknown/deny.

Initial process-family candidates to test in Task 29:

- npm: `node`, `npm`, `npx`, `corepack`;
- pip: `python`, versioned Python basenames, `pip`, versioned pip basenames;
- Go: `go`, `compile`, `link`, `asm`, `cgo`.

Task 29 must prove the exact bounded normalization rules and reject unexpected
names; this brief does not authorize substring matching.

### 3.2 Product authority

- A Cleanup Plan is a persisted proposal.
- Checkbox selection is in-memory intent.
- Policy decisions are persisted audit facts.
- Confirmation mints the only execution authorization.
- The authorization is non-`Codable`, internal, one-shot and admitted within
  30 seconds.
- An admitted serial batch does not falsely abort merely because that
  admission deadline later passes.
- Every later action still receives a current Policy and filesystem
  revalidation.
- Selection generation, decision fingerprint or workflow mutation invalidates
  an unused authorization.

### 3.3 Stale and cancellation

- Changed catalog/profile, root lease, identity, bytes, mtime, ownership,
  volume, evidence or activity blocks execution.
- Review may preserve or downgrade persisted Ready/Review; it cannot promote a
  persisted Protected/Unknown item.
- A stale sheet exposes refresh/cancel only.
- Overlapping selected ancestor/descendant paths block the entire selection.
- Cancellation is valid before execution and between actions.
- A synchronous Foundation Trash call supports only Stop After Current Action.

### 3.4 Journal and Manifest

- Intent and action start are durable before each target write.
- Returned outcomes are durable before a later action starts.
- A crash after `actionStarted` but before a durable outcome is always
  `outcomeUnknown`, regardless of what the path currently looks like.
- Unknown stops the batch and is finalized into an immutable Manifest; it is
  never automatically retried.
- Manifest insertion is insert-only with idempotent same-ID/same-payload retry.
- Same ID with different bytes is corruption.
- Manifest persistence failure becomes `auditPending`; retry saves audit only
  and never reruns a filesystem action.
- Exact original/Trash paths expire with linked seven-day Evidence. The
  90-day Manifest retains stable IDs, typed recovery state, Policy, measures,
  result and error, not path-rich receipts.

## 4. Files

Create:

```text
docs/upstream-studies/epic-8-safe-execution.md
docs/adr/0011-review-policy-authorization.md
docs/adr/0012-cleanup-execution-journal.md
docs/plans/active/task-27-implementation-brief.md
```

Update:

```text
AGENTS.md
StornautAppUITests/StornautAppUITests.swift
StornautApp/History/HistoryView.swift
docs/README.md
docs/agent/coding-agent-handoff.md
docs/plans/active/README.md
docs/plans/active/epic-8-safe-execution-vertical-slice.md
docs/plans/roadmap.md
docs/adr/README.md
docs/upstream-studies/README.md
docs/reports/README.md
```

Do not modify Rule JSON, SQLite schema, App state or product behavior in Task
27. Accepted Swift changes are limited to:

- a semantic accessibility identifier on the existing History confirmation;
- state-driven XCUITest focus/action helpers that prevent external System
  Settings or stale AX nodes from consuming an interaction.

## 5. Baseline and Validation

The study records:

- baseline HEAD `e4f936a99e257e55c000111833bd460277dc2bc9`;
- macOS 26.5.1 / arm64 / Xcode 26.6 / Swift 6.3.3;
- SQLite 3.51.0 and live Evidence Store schema `2`;
- built-in Catalog SHA-256
  `133b3829816fa951f03cb87473e03454c3e561b421c83e6c8efaf8ad89849e99`;
- 67 rules, 34 `moveToTrash`, zero Ready;
- ad-hoc Debug App identity `com.eriklee.stornaut`, App Sandbox disabled;
- current Foundation and SwiftUI compiled API witnesses.

Required checks:

```bash
scripts/check-doc-links
git diff --check
scripts/verify
```

The first auxiliary normal-build XcodeBuildMCP call incorrectly repeated the
session's configured `derivedDataPath` and failed before build with:

```text
option '-derivedDataPath' may only be provided once
```

This is a harness invocation error, not a project failure. The final check must
use the repository's configured XcodeBuildMCP defaults without duplicating
that argument.

Final unified verifier:

- SHA-256:
  `a634ca746cee1eef26ea66206281db8a96ea442b17fda48a64eb65b388e4b1e4`;
- XCUITest `9/9`;
- all 17 screenshot contracts passed;
- SwiftPM `279/279` twice;
- App/bundle/Release/localization/docs gates passed.

## 6. Review Focus

Review the documentation diff for:

- any implicit authorization or reusable capability;
- Ready promotion without complete current evidence;
- uv direct directory mutation;
- path-rich data leaking into 90-day audit;
- crash recovery that could duplicate a Trash action;
- overwrite-capable Manifest persistence;
- false `Freed` accounting;
- hidden real Registered Actions, Shell or permanent deletion;
- a Task 28 implementation detail that contradicts the current APIs.

## 7. Task 28 Handoff

Task 28 may start only after Task 27 is reviewed, verified, committed and
pushed. It must:

- write red domain/migration/journal tests first;
- evolve existing cleanup types to domain v2, not add parallel V2 public types;
- migrate Evidence Store atomically from fresh/v1/v2 to v3;
- preserve historical v1 records conservatively;
- make final Manifest insertion immutable and idempotent;
- keep authorization non-persistable by construction;
- keep path-rich recovery evidence outside the minimal Manifest.
