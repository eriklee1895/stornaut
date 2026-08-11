# Epic 2–4 Task 11 Code Review — 2026-08-10

> **Historical-scope notice (2026-08-11):** Deep Dive paused/no-go references
> record the reviewed Phase B scope, not current Codex policy. See capability-first
> [ADR 0004](../adr/0004-codex-file-read-isolation.md).

> 状态：All confirmed findings fixed; post-fix review has no open P0–P2
> finding
>
> 范围：SQLite boundary、Evidence/Local Knowledge dual stores、migration、
> retention、paging、backup 与 local storage policy
>
> 方法：`bits-code-guard` diff scope + 7-dimension Swift/SQLite manual
> fallback + adversarial focused tests + full repository verification

## 1. Review Scope

- 11 implementation/test/fixture files in the final code review scope;
- 3,206 reviewed changed lines after fixes;
- system SQLite open/configuration/statement/transaction/backup boundary;
- Evidence v0-to-v1 migration and exact current schema;
- typed Evidence and Local Knowledge repositories;
- seven/90-day retention, independent clear and backup policies;
- private Application Support/Caches path selection and file permissions.

`bits-code-guard` found all Swift/SQL code files, excluded the two Markdown
status updates as media and returned no repository custom workflow. Subagent
delegation was unavailable for this iteration, so the documented large-diff
fallback reviewed four functional groups; the final scope also includes the
Codex test-only timeout isolation exposed by full-suite load:

1. SQLite and local filesystem boundary;
2. Evidence schema and repositories;
3. Local Knowledge role;
4. migration and persistence verification.

The review covered logic, business semantics, security/privacy, concurrency,
robustness, performance and quality. The post-fix automatic report is retained
at `/tmp/stornaut_task11_review_1786294891/report.html`; its result is no open
P0–P2 finding.

## 2. Confirmed Findings and Fixes

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P0 | Read APIs initially used `try?`, so a database-level error could appear as empty History | Made store reads throwing; only individual closed-payload decode failures enter `corruptRecordIDs` | malformed-row isolation plus database-corruption fail-closed tests |
| P1 | `.memory` used a relative URL sentinel; after removing a stray `:memory:` worktree file, finalize treated it as a disk store and six focused tests failed | Pass the explicit in-memory configuration bit through finalization and always open SQLite with the native `:memory:` string | clean-worktree focused suite passes and no `:memory:` file is created |
| P1 | Any zero-`application_id` SQLite file could be silently adopted and a claimed v1 database was not compared against an exact schema | Claim only an empty or known v0 schema inside the migration transaction; compare normalized table/index DDL against a reference schema built by the same SQLite runtime | arbitrary foreign schema, wrong role, future version, dropped-table and same-name/missing-FK tests |
| P1 | `quick_check` does not report foreign-key violations | Run Evidence `foreign_key_check` before writes in addition to `quick_check` | persisted orphan snapshot fixture fails closed |
| P1 | Cleanup Plan/Manifest payloads could request expiry later than fixed seven/90-day product retention | Reject writes whose expiry exceeds the store-enforced deadline and index plan expiry separately | long-expiry plan and Manifest rejection test |
| P1 | A decodable JSON payload whose typed ID differed from its SQLite primary key was returned as healthy data | Validate row key against decoded aggregate key; isolate it in pages and fail direct lookup | malformed and ID-mismatched session tests |
| P1 | Paged filters trusted redundant SQLite relationship/disposition columns without comparing them to the closed payload, so a damaged row could enter the wrong disposition/session page | Validate page relationship, filter, ordering and timestamp columns against each decoded value before returning it | Protected payload with a corrupted Ready index value is isolated from the Ready page |
| P1 | The initial 10,000-row page cap combined with the 1 MiB row cap still allowed a pathological request to materialize roughly 10 GiB | Use one shared 100-record page ceiling for both stores | Evidence and Local Knowledge reject page size 101 |
| P1 | Backup temporary files were opened by SQLite before permissions were tightened, and replacement used higher-level existence checks | Atomically create a no-follow `0600` temporary file, use `sqlite3_backup_*`, revalidate coordinated destination and publish with one rename | fresh/replacement backup, mode and symlink-destination tests |
| P1 | Path mode enforcement used path-based `chmod` after `lstat`, leaving an avoidable substitution window | Open no-follow file/directory descriptors, validate with `fstat` and apply mode with `fchmod` | owner/mode/symlink boundary tests |
| P1 | Local Knowledge had role isolation but lacked malformed-row isolation and header preflight parity | Add SQLite header check, exact schema, row identity check and typed corrupt-row paging | healthy fact survives malformed sibling record |

