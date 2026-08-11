# Task 28 Implementation Brief — Cleanup Domain v2 and Store v3

> Status: Completed and passed
>
> Date: 2026-08-11
>
> Parent plan:
> [Epic 8 Safe Execution Vertical Slice](epic-8-safe-execution-vertical-slice.md)
>
> Accepted decisions:
> [ADR 0011](../../adr/0011-review-policy-authorization.md) and
> [ADR 0012](../../adr/0012-cleanup-execution-journal.md)

## 1. Objective

Create the closed persistence contracts required before any product cleanup
or Review wiring:

```text
historical cleanup v1 payload
→ conservative in-memory v2 projection

new cleanup v2 payload
→ closed Plan / Policy / Journal / Manifest invariants
→ Evidence Store schema v3
→ immutable and idempotent Manifest insert
```

Task 28 performs no filesystem cleanup, enables no CTA and adds no execution
authorization. It is complete only when:

- v1-only domain records reject schema v2 instead of silently accepting it;
- historical Cleanup Plan/Policy/Manifest v1 fixtures decode conservatively;
- every new cleanup write is schema v2 and current, not a legacy projection;
- journal records are bounded, path-free and transition monotonically;
- Store migration supports fresh/v0/v1/v2 → v3 atomically;
- Manifest same-ID/same-payload retry is idempotent and any mutation conflicts;
- Plan/Policy/Manifest/journal paging isolates corrupt rows;
- Clear Evidence and Clear Manifests preserve their safety boundary;
- retention differentiates no-write prepared journals from audit-relevant runs;
- focused/full verification and code review pass.

## 2. Domain v2 Shape

### 2.1 Version boundary

Add `DomainSchemaVersion.v2`.

All existing non-cleanup domain types remain v1-only and explicitly reject v2.
Cleanup records use their existing public type names and decode:

- v1 payload → schema-v2 conservative projection with
  `compatibility = legacyV1`;
- v2 payload → `compatibility = current` and all current fields required.

Legacy projections are readable/exportable but cannot be written through the
new execution persistence APIs.

### 2.2 Cleanup Plan

A current Plan binds:

- one scan session and scope;
- one Primary Root identity;
- catalog and execution-profile versions;
- one plan fingerprint;
- bounded ordered items;
- each item to classification/rule/profile, expected relative path and full
  file identity, byte measures and evidence/activity fingerprints.

Current items require `MoveToTrash`; Registered Action proposals remain
historical/non-executable in Task 28. Duplicate item/snapshot/classification or
expected identities, and ancestor/descendant paths, are rejected.

### 2.3 Policy Decision

A current decision binds:

- one plan and item;
- selection generation and origin;
- plan and decision fingerprints;
- disposition, result and stable reason keys.

Allowed Review requires explicit user selection. Protected/Unknown cannot be
allowed. Policy remains audit data and is never an authorization token.

### 2.4 Manifest

A current Manifest includes:

- immutable ordered records;
- Policy decision identity and reason keys;
- typed result, recovery and error stage;
- selected, processed, moved-to-Trash and permanent byte measures;
- a checked aggregate equal to record sums;
- optional non-causal volume observation.

MoveToTrash permanent bytes are zero. A success requires moved-to-Trash
recovery truth. Failure/Unknown requires a typed error. Cancelled-not-started
may have no timestamps or processed bytes. No path or Trash URL field exists.

## 3. Journal Contract

The internal journal stores:

- run/plan/manifest IDs and selection generation/fingerprint;
- ordered item/action entries, expected identity and fingerprints;
- prepared/started/outcome/cancelled states;
- typed path-free outcome and destination identity;
- stop-after-current intent;
- stage, retention class and timestamps.

Maximums:

- 100 actions;
- unique action and Plan item IDs;
- one started action at a time;
- ordered prefix of outcomes, then at most one started action, then prepared
  entries;
- no stage regression.

Retention classes:

- `evidenceLinked`: only a purely prepared, no-write journal; maximum 7 days;
- `audit`: any started/outcome/manifest-pending state; maximum 90 days.

Clear Evidence may remove only evidence-linked no-write journals. Clear
Manifests removes final Manifests and all execution journals but never user
files, Trash or Local Knowledge.

## 4. Store v3

Add one strict `cleanup_run_journals` table:

```text
id primary key
plan_id
stage
retention_class
updated_at_ms
expires_at_ms
payload
```

Do not foreign-key it to Cleanup Plan: audit-relevant journal state must survive
seven-day Evidence/Plan deletion. Add expiry/stage indexes.

Store APIs:

- current Plan write + single/load/page;
- current Policy write + plan page;
- journal insert/monotonic update/load/page/delete;
- immutable Manifest insert/load/page/delete;
- corrupt-row isolation for pages.

Manifest insertion:

```text
missing ID → insert
same ID + identical storage identity + identical payload → success/no-op
same ID + any different byte/storage value → immutableRecordConflict
```

No `ON CONFLICT DO UPDATE` is reachable for Manifest.

## 5. Tests First

Add focused suites before implementation:

```text
CleanupDomainV2Tests
CleanupJournalTests
CleanupStoreV3Tests
EvidenceMigrationTests updates
RetentionPolicyTests updates
```

