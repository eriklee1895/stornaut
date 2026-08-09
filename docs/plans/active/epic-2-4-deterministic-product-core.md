# Stornaut Epic 2–4 Deterministic Product Core Implementation Plan

> **Status:** Approved — Task 9 complete; Task 10 next
>
> **Roadmap phase:** Phase B — Deterministic Product Core
>
> **Plan date:** 2026-08-09
>
> **Execution rule:** Implement this plan task-by-task, keep checkbox state and
> evidence current, and create one reviewed, verified commit per Task.

**Goal:** Turn the Epic 1 Swift Surveyor and safety seams into a useful,
deterministic macOS scanning product that persists explainable snapshots,
classifies known developer storage with provenance and activity protection, and
renders real Quick Scan, Overview, History and relevant Settings states without
calling Codex or writing to the scanned target.

**Architecture:** `StornautCore` owns immutable domain contracts, a
SQLite-backed local store, production Surveyor orchestration, truthful space
accounting, the compiled Knowledge Base, conservative activity fusion and
structured Local Knowledge. The App consumes typed observable state and never
performs scanning or persistence directly from a SwiftUI `View`. Scanning is
read-only with respect to user-selected roots; all database and derived-data
writes remain inside Stornaut-owned Application Support/Caches locations.
Quick Scan has no dependency on or call path into `StornautCodex`.

**Roadmap relationship:** This plan implements only Phase B / Epic 2–4. It does
not absorb Phase C merely because several Epic 8 contracts are shared with the
domain model. After the Phase B evidence gate, create and obtain approval for a
separate deterministic Epic 8 active plan.

**Validated baseline:** Task 9 started from
`11b9b79e9ed9df3bf75b7f976c1aa7b43d44a5df`. The current Swift Surveyor has
already demonstrated a full-root run below the five-minute target with bounded
memory and sub-millisecond producer cancellation response. Those measurements
justify continuing in Swift; they do not make raw entry sums valid APFS
accounting.

## 1. Approval Decisions Encoded by This Plan

Approval of this plan confirms the following delivery boundaries:

1. Phase B ends after a read-only, no-Codex scanning product and its evidence
   gate. Review, Policy-to-Executor orchestration and real cleanup remain a
   separate Phase C plan.
2. Epic 2 still defines `CleanupPlan`, `PolicyDecision`, `CleanupAction`,
   `CleanupManifest` and accounting contracts because later phases share them.
   In this plan they are non-executable records and fixture-backed store
   projections only.
3. Use the system SQLite library through a small repository-owned Swift/C
   boundary unless Task 9 produces evidence that this is not viable. Do not add
   an ORM or third-party package by default.
4. Knowledge Base rules are checked-in source with a build-time compiler and an
   immutable runtime catalog. If a YAML parser dependency is proposed, Task 14
   must first document its exact version, license, distribution impact and why
   a constrained repository-owned compiler is insufficient.
5. Initial rules must cover every family named by PRD FR-2, but conservative
   evidence is more important than aggressive reclaim totals. A family may
   initially classify items as `Review Recommended`, `Protected` or `Unknown`;
   no rule becomes `Ready to Reclaim` merely to improve coverage.
6. Phase B History shows real scan/snapshot records and supports their
   retention lifecycle. It must not fabricate Cleanup Manifest records before
   Phase C creates them.
7. The enabled `Review Reclaim Plan` action is deferred to Phase C. Phase B
   must not ship a dead navigation path, a fake cleanup result, or a bypass
   around the roadmap gate.

## 2. Global Constraints

- Preserve every invariant in `AGENTS.md` and the coding-agent handoff.
- Quick Scan never invokes a model, Codex process, Probe Bridge, Adapter or
  cleanup action.
- Surveyor and classification are read-only with respect to scanned roots.
  Persistence writes only to Stornaut-owned local storage.
- Permission failures, races and decode errors remain partial/unknown; never
  report them as `0 B`, `Ready to Reclaim` or successful completion.
- `ReclaimDisposition` has exactly `readyToReclaim`,
  `reviewRecommended`, `protected` and `unknown`. Risk and confidence remain
  separate fields.
- Time or staleness alone cannot produce `readyToReclaim`. A denylist match,
  veto or active-use signal cannot be weakened by a rule overlay or Local
  Knowledge.
- Controlled text snippets, raw file content and raw Codex JSONL are outside
  every Phase B persistence API.
- Snapshot/classification/evidence/plan records default to seven-day
  retention. Minimal Cleanup Manifest records default to 90 days. Expiring
  linked evidence must not invalidate an otherwise retained minimal Manifest.
- Do not introduce Rust, telemetry, cloud storage, remote rules, background
  monitoring, scheduled scans, login items, `MenuBarExtra`, real Registered
  Actions or release/notarization work.
- Do not copy Mole GPL code or Pearcleaner restricted code. Rules learned from
  upstream behavior require provenance and independent fixtures.
- App UI changes require narrow tests, a real `.app` launch, read-only
  Peekaboo observation and XCUITest/screenshot verification in both Light and
  Dark appearances.
- English and `zh-Hans` localization keys must stay in parity. User-visible
  fixture paths, generated-concept values and machine-specific paths must not
  be hard-coded into product UI.
- A Task is complete only after focused checks and the current unified verifier
  pass. Update an ADR/report with measured evidence rather than converting an
  unproven assumption into a comment.

## 3. Explicit Non-Goals

This plan does not implement:

- production Deep Dive, Candidate Planner or Codex-driven investigation;
- a real Codex-to-Probe Broker disk investigation path;
- Review selection, final user cleanup confirmation or execution workflow;
- an enabled `MoveToTrash` product flow, Undo, or any real Registered Action;
- Cleanup Result UI or production Cleanup Manifest creation;
- external Mole, kondo, Homebrew, Docker or system-tool Adapters;
- L1/L2 file-content reading;
- permanent deletion;
- Developer ID signing, hardened runtime, Gatekeeper, notarization or release;
- FSEvents incremental/background scanning, remote rule updates or cloud sync;
- a complete DaisyDisk-style treemap or any unapproved navigation destination.

The existing Epic 1 action and Codex spike code remains testable but dormant
from Phase B product flows.

## 4. Phase B Domain and Accounting Semantics

The implementation must make these distinctions explicit before UI work:

- **Scan session:** one user-initiated attempt, with roots, started/finished
  timestamps, terminal state, completed scopes and unfinished scopes.
