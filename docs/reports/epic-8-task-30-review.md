# Epic 8 Task 30 Code Review and Completion Audit

> Status: Passed; implementation, completion audit, independent review and
> final unified verifier complete
>
> Date: 2026-08-14
>
> Baseline:
> `cacdc0dbfc1acfa0645f0305e31f284878865ecd`
>
> Scope: memory-only Review selection, pure Cleanup Policy, bounded current
> context collection, exact Store joins, typed stale projection and one-shot
> authorization

## 1. Objective and Success Criteria

Task 30 had to deliver the write-free admission layer between the immutable
Task 29 Plan and the future Task 31 serial execution coordinator:

```text
retained Cleanup Plan
+ in-memory Review Selection
+ exact selected Store truth
+ fresh filesystem/activity/catalog/root/workflow context
→ pure per-item Policy Decisions
→ typed stale result or exact confirmation
→ internal one-shot Execution Authorization
```

Completion required all of the following:

1. Plan, selection, Policy audit and authorization remain different types;
2. current I/O collection is separate from the pure Policy gate;
3. selection is memory-only, ordered by Plan and generation/fingerprint bound;
4. Store v3 reads selected snapshot/classification/Evidence truth exactly and
   without a migration;
5. root access, current identity, catalog/profile, Evidence and one shared
   activity capture are revalidated;
6. every selected item receives one deterministic allow/deny decision with
   stable reason keys;
7. stale output contains affected items and only refresh/cancel actions;
8. final confirmation binds exact count, order, action, bytes, Review count
   and all decision/context/selection fingerprints;
9. authorization is non-`Codable`, internal, actor-owned, one-shot and
   admitted within at most 30 seconds;
10. first admission attempt consumes authority even when expired, mismatched
    or workflow-blocked;
11. root access lease remains alive from collection through admission;
12. the final low-level `ActionPolicyGate` still runs later and rejects the
    allowed root itself while permitting safe HOME descendants;
13. no Trash call, target mutation, App Review UI/CTA, Registered Action,
    Deep Dive, Store v4 or third-party dependency is introduced;
14. tests-first evidence, independent review, focused/full verification and
    one independent commit/push are complete.

## 2. Prompt-to-Artifact Checklist

| Requirement | Artifact/evidence | Result |
| --- | --- | --- |
| Memory-only selection | `CleanupSelection.swift`; non-`Codable` ordered item/origin/generation/fingerprint value | Passed |
| Duplicate/unknown/empty/Protected/Unknown rejection | `CleanupPolicyGateTests.swift` selection matrix | Passed |
| Maximum 100 selected | inherited `CleanupPlan` hard maximum plus Task 30 regression | Passed |
| Overlap conflict | Plan invariant repeated by selection constructor | Passed |
| Pure Policy | `CleanupPolicyGate.swift`; boundary script forbids mutable I/O and App/runtime imports | Passed |
| Separate collector | `CleanupPolicyContextCollector.swift` with injected Store/root/workflow/activity/identity providers | Passed |
| Exact selected Store truth | `EvidenceStore.cleanupPolicyRecords`; exact by-ID snapshot/classification and bounded Evidence reads | Passed |
| No Store migration | schema remains v3; boundary gate pins version | Passed |
| Complete persisted semantic join | Rule/Profile/path/category/risk/confidence/recovery/evidence keys/snapshot identity and bytes | Passed |
| One Activity capture | collector captures once and evaluates all selected profiles from the same context | Passed |
| Root access lifecycle | typed direct/security-scoped/unavailable access retained through authorization admission | Passed |
| Current identity reuse | resolver accepts the collector's already-read current identity; no second target `stat` in one collection | Passed |
| Catalog/Profile drift | current built-in versions must match Plan and one another | Passed |
| Evidence freshness | exact kind/source/identifier/summary/timeline/freshness validation | Passed |
| Activity fail-closed | active and unavailable both deny; incomplete enumeration cannot become inactive | Passed |
| Stable reasons | closed `policy.*` reason keys and typed stale groups | Passed |
| Exact affected items | denied decision IDs form the stale affected set | Passed |
| No stale bypass | stale actions are exactly Refresh Affected Items and Cancel | Passed |
| Deterministic decision facts | canonical fingerprints avoid `String(describing:)` and include evaluation time for audit identity | Passed |
| Checked bytes | final logical/allocated totals use checked addition and `ByteCount` bounds | Passed |
| One-shot authority | internal `CleanupAuthorizationController` actor and opaque nonce | Passed |
| Non-persistable authority | no `Codable`/`Equatable`/`Hashable` or public initializer | Passed |
| No duplicate mint | one decision fingerprint maps to one pending/consumed/invalidated capability | Passed |
| Internal clock | controller owns the clock; callers cannot submit arbitrary issue/admission time | Passed |
| 30-second admission | deadline is bounded by both fresh context and issue time | Passed |
| First-attempt consumption | actor changes pending to consumed before expiry/confirmation/workflow checks | Passed |
| Admitted batch not time-cancelled | admitted value has no execution deadline or cancellation timer | Passed |
| Persisted Policy cannot replay | authorization requires actor-owned pending nonce plus exact collected context | Passed |
| Low-level final gate retained | `ActionPolicyGate` unchanged as Task 31 final boundary except root hardening | Passed |
| Ordinary root self-target blocked | `ActionPolicyError.allowedRoot` independent of allowed-root ordering | Passed |
| HOME descendants remain eligible | dedicated safe HOME descendant regression | Passed |
| No target writes | boundary verifier forbids Trash and filesystem write calls in Task 30 files | Passed |
| No App/UI wiring | App targets unchanged; boundary verifier checks working tree | Passed |
| No Registered Action | production Registry remains `ActionRegistry(definitions: [])` | Passed |
| No Codex/Adapter | source boundary and package graph remain unchanged | Passed |