## 3. Store and Safety Result

### Persistence boundary

- `Evidence.sqlite` and `LocalKnowledge.sqlite` have separate actors,
  connections, schemas, application IDs, backup behavior and clear operations.
- SQLite is the system library linked through SwiftPM; no ORM or package
  dependency was added.
- Values are bound through prepared statements. Interpolated identifiers are
  closed private constants selected by typed repository methods, never caller
  input.
- Payloads remain closed versioned domain values capped at 1 MiB. No raw
  content/blob table or arbitrary persistence API exists.

### Migration and integrity

- New stores and the checked-in v0 fixture migrate to schema version 1.
- Role assignment, schema creation and `user_version` change share one
  `BEGIN IMMEDIATE` transaction.
- Injected migration failure rolls back role ID, schema and version.
- Future schema, wrong role, arbitrary zero-ID database, exact-schema mismatch,
  invalid SQLite header, failed `quick_check` and Evidence foreign-key damage
  fail without reset/downgrade.
- DELETE journal mode, foreign keys, full synchronization and disabled
  trusted/writable schema are explicitly configured.

### Local filesystem and retention

- Durable databases route only under injected/production Application Support;
  Caches is prepared only for disposable future derived data.
- Existing ancestors are canonicalized; private items are current-user-owned,
  no-follow and `0700`/`0600`.
- Evidence is excluded from system backup; user-confirmed Local Knowledge
  remains eligible.
- Scan aggregates and Cleanup Plans cannot exceed seven days. Minimal
  Manifests cannot exceed 90 days and do not depend on an Evidence foreign key,
  so Evidence expiry does not delete retained audit data.
- Evidence, Manifest and Local Knowledge clearing are independent and do not
  address scanned roots or Trash.

## 4. Verification

Focused result after review fixes:

- 18 migration/store/retention tests passed;
- fresh schema, v0 migration, rollback and future/wrong-role refusal;
- exact schema and `foreign_key_check`;
- cascade/cancellation, record isolation, paging/query plans;
- seven/90-day lifecycle and separate clears;
- owner/mode/no-symlink/backup-role behavior;
- consistent fresh and replacement online backup;
- no `:memory:`, rollback-journal, WAL or SHM worktree residue.

The first full verifier exposed two unrelated fake Codex scenarios inheriting
the fixture's two-second timeout: under the new parallel SQLite/CLI load, the
successful and invalid-envelope cases timed out at about 2.39 seconds before
their actual assertions. They now use a test-local ten-second ceiling, matching
the earlier output-limit isolation. Dedicated two-second timeout, descendant
termination and cancellation tests are unchanged. Three consecutive full
157-test SwiftPM stress runs passed in 4.182, 3.688 and 3.392 seconds with no
fixture process residue.

Dependency and documentation checks:

- `swift package show-dependencies --format text`: no external dependencies;
- `scripts/check-doc-links`: all local Markdown links resolve;
- `git diff --check`: clean.

Final `scripts/verify` passed:

- 157 SwiftPM tests (3 opt-in diagnostics skipped by design);
- Xcode App contract tests;
- 2/2 XCUITest cases;
- four Light/Dark shell/Settings screenshots and image checks;
- local App signing and bundle verification;
- English/`zh-Hans` localization parity;
- docs links and diff whitespace checks.

## 5. Remaining Boundaries

- Transaction batches are cancellation-aware and actor serialized; production
  batch-size tuning remains coupled to Task 12 scan orchestration.
- The wrapper has adversarial migration/store tests but no fuzz target yet.
- Task 12 owns production Surveyor session lifecycle and incremental writes.
- Task 13 owns truthful reconciliation rather than raw entry sums.
- Cleanup execution remains Phase C; persisted Task 11 plan/decision/manifest
  records carry no authority.
- Deep Dive remains no-go/paused.