- **Snapshot:** immutable observed filesystem or volume fact associated with a
  session. Progress events are not embedded in each final path fact.
- **Classification:** rule/activity/local-knowledge projection over a snapshot,
  including disposition, risk, confidence, recovery, required/missing evidence
  and catalog version.
- **Evidence:** typed fact or display-safe structured summary with source,
  freshness and observation time. It never stores raw controlled content.
- **Cleanup plan / policy / manifest:** stable contracts for later phases.
  Their existence in SQLite is not authority to execute.
- **Known:** disjoint, successfully measured storage attributed by a validated
  rule or producer mapping.
- **Unknown:** measured or volume-residual storage not yet attributable with
  sufficient evidence.
- **Unmeasurable:** an explicit coverage gap. Its byte amount is optional; when
  unavailable the UI shows an em dash and affected scopes, never zero.
- **Free:** a volume-level system observation with source and sample time, not
  a sum inferred from scanned entries.
- **Reclaimable:** a policy/disposition dimension and never part of the
  `Known + Unknown + Unmeasurable + Free` occupancy equation.

Task 13 must write the precise formulas and overlap policy in ADR 0009. If APFS
or permission evidence cannot support an exact additive partition, the model
must represent that limitation instead of forcing a visually convenient sum.

## 5. Planned File Map

Exact filenames may be refined by the corresponding Upstream Study and ADR,
but responsibility boundaries must remain:

```text
Sources/StornautCore/
  Domain/                 Stable IDs and immutable shared records
  Evidence/               Store protocols, SQLite implementation, retention
  Surveyor/               Production read-only scan engine and events
  QuickScan/              Session coordinator and dependency boundaries
  Accounting/             Volume baseline and reconciled Space Ledger
  KnowledgeBase/          Rule schema, compiler, catalog and overlays
  Activity/               Git/App/process signals and conservative fusion
  LocalKnowledge/         Confirmed structured facts and stale invalidation

Rules/
  BuiltIn/                Provenance-bearing YAML source
  Schema/                 Rule schema/version contract

Tests/StornautCoreTests/
Tests/Fixtures/Domain/
Tests/Fixtures/EvidenceStore/
Tests/Fixtures/QuickScan/
Tests/Fixtures/Rules/
Tests/Fixtures/Activity/

StornautApp/
  Overview/
  Scan/
  History/
  Settings/
  DesignSystem/

docs/adr/0007-...          Domain and persistence decision
docs/adr/0008-...          Production Quick Scan lifecycle
docs/adr/0009-...          Space accounting semantics
docs/adr/0010-...          Knowledge and activity policy
docs/upstream-studies/     Topic-specific implementation briefs
docs/reports/              Phase B benchmark and validation evidence
```

Every production Swift file should have one primary responsibility. Store,
scanner, rule and activity protocols must be testable without launching the
App. SwiftUI `View` types consume ViewModel state and may only send typed user
intents.

## 6. Task Sequence and Dependencies

```text
Task 9  Phase B study map and dependency decisions
  ↓
Task 10 Domain contracts and anonymous fixtures
  ↓
Task 11 SQLite Evidence Store, migrations and retention
  ↓
Task 12 Production Surveyor and persisted scan lifecycle
  ↓
Task 13 Truthful Space Ledger
  ↓
Task 14 Rule compiler, schema and conservative overlays
  ↓
Task 15 Protected and veto rule catalog
  ↓
Task 16 Project artifact rule catalog
  ↓
Task 17 Package and build cache rule catalog
  ↓
Task 18 Runtime, image, tool and residue rule catalog
  ↓
Task 19 Activity protection and Local Knowledge
  ↓
Task 20 Deterministic Quick Scan orchestration and safety audit
  ↓
Task 21 App state, fixture injection and design system
  ↓
Task 22 Snapshot-first Overview
  ↓
Task 23 Quick Scan progress and results
  ↓
Task 24 Scan-only History
  ↓
Task 25 Phase B Settings
  ↓
Task 26 Phase B evidence gate and handoff
```

Tasks 12–19 may expose protocols that permit isolated implementation, but do
not merge or claim an end-to-end Quick Scan before Task 20 verifies the complete
dependency graph.

---

### Task 9: Phase B Upstream Study Map and Implementation Decisions

**Files:**

- Create: `docs/upstream-studies/epic-2-domain-persistence.md`
- Create: `docs/upstream-studies/epic-3-quick-scan.md`
- Create: `docs/upstream-studies/epic-4-knowledge-activity.md`
- Create: `docs/upstream-studies/epic-2-4-ui.md`
- Create: `docs/adr/0007-domain-persistence-boundary.md`
- Modify if needed: `ThirdPartyNotices/README.md`

**Purpose:** Complete the Reference Study Gate before choosing store APIs,
schema compilation mechanics, production scan behavior or activity collection.

- [x] **Step 1: Revalidate the execution baseline**

Record the current OS, Xcode, Swift, architecture, package dependency graph,
Git HEAD and installed SQLite version. Confirm the worktree contains no
unrelated changes and Deep Dive remains paused.

- [x] **Step 2: Study domain and persistence sources**

Read current SQLite transaction, WAL, foreign-key, `user_version`, corruption
and backup documentation plus Apple guidance for Application Support, Caches,
file coordination and local data protection. Compare system `libsqlite3`, a
small repository-owned wrapper and third-party Swift wrappers.

ADR 0007 must decide:

- connection ownership and Swift concurrency isolation;
- migration atomicity and downgrade behavior;
- statement binding/error mapping;
- application-owned database and cache paths;
- whether WAL is appropriate for this single-process App;
- corruption isolation and export/delete behavior;
- why the selected approach needs no ORM by default.

- [x] **Step 3: Refresh Quick Scan upstream behavior**

Study the exact current commits/licenses and relevant files for Mole,
ClearDisk and kondo plus Apple filesystem/volume APIs. Reuse the accepted Epic
1 Surveyor performance evidence; do not repeat source reading that has not
changed. Record scan progress, taxonomy, cancellation, permission and
accounting ideas separately from non-reusable code.

- [x] **Step 4: Refresh Knowledge and Activity upstream behavior**

Study Mole, ClearDisk, kondo and Cluttered for taxonomy, Git dirty/untracked/
ahead protection, running App/IDE protection, path vetoes and fixtures. GPL or
restricted sources remain behavior-reference-only.