## 3. Tests-First Evidence

The first focused command intentionally failed before production Task 30
types existed:

```text
swift test --no-parallel \
  --filter 'CleanupPolicy|CleanupAuthorization|actionPolicyGateRejectsTheAllowedScanRoot'

EXIT_STATUS=1
cannot find type 'ReviewSelection' in scope
cannot find type 'CleanupPolicyEvaluation' in scope
cannot find type 'CleanupConfirmation' in scope
type 'ActionPolicyError' has no member 'allowedRoot'
```

Log and digest:

```text
/tmp/stornaut-task30-red-tests.log
SHA-256 90ec8f93bbd29f6a15c6727e782d2584d06dcf3a5875b6ca2d9478f8657c0db7
```

Because the missing production types prevented the repository test target
from compiling, a separate temporary SwiftPM witness linked the baseline
`StornautCore` and asserted that the allowed scan root itself must be denied.
It compiled and failed exactly because baseline `ActionPolicyGate` returned a
preflight token for that root. This confirmed the tests-first P1 security
finding before production code changed.

The final Task 30 tests cover:

- Plan-order selection and exact origins;
- empty, duplicate, unknown, Protected, Unknown and over-100 rejection;
- explicit Review selection;
- selection generation/fingerprint drift;
- Plan/session/scope/root/catalog/profile/context expiry;
- exact identity, bytes, path, Evidence and Activity drift;
- workflow conflicts and lost root access;
- stable affected-item stale projection;
- checked confirmation counts and byte totals;
- exact audit identity across evaluation times;
- current real temporary filesystem collection;
- single activity capture;
- provider and Store failures before later providers run;
- tampered persisted classification semantics;
- exact Store join and unknown-item rejection;
- one-shot success, expiry, mismatch, conflict, invalidation and concurrency;
- duplicate authorization issue resistance;
- structural non-`Codable`/non-public authority;
- scan-root self-target and safe HOME descendant behavior.

## 4. Architecture Delivered

### 4.1 Selection

`ReviewSelection` is a non-persisted value ordered by immutable Plan order.
It binds:

- Plan ID and Plan fingerprint;
- generation;
- ordered item IDs and per-item origin;
- canonical relative target paths.

The Plan already rejects duplicate/overlapping identities and paths and has a
100-item maximum. The selection constructor repeats the relevant membership,
origin and overlap checks instead of trusting UI state.

### 4.2 Exact Store truth

