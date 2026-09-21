# Epic 2–4 Task 9 Code Review — 2026-08-09

> **Historical-scope notice (2026-08-11):** Deep Dive paused/no-go references
> record the reviewed Phase B scope, not current Codex policy. See capability-first
> [ADR 0004](../adr/0004-codex-file-read-isolation.md).

> 状态：Two confirmed design findings fixed; no open P0–P2 finding
>
> 范围：Task 9 Phase B studies、ADR 0007、active-plan/routing updates
>
> 方法：`bits-code-guard` scope discovery + 7-dimension manual fallback +
> specification/license/evidence audit

## 1. Review Scope

- 14 changed Markdown files;
- four Phase B implementation studies;
- Proposed ADR 0007;
- active plan approval and Task 9 execution evidence;
- AGENTS/handoff/roadmap/docs routing reconciliation.

`bits-code-guard` correctly identified the Git diff but its file filter
classified every Markdown file as binary/media, leaving zero automatic review
files. That empty result was not accepted as evidence. The review continued
with the skill's no-subagent/manual fallback across:

- logic;
- business semantics;
- security/privacy;
- concurrency;
- robustness;
- performance;
- quality/maintainability.

Additional checks covered upstream commit/license claims, source fingerprints,
temporary-probe cleanup, docs authority and Phase B scope.

## 2. Confirmed Findings and Fixes

| Severity | Finding | Fix | Follow-up evidence |
| --- | --- | --- | --- |
| P1 | ADR selected rollback journal but only required reading `PRAGMA journal_mode`; a database previously in WAL mode would remain WAL and violate the stated sidecar/backup/clear assumptions | Require `PRAGMA journal_mode=DELETE`, verify the returned mode, and add a WAL-to-DELETE fixture gate | Task 11 acceptance gate now requires the explicit transition and verification |
| P1 | One database for short-lived Evidence/Manifest and durable Local Knowledge coupled different retention, backup, corruption and clear boundaries; system backup could extend nominal seven/90-day Evidence retention | Split `Evidence.sqlite` and `LocalKnowledge.sqlite` into role-specific actor-owned stores with distinct `application_id`; exclude Evidence from backup while retaining normal backup for user-confirmed Local Knowledge | Task 11 gates now cover role IDs, independent corruption, backup policy and separate clearing |

The fixes also make private storage requirements explicit:

- Application Support subdirectory is current-user-owned, non-symlink, mode
  `0700`;
- database files are current-user-owned, non-symlink, mode `0600`;
- live database files are never copied for export;
- SQLite backup creates a closed snapshot before coordinated/atomic destination
  writing.

## 3. Manual Review Result

### Logic and business semantics

- Task numbering and dependencies remain continuous from 9 through 26.
- Task 9 does not implement Task 10 product code.
- ADR 0007 remains Proposed until Task 11 proves its acceptance gates.
- Phase B remains read-only with respect to scan targets.
- Manifest persistence contracts do not imply Phase C execution.

### Security and privacy

- No secret, credential, private path or raw user scan output is committed.
- Mole GPL and restricted-source boundaries remain behavior-only.
- No package dependency or copied upstream code was added.
- Evidence backup retention no longer silently exceeds product TTL.
- Deep Dive remains no-go/paused.

### Concurrency and robustness

- Store ownership is actor-isolated by database role.
- Migration, future-version, busy/locked, corruption and rollback behavior are
  explicit acceptance gates rather than unverified success claims.
- Quick Scan cancellation, partial data, store failure and one-active-session
  behavior are mapped to later tests.

### Performance

- The production plan retains bounded scanner queues, event streams, database
  batches and paged queries.
- WAL is not added without measured contention.
- Rule matching requires deterministic hashing and a cumulative benchmark.

### Quality and evidence

- Every study records exact source/version/license/material read.
- Comparison libraries are not presented as dependencies.
- Existing `$erik-gpt-image-2` canonical assets are sufficient; no redundant
  image generation was performed.
- UI assets remain non-pixel specifications.

## 4. Verification Required Before Commit

- `scripts/check-doc-links`;
- `git diff --check`;
- no stale Proposed-plan routing;
- no external SwiftPM dependencies;
- full `scripts/verify`;
- commit trailer exactly once;
- push and local/remote HEAD equality.

## 5. Remaining Risks

- The direct SQLite wrapper is not implemented; ADR 0007 cannot be Accepted.
- Evidence backup exclusion and POSIX ownership/mode checks still need real
  Task 11 tests.
- Yams 6.2.2 is only a Task 14 candidate; it requires a fresh dependency,
  license and App-bundle reachability audit before addition.
- Packaged-App full-scope FDA remains unmeasured.
- Deep Dive remains paused.