The study must decide the build-time rule-source/compiler strategy before a
YAML parser or code generator is added.

- [x] **Step 5: Reconcile approved UI inputs**

Review the approved Overview, Quick Scan, Scan Results, History, Settings and
resilience canonical documents. The study records layout/state contracts only;
it must not infer product behavior from generated example values.

- [x] **Step 6: Verify documentation, review, commit and push**

Run:

```bash
scripts/check-doc-links
git diff --check
```

Expected: all studies contain URL, commit/version, license, exact material
read, adoption/rejection notes, fixture/benchmark plan and relative Stornaut
improvement. ADR 0007 may be `Proposed` until Task 11 supplies implementation
evidence.

Execution evidence:

- Baseline: macOS 26.5.1 (`25F80`), arm64, Xcode 26.6 (`17F113`),
  Swift 6.3.3, system SQLite 3.51.0, no SwiftPM dependencies.
- System SQLite direct Swift import/link probe passed.
- Disposable SwiftPM migration probe passed `BEGIN IMMEDIATE`,
  `user_version=1`, foreign-key rejection and rollback.
- Current Mole/ClearDisk/kondo snapshots matched the accepted Epic 1 study;
  Cluttered `v1.2.0` and persistence-wrapper comparison snapshots were added.
- Four accepted implementation studies and Proposed ADR 0007 now record exact
  sources, fingerprints, non-reuse boundaries and downstream tests.
- Existing `$erik-gpt-image-2` canonical assets are sufficient for Phase B;
  no new image or web asset was added.
- `bits-code-guard` filtered Markdown as media, so the empty automatic result
  was rejected; the seven-dimension manual fallback found two P1 design issues.
- Review fixes require explicit WAL-to-DELETE transition and separate
  Evidence/Local Knowledge databases with independent backup/corruption
  boundaries; see the Task 9 review report.
- `scripts/verify` passed 119 SwiftPM tests, 2/2 XCUITest cases, four
  Light/Dark screenshots, App bundle/signing, localization and docs.

Suggested commit subject: `docs: define Phase B implementation gates`

---

### Task 10: Epic 2 Domain Contracts and Anonymous Fixtures

**Files:**

- Create: `Sources/StornautCore/Domain/`
- Create: `Sources/StornautCore/Accounting/SpaceAccounting.swift`
- Modify/migrate: existing Surveyor and Action domain types
- Create: `Tests/StornautCoreTests/DomainContractTests.swift`
- Create: `Tests/Fixtures/Domain/`
- Create: `Tests/Fixtures/QuickScan/anonymous-developer-tree.json`

**Interfaces:**

- Produces stable IDs, enums and immutable `Codable & Sendable` records for
  sessions, snapshots, classifications, evidence, plans, policy decisions,
  actions, manifests and accounting.
- Does not produce persistence, UI, scanner processes or executable authority.

- [ ] **Step 1: Write fixture decode and invariant tests first**

Tests must fail because the production domain contracts do not yet exist.
Cover:

- stable round-trip encoding with explicit schema versions;
- exactly four `ReclaimDisposition` values;
- risk and confidence independent from disposition;
- partial/cancelled scan sessions retaining completed and unfinished scopes;
- unmeasurable amounts supporting `nil`, never implicit zero;
- Cleanup Plan records being non-executable data;
- minimal Manifest fixtures excluding evidence payload/raw content;
- byte values rejecting negative/overflow-prone representations;
- IDs for different aggregate types not being interchangeable.

- [ ] **Step 2: Separate scan events from final facts**

Migrate the Epic 1 `PathSnapshot`/`ScanProgress` spike shape so progress is a
session event, not duplicated inside every persisted path snapshot. Preserve
the previously validated no-follow, identity and partial-error facts.

Do not keep parallel “spike” and “production” domain types after migration
unless an ADR names a bounded compatibility reason.

- [ ] **Step 3: Add cleanup and manifest contracts without wiring execution**

Reuse the narrow existing typed action vocabulary, but distinguish:

- a plan proposal;
- a Policy decision record;
- an execution request/token owned by later Phase C;
- an immutable minimal Manifest result.

No initializer in a persisted plan or manifest may invoke the existing
`ActionExecutor`.

- [ ] **Step 4: Add anonymous realistic fixtures**

Represent the case-study shapes without usernames, private repository names,
absolute home paths, secrets or copied upstream output:

- nested project artifacts and package caches;
- a dirty/active project;
- an unknown large consumer;
- a protected browser/credential-like path;
- a permission-limited subtree;
- overlapping parent/child candidates;
- a partial cancelled session.

- [ ] **Step 5: Run focused and full verification**

Run the focused domain tests, `swift test`, `scripts/check-doc-links` and
`git diff --check`, then the current `scripts/verify`.

Suggested commit subject: `feat: define deterministic storage domain`

---

### Task 11: SQLite Evidence Store, Migrations and Retention

**Files:**

- Create: system SQLite boundary selected by ADR 0007
- Create: `Sources/StornautCore/Evidence/`
- Create: `Sources/StornautCore/LocalKnowledge/LocalKnowledgeStore.swift`
- Create: `Tests/StornautCoreTests/EvidenceStoreTests.swift`
- Create: `Tests/StornautCoreTests/EvidenceMigrationTests.swift`
- Create: `Tests/StornautCoreTests/RetentionPolicyTests.swift`
- Create: `Tests/Fixtures/EvidenceStore/`
- Update: `docs/adr/0007-domain-persistence-boundary.md`
- Update if applicable: `Package.swift`, `ThirdPartyNotices/README.md`

**Interfaces:**

- Produces actor/serialized store APIs; callers never compose SQL.
- Supports temporary/in-memory test stores and Application Support production
  location selection.

- [ ] **Step 1: Write migration and transaction failures first**

Cover:

- fresh database creation at schema version 1;
- deterministic migration from each checked-in old fixture;
- rollback on a deliberately failing migration;
- rejecting a future/unsupported schema version;
- foreign-key integrity and cascade behavior;
- one malformed record being isolated rather than hiding healthy sessions;
- cancelled writes not leaving a session falsely complete.

- [ ] **Step 2: Implement typed repositories**

At minimum persist:

- scan sessions and roots;
- path/volume snapshots;
- classifications and display-safe evidence;
- non-executable cleanup plans and policy decisions;
- minimal cleanup manifests;
- structured Local Knowledge and provenance.

