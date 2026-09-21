# Epic 8 Task 28 Code Review

> Status: Passed after confirmed findings were corrected
>
> Date: 2026-08-11
>
> Scope: cleanup domain v2, Evidence Store v3, execution journal, migration,
> retention and anonymous fixtures/tests

## 1. Review Scope

The review covered every Task 28 production, fixture, test and routing change:

```text
Sources/StornautCore/Actions/CleanupRunJournal.swift
Sources/StornautCore/Accounting/*
Sources/StornautCore/Domain/*
Sources/StornautCore/Evidence/*
Sources/StornautCore/KnowledgeBase/RuleCatalog.swift
Sources/StornautCore/LocalKnowledge/LocalKnowledgeStore.swift
Sources/StornautCore/Surveyor/PathSnapshot.swift
Tests/Fixtures/EvidenceStore/v2-evidence.sql
Tests/StornautCoreTests/Cleanup*Tests.swift
Tests/StornautCoreTests/CleanupPersistenceTestSupport.swift
Tests/StornautCoreTests/DomainContractTests.swift
Tests/StornautCoreTests/EvidenceMigrationTests.swift
Tests/StornautCoreTests/EvidenceStoreTests.swift
Tests/StornautCoreTests/RetentionPolicyTests.swift
```

The repository `bits-code-guard` workflow reviewed 19 tracked files. Its
working-tree range does not include untracked files, so the seven new Task 28
files were added to the same logic/security/robustness review manually. No
repository-specific custom workflow was configured.

## 2. Confirmed Findings and Corrections

### 2.1 A run could first appear as `actionStarted`

**Severity before fix:** P1 crash/replay safety  
**Disposition:** Fixed

The first journal save now requires `prepared`, a retained current Plan and an
ordered selected subset whose entries match persisted current allowed Policy
decisions. A target write cannot be represented without prior durable intent.

### 2.2 Ordinal stage comparison rejected the second action

**Severity before fix:** P1 core state-machine correctness  
**Disposition:** Fixed

Batch execution alternates `actionStarted` and `actionOutcomeRecorded`.
Ordinal comparison was replaced by an explicit transition graph. Tests cover
first start, durable outcome, second start and final outcome.

### 2.3 One update could persist an outcome and start the next action

**Severity before fix:** P1 write-ordering correctness  
**Disposition:** Fixed

Entry state changes now require a stage transition. Same-stage writes may
update only journal metadata such as Stop After Current, not action states.
Every returned outcome therefore becomes durable before the later start.

### 2.4 State changes could reuse the old update timestamp

**Severity before fix:** P2 audit ordering  
**Disposition:** Fixed

A byte-identical retry may keep the timestamp. Any changed journal requires a
strictly later `updatedAt`; expiry may extend only within its retention class
and may not regress.

### 2.5 Audit recovery lost minimal Policy/action facts

**Severity before fix:** P1 recovery completeness  
**Disposition:** Fixed

Each path-free entry now retains action type, Policy decision ID, disposition
and stable reason keys. Authorization, original path, Trash URL, stdout,
stderr, arbitrary command and private content remain absent.

### 2.6 Cancelled actions lost selected candidate bytes

**Severity before fix:** P1 accounting truth  
**Disposition:** Fixed

Cancelled/not-started records keep candidate logical/allocated bytes while
processed, Trash and permanent bytes remain zero. Successful Trash records
must process and move the complete candidate measures.

### 2.7 A prepared journal could bind denied or unrelated Policy

**Severity before fix:** P1 authorization/audit semantics  
**Disposition:** Fixed

First persistence verifies the exact retained Plan item, full identity, action,
Policy item, allowed outcome, disposition, reason keys and selection
generation. Policy is still audit truth, not execution authorization.

### 2.8 Plan scope/root identity was under-bound

**Severity before fix:** P1 plan integrity  
**Disposition:** Fixed

Current Plan persistence requires the scope to be a completed scope of the
retained terminal ScanSession. Every current item must share the Primary Root
device, and duplicate full identity or device/inode, ancestor/descendant paths
and non-Trash actions are rejected.

### 2.9 Migration steps were individually atomic, not chain-atomic

**Severity before fix:** P1 migration integrity  
**Disposition:** Fixed

The complete fresh/v0/v1/v2 → v3 chain now runs in one transaction. Injected
v1, v2 or v3 failure restores the original user version, application ID and
schema objects.

### 2.10 Immutable check-then-insert was connection-local only

**Severity before fix:** P1 cross-process integrity  
**Disposition:** Fixed

Plan, Policy and Manifest identity checks plus insertion, and journal
transition checks plus update, now run inside `BEGIN IMMEDIATE`. A two-store
fixture proves same-payload retries remain idempotent across connections.

### 2.11 Evidence deletion could orphan a prepared journal

**Severity before fix:** P2 retention/privacy  
**Disposition:** Fixed

Individual scan deletion, retention sweep and Clear Evidence remove only
`evidenceLinked` no-write journals associated with deleted Plans. Audit
journals and final Manifests remain until their 90-day/Clear Manifests
lifecycle.

### 2.12 Strict decoding covered only journal top-level keys

**Severity before fix:** P2 closed-contract robustness  
**Disposition:** Fixed

All current cleanup, journal, FileIdentity, action and accounting nested
payloads reject unknown fields. Tests inject nested authorization/path data
and future schema versions.

### 2.13 Legacy projections inherited current-v2 bounds

**Severity before fix:** P2 backward compatibility  
**Disposition:** Fixed

Historical v1 Cleanup Plan/Policy/Manifest payloads retain their original v1
invariants when projected to `legacyV1`. Current-v2 write-only limits do not
retroactively quarantine old readable history.

## 3. Final Review Result

- P0: 0;
- P1: 0 unresolved;
- P2: 0 unresolved.

Task 28 adds no target filesystem write, execution authorization, Review CTA,
real Trash wiring, Registered Action, Adapter, Deep Dive implementation or
release behavior.

## 4. Validation Evidence

Focused final suite:

```text
39/39 passed
/tmp/stornaut-task28-focused-final-2.log
SHA-256 6c7211d044054a82b91610e712357cc95e94ac132025b8568e4b8cbd86c9e8dc
```

Complete SwiftPM serial suite:

```text
305/305 passed; three opt-in diagnostics skipped
/tmp/stornaut-task28-full-swift-test-serial.log
SHA-256 c929d0799daa971d94d7dbf22519350c65870653c888ea4f4f5152d6844b01d5
```

The supporting local `bits-code-guard` HTML report is:

```text
/tmp/stornaut_task28_review_1786428439/report.html
```

## 5. Final Unified Gate

The final uninterrupted `scripts/verify`, executed with shell `pipefail`,
exited `0`.

```text
/tmp/stornaut-task28-unified-verify-undisturbed.log
SHA-256 25716afc4a7936e879dc86082c0c33177888b57a47d8e09cbce6bd611b5adca1
```

Final evidence:

- XCUITest `9/9` and 17 canonical screenshots;
- shell Dark `39.41 / sd 29.72`, Settings Dark `42.87 / sd 22.13`;
- Phase B gate `303/303`;
- full SwiftPM `303/303` plus matcher benchmarks
  `0.230 s`, `0.395 s`, `0.534 s`;
- all source/App boundaries, Xcode App tests/build, signing and bundle;
- Release fixture isolation, localization, rule compiler and docs.

Task 28 has no unresolved P0–P2 finding and is ready for one independent
commit/push.