`EvidenceStore.cleanupPolicyRecords` reads only the selected Plan items. For
each item it verifies:

- the persisted Plan is byte-equal to the supplied current Plan;
- selected IDs are unique, known and bounded;
- exact snapshot/classification IDs and parent joins;
- mirrored SQLite columns and payload identity;
- one scan session and scope;
- at most 100 Evidence records per selected snapshot.

No table, column, index or migration changed. Store schema remains v3.

### 4.3 Read-only collector

`CleanupPolicyContextCollector` performs all mutable observations:

- exact selected Store truth;
- one terminal completed scan/scope;
- current bundled Rule/Profile catalogs;
- typed direct or security-scoped root access;
- current root and target identity;
- one running App/process capture;
- current resolver/classifier result;
- exact persisted Evidence validation;
- workflow availability snapshot.

The collector returns either a complete immutable context or a typed blocked
outcome. A security-scoped root lease is retained in the collected context,
pending authorization and admitted batch; it is not represented by a naked
boolean.

### 4.4 Pure Policy

`CleanupPolicyGate.evaluate` performs no Store, filesystem, process, bundle,
App or network I/O. It evaluates typed values and returns either:

```text
allowed(decisions, confirmation)
blocked(decisions, stale)
```

Every selected item gets one `PolicyDecision`. Allowed decisions use the
existing persisted v2 audit record but do not grant authority. The aggregate
confirmation binds all selected decisions and checked byte totals.

### 4.5 One-shot authority

`CleanupAuthorizationController` is internal to `StornautCore`. It:

- issues only from an exact allowed evaluation, confirmation and collected
  context;
- keeps one pending nonce per decision fingerprint;
- owns its clock;
- limits admission to the earlier of fresh-context expiry and 30 seconds
  after issue;
- consumes before checking expiry, mismatch or workflow conflict;
- admits at most one caller under actor isolation;
- carries the root access lease into the admitted batch;
- never persists or exposes an executable action.

Task 31 will be the first consumer and will still perform fresh per-item pure
Policy and low-level `ActionPolicyGate` revalidation before any fake/injected
write.

## 5. Confirmed Review Findings and Corrections

### 5.1 Ordinary allowed root could receive a preflight token

**Severity before fix:** P1 security boundary

**Disposition:** Fixed

Baseline `ActionPolicyGate` treated `root contains target` as true when the
target equaled the root. The final gate now rejects any target equal to any
allowed root before descendant matching, independent of root list ordering.

### 5.2 Selection context did not initially bind generation and fingerprint

**Severity before fix:** P1 stale authorization integrity

**Disposition:** Fixed

The current context now binds selection generation, fingerprint and exact
ordered IDs. Any post-collection selection change denies all affected items.

### 5.3 Duplicate issue calls could mint parallel capabilities

**Severity before fix:** P1 authorization replay

**Disposition:** Fixed

The actor now maps one aggregate decision fingerprint to exactly one
pending/consumed/invalidated nonce. A second issue returns the same pending
capability or rejects after consumption/invalidation.

### 5.4 Authorization accepted caller-supplied clock values

**Severity before fix:** P1 expiry bypass

**Disposition:** Fixed

Issue and admission now use one actor-owned injected clock. Production callers
cannot move time backward or choose an arbitrary issue instant.

### 5.5 Security-scoped root lease could end after collection

**Severity before fix:** P1 root-access lifecycle

**Disposition:** Fixed

The initial observation used availability state but did not retain the lease
through authorization. The typed root access object now flows through
collected context, pending authorization and admitted batch.

### 5.6 HOME as an allowed scan root blocked every safe descendant

**Severity before fix:** P1 product correctness

**Disposition:** Fixed

The low-level gate still rejects HOME itself, but no longer rejects HOME as
an allowed container root. Sensitive-path policy and exact descendant/current
identity checks continue to apply.

### 5.7 Policy evaluation audit IDs collided across evaluation times

**Severity before fix:** P1 immutable audit correctness

**Disposition:** Fixed

Per-item decision fingerprints and deterministic IDs now include the exact
evaluation timestamp bit pattern. Identical facts evaluated at different
times remain distinct immutable audit records.