Use prepared statements and bound values. No raw content/blob field may be a
generic escape hatch.

- [ ] **Step 3: Enforce local storage boundaries**

Production path selection must use the App container-appropriate Application
Support directory for durable data and Caches only for disposable derived
artifacts. Do not create `~/.stornaut`. Test path selection without writing to
the real user store.

- [ ] **Step 4: Implement retention and manual clear**

Use an injected clock and transactionally verify:

- seven-day expiry for scan/snapshot/classification/evidence/plan records;
- 90-day expiry for minimal manifests;
- linked evidence expiry does not delete a retained manifest;
- clear evidence and clear manifests are separate operations;
- Local Knowledge is not accidentally removed by evidence cleanup;
- deleting local records never mutates scanned files or Trash.

- [ ] **Step 5: Add bounded query and paging contracts**

History and Scan Results must load ordered pages/projections, not materialize
the full filesystem tree. Add query plans/index assertions for session time,
parent/path relationships, classification filters and retention expiry.

- [ ] **Step 6: Validate and accept ADR 0007**

Run focused store/migration/retention tests, inspect the database fixture with
the installed SQLite CLI when available, then run `scripts/verify`.

ADR 0007 becomes `Accepted` only with migration, path and dependency evidence.

Suggested commit subject: `feat: persist local scan evidence`

---

### Task 12: Production Surveyor and Persisted Scan Lifecycle

**Files:**

- Modify/rename: `Sources/StornautCore/Surveyor/SurveyorSpike.swift`
- Modify: `Sources/StornautCore/Surveyor/ScanRequest.swift`
- Modify: `Sources/StornautCore/Surveyor/PathSnapshot.swift`
- Create: `Sources/StornautCore/QuickScan/ScanSessionWriter.swift`
- Create: `Sources/StornautCore/QuickScan/QuickScanEvent.swift`
- Modify: `Benchmarks/SurveyorBenchmark/`
- Create/modify: Surveyor and session lifecycle tests
- Create: `docs/adr/0008-production-quick-scan-lifecycle.md`

**Interfaces:**

- Produces a bounded stream of typed stage/progress/fact/issue events.
- Persists facts incrementally without retaining a complete object graph.
- Returns a terminal completed, partial, cancelled or failed session record.

- [ ] **Step 1: Complete the Task 12 study gate**

Confirm the Epic 3 study covers the concrete APIs and production changes used
here. Record any differences from the Epic 1 benchmark implementation.

- [ ] **Step 2: Write lifecycle tests first**

Cover:

- five approved stages in monotonic order;
- first useful results emitted before scan completion;
- bounded worker, directory queue, stream and database batch sizes;
- cancellation preserving committed facts and unfinished scopes;
- consumer backpressure without silent result loss;
- permission/mount/race failures becoming localized issues;
- symlinks not followed and cross-volume traversal disabled by default;
- root replacement/identity changes failing closed;
- store failure stopping the session without rewriting it as success.

- [ ] **Step 3: Replace the spike façade**

Rename or retire `SurveyorSpike`. Preserve the validated POSIX safety behavior
while exposing production domain events. A normal user cancellation is a
partial terminal result, not an error that discards prior observations.

- [ ] **Step 4: Add volume and root baselines**

Capture source and sample time for capacity/free-space observations and root
identity. Do not derive volume free space from path sums.

- [ ] **Step 5: Persist incrementally**

Use bounded batches/transactions. Progress events may be transient; final
session, facts, issues and unfinished scopes must survive App navigation or
restart. Do not persist current-file log spam.

- [ ] **Step 6: Refresh synthetic benchmark**

Update the fixture generator/benchmark for the production event and store
path. Assert deterministic counts, bounded memory and cancellation completion.
Real-machine Phase B benchmarking remains Task 26.

- [ ] **Step 7: Verify and record ADR 0008**

Run focused Surveyor/lifecycle tests, the synthetic benchmark and
`scripts/verify`.

Suggested commit subject: `feat: productionize deterministic surveyor`

---

### Task 13: Truthful Space Ledger and Explainability

**Files:**

- Create/modify: `Sources/StornautCore/Accounting/`
- Create: `Tests/StornautCoreTests/SpaceAccountingTests.swift`
- Create: `Tests/Fixtures/QuickScan/accounting-scenarios.json`
- Create: `docs/adr/0009-space-accounting-semantics.md`

**Interfaces:**

- Consumes volume baselines plus disjoint snapshot/classification projections.
- Produces an immutable Space Ledger with sampled values, sources, formulas,
  coverage gaps and explanation strings/keys.

- [ ] **Step 1: Write adversarial accounting tests first**

Cover:

- parent/child overlap;
- hard links;
- sparse and compressed files where available;
- clone/purgeable semantics represented as caveats rather than guessed savings;
- permission-limited subtrees with unknown byte amount;
- volume change during a scan;
- integer overflow;
- free-space change not attributed to a scan or candidate;
- reclaim disposition not changing occupancy totals.

- [ ] **Step 2: Define disjoint accounting units**

Document and implement how an item becomes an accounting owner and how child
facts are suppressed from additive totals. Raw recursive directory plus child
allocated-byte sums must never be presented as volume truth.

- [ ] **Step 3: Define Known/Unknown/Unmeasurable/Free formulas**

ADR 0009 must show examples and reconciliation equations. Every displayed
number carries source and sample time. If a permission gap has no defensible
byte estimate, represent it as unavailable and keep the residual explanation
honest.

- [ ] **Step 4: Add stable formatting inputs, not UI strings**

Core emits typed amounts/status/reasons. Localization and byte formatting stay
in the App layer; Core does not bake English prose into persisted records.

- [ ] **Step 5: Verify**

Run focused accounting tests, synthetic benchmark regression and
`scripts/verify`. Accept ADR 0009 only after fixtures reconcile without hidden
double counting.

Suggested commit subject: `feat: reconcile deterministic space ledger`

---

### Task 14: Rule Compiler, Schema and Conservative Overlays

**Files:**

- Create: `Rules/Schema/`
- Create: `Sources/StornautCore/KnowledgeBase/`
- Create: rule compiler executable/plugin/script selected by the study
- Create: `Tests/StornautCoreTests/RuleCompilerTests.swift`
- Create: `Tests/StornautCoreTests/RuleOverlayTests.swift`
- Create: `Tests/Fixtures/Rules/`
- Update if applicable: `Package.swift`, `ThirdPartyNotices/README.md`
- Create: `docs/adr/0010-knowledge-activity-policy.md`

