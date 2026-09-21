# ADR 0007: Domain Persistence Boundary

> Status: Accepted; Phase B evidence gate validated
>
> Date: 2026-08-09
>
> Decision owners: Stornaut maintainers
>
> Related study:
> [`../upstream-studies/epic-2-domain-persistence.md`](../upstream-studies/epic-2-domain-persistence.md)

## Context

Phase B needs durable, queryable local records for:

- scan sessions and roots;
- path and volume snapshots;
- classifications and display-safe evidence;
- non-executable cleanup plans/policy decisions;
- minimal cleanup manifests;
- structured Local Knowledge.

The store must support incremental writes, paging, exact migrations, seven/90-
day retention, partial-record isolation and immediate user clearing. It must
never become a generic persistence channel for raw controlled content, Codex
JSONL or free-text Agent memory.

The current package has no third-party dependencies. Before implementation, the
plan requires a measured choice between system SQLite, a third-party Swift
wrapper, Apple object persistence and file-based formats.

## Decision

Use system SQLite through a small repository-owned Swift/C boundary with two
role-separated databases:

- `Evidence.sqlite`: scan/snapshot/classification/evidence/plan/minimal
  Manifest records and their seven/90-day retention;
- `LocalKnowledge.sqlite`: explicit user-confirmed structured knowledge with no
  evidence payload.

The separation gives the two stores independent retention, backup, corruption,
clear and migration boundaries.

### Ownership and concurrency

- Each store has a dedicated Swift `actor` that owns one SQLite connection.
- Each actor serializes its connection and statement operations.
- Callers use typed repository methods; no raw SQL or SQLite pointer escapes.
- The connection opens with read/write/create and full-mutex flags.
- Prepared statements use bound values only.
- Bounded write batches observe cancellation between rows and transactions.
- High-volume snapshot batches reuse one prepared statement. The production
  default is 4,096 rows and the hard maximum is 8,192; the first useful fact
  is committed separately before bulk batching begins.

### Storage locations

Durable records live under:

```text
URL.applicationSupportDirectory/com.eriklee.stornaut/
```

Discardable derived data lives under:

```text
URL.cachesDirectory/com.eriklee.stornaut/
```

Production code creates neither `~/.stornaut` nor a store inside a scan root.
Tests inject temporary directories and do not touch the real user store.

The Stornaut support subdirectory is created/verified as a non-symlink directory
owned by the current user with mode `0700`. Database files are non-symlinks
owned by the current user with mode `0600`. SQLite journals remain inside the
private directory.

`Evidence.sqlite` is marked excluded from system backup because backup copies
would otherwise outlive the product's seven/90-day lifecycle. The separately
stored Local Knowledge is eligible for normal Application Support backup
because it contains durable, user-confirmed facts and no raw evidence content.

### Connection configuration

Each connection explicitly sets/verifies:

```text
PRAGMA foreign_keys = ON
PRAGMA synchronous = FULL
PRAGMA journal_mode = DELETE
PRAGMA application_id
PRAGMA user_version
```

The repository assigns distinct Stornaut `application_id` values to the
Evidence and Local Knowledge roles in Task 11. A zero ID is initialized only
for a new empty database; a mismatched nonzero ID fails closed.

### Journal mode

Start with SQLite's DELETE rollback journal, not WAL:

- each role has one serialized connection;
- no measured reader/writer contention justifies WAL;
- rollback mode avoids WAL/SHM sidecar lifecycle during clear, export and
  corruption recovery;
- bounded transactions keep write locks short.

Open explicitly requests and verifies `journal_mode=DELETE`, so an existing WAL
database cannot silently retain the old mode. WAL requires a later measured ADR
covering checkpoints, backup and sidecar behavior.

### Migrations and downgrade

- `PRAGMA user_version` is the schema version. Task 12 advances Evidence to v2
  with the closed `volume_baselines` table; Local Knowledge remains v1.
- A zero `application_id` is claimable only when the exact known empty/legacy
  schema fingerprint matches; arbitrary SQLite files are never adopted.