Required red cases:

- v2 accepted only by cleanup types;
- future/unsupported versions rejected;
- v1 cleanup fixtures project to legacy, non-writable v2;
- missing scope/catalog/profile/root/fingerprint/identity rejected;
- duplicate and overlapping Plan items rejected;
- allowed Review without explicit selection rejected;
- no Codable authorization field in any persisted JSON;
- journal path/URL payload injection rejected by strict decoding;
- invalid stage/action prefix and transition regression rejected;
- v2 Store write rejects legacy projections;
- fresh/v0/v1/v2 migration to v3 and injected v3 rollback;
- Manifest identical retry versus mutation conflict;
- Plan/Policy/Manifest/journal paging and corruption isolation;
- seven-day versus 90-day retention and separate clear operations.

The first focused command is expected to fail at compile time because the v2
and journal APIs do not yet exist. That failure is the tests-first evidence.

## 6. Non-Goals

Task 28 does not implement:

- execution-profile Rule changes;
- evidence resolution or Plan building;
- pure Cleanup Policy evaluation;
- `ExecutionAuthorization`;
- execution coordinator or Trash calls;
- Review, Cleanup Result or History UI;
- real Registered Actions;
- Deep Dive, Adapter or release work.

## 7. Verification and Review

Focused:

```bash
swift test --filter 'CleanupDomainV2|CleanupJournal|CleanupStoreV3|EvidenceMigration|RetentionPolicy'
```

Then:

```bash
swift test
scripts/verify
scripts/check-doc-links
git diff --check
```

Code review focuses on:

- capability/authorization persistence;
- path leakage into journal/Manifest;
- migration rollback and schema signatures;
- FK/cascade behavior across 7/90-day records;
- overwrite or state-regression paths;
- duplicate replay after crash;
- unchecked arithmetic and payload bounds.

## 8. Implementation Outcome

Implemented contracts:

- `DomainSchemaVersion.v2`, current/legacy cleanup compatibility and explicit
  v1-only rejection for all non-cleanup persisted domain records;
- current bounded Plan, Policy and Manifest contracts with strict nested JSON
  decoding and conservative v1 projections;
- path-free `CleanupRunJournal` with ordered selected subsets, minimal Policy
  audit facts, explicit stage transitions and strictly advancing updates;
- Evidence Store schema v3 with a strict journal table and no Plan foreign key;
- immutable, idempotent Plan/Policy/Manifest writes protected by
  `BEGIN IMMEDIATE`, including multi-connection retries;
- atomic fresh/v0/v1/v2 → v3 migration with injected rollback at every target
  version;
- separate seven-day evidence-linked journal and 90-day audit retention;
- corruption-isolating Plan/Policy/journal/Manifest pages and separate Clear
  Evidence/Clear Manifests behavior.

The tests-first compile failure is preserved in:

```text
/tmp/stornaut-task28-red-tests.log
```

The final focused suite passed `39/39`:

```text
/tmp/stornaut-task28-focused-final-2.log
SHA-256 6c7211d044054a82b91610e712357cc95e94ac132025b8568e4b8cbd86c9e8dc
```

The complete SwiftPM suite passed serially `305/305`, with the three existing
opt-in diagnostics skipped:

```text
/tmp/stornaut-task28-full-swift-test-serial.log
SHA-256 c929d0799daa971d94d7dbf22519350c65870653c888ea4f4f5152d6844b01d5
```

An earlier default parallel full run exposed only existing load-sensitive
Codex/Surveyor/Quick Scan timeouts. The affected Codex process group passed
serially `16/16`, and the complete serial suite then passed. No product
assertion or timeout was weakened.

Review evidence:

- `bits-code-guard` covered the 19 tracked changed files;
- its working-tree mode omitted seven untracked Task 28 files, so those files
  received a documented full manual fallback review;
- 13 state, persistence, compatibility and retention findings were corrected;
- no unresolved P0–P2 finding remains.

Final uninterrupted unified verifier:

```text
/tmp/stornaut-task28-unified-verify-undisturbed.log
SHA-256 25716afc4a7936e879dc86082c0c33177888b57a47d8e09cbce6bd611b5adca1
```

It passed with XCUITest `9/9`, 17 canonical screenshots, the Phase B
`303/303` gate, full SwiftPM `303/303`, matcher benchmarks `0.230 s`,
`0.395 s`, `0.534 s`, all boundaries, Xcode App tests/build, ad-hoc signing,
bundle verification, Release fixture isolation, localization parity, rule
compiler and docs.

The final UI runner uses existing typed debug destinations for Scan and
History trend, independent fixture sessions for long Settings sections, and
semantic action/result assertions instead of unstable SwiftUI `.sheets` roles.
No product assertion or timeout was weakened. A clean Phase B gate was also
made self-contained after stale cross-target SwiftPM incremental artifacts
caused the rule compiler to crash before a clean rebuild produced the exact
expected catalog hash.

Task 28 adds no target filesystem write or product CTA. It is complete and may
be committed/pushed as one iteration. Per the user's instruction, Phase C
pauses after this Task for a review of the updated capability-first ADR 0004;
Task 29 is not active.