**Interfaces:**

- Produces a versioned immutable `RuleCatalog`.
- Classifies metadata/facts only; it cannot execute an action.

- [ ] **Step 1: Complete the Task 14 study and dependency gate**

Record exact upstream commits/licenses and whether rule YAML parsing introduces
a package. Any new dependency must be reviewed before its code lands.

- [ ] **Step 2: Write compiler rejection tests first**

Reject:

- duplicate or unstable IDs;
- unknown schema versions, dispositions, risks or action types;
- malformed paths/globs and rules matching `/`, HOME or a volume root;
- missing provenance, source URL, version/commit, license or verification date;
- `readyToReclaim` without recovery, required activity checks and
  `MoveToTrash` recommendation;
- any rule proposing Shell, arbitrary executable/args or permanent deletion;
- overlays that lower denylist, veto, required evidence, risk or disposition.

- [ ] **Step 3: Implement compile-time catalog generation**

Validate YAML/source during build or an explicit checked verification step and
ship a deterministic immutable catalog. Runtime scanning must not repeatedly
parse arbitrary YAML from the scanned disk.

- [ ] **Step 4: Implement monotonic local overlays**

Overlays may narrow a scope, add exclusions, raise risk, require more evidence
or make a disposition more conservative. They cannot create an executable,
override a veto, weaken the permanent denylist or promote an item directly to
`Ready to Reclaim`.

- [ ] **Step 5: Verify compiler determinism**

Compile a minimal test catalog twice and compare output hashes. Run all
compiler/overlay/safety tests and `scripts/verify`.

ADR 0010 remains proposed until Task 19 validates activity fusion.

Suggested commit subject: `feat: enforce safe rule compilation`

---

### Task 15: Protected and Veto Rule Catalog

**Files:**

- Create: `Rules/BuiltIn/`
- Create: `Tests/StornautCoreTests/RuleCatalogTests.swift`
- Create/expand: `Tests/Fixtures/Rules/`
- Update: `docs/upstream-studies/epic-4-knowledge-activity.md`
- Update if needed: `ThirdPartyNotices/README.md`

**Interfaces:**

- Produces the first immutable built-in catalog consumed by later rule Tasks.
- Does not produce an action invocation or runtime YAML loading surface.

- [ ] **Step 1: Add protected/veto rules first**

Cover browser user data, credentials, Photos, Mail, Messages, system locations,
HOME, volume roots and the permanent sensitive-path denylist. Rule-level vetoes
may add defense in depth but cannot replace `SensitivePathDenylist` or lower its
coverage.

- [ ] **Step 2: Add collision and bypass fixtures**

Test nested protected paths, case/Unicode variations, symlink-resolved targets,
lookalike directory names and overlay attempts to reduce protection.

- [ ] **Step 3: Prove provenance and independent policy coverage**

Every rule includes source URL, exact commit/version, license, usage mode,
independent verification date and rationale. Tests must prove the Swift
denylist still rejects the same sensitive targets when the catalog is absent.

- [ ] **Step 4: Verify**

Compile twice and compare output hashes. Run catalog/overlay/denylist safety
tests and `scripts/verify`.

Suggested commit subject: `feat: protect sensitive storage rules`

---

### Task 16: Project Artifact Rule Catalog

**Files:**

- Expand: `Rules/BuiltIn/`
- Expand: `Tests/StornautCoreTests/RuleCatalogTests.swift`
- Expand: `Tests/Fixtures/Rules/`
- Update: `docs/upstream-studies/epic-4-knowledge-activity.md`

- [ ] **Step 1: Add project artifact families**

Cover Node.js, Python, Rust, Go, Java, Ruby, PHP, Flutter and Xcode project
artifacts. Each rule identifies producer, artifact lifecycle, recovery/rebuild
method, cost and the activity evidence required before any reclaim
recommendation.

- [ ] **Step 2: Add positive and safety fixtures**

For every family, include an independently constructed positive fixture plus an
active, dirty, unpushed, ambiguous or lookalike safety fixture. A project root
or source directory cannot become a reclaim candidate merely because it
contains a known artifact name.

- [ ] **Step 3: Compare behavior without copying implementation**

Use clean-room fixtures to compare selected artifact classifications against
documented kondo, Mole and ClearDisk behavior. Record false positives, false
negatives and intentionally more conservative Stornaut outcomes.

- [ ] **Step 4: Verify**

Check provenance completeness and deterministic catalog hashes. Benchmark this
catalog version over the anonymous project fixture, then run rule/safety tests
and `scripts/verify`.

Suggested commit subject: `feat: classify project artifacts safely`

---

### Task 17: Package and Build Cache Rule Catalog

**Files:**

- Expand: `Rules/BuiltIn/`
- Expand: `Tests/StornautCoreTests/RuleCatalogTests.swift`
- Expand: `Tests/Fixtures/Rules/`
- Update: `docs/upstream-studies/epic-4-knowledge-activity.md`

- [ ] **Step 1: Add package/build cache families**

Cover npm, pnpm, Yarn, Bun, uv, pip, Conda, Cargo, Go, Gradle, Maven and
Homebrew cache/build-store locations. Distinguish a cache from an installed
runtime, environment, package source or user-owned configuration.

- [ ] **Step 2: Add recovery, activity and ownership fixtures**

Each family includes a positive fixture, a protected/config lookalike, an
active-use case and a recovery/rebuild contract. Global cache paths require
explicit user-scope/ownership facts and may remain `Review Recommended`.

- [ ] **Step 3: Compare behavior and provenance**

Record clean-room behavior comparisons with Mole/ClearDisk/kondo where
applicable. A generated provenance manifest must make every source, license,
verification date and usage mode reviewable.

- [ ] **Step 4: Verify**

Check deterministic catalog hashes and benchmark cumulative matching over the
anonymous fixture. Run rule/safety tests and `scripts/verify`.

Suggested commit subject: `feat: classify developer caches safely`

---

### Task 18: Runtime, Image, Tool and Residue Rule Catalog

**Files:**

- Expand: `Rules/BuiltIn/`
- Expand: `Tests/StornautCoreTests/RuleCatalogTests.swift`
- Expand: `Tests/Fixtures/Rules/`
- Update: `docs/upstream-studies/epic-4-knowledge-activity.md`
- Update if needed: `ThirdPartyNotices/README.md`