- Every checked-in migration declares exact input/output versions.
- Migrations execute in order inside `BEGIN IMMEDIATE`.
- Any SQL, validation or foreign-key failure rolls back the whole step.
- A future version produces `unsupportedFutureSchema` and is never downgraded
  or mutated.
- Migration failure never triggers silent database deletion/reset.

### Error mapping

SQLite return codes map into typed Stornaut errors carrying:

- operation category;
- primary and extended SQLite code;
- redacted database role/table context;
- no bound secret/path payload or raw SQL interpolation.

Busy/locked behavior is bounded. Schema/corruption errors are not retried as if
transient.

### Corruption, export and delete

- Opening a store performs a bounded `quick_check`; Evidence also performs
  `foreign_key_check` before writes.
- A claimed current-version database must match the exact expected table/index
  fingerprint; missing or foreign objects fail closed without reset.
- Explicit diagnostics may run `integrity_check`.
- A single undecodable or primary-key-mismatched record is isolated in paged
  typed projections; direct lookup fails rather than returning misbound data.
- Database-level corruption blocks writes; it is not shown as empty history.
- Corruption of Evidence does not make Local Knowledge unreadable, and the
  inverse is also true.
- Live backup/export uses SQLite's backup API rather than copying database
  files while open. Its temporary snapshot is atomically created at `0600`
  before SQLite writes and published with one coordinated rename.
- Clear evidence and clear manifests are separate transactions.
- Clearing local records never changes scan targets, Trash or existing cleanup
  effects.

### Closed persistence schema

The Evidence Store has typed columns/records for approved domain data. It does
not expose a generic raw blob, arbitrary JSON payload or content snippet table.
Structured JSON is permitted only for a versioned closed value with bounded
size and strict decoding. Generic records remain capped at 1 MiB. The closed
`SpaceLedger` role alone has a 16 MiB ceiling because a real scan can contain
thousands of typed owners and coverage gaps; that larger limit is not exposed
as a generic payload escape hatch.

### File coordination

Normal database access does not use `NSFileCoordinator`: both database files
are private App support files and their respective actors are the only owners.
Explicit export first creates a consistent SQLite backup snapshot, closes that
snapshot, then performs a coordinated/atomic write to the user-selected
destination. No live database, rollback journal or sidecar is copied directly.

## Evidence

### System library feasibility

The macOS 26.5 SDK provides `sqlite3.h` and `libsqlite3.tbd`.

A disposable Swift program successfully:

- imported `SQLite3`;
- linked with `-lsqlite3`;
- opened an in-memory database;
- reported runtime SQLite 3.51.0.

### SwiftPM and transaction feasibility

A disposable Swift 6 package using:

```swift
linkerSettings: [.linkedLibrary("sqlite3")]
```

successfully:

- opened with full mutex;
- enabled foreign keys;
- ran a `BEGIN IMMEDIATE` migration;
- created related tables;
- set/read `user_version=1`;
- rejected a foreign-key violation;
- rolled back the failed write.

Observed output:

```text
sqlite=3.51.0 user_version=1 foreign_keys=ON rollback=verified
```

### Local path evidence

Current Foundation returns user Application Support and Caches directories.
Apple documentation assigns required app support to the former and
reconstructible files to the latter.

### Alternatives

- GRDB 7.11.1: mature/MIT/system SQLite, but unnecessarily large production
  dependency for the current schema.
- SQLite.swift 0.16.0: MIT, but current package includes additional CSQLite and
  SQLCipher dependency declarations.
- JSON/plist: insufficient atomic migration, paging and referential integrity.
- Core Data/SwiftData: object-graph and migration behavior is less explicit
  than the required fixture-inspectable contract.

No upstream code or package was added in Task 9.

## Consequences

Positive:

- no third-party production persistence dependency;
- explicit schema, retention and privacy boundary;
- independent Evidence and Local Knowledge failure/backup boundaries;
- deterministic migration fixtures and CLI inspection;
- paging and transactional incremental persistence;
- actor isolation aligns with Swift 6 concurrency.

Costs:

- Stornaut owns statement lifetime, binding and error mapping;
- low-level tests are mandatory;
- the wrapper must be kept narrow to avoid creating an untested ORM;
- rollback mode may limit future concurrent history reads during large writes.

## Residual Risks

- The narrow wrapper is implemented and adversarially tested but is not fuzzed.
- The 2-second busy timeout remained sufficient during the Phase B real-machine
  product benchmark. It is still a bounded policy rather than a general
  concurrency guarantee.
- `quick_check` may not find every latent corruption.
- A single database file is still a failure domain; per-record decode
  isolation does not repair page-level corruption.
- Local Knowledge is backed up by default and may contain user-confirmed path
  scopes. Release privacy documentation must state this. Evidence/Manifest
  storage is excluded so its TTL is not silently extended by system backup.
- File protection/encryption-at-rest behavior remains the user's macOS volume
  responsibility; Stornaut does not invent custom encryption in Phase B.

## Acceptance Evidence

Task 11 accepts this ADR with the following implementation evidence:

1. fresh v1 schema creation and checked-in v0-to-v1 fixture migration pass;
2. injected migration failure rolls back schema, `user_version` and role ID;
3. future, wrong-role, arbitrary zero-ID and damaged exact schemas fail closed;
4. Evidence and Local Knowledge use distinct application IDs, actor-owned
   connections and independent files;
5. connections verify DELETE journal mode, full synchronization, foreign keys,
   disabled trusted/writable schema and bounded busy behavior;
6. `quick_check`, Evidence `foreign_key_check` and exact schema fingerprints
   reject database-level damage without reset;
7. bound values, closed typed payloads and 1 MiB limits prevent a generic raw
   content channel; error operations contain no values or SQL text;
8. paged projections isolate malformed/ID-mismatched rows while preserving
   healthy records; role corruption remains independent;
9. store-enforced seven/90-day ceilings and transactional expiry preserve a
   Manifest after linked Evidence deletion; manual clears remain separate;
10. injected Application Support/Caches routes, no-follow opens, current-user
    ownership and `0700`/`0600` enforcement pass without touching user data;
11. Evidence backup exclusion and Local Knowledge backup eligibility pass;
12. session/path/classification/retention query-plan index assertions pass;
13. `sqlite3_backup_*` export passes fresh and replacement snapshots and rejects
    destination symlinks;
14. focused migration/store/retention verification passes 18 tests without
    worktree database or journal residue;
15. full `scripts/verify` passes (recorded in the Task 11 review/report and
    active plan evidence);
16. `swift package show-dependencies` remains dependency-free and no App-bundle
    framework was introduced.

Task 12 later exercised this accepted migration mechanism with a checked-in,
exact-schema v1 fixture and transactional v1-to-v2 rollback. ADR 0008 owns the
new Quick Scan lifecycle and volume-baseline semantics; it does not change the
storage boundary accepted here.

## Phase B Gate Evidence

Task 26 keeps this ADR Accepted with additional production-path evidence:

1. `EvidenceStore` reuses prepared statements for bounded snapshot batches and
   keyset-pages retained facts without loading a whole scan into memory.
2. The product persists candidate/owner/coverage-gap facts plus a closed full
   `ScanAggregate`; arbitrary non-candidate paths outside the bounded display
   sample are not retained merely to reconstruct counts.
3. Full snapshot, classification, disposition and evidence counts remain
   separate from the bounded 100-record App projection.
4. Generic payloads still fail above 1 MiB, while a dedicated test proves only
   `SpaceLedger` may use the 16 MiB role-specific allowance.
5. The final-source current-machine Home product run retained
   3,107,607-entry aggregate truth, 4,261 classifications, 9,463 evidence
   records and a typed ledger in a 20,795,392-byte DELETE-journal database.
6. Migration, rollback, future-schema, wrong-role, corruption, seven/90-day
   retention, separate clear and 250-row keyset paging regressions passed in
   the Phase B focused gate.
7. No external package, generic raw-content table, WAL sidecar or target-root
   store was introduced.

The Phase B gate does not change the one-file failure domain, release privacy
documentation requirement or encryption-at-rest residual risks above.