### 5.8 Persisted classification semantics were initially under-validated

**Severity before fix:** P1 fail-open persisted truth

**Disposition:** Fixed

The collector now validates persisted category, risk, confidence, producer,
recovery, required/missing evidence, disposition and exact Rule/Profile/path
bindings, plus snapshot identity and byte fields.

### 5.9 Fingerprint and identity collection needed deterministic closure

**Severity before fix:** P2 robustness

**Disposition:** Fixed

Policy fingerprints now use explicit closed encodings instead of
`String(describing:)`, and the resolver accepts the collector's already-read
current identity so one collection does not create an unnecessary second
target-identity observation.

## 6. Independent Review

`bits-code-guard` was run over tracked changes, then its known untracked-file
limitation was closed by a full-file review list containing all Task 30
production, test and boundary files.

Post-fix result:

```text
13 files reviewed
0 unresolved P0
0 unresolved P1
0 unresolved P2
```

Local artifacts:

```text
/tmp/stornaut_task30_code_review/report.html
/tmp/stornaut_task30_code_review/report.md
```

These transient local review artifacts are not committed.

## 7. Verification Results

### Focused post-review

```text
61/61 passed
SHA-256 40d8c98219d5cac2f3b0709f36b7aa565a9bac6fe240a692a80c7b14d31ab35c
```

### Complete StornautCore

```text
249/249 passed
SHA-256 bcacd4144efcc8b75872c226bfc01364293b5bf1047fe75293cacf94971206cf
```

### Complete serial SwiftPM

```text
581/581 passed
8 explicit opt-in diagnostics skipped
SHA-256 86197af4b0fb0490e8dc54cb5226119bd59c1de0fe227167d3b0bd6b9b911205
```

### Authoritative full verifier

```text
scripts/verify
exit 0
```

Key full-mode evidence:

- Automation readiness: passed;
- XCUITest: 11/11 passed;
- screenshot contracts: 17 exported and validated;
- SwiftPM build: passed;
- ordinary parallel SwiftPM: 578/578 passed, benchmarks separately passed;
- matcher benchmarks: 3/3 passed;
- Phase B product/cancellation evidence: passed;
- all source boundaries, including new Cleanup Policy boundary: passed;
- App tests/snapshots: passed;
- Debug App build/sign/bundle: passed;
- Release fixture isolation: passed;
- localization, rule compiler, verifier contract, docs and diff: passed.

Unified log:

```text
/tmp/stornaut-task30-unified-verify.log
SHA-256 736fcc35d91561832fcdc223d5b885c21c094d99dae05e8434987904dae1168c
```

No UI code changed, so Task 30 required no new product screenshot. The full
XCUITest and 17 existing screenshot contracts prove that the Core-only change
did not regress the current App surface.

## 8. Boundary and Scope Audit

Task 30 does not:

- call Trash or mutate a cleanup target;
- create `CleanupExecutionCoordinator`;
- execute a journal or finalize a Manifest;
- add Cleanup Result accounting;
- add Review/confirmation/stale SwiftUI;
- add an App cleanup CTA;
- add a production Registered Action;
- change the Rule/Profile Catalog;
- add Deep Dive or Adapter behavior;
- migrate Store v3;
- add dependencies;
- change release/notarization scope.

`scripts/verify-cleanup-policy-boundaries` is now part of the unified source
boundary step and verifies these constraints mechanically.

## 9. Remaining Gates

Task 31 may now implement the serial coordinator using fake/injected Trash
only. It must:

- require an admitted Task 30 batch;
- persist prepared journal state before each action;
- collect fresh context and run pure Policy per item;
- run low-level `ActionPolicyGate` immediately before the injected action;
- preserve partial/unknown outcomes and stop rules;
- produce truthful accounting and immutable Manifest state.

The real App Trash dependency remains disabled. Task 35's signed-App
disposable Trash diagnostic still requires separate explicit user opt-in.

## 10. Final Decision

Task 30 is complete.

The repository now has a deterministic, write-free Policy and authorization
layer with no unresolved P0–P2 findings. This result does not enable target
mutation. Task 31 is the next eligible deterministic task.