- [ ] **Step 1: Add remaining FR-2 families**

Cover Docker, Colima, Lima, Xcode, JetBrains, VS Code, Cursor, AI tool runtimes,
Electron ShipIt/update residue and common temporary residue. Runtime images and
tool state default conservatively because path size alone does not prove they
are unused or safely reconstructable.

- [ ] **Step 2: Add positive, active and destructive-lookalike fixtures**

Each family has independent positive/safety fixtures, including running-tool,
mounted/attached image, current update, user data and nested credential cases.
No rule proposes external cleanup commands in Phase B.

- [ ] **Step 3: Close the FR-2 catalog audit**

Generate a coverage/provenance manifest showing every PRD FR-2 family, rule ID,
source/version/license, verification date, fixture and conservative
disposition. Missing families fail verification rather than disappearing from
the report.

- [ ] **Step 4: Benchmark and verify the complete catalog**

Compare selected clean-room behavior against documented upstream behavior,
compile twice for identical hashes, and prove cumulative matching does not
dominate the anonymous Quick Scan fixture. Run all rule/safety tests and
`scripts/verify`.

Suggested commit subject: `feat: complete deterministic storage catalog`

---

### Task 19: Activity Protection and Structured Local Knowledge

**Files:**

- Create: `Sources/StornautCore/Activity/`
- Create/modify: `Sources/StornautCore/LocalKnowledge/`
- Create: `Tests/StornautCoreTests/ActivityFusionTests.swift`
- Create: `Tests/StornautCoreTests/GitActivityTests.swift`
- Create: `Tests/StornautCoreTests/LocalKnowledgeTests.swift`
- Create: `Tests/Fixtures/Activity/`
- Update: `docs/adr/0010-knowledge-activity-policy.md`

**Interfaces:**

- Produces typed activity evidence and a conservative classification reduction.
- Local Knowledge accepts only explicit user-confirmed structured facts.

- [ ] **Step 1: Write conservative fusion tests first**

Cover:

- Git dirty, untracked and ahead/unpushed states;
- IDE/App running and related-process signals;
- conflicting recent/stale timestamps;
- missing provider data and permission denial;
- Stornaut-caused observation timestamps not becoming user activity;
- veto/active evidence overriding a reclaim recommendation;
- time alone never producing `readyToReclaim`.

- [ ] **Step 2: Implement bounded providers**

Providers have fixed inputs, timeouts and output limits. If `/usr/bin/git` is
used, use fixed read-only arguments/environment and tests proving no arbitrary
Shell or repository mutation. App/IDE/process collection must use approved
native APIs where practical and degrade locally when unavailable.

Do not introduce generic Adapter execution in this Task.

- [ ] **Step 3: Implement the activity reducer**

Retain original signals and reasons. Conflicts choose the more conservative
disposition/risk outcome; a provider error affects only its dependent
classification.

- [ ] **Step 4: Implement structured Local Knowledge**

Support user-confirmed:

- producer mapping;
- path-scope preference/exclusion;
- keep decision;
- verified recovery method;
- provenance and observed/updated timestamps.

File identity, activity change, catalog version change or scope change can mark
a finding stale. Do not support free-text Agent memory or a direct disposition
override.

- [ ] **Step 5: Verify and accept ADR 0010**

Run focused activity/local-knowledge tests, source/audit checks for arbitrary
Shell and target writes, then `scripts/verify`.

Suggested commit subject: `feat: protect active developer storage`

---

### Task 20: Deterministic Quick Scan Orchestration and Safety Audit

**Files:**

- Create: `Sources/StornautCore/QuickScan/QuickScanCoordinator.swift`
- Create: `Sources/StornautCore/QuickScan/QuickScanState.swift`
- Create: `Tests/StornautCoreTests/QuickScanIntegrationTests.swift`
- Create: `Tests/StornautCoreTests/QuickScanBoundaryTests.swift`
- Create: `scripts/verify-quick-scan-boundaries`
- Modify: `scripts/verify`

**Interfaces:**

- Orchestrates volume baseline → Surveyor → store → rule classification →
  activity protection → accounting.
- Emits page-preserving typed state for App ViewModels.

- [ ] **Step 1: Write end-to-end fixture tests first**

Run an anonymous temporary tree through the real coordinator and verify:

- incremental stage/result events;
- expected known, unknown, protected and unmeasurable outcomes;
- cancellation retains a queryable partial session;
- one provider/store/classification failure invalidates only dependent output;
- restart can load the latest valid snapshot;
- all output is reproducible under an injected clock/identity source.

- [ ] **Step 2: Enforce zero Codex invocation**

The Quick Scan implementation lives in `StornautCore` and has no
`StornautCodex` dependency. Add a fake Codex executable that would create a
marker if launched; a complete Quick Scan must leave the marker absent.
Boundary verification also rejects imports or bridge/runtime references from
Quick Scan, Overview and Scan product paths.

- [ ] **Step 3: Enforce zero scanned-target writes**

Before and after a Quick Scan fixture, compare path set, type, identity,
content hash, size and modification time. Run against a read-only target where
possible. Verify database/cache writes occur only under the injected
Stornaut-owned directory.

Do not claim syscall-level proof from this test; combine behavioral evidence
with source review showing Surveyor opens target descriptors read-only and
Quick Scan exposes no mutation dependency.

- [ ] **Step 4: Add restart and concurrent-intent policy**

Only one Quick Scan may own a session at a time. Navigation does not cancel it.
User cancellation is explicit and idempotent. A second start request must
reuse, reject or explicitly replace according to one documented state
transition; it must not create two uncontrolled full-disk scans.

- [ ] **Step 5: Integrate the verification script**

`scripts/verify-quick-scan-boundaries` must be local, deterministic and
non-privileged. Add it to `scripts/verify` after Swift tests and before UI
tests.

- [ ] **Step 6: Verify**

Run focused end-to-end/boundary tests, the full Swift suite and
`scripts/verify`.

Suggested commit subject: `feat: orchestrate model-free quick scan`

---

### Task 21: App State, Fixture Injection and Design System

**Files:**

- Create: App-level store/ViewModel dependency container selected by the study
- Create: `StornautApp/DesignSystem/`
- Modify: `StornautApp/AppShell/RootView.swift`
- Modify: localization resources
- Create/modify: App state and reducer tests

**Interfaces:**

- Consumes Quick Scan/store projections through ViewModels.
- Does not call Surveyor, SQLite, Codex or action APIs from SwiftUI Views.

- [ ] **Step 1: Complete the UI study gate**

Use the approved UI specification and canonical references. Create deterministic
DEBUG-only fixture injection for UI tests; sample values must not leak into
production defaults.

- [ ] **Step 2: Define page-preserving App state**

ViewModel/reducer tests cover empty, loading, partial, cancelled, success,
limited-permission, stale and error states before visual implementation.
State preserves valid results when one dependency fails.

- [ ] **Step 3: Add dependency injection and DEBUG fixtures**

Production composition uses real Phase B services. XCUITest may select
checked-in deterministic fixtures only through a DEBUG launch argument. Unknown
arguments and release builds must not activate fixture data.

- [ ] **Step 4: Establish reusable semantic components**

Create the smallest shared tokens/components needed by the planned pages:
metrics, disposition labels, coverage/retention badges, empty/recovery states
and accessible byte/status formatting. Do not build a generic design framework
or transcribe raw image-model colors/layouts.

- [ ] **Step 5: Verify App architecture**

Run reducer/composition tests, build the real App shell and run
`scripts/verify`. This Task does not replace the placeholder destination pages.

Suggested commit subject: `feat: establish deterministic app state`

---

### Task 22: Snapshot-First Overview

**Files:**

- Create: `StornautApp/Overview/`
- Modify: `StornautApp/AppShell/RootView.swift`
- Modify: localization resources
- Create/modify: Overview unit/UI tests and screenshot checks

- [ ] **Step 1: Write Overview state and contract tests first**

Cover no snapshot, current snapshot, stale snapshot, scan in progress, limited
coverage and local store failure. Assert that Free, Explained and Ready to
Reclaim are different fields and that Unknown/Unmeasurable do not collapse.

- [ ] **Step 2: Implement snapshot-first Overview**

Render volume and latest-snapshot time, the three primary metrics, the Space
Ledger, primary Quick Scan entry and at most three real top opportunities.
Deep Dive remains visibly paused/blocked by the current safety gate and cannot
start from this plan. No fake investigation metrics are shown.

- [ ] **Step 3: Verify accessibility and themes**

Ledger segments expose label, exact byte amount when available, source/sample
time and coverage status to VoiceOver. Verify Light/Dark and English/`zh-Hans`
without relying on color alone.

- [ ] **Step 4: Run the real App UI loop**

Run focused tests, build/launch the actual `.app`, capture/inspect representative
Overview states with read-only Peekaboo, update XCUITest/screenshot checks and
run `scripts/verify`.

Suggested commit subject: `feat: render snapshot-first overview`

---

### Task 23: Quick Scan Progress and Results

**Files:**

- Create: `StornautApp/Scan/`
- Modify: localization resources
- Create/modify: Scan unit/UI tests and screenshot checks

- [ ] **Step 1: Write scan-flow reducer tests first**

Cover idle, five stages, partial results, explicit stop, cancellation,
permission-limited, store failure and completed results. Navigation away and
back preserves the active session.

- [ ] **Step 2: Implement Quick Scan progress**

Use the approved five-stage rail and stable results outline. Show scope,
candidates, measured amount and elapsed time without mixing units. `Stop Scan`
is neutral and explains that a partial snapshot is retained.

- [ ] **Step 3: Implement read-only Scan Results**

Use approved lifecycle groups, filters, columns and the read-only Evidence
Inspector. Known-rule rows have no AI decoration. Unknown items may explain
that Deep Dive is paused, but no Codex process starts.

Do not add an enabled Review/Trash action in Phase B.

- [ ] **Step 4: Verify accessibility and themes**

Stages, filters, results, disclosure and partial/limited states are keyboard and
VoiceOver usable. Missing measurements use an em dash and explanation, not
zero.

- [ ] **Step 5: Run the real App UI loop**

Run focused tests, build/launch the actual `.app`, inspect in-progress, partial
and completed states with read-only Peekaboo, update XCUITest/Light/Dark
screenshots and run `scripts/verify`.

Suggested commit subject: `feat: deliver quick scan results`

---

### Task 24: Scan-Only History

**Files:**

- Create: `StornautApp/History/`
- Modify: localization resources
- Create/modify: History unit/UI tests and screenshot checks

- [ ] **Step 1: Write History projection tests first**

Cover empty, current, partial, expired evidence, single corrupt record,
retention countdown, filters and confirmed deletion. Deleting a record does not
touch target files, Trash or Local Knowledge.

- [ ] **Step 2: Implement master-detail History**

Use the approved date-grouped navigator and typed detail projection for real
Quick Scan sessions/snapshots. Show terminal state, coverage, lineage and
retention without implying causality.

Do not create synthetic Cleanup Manifest rows. `Storage Trend` remains an
on-demand History substate and appears only after at least four real,
user-initiated snapshots exist. It must label Used/Free samples and event
markers without implying background collection or causal attribution.

- [ ] **Step 3: Verify accessibility and themes**

Keyboard selection, search/filter, record status, retention and errors are
accessible and not color-only.

- [ ] **Step 4: Run the real App UI loop**

Run focused tests, build/launch the actual `.app`, inspect populated, expired
and corrupt-record states with read-only Peekaboo, update XCUITest/Light/Dark
screenshots and run `scripts/verify`.

Suggested commit subject: `feat: add scan history workspace`

---

### Task 25: Phase B Settings

**Files:**

- Expand: `StornautApp/Settings/`
- Modify: localization resources
- Create/modify: Settings unit/UI tests and screenshot checks

- [ ] **Step 1: Write Settings behavior tests first**

Cover appearance/language, scan roots/exclusions, separate evidence/manifest
clear confirmations, Local Knowledge review/forget and read-only permission/
Deep Dive policy facts.

- [ ] **Step 2: Implement the approved six-section shell**

Fully wire the Phase B parts:

- General appearance/language;
- Scanning roots and exclusions;
- Privacy & Data retention facts and separate clear actions;
- structured Local Knowledge review/forget.

Permissions and Codex & Deep Dive show only existing evidence-backed status and
safe repair/check actions. They expose no permission, denylist or safety
bypass. Unimplemented Adapter or investigation controls are not fabricated.

- [ ] **Step 3: Verify localization and accessibility**

Keep English/`zh-Hans` keys in parity. Verify keyboard navigation, native
Settings sizing, status semantics, confirmation sheets and Light/Dark.

- [ ] **Step 4: Run the real App UI loop**

Run focused tests, build/launch the actual `.app`, inspect representative
General, Scanning, Privacy & Data and Local Knowledge states with read-only
Peekaboo, update XCUITest/screenshots and run `scripts/verify`.

Record any AutomationMode initialization delay as runner evidence; do not
change TCC, Accessibility, Event Synthesizing or Screen Recording.

Suggested commit subject: `feat: add deterministic scan settings`

---

### Task 26: Phase B Evidence Gate and Handoff

**Files:**

- Create: `docs/reports/epic-2-4-validation-report.md`
- Update: ADRs 0007–0010 with final evidence/status
- Update: `README.md`, `AGENTS.md`, `docs/README.md`
- Update: `docs/agent/coding-agent-handoff.md`
- Update: `docs/plans/roadmap.md`
- Move after completion:
  `docs/plans/active/epic-2-4-deterministic-product-core.md` to
  `docs/plans/completed/`
- Update: `docs/plans/active/README.md`

- [ ] **Step 1: Run anonymous fixture and safety regression suites**

Report domain, migration, retention, Surveyor, accounting, rule, activity,
Local Knowledge, no-Codex and no-target-write evidence. Include skipped or
environment-dependent tests explicitly.

- [ ] **Step 2: Run a real-machine Quick Scan benchmark**

On the current Apple Silicon development machine, record:

- OS/Xcode/Swift, volume baseline and permitted scope;
- elapsed time, time to first useful result and cancellation latency;
- peak RSS and store size;
- entry/session/classification counts;
- permission/mount/race issues and unfinished scopes;
- Known/Unknown/Unmeasurable/Free explanations;
- proof that no Codex marker/process was invoked;
- target-write audit method and limitations.

The goal remains under five minutes on the 460 GiB-class machine. A slower
result or unexplained accounting does not authorize Rust or false totals; it
requires a measured ADR/plan correction.

- [ ] **Step 3: Run App and UI acceptance**

Run the unified verifier and actual-window Light/Dark/English/`zh-Hans`
inspection. Confirm Quick Scan remains useful with Codex unavailable and with
limited access.

- [ ] **Step 4: Audit Phase B scope**

Search product sources and the App bundle for:

- Codex invocation from Quick Scan;
- target-disk mutation;
- arbitrary Shell or executable/args;
- enabled cleanup/Trash/Registered Action flows;
- raw controlled-content persistence;
- telemetry/network/remote-rule/background/MenuBar/login-item additions;
- unreviewed dependencies or copied upstream code.

- [ ] **Step 5: Write the gate decision**

The report must separately decide:

- deterministic domain/persistence;
- production Quick Scan;
- accounting explainability;
- Knowledge/Activity safety;
- App/UI readiness for Phase C planning;
- Deep Dive, which remains no-go/paused unless a separate approved gate changes
  it;
- release, which remains not evaluated.

- [ ] **Step 6: Close the plan lifecycle**

Only after every accepted Task and the final verifier pass:

1. move this plan to `completed/`;
2. leave `active/` without executable work;
3. update the handoff and roadmap current state;
4. commit and push the Phase B report/lifecycle change;
5. propose a separate Phase C deterministic Epic 8 active plan.

Suggested commit subject: `docs: close deterministic product core gate`

## 7. Verification Matrix

| Claim | Required evidence |
| --- | --- |
| Domain contracts are stable | versioned anonymous fixtures and round-trip/invariant tests |
| SQLite is safe to evolve | fresh/migration/rollback/future-version/corruption tests |
| Retention respects boundaries | injected-clock 7/90-day and separate-clear tests |
| Quick Scan streams safely | bounded queue/backpressure/partial/cancellation tests |
| Target roots are read-only | dependency/source audit plus before/after fixture mutation check |
| Quick Scan never invokes Codex | module boundary, fake executable marker and integration test |
| Accounting is explainable | ADR formulas and adversarial APFS/overlap/permission fixtures |
| Rules are trustworthy | compiler rejection tests, provenance, clean-room fixtures |
| Activity fails conservative | dirty/unpushed/running/conflict/provider-failure tests |
| Local Knowledge cannot weaken policy | monotonic overlay and stale-invalidation tests |
| UI reflects real state | reducer tests, XCUITest, Light/Dark screenshots, Peekaboo inspection |
| Phase B meets performance goal | current-machine benchmark with time/RSS/store/coverage evidence |
| No scope leakage | source, dependency, bundle and product-behavior audit |

## 8. Commit and Push Contract

After plan approval, each completed Task gets one dedicated commit and is
pushed immediately to `origin/main`. Do not combine multiple incomplete Tasks
to hide a failing gate.

Before every commit:

```bash
git status --short
git diff --check
```

Run the Task-focused checks and `scripts/verify`. Commit messages must end with
the repository-required trailer exactly once:

```text
Co-authored-by: TRAE CLI <noreply@bytedance.com>
```

Push with invalid environment tokens removed:

```bash
env -u GITHUB_TOKEN -u GH_TOKEN git push origin main
```

Do not push known failures, private machine paths, secrets, raw content,
unredacted database captures or temporary real-user scan output.

## 9. Plan Self-Review

- **Roadmap alignment:** Only Phase B / Epic 2–4 is executable here. Phase C,
  Deep Dive, Adapters and release remain separate.
- **Safety:** The plan adds no product write path. Existing action spikes remain
  unreachable from Quick Scan/UI.
- **Privacy:** Persistence has a closed schema, seven/90-day lifecycle and no
  raw-content escape hatch.
- **Accounting:** Exactness is evidence-driven; unavailable values remain
  unavailable.
- **Licensing:** Every rule/dependency has a pre-implementation provenance and
  license gate.
- **Performance:** Incremental persistence, paging and bounded queues avoid a
  whole-disk in-memory object graph.
- **UI:** Approved state/interaction contracts are implemented with real App
  verification, not generated-image transcription.
- **Failure behavior:** Partial data is retained, affected scopes are explicit,
  and errors never promote a reclaim decision.
- **Exit:** The plan ends in evidence and an empty active-plan queue, not an
  implicit jump into deterministic cleanup.
