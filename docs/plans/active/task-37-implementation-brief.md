# Task 37 Implementation Brief — Investigation Persistence and Retention

> **Status:** Approved; current from the pushed Task 36 baseline.
>
> **Parent plan:**
> [Phase D Conditional Deep Dive](phase-d-conditional-deep-dive.md)
>
> **Normative contract:**
> [Investigation Canonical v1](../../specs/investigation-canonical-v1.md).

## 1. Objective

Task 37 gives the Task 36 investigation domain durable, privacy-bounded local
truth:

```text
retained terminal Quick Scan source
→ exhaustive typed source-row manifest
→ Swift-computed source fingerprint
→ immutable Investigation session/targets
→ immutable partial/final report transaction
→ bounded paging, retention and exact local-record deletion
```

Task 37 owns the only Evidence Store migration in Phase D: schema v3 to v4,
including direct migration from fixture versions v0/v1/v2 and current v3.
It does not launch Codex, parse App Server events, add the
`StornautInvestigation` coordinator, change Deep Dive availability, project
Agent proposals into Review, or add App UI.

Completion requires tests-first Store contracts, migration and privacy
adversarial fixtures, zero unresolved independent P0–P2 findings, one
uninterrupted authoritative `scripts/verify --full` exit `0`, and an
independent commit/push.

## 2. Preconditions

Task 37 begins only after:

- Task 35 is committed and pushed;
- Task 36 is independently committed and pushed;
- `InvestigationPlan`, v2 targets, canonical source manifest, fingerprints,
  budget ledger, stop outcomes and all six canonical vectors are checked in;
- normal App Deep Dive remains unavailable;
- the existing Evidence Store is verified at schema v3 on the Task 36
  baseline.

If Task 36 changes any normative record, token, bound, fingerprint or rejoin
barrier, this brief must be updated before Store code is written.

Task 36's pure planner remains Store-neutral. Task 37 adapts it by invoking
the planner inside the `EvidenceStore` actor/transaction with a non-escaping
Store cursor. No public caller builds or submits a production source
projection or Plan.

## 3. Store v4 Ownership

### 3.1 Migration

`EvidenceStore.schemaVersion` advances from `3` to `4`. The migration must:

- use the current transaction and rollback mechanism;
- preserve application-role verification and SQLite integrity checks;
- migrate v0→v4, v1→v4, v2→v4 and v3→v4;
- refuse a future schema version;
- leave the original database byte-logically usable at its prior version if
  the v4 migration transaction fails;
- preserve all Scan, classification, evidence, Space Ledger, Cleanup Plan,
  Policy, journal and Cleanup Manifest records;
- not rewrite, extend or weaken the 90-day Cleanup Manifest contract;
- install foreign keys and indexes before setting `PRAGMA user_version = 4`;
- verify exact table/index/foreign-key/check constraints after migration.

No migration may infer a v2 Investigation target from a legacy v1 target.
Legacy v1 investigation fixtures remain migration-only evidence and cannot
enter the v4 product tables.

### 3.2 Proposed tables

The exact schema may consolidate immutable payloads only if all ownership,
identity and paging invariants remain explicit. The expected logical records
are:

```text
investigation_sessions
investigation_source_rows
investigation_relevance_tokens
investigation_targets
investigation_runs
investigation_run_targets
investigation_reports
investigation_evidence
investigation_report_degradations
investigation_budget_events
```

Required ownership:

- one Investigation session owns one immutable source Scan session/scope and
  source fingerprint;
- one Investigation session owns its complete source manifest as
  `investigation_source_rows`, one row per canonical `SourceRowV1`, with a
  contiguous canonical ordinal and all required `StorageColumnV1` values
  materialized as typed SQLite columns under exact row-kind NULL/check shapes;
- one Investigation session owns its canonical relevance-token set as
  `investigation_relevance_tokens`, one token per contiguous canonical
  ordinal;
- one Investigation session owns bounded v2 targets and at most `16` runs
  (`run_ordinal 0...15`), including continuations;
- one run belongs to one Investigation session and owns one immutable strict
  Plan JSON, plan/target-set fingerprints, budget preset and ordered
  `investigation_run_targets` membership; completed/final and
  partial outcomes own exactly one immutable final/partial report,
  while blocked/failed outcomes own zero reports and promote zero evidence;
- evidence belongs to exactly one same-session report/run and a target admitted
  by that exact run's `investigation_run_targets` membership;
- budget events belong to exactly one same-session run, including runs with no
  report;
- no report, evidence or budget row may outlive or exist without its owning
  Investigation session;
- continuation lineage references a retained verified partial report and a
  distinct new run identity;
- only deletion of the owning Investigation session cascades through
  Investigation-local records. Direct run/report/target/evidence/degradation/
  budget deletion is not a public API and lineage/terminal foreign keys use
  deferred `NO ACTION` so a child cannot erase its parent or continuation
  chain.

Every table carries enough typed identity columns to validate payload identity
without trusting JSON alone. Payloads use the existing strict `DomainJSON`
encoding and must byte-identically decode/re-encode.

The complete manifest is never encoded into one `investigation_sessions`
payload. `investigation_source_rows` stores at most `300_002` rows and
materializes each row's kind, primary ID, exact required non-payload storage
columns, source payload byte count and source payload SHA-256. In addition to
owner/ordinal/kind/primary-ID columns, its closed nullable-column superset is:

```text
source_id
source_session_id
source_relative_path
source_snapshot_id
source_disposition
source_started_at_ms
source_finished_at_ms
source_expires_at_ms
source_observed_at_ms
source_classified_at_ms
source_payload_byte_count
source_payload_sha256
```

The row-kind checks require exactly the non-null shape and value kind specified
by canonical `StorageColumnV1`; all inapplicable columns must be NULL.
`source_owner_session_id` and `source_snapshot_row_kind` are generated, never
caller-bound, and exist only to make retained-session and snapshot-parent
ownership deferred composite foreign keys. `source_id == primary_id` is
mandatory. The manifest stores no source payload bytes.
`investigation_relevance_tokens` stores at most `256` canonical tokens.
A unique `(investigation_id, ordinal)` plus unique
`(investigation_id, row_kind, primary_id)` prevents reorder and membership
ambiguity. A session stores the expected row/token counts and canonical source
fingerprint so insertion and every rejoin prove exact completeness.

`investigation_runs` is the sole owner of run identity, immutable run Plan,
continuation parent, runtime state and terminal linkage. Session state is
aggregate product state; it cannot substitute for a run row or allow two
terminal reports for one run. A continuation never mutates/replaces its parent
Plan: Store rejoin creates a new run-owned Plan and ordered unresolved-target
membership under a new caller-created run ID.

### 3.3 Normative SQLite shape

All v4 tables are `STRICT`. The following identity/manifest columns and
constraints are normative; implementation may add only separately reviewed
indexes or immutable typed payload columns and may not weaken these checks:

```sql
CREATE TABLE investigation_sessions (
    id TEXT PRIMARY KEY NOT NULL CHECK (
        length(CAST(id AS BLOB)) BETWEEN 15 AND 128
        AND id GLOB 'investigation-?*'
        AND id NOT GLOB '*[^A-Za-z0-9._-]*'
    ),
    scan_session_id TEXT NOT NULL CHECK (
        length(CAST(scan_session_id AS BLOB)) BETWEEN 6 AND 128
        AND scan_session_id GLOB 'scan-?*'
        AND scan_session_id NOT GLOB '*[^A-Za-z0-9._-]*'
    ),
    scan_scope_id TEXT NOT NULL CHECK (
        length(CAST(scan_scope_id AS BLOB)) BETWEEN 7 AND 128
        AND scan_scope_id GLOB 'scope-?*'
        AND scan_scope_id NOT GLOB '*[^A-Za-z0-9._-]*'
    ),
    source_fingerprint BLOB NOT NULL
        CHECK (length(source_fingerprint) = 32),
    state TEXT NOT NULL CHECK (state IN (
        'planned', 'awaitingDisclosure', 'ready', 'running',
        'pauseRequested', 'stopRequested', 'terminalBarrier', 'paused',
        'completed', 'partial', 'blocked', 'failed'
    )),
    stage TEXT NOT NULL CHECK (
        stage IN ('prioritize', 'identify', 'verify', 'buildPlan')
    ),
    source_row_count INTEGER NOT NULL
        CHECK (source_row_count BETWEEN 2 AND 300002),
    relevance_token_count INTEGER NOT NULL
        CHECK (relevance_token_count BETWEEN 0 AND 256),
    source_payload_byte_count INTEGER NOT NULL
        CHECK (source_payload_byte_count BETWEEN 1 AND 268435456),
    source_canonical_byte_count INTEGER NOT NULL
        CHECK (source_canonical_byte_count BETWEEN 1 AND 536870912),
    run_count INTEGER NOT NULL DEFAULT 0
        CHECK (run_count BETWEEN 0 AND 16),
    report_count INTEGER NOT NULL DEFAULT 0
        CHECK (report_count BETWEEN 0 AND 16),
    evidence_row_count INTEGER NOT NULL DEFAULT 0
        CHECK (evidence_row_count BETWEEN 0 AND 8192),
    evidence_payload_byte_count INTEGER NOT NULL DEFAULT 0
        CHECK (evidence_payload_byte_count BETWEEN 0 AND 67108864),
    degradation_row_count INTEGER NOT NULL DEFAULT 0
        CHECK (degradation_row_count BETWEEN 0 AND 1024),
    degradation_payload_byte_count INTEGER NOT NULL DEFAULT 0
        CHECK (degradation_payload_byte_count BETWEEN 0 AND 4194304),
    budget_event_count INTEGER NOT NULL DEFAULT 0
        CHECK (budget_event_count BETWEEN 0 AND 65536),
    budget_payload_byte_count INTEGER NOT NULL DEFAULT 0
        CHECK (budget_payload_byte_count BETWEEN 0 AND 33554432),
    created_at_ms INTEGER NOT NULL,
    updated_at_ms INTEGER NOT NULL,
    expires_at_ms INTEGER NOT NULL,
    UNIQUE (id, scan_session_id)
) STRICT;

CREATE TABLE investigation_source_rows (
    investigation_id TEXT NOT NULL,
    ordinal INTEGER NOT NULL CHECK (ordinal BETWEEN 0 AND 300001),
    row_kind TEXT NOT NULL CHECK (row_kind IN (
        'scan-session-v1', 'path-snapshot-v1', 'classification-v1',
        'evidence-v1', 'space-ledger-v1'
    )),
    primary_id TEXT NOT NULL CHECK (
        length(CAST(primary_id AS BLOB)) BETWEEN 1 AND 128
        AND primary_id NOT GLOB '*[^A-Za-z0-9._-]*'
    ),
    source_id TEXT NOT NULL CHECK (
        source_id = primary_id
        AND length(CAST(source_id AS BLOB)) BETWEEN 1 AND 128
        AND source_id NOT GLOB '*[^A-Za-z0-9._-]*'
    ),
    source_session_id TEXT CHECK (
        source_session_id IS NULL OR (
            length(CAST(source_session_id AS BLOB)) BETWEEN 1 AND 128
            AND source_session_id NOT GLOB '*[^A-Za-z0-9._-]*'
        )
    ),
    source_owner_session_id TEXT GENERATED ALWAYS AS (
        CASE row_kind
            WHEN 'scan-session-v1' THEN primary_id
            WHEN 'path-snapshot-v1' THEN source_session_id
            WHEN 'space-ledger-v1' THEN source_session_id
            ELSE NULL
        END
    ) STORED,
    source_relative_path TEXT CHECK (
        source_relative_path IS NULL OR (
            length(CAST(source_relative_path AS BLOB)) BETWEEN 1 AND 16384
            AND instr(source_relative_path, char(0)) = 0
        )
    ),
    source_snapshot_id TEXT CHECK (
        source_snapshot_id IS NULL OR (
            length(CAST(source_snapshot_id AS BLOB)) BETWEEN 1 AND 128
            AND source_snapshot_id NOT GLOB '*[^A-Za-z0-9._-]*'
        )
    ),
    source_snapshot_row_kind TEXT GENERATED ALWAYS AS (
        CASE WHEN source_snapshot_id IS NULL
            THEN NULL
            ELSE 'path-snapshot-v1'
        END
    ) STORED,
    source_disposition TEXT CHECK (
        source_disposition IS NULL OR source_disposition IN (
            'readyToReclaim', 'reviewRecommended', 'protected', 'unknown'
        )
    ),
    source_started_at_ms INTEGER,
    source_finished_at_ms INTEGER,
    source_expires_at_ms INTEGER,
    source_observed_at_ms INTEGER,
    source_classified_at_ms INTEGER,
    source_payload_byte_count INTEGER NOT NULL CHECK (
        source_payload_byte_count BETWEEN 1 AND
            CASE row_kind
                WHEN 'space-ledger-v1' THEN 16777216
                ELSE 1048576
            END
    ),
    source_payload_sha256 BLOB NOT NULL CHECK (
        length(source_payload_sha256) = 32
    ),
    PRIMARY KEY (investigation_id, ordinal),
    UNIQUE (investigation_id, row_kind, primary_id),
    FOREIGN KEY (investigation_id)
        REFERENCES investigation_sessions(id) ON DELETE CASCADE
        DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY (investigation_id, source_owner_session_id)
        REFERENCES investigation_sessions(id, scan_session_id)
        ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY (
        investigation_id, source_snapshot_row_kind, source_snapshot_id
    ) REFERENCES investigation_source_rows(
        investigation_id, row_kind, primary_id
    ) ON DELETE CASCADE DEFERRABLE INITIALLY DEFERRED,
    CHECK (
        (row_kind = 'scan-session-v1'
            AND primary_id GLOB 'scan-?*'
            AND source_session_id IS NULL
            AND source_relative_path IS NULL
            AND source_snapshot_id IS NULL
            AND source_disposition IS NULL
            AND source_started_at_ms IS NOT NULL
            AND source_finished_at_ms IS NOT NULL
            AND source_expires_at_ms IS NOT NULL
            AND source_observed_at_ms IS NULL
            AND source_classified_at_ms IS NULL)
        OR
        (row_kind = 'path-snapshot-v1'
            AND primary_id GLOB 'snapshot-?*'
            AND source_session_id IS NOT NULL
            AND source_session_id GLOB 'scan-?*'
            AND source_relative_path IS NOT NULL
            AND source_snapshot_id IS NULL
            AND source_disposition IS NULL
            AND source_started_at_ms IS NULL
            AND source_finished_at_ms IS NULL
            AND source_expires_at_ms IS NULL
            AND source_observed_at_ms IS NOT NULL
            AND source_classified_at_ms IS NULL)
        OR
        (row_kind = 'classification-v1'
            AND primary_id GLOB 'classification-?*'
            AND source_session_id IS NULL
            AND source_relative_path IS NULL
            AND source_snapshot_id IS NOT NULL
            AND source_snapshot_id GLOB 'snapshot-?*'
            AND source_disposition IS NOT NULL
            AND source_started_at_ms IS NULL
            AND source_finished_at_ms IS NULL
            AND source_expires_at_ms IS NULL
            AND source_observed_at_ms IS NULL
            AND source_classified_at_ms IS NOT NULL)
        OR
        (row_kind = 'evidence-v1'
            AND primary_id GLOB 'evidence-?*'
            AND source_session_id IS NULL
            AND source_relative_path IS NULL
            AND source_snapshot_id IS NOT NULL
            AND source_snapshot_id GLOB 'snapshot-?*'
            AND source_disposition IS NULL
            AND source_started_at_ms IS NULL
            AND source_finished_at_ms IS NULL
            AND source_expires_at_ms IS NULL
            AND source_observed_at_ms IS NOT NULL
            AND source_classified_at_ms IS NULL)
        OR
        (row_kind = 'space-ledger-v1'
            AND primary_id GLOB 'scan-?*'
            AND source_session_id IS NOT NULL
            AND source_session_id = primary_id
            AND source_relative_path IS NULL
            AND source_snapshot_id IS NULL
            AND source_disposition IS NULL
            AND source_started_at_ms IS NULL
            AND source_finished_at_ms IS NULL
            AND source_expires_at_ms IS NULL
            AND source_observed_at_ms IS NULL
            AND source_classified_at_ms IS NULL)
    )
) STRICT;

CREATE TABLE investigation_relevance_tokens (
    investigation_id TEXT NOT NULL,
    ordinal INTEGER NOT NULL CHECK (ordinal BETWEEN 0 AND 255),
    token TEXT NOT NULL CHECK (
        length(CAST(token AS BLOB)) BETWEEN 1 AND 128
        AND token NOT GLOB '*[^A-Za-z0-9._-]*'
    ),
    PRIMARY KEY (investigation_id, ordinal),
    UNIQUE (investigation_id, token),
    FOREIGN KEY (investigation_id)
        REFERENCES investigation_sessions(id) ON DELETE CASCADE
        DEFERRABLE INITIALLY DEFERRED
) STRICT;
```

`STRICT` affinity plus the checks above distinguish TEXT/INTEGER/BLOB.
Task 37 must extend the internal SQLite binding layer with exact BLOB support;
hex text is not an allowed substitute for fingerprints or SHA-256.

Cross-row canonical order cannot be proved by a per-row `CHECK`. Before
commit and on every load, the Store verifies:

- row count equals `source_row_count`, ordinals are exactly `0..<count`, and
  no ordinal is missing;
- the SQL candidate order is
  `length(CAST(row_kind AS BLOB)), CAST(row_kind AS BLOB),
  length(CAST(primary_id AS BLOB)), CAST(primary_id AS BLOB)`;
- because `(row_kind, primary_id)` is unique and fields 1–2 precede all other
  `SourceRowV1` fields, that order is the only possible complete-row canonical
  order; Swift nevertheless encodes every adjacent complete row and verifies
  unsigned lexicographic increase;
- relevance count equals `relevance_token_count`, ordinals are contiguous,
  and order equals unsigned lexicographic complete encoded token bytes;
- checked sums equal both session byte-count columns and the source
  fingerprint recomputes exactly.

The remaining ownership tables use this normative minimum DDL:

```sql
CREATE TABLE investigation_targets (
    investigation_id TEXT NOT NULL,
    target_id TEXT NOT NULL CHECK (
        length(CAST(target_id AS BLOB)) = 71
        AND target_id GLOB 'target-?*'
        AND substr(target_id, 8) NOT GLOB '*[^0-9a-f]*'
    ),
    ordinal INTEGER NOT NULL CHECK (ordinal BETWEEN 0 AND 511),
    target_kind TEXT NOT NULL CHECK (target_kind IN (
        'unknown-large-consumer-v1', 'unexplained-space-gap-v1',
        'classification-conflict-v1', 'unknown-producer-v1',
        'stale-or-insufficient-evidence-v1'
    )),
    payload TEXT NOT NULL CHECK (
        length(CAST(payload AS BLOB)) BETWEEN 1 AND 65536
    ),
    PRIMARY KEY (investigation_id, target_id),
    UNIQUE (investigation_id, ordinal),
    FOREIGN KEY (investigation_id)
        REFERENCES investigation_sessions(id) ON DELETE CASCADE
        DEFERRABLE INITIALLY DEFERRED
) STRICT;

CREATE TABLE investigation_runs (
    investigation_id TEXT NOT NULL,
    run_id TEXT NOT NULL CHECK (
        length(CAST(run_id AS BLOB)) BETWEEN 19 AND 128
        AND run_id GLOB 'investigation-run-?*'
        AND run_id NOT GLOB '*[^A-Za-z0-9._-]*'
    ),
    run_ordinal INTEGER NOT NULL CHECK (run_ordinal BETWEEN 0 AND 15),
    target_set_fingerprint BLOB NOT NULL
        CHECK (length(target_set_fingerprint) = 32),
    plan_fingerprint BLOB NOT NULL
        CHECK (length(plan_fingerprint) = 32),
    plan_json TEXT NOT NULL
        CHECK (length(CAST(plan_json AS BLOB)) BETWEEN 1 AND 4194304),
    budget_preset TEXT NOT NULL
        CHECK (budget_preset IN ('focused', 'balanced', 'thorough')),
    plan_created_at_ms INTEGER NOT NULL,
    plan_expires_at_ms INTEGER NOT NULL
        CHECK (plan_expires_at_ms > plan_created_at_ms),
    target_count INTEGER NOT NULL CHECK (target_count BETWEEN 1 AND 512),
    parent_run_id TEXT,
    parent_report_id TEXT,
    parent_report_kind TEXT GENERATED ALWAYS AS (
        CASE WHEN parent_report_id IS NULL THEN NULL ELSE 'partial' END
    ) STORED,
    state TEXT NOT NULL CHECK (state IN (
        'planned', 'awaitingDisclosure', 'ready', 'running',
        'pauseRequested', 'stopRequested', 'terminalBarrier',
        'completed', 'partial', 'blocked', 'failed'
    )),
    stage TEXT NOT NULL CHECK (
        stage IN ('prioritize', 'identify', 'verify', 'buildPlan')
    ),
    terminal_cause TEXT CHECK (
        terminal_cause IS NULL OR (
            length(CAST(terminal_cause AS BLOB)) BETWEEN 1 AND 128
            AND terminal_cause NOT GLOB '*[^A-Za-z0-9._-]*'
        )
    ),
    terminal_report_id TEXT CHECK (
        terminal_report_id IS NULL OR (
            length(CAST(terminal_report_id AS BLOB)) BETWEEN 22 AND 128
            AND terminal_report_id GLOB 'investigation-report-?*'
            AND terminal_report_id NOT GLOB '*[^A-Za-z0-9._-]*'
        )
    ),
    budget_event_count INTEGER NOT NULL DEFAULT 0
        CHECK (budget_event_count BETWEEN 0 AND 4096),
    budget_payload_byte_count INTEGER NOT NULL DEFAULT 0
        CHECK (budget_payload_byte_count BETWEEN 0 AND 4194304),
    expected_report_kind TEXT GENERATED ALWAYS AS (
        CASE state
            WHEN 'completed' THEN 'final'
            WHEN 'partial' THEN 'partial'
            ELSE NULL
        END
    ) STORED,
    created_at_ms INTEGER NOT NULL,
    updated_at_ms INTEGER NOT NULL,
    terminal_at_ms INTEGER,
    payload TEXT NOT NULL CHECK (
        length(CAST(payload AS BLOB)) BETWEEN 1 AND 1048576
    ),
    PRIMARY KEY (investigation_id, run_id),
    UNIQUE (investigation_id, run_ordinal),
    UNIQUE (
        investigation_id, terminal_report_id, run_id, expected_report_kind
    ),
    FOREIGN KEY (investigation_id)
        REFERENCES investigation_sessions(id) ON DELETE CASCADE
        DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY (
        investigation_id, parent_report_id, parent_run_id, parent_report_kind
    ) REFERENCES investigation_reports(
        investigation_id, report_id, run_id, report_kind
    ) ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY (
        investigation_id, terminal_report_id, run_id, expected_report_kind
    ) REFERENCES investigation_reports(
        investigation_id, report_id, run_id, report_kind
    ) ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED,
    CHECK (
        (parent_run_id IS NULL AND parent_report_id IS NULL)
        OR
        (parent_run_id IS NOT NULL AND parent_report_id IS NOT NULL
            AND parent_run_id <> run_id)
    ),
    CHECK (
        (state IN ('completed', 'partial', 'blocked', 'failed')
            AND terminal_at_ms IS NOT NULL)
        OR
        (state NOT IN ('completed', 'partial', 'blocked', 'failed')
            AND terminal_at_ms IS NULL)
    ),
    CHECK (
        (state IN ('completed', 'partial')
            AND terminal_report_id IS NOT NULL)
        OR
        (state NOT IN ('completed', 'partial')
            AND terminal_report_id IS NULL)
    )
) STRICT;

CREATE TABLE investigation_run_targets (
    investigation_id TEXT NOT NULL,
    run_id TEXT NOT NULL,
    ordinal INTEGER NOT NULL CHECK (ordinal BETWEEN 0 AND 511),
    target_id TEXT NOT NULL,
    PRIMARY KEY (investigation_id, run_id, ordinal),
    UNIQUE (investigation_id, run_id, target_id),
    FOREIGN KEY (investigation_id, run_id)
        REFERENCES investigation_runs(investigation_id, run_id)
        ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY (investigation_id, target_id)
        REFERENCES investigation_targets(investigation_id, target_id)
        ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY (investigation_id)
        REFERENCES investigation_sessions(id) ON DELETE CASCADE
        DEFERRABLE INITIALLY DEFERRED
) STRICT;

CREATE TABLE investigation_reports (
    investigation_id TEXT NOT NULL,
    report_id TEXT NOT NULL CHECK (
        length(CAST(report_id AS BLOB)) BETWEEN 22 AND 128
        AND report_id GLOB 'investigation-report-?*'
        AND report_id NOT GLOB '*[^A-Za-z0-9._-]*'
    ),
    run_id TEXT NOT NULL,
    report_kind TEXT NOT NULL CHECK (report_kind IN ('final', 'partial')),
    created_at_ms INTEGER NOT NULL,
    evidence_row_count INTEGER NOT NULL
        CHECK (evidence_row_count BETWEEN 0 AND 512),
    evidence_payload_byte_count INTEGER NOT NULL
        CHECK (evidence_payload_byte_count BETWEEN 0 AND 8388608),
    degradation_row_count INTEGER NOT NULL
        CHECK (degradation_row_count BETWEEN 0 AND 64),
    degradation_payload_byte_count INTEGER NOT NULL
        CHECK (degradation_payload_byte_count BETWEEN 0 AND 524288),
    payload TEXT NOT NULL CHECK (
        length(CAST(payload AS BLOB)) BETWEEN 1 AND 1048576
    ),
    PRIMARY KEY (investigation_id, report_id),
    UNIQUE (investigation_id, run_id),
    UNIQUE (investigation_id, report_id, run_id),
    UNIQUE (investigation_id, report_id, run_id, report_kind),
    FOREIGN KEY (investigation_id, report_id, run_id, report_kind)
        REFERENCES investigation_runs(
            investigation_id, terminal_report_id, run_id, expected_report_kind
        ) ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY (investigation_id)
        REFERENCES investigation_sessions(id) ON DELETE CASCADE
        DEFERRABLE INITIALLY DEFERRED
) STRICT;

CREATE TABLE investigation_evidence (
    investigation_id TEXT NOT NULL,
    report_id TEXT NOT NULL,
    run_id TEXT NOT NULL,
    target_id TEXT NOT NULL,
    evidence_id TEXT NOT NULL CHECK (
        length(CAST(evidence_id AS BLOB)) BETWEEN 24 AND 128
        AND evidence_id GLOB 'investigation-evidence-?*'
        AND evidence_id NOT GLOB '*[^A-Za-z0-9._-]*'
    ),
    ordinal INTEGER NOT NULL CHECK (ordinal BETWEEN 0 AND 511),
    evidence_kind TEXT NOT NULL CHECK (evidence_kind IN (
        'finding', 'proposal', 'counter-evidence', 'unresolved'
    )),
    payload TEXT NOT NULL CHECK (
        length(CAST(payload AS BLOB)) BETWEEN 1 AND 65536
    ),
    PRIMARY KEY (investigation_id, report_id, evidence_id),
    UNIQUE (investigation_id, report_id, ordinal),
    FOREIGN KEY (investigation_id, report_id, run_id)
        REFERENCES investigation_reports(investigation_id, report_id, run_id)
        ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY (investigation_id, run_id, target_id)
        REFERENCES investigation_run_targets(
            investigation_id, run_id, target_id
        )
        ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY (investigation_id)
        REFERENCES investigation_sessions(id) ON DELETE CASCADE
        DEFERRABLE INITIALLY DEFERRED
) STRICT;

CREATE TABLE investigation_report_degradations (
    investigation_id TEXT NOT NULL,
    report_id TEXT NOT NULL,
    run_id TEXT NOT NULL,
    degradation_id TEXT NOT NULL CHECK (
        length(CAST(degradation_id AS BLOB)) BETWEEN 27 AND 128
        AND degradation_id GLOB 'investigation-degradation-?*'
        AND degradation_id NOT GLOB '*[^A-Za-z0-9._-]*'
    ),
    ordinal INTEGER NOT NULL CHECK (ordinal BETWEEN 0 AND 63),
    degradation_kind TEXT NOT NULL CHECK (degradation_kind IN (
        'usage-unavailable', 'capability-unavailable',
        'source-limited', 'runtime-limited'
    )),
    payload TEXT NOT NULL CHECK (
        length(CAST(payload AS BLOB)) BETWEEN 1 AND 16384
    ),
    PRIMARY KEY (investigation_id, report_id, degradation_id),
    UNIQUE (investigation_id, report_id, ordinal),
    FOREIGN KEY (investigation_id, report_id, run_id)
        REFERENCES investigation_reports(investigation_id, report_id, run_id)
        ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY (investigation_id)
        REFERENCES investigation_sessions(id) ON DELETE CASCADE
        DEFERRABLE INITIALLY DEFERRED
) STRICT;

CREATE TABLE investigation_budget_events (
    investigation_id TEXT NOT NULL,
    run_id TEXT NOT NULL,
    event_id TEXT NOT NULL CHECK (
        length(CAST(event_id AS BLOB)) BETWEEN 28 AND 128
        AND event_id GLOB 'investigation-budget-event-?*'
        AND event_id NOT GLOB '*[^A-Za-z0-9._-]*'
    ),
    ordinal INTEGER NOT NULL CHECK (ordinal BETWEEN 0 AND 4095),
    event_kind TEXT NOT NULL CHECK (event_kind IN (
        'reservation', 'commit', 'release', 'direct-tool-observation',
        'token-observation', 'usage-unavailable', 'evidence-gain',
        'no-evidence-gain', 'stop-evaluation', 'terminal-summary'
    )),
    payload TEXT NOT NULL CHECK (
        length(CAST(payload AS BLOB)) BETWEEN 1 AND 16384
    ),
    PRIMARY KEY (investigation_id, run_id, event_id),
    UNIQUE (investigation_id, run_id, ordinal),
    FOREIGN KEY (investigation_id, run_id)
        REFERENCES investigation_runs(investigation_id, run_id)
        ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED,
    FOREIGN KEY (investigation_id)
        REFERENCES investigation_sessions(id) ON DELETE CASCADE
        DEFERRABLE INITIALLY DEFERRED
) STRICT;

CREATE TRIGGER investigation_runs_quota
BEFORE INSERT ON investigation_runs
WHEN (
    SELECT count(*) FROM investigation_runs
    WHERE investigation_id = NEW.investigation_id
) >= 16
BEGIN
    SELECT RAISE(ABORT, 'investigation run quota exceeded');
END;

CREATE TRIGGER investigation_evidence_quota
BEFORE INSERT ON investigation_evidence
WHEN
    (
        SELECT count(*) FROM investigation_evidence
        WHERE investigation_id = NEW.investigation_id
          AND report_id = NEW.report_id
    ) >= 512
    OR
    COALESCE((
        SELECT sum(length(CAST(payload AS BLOB)))
        FROM investigation_evidence
        WHERE investigation_id = NEW.investigation_id
          AND report_id = NEW.report_id
    ), 0) + length(CAST(NEW.payload AS BLOB)) > 8388608
    OR
    COALESCE((
        SELECT sum(length(CAST(payload AS BLOB)))
        FROM investigation_evidence
        WHERE investigation_id = NEW.investigation_id
    ), 0) + length(CAST(NEW.payload AS BLOB)) > 67108864
BEGIN
    SELECT RAISE(ABORT, 'investigation evidence quota exceeded');
END;

CREATE TRIGGER investigation_degradation_quota
BEFORE INSERT ON investigation_report_degradations
WHEN
    (
        SELECT count(*) FROM investigation_report_degradations
        WHERE investigation_id = NEW.investigation_id
          AND report_id = NEW.report_id
    ) >= 64
    OR
    COALESCE((
        SELECT sum(length(CAST(payload AS BLOB)))
        FROM investigation_report_degradations
        WHERE investigation_id = NEW.investigation_id
          AND report_id = NEW.report_id
    ), 0) + length(CAST(NEW.payload AS BLOB)) > 524288
    OR
    COALESCE((
        SELECT sum(length(CAST(payload AS BLOB)))
        FROM investigation_report_degradations
        WHERE investigation_id = NEW.investigation_id
    ), 0) + length(CAST(NEW.payload AS BLOB)) > 4194304
BEGIN
    SELECT RAISE(ABORT, 'investigation degradation quota exceeded');
END;

CREATE TRIGGER investigation_budget_quota
BEFORE INSERT ON investigation_budget_events
WHEN
    (
        SELECT count(*) FROM investigation_budget_events
        WHERE investigation_id = NEW.investigation_id
          AND run_id = NEW.run_id
    ) >= 4096
    OR
    COALESCE((
        SELECT sum(length(CAST(payload AS BLOB)))
        FROM investigation_budget_events
        WHERE investigation_id = NEW.investigation_id
          AND run_id = NEW.run_id
    ), 0) + length(CAST(NEW.payload AS BLOB)) > 4194304
    OR
    COALESCE((
        SELECT sum(length(CAST(payload AS BLOB)))
        FROM investigation_budget_events
        WHERE investigation_id = NEW.investigation_id
    ), 0) + length(CAST(NEW.payload AS BLOB)) > 33554432
BEGIN
    SELECT RAISE(ABORT, 'investigation budget quota exceeded');
END;

CREATE TRIGGER investigation_source_rows_owner_delete_only
BEFORE DELETE ON investigation_source_rows
WHEN EXISTS (
    SELECT 1 FROM investigation_sessions WHERE id = OLD.investigation_id
)
BEGIN
    SELECT RAISE(ABORT, 'whole investigation delete required');
END;

CREATE TRIGGER investigation_relevance_tokens_owner_delete_only
BEFORE DELETE ON investigation_relevance_tokens
WHEN EXISTS (
    SELECT 1 FROM investigation_sessions WHERE id = OLD.investigation_id
)
BEGIN
    SELECT RAISE(ABORT, 'whole investigation delete required');
END;

CREATE TRIGGER investigation_targets_owner_delete_only
BEFORE DELETE ON investigation_targets
WHEN EXISTS (
    SELECT 1 FROM investigation_sessions WHERE id = OLD.investigation_id
)
BEGIN
    SELECT RAISE(ABORT, 'whole investigation delete required');
END;

CREATE TRIGGER investigation_runs_owner_delete_only
BEFORE DELETE ON investigation_runs
WHEN EXISTS (
    SELECT 1 FROM investigation_sessions WHERE id = OLD.investigation_id
)
BEGIN
    SELECT RAISE(ABORT, 'whole investigation delete required');
END;

CREATE TRIGGER investigation_run_targets_owner_delete_only
BEFORE DELETE ON investigation_run_targets
WHEN EXISTS (
    SELECT 1 FROM investigation_sessions WHERE id = OLD.investigation_id
)
BEGIN
    SELECT RAISE(ABORT, 'whole investigation delete required');
END;

CREATE TRIGGER investigation_reports_owner_delete_only
BEFORE DELETE ON investigation_reports
WHEN EXISTS (
    SELECT 1 FROM investigation_sessions WHERE id = OLD.investigation_id
)
BEGIN
    SELECT RAISE(ABORT, 'whole investigation delete required');
END;

CREATE TRIGGER investigation_evidence_owner_delete_only
BEFORE DELETE ON investigation_evidence
WHEN EXISTS (
    SELECT 1 FROM investigation_sessions WHERE id = OLD.investigation_id
)
BEGIN
    SELECT RAISE(ABORT, 'whole investigation delete required');
END;

CREATE TRIGGER investigation_degradations_owner_delete_only
BEFORE DELETE ON investigation_report_degradations
WHEN EXISTS (
    SELECT 1 FROM investigation_sessions WHERE id = OLD.investigation_id
)
BEGIN
    SELECT RAISE(ABORT, 'whole investigation delete required');
END;

CREATE TRIGGER investigation_budget_owner_delete_only
BEFORE DELETE ON investigation_budget_events
WHEN EXISTS (
    SELECT 1 FROM investigation_sessions WHERE id = OLD.investigation_id
)
BEGIN
    SELECT RAISE(ABORT, 'whole investigation delete required');
END;

CREATE TRIGGER investigation_source_rows_immutable
BEFORE UPDATE ON investigation_source_rows
BEGIN
    SELECT RAISE(ABORT, 'immutable investigation row');
END;

CREATE TRIGGER investigation_relevance_tokens_immutable
BEFORE UPDATE ON investigation_relevance_tokens
BEGIN
    SELECT RAISE(ABORT, 'immutable investigation row');
END;

CREATE TRIGGER investigation_targets_immutable
BEFORE UPDATE ON investigation_targets
BEGIN
    SELECT RAISE(ABORT, 'immutable investigation row');
END;

CREATE TRIGGER investigation_run_targets_immutable
BEFORE UPDATE ON investigation_run_targets
BEGIN
    SELECT RAISE(ABORT, 'immutable investigation row');
END;

CREATE TRIGGER investigation_reports_immutable
BEFORE UPDATE ON investigation_reports
BEGIN
    SELECT RAISE(ABORT, 'immutable investigation row');
END;

CREATE TRIGGER investigation_evidence_immutable
BEFORE UPDATE ON investigation_evidence
BEGIN
    SELECT RAISE(ABORT, 'immutable investigation row');
END;

CREATE TRIGGER investigation_degradations_immutable
BEFORE UPDATE ON investigation_report_degradations
BEGIN
    SELECT RAISE(ABORT, 'immutable investigation row');
END;

CREATE TRIGGER investigation_budget_immutable
BEFORE UPDATE ON investigation_budget_events
BEGIN
    SELECT RAISE(ABORT, 'immutable investigation row');
END;

CREATE TRIGGER investigation_sessions_immutable_source
BEFORE UPDATE ON investigation_sessions
WHEN
    NEW.id IS NOT OLD.id
    OR NEW.scan_session_id IS NOT OLD.scan_session_id
    OR NEW.scan_scope_id IS NOT OLD.scan_scope_id
    OR NEW.source_fingerprint IS NOT OLD.source_fingerprint
    OR NEW.source_row_count IS NOT OLD.source_row_count
    OR NEW.relevance_token_count IS NOT OLD.relevance_token_count
    OR NEW.source_payload_byte_count IS NOT OLD.source_payload_byte_count
    OR NEW.source_canonical_byte_count IS NOT OLD.source_canonical_byte_count
    OR NEW.created_at_ms IS NOT OLD.created_at_ms
    OR NEW.expires_at_ms IS NOT OLD.expires_at_ms
BEGIN
    SELECT RAISE(ABORT, 'immutable investigation source');
END;

CREATE TRIGGER investigation_runs_immutable_plan
BEFORE UPDATE ON investigation_runs
WHEN
    NEW.investigation_id IS NOT OLD.investigation_id
    OR NEW.run_id IS NOT OLD.run_id
    OR NEW.run_ordinal IS NOT OLD.run_ordinal
    OR NEW.target_set_fingerprint IS NOT OLD.target_set_fingerprint
    OR NEW.plan_fingerprint IS NOT OLD.plan_fingerprint
    OR NEW.plan_json IS NOT OLD.plan_json
    OR NEW.budget_preset IS NOT OLD.budget_preset
    OR NEW.plan_created_at_ms IS NOT OLD.plan_created_at_ms
    OR NEW.plan_expires_at_ms IS NOT OLD.plan_expires_at_ms
    OR NEW.target_count IS NOT OLD.target_count
    OR NEW.parent_run_id IS NOT OLD.parent_run_id
    OR NEW.parent_report_id IS NOT OLD.parent_report_id
    OR NEW.created_at_ms IS NOT OLD.created_at_ms
    OR NEW.payload IS NOT OLD.payload
BEGIN
    SELECT RAISE(ABORT, 'immutable investigation run plan');
END;
```

Only direct ownership foreign keys to `investigation_sessions` use
`ON DELETE CASCADE`. Lineage, terminal-report, report/evidence/target and
run/budget relationships use `ON DELETE NO ACTION DEFERRABLE INITIALLY
DEFERRED`. This permits one transactional whole-Investigation delete because
all owned rows are removed together, but rejects direct deletion of a report,
run or target that would erase terminal truth or continuation descendants.
Run parent IDs must differ from the child run ID. Payload columns are strict
`TEXT`, byte-bounded with `length(CAST(payload AS BLOB))`, and
byte-identically strict-decode/re-encode. Target/report/evidence/budget IDs,
closed kind/state/cause fields, payload limits and timestamp columns are
separately verified by typed Store admission and schema-verification tests.
No globally keyed child row is accepted without its same-Investigation
composite owner.

The DDL independently enforces row-local identity, shape, ownership, foreign
keys, immutable child rows, direct-child deletion denial and insert quotas. In
particular, evidence must reference the exact same-run target membership. The
DDL does not claim to enforce decoded Plan membership completeness/order,
aggregate-counter equality or lifecycle transitions by itself.

Every product connection is created only inside the private
`EvidenceStore`/`SQLiteConnection` owner. No database handle, generic SQL
execution API, prepared-statement factory or mutable connection escapes that
owner. Immediately after open and before any schema or product statement, the
owner:

- enables `SQLITE_DBCONFIG_DEFENSIVE`, `foreign_keys=ON` and
  `trusted_schema=OFF`;
- installs a deny-by-default `sqlite3_set_authorizer`;
- defaults the authorizer to deny every `INSERT`, `UPDATE`, `DELETE`, schema
  mutation, `ATTACH`, `DETACH`, writable-schema action and extension-loading
  path involving Investigation data;
- permits one private migration mode only for the exact v4 migration
  statements;
- permits one private typed-operation mode only while preparing fixed,
  source-constant SQL for a closed operation enum. Each mode allowlists exact
  action/table/update-column triples and returns to deny-all before binding or
  stepping;
- rejects nested mode entry, arbitrary SQL text, statement preparation outside
  the owner and any authorizer callback not explicitly allowed.

The typed-operation mode is not a bearer capability and cannot escape its
non-async preparation closure. The actor serializes mode changes. Prepared
statements are finalized before mode exit or retained only by the private
operation object that created them; callers can bind typed values but cannot
change SQL. Structural verification rejects public/internal generic
`execute(sql:)`, raw connection access and Investigation SQL outside the
closed persistence file.

This boundary prevents product code from bypassing the Store verifier with raw
SQL. A separate same-user process can still tamper with a user-owned SQLite
file; authorizer is not an OS containment claim. Every reopen and every
Investigation transaction therefore verifies application/schema identity,
integrity, foreign keys and the relevant cross-row invariants, and classifies
external mutation as corrupt rather than repairing or trusting it.

The Store API and transaction pre-commit verifier enforce:

- at most `16` runs per Investigation;
- exactly `1...512` contiguous ordered target memberships per run, matching
  the strict decoded run-owned Plan and `target_count`;
- at most `512` target-scoped evidence rows and `8 MiB` aggregate
  target-scoped evidence payload per report;
- at most `64` report-scoped degradation rows and `512 KiB` aggregate
  degradation payload per report;
- at most `4,096` aggregate budget events and `4 MiB` aggregate budget-event
  payload per run;
- at most `64 MiB` target-scoped evidence, `4 MiB` degradation payload and
  `32 MiB` budget-event payload across one Investigation.

The report/run count/byte columns are immutable terminal accounting for their
owner. The session aggregate columns are updated only in the same insertion,
budget or terminal transaction. Every value must equal checked
`COUNT`/`SUM(length(CAST(payload AS BLOB)))` queries over all owned rows before
commit. The Store transaction API refuses commit if a counter is stale even
when it remains numerically within its `CHECK` range. Overflow rejects
atomically; it is never truncated.
These quotas are Store ceilings, not authority to exceed the lower strict
Envelope v2 limits (`512` evidence references, `256` findings, `256`
proposals) or the selected runtime budget.

The quota triggers independently reject direct-SQL maxima before insertion.
The owner-delete triggers reject every direct child delete while the owning
session exists. During the one allowed session delete, SQLite removes the
parent first and then cascades all children, so those triggers permit only
that owner-driven operation. Migration tests execute both direct-delete
rejection and full-session cascade against the actual extracted DDL.
Identity/payload child rows are insert-only: immutable-update triggers reject
direct SQL changes that could bypass insert quotas or fingerprint/cardinality
checks. Session source identity/retention and run Plan/lineage identity have
separate immutable-column triggers. The remaining
`investigation_sessions` aggregate state/counters/`updated_at_ms` and
`investigation_runs` state/stage/terminal/counter/`updated_at_ms` fields are
mutable only because atomic product transitions require them; the private
authorizer allows exact columns only for the corresponding typed Store
operation. That operation revalidates immutable Plan/identity bytes, legal
state transition and all aggregate queries before commit. DDL-only tests must
not be described as proving those cross-row or lifecycle invariants.

### 3.4 Session and run state

Persist separate closed typed state sets selected by the Task 36 domain and
Phase D plan.

Run states:

- planned;
- awaitingDisclosure;
- ready;
- running;
- pauseRequested;
- stopRequested;
- terminalBarrier;
- completed;
- partial;
- blocked;
- failed.

Session aggregate states use the same set plus `paused`. Pause terminalizes the
current run as `partial` with exactly one partial report, then updates the
owning session aggregate to `paused` in the same transaction. No
`investigation_runs.state` row may contain `paused`.

Cancellation has no persisted `cancelRequested`/`cancelled` state. At the
first accepted cancel fact the actor enters `terminalBarrier` with immutable
typed `userCancelled` primary cause; successful drain/commit produces
canonical `partial`. Store v4 rejects standalone `cancelRequested` and
`cancelled` states.

Task 37 persists state; it does not implement the Task 38 reducer. Illegal
transitions, terminal-to-running regression, duplicate terminal report
identity and report replacement are rejected by Store admission APIs.

Run terminal cardinality is exact:

- `completed` run → exactly one `final` report;
- `partial` run, including pause/user cancellation → exactly one `partial`
  report;
- `blocked` or `failed` run → zero reports and zero promoted evidence;
- a Store failure too severe to durably record `failed` leaves the prior
  nonterminal row for crash recovery and exposes only in-memory failed truth;
  it never fabricates a report.

Session `paused` is aggregate state over a terminal partial run and a possible
future continuation; it is not a second report kind. Unique run/report keys
and terminal transaction checks enforce these counts on first commit and
idempotent replay.

## 4. Immutable Source Manifest and Rejoin

### 4.1 Manifest contents

The persisted source projection is exactly the Task 36 canonical
`SourceProjectionV1`:

- one terminal `scan-session-v1` row;
- one complete `space-ledger-v1` row;
- exhaustive selected-scope `path-snapshot-v1` rows;
- exhaustive selected-scope `classification-v1` rows;
- exhaustive selected-scope `evidence-v1` rows;
- exact non-payload SQLite identity columns;
- exact UTF-8 payload byte count and SHA-256;
- bounded relevance tokens.

No top-N, sampling, silent truncation or later best-effort reconstruction is
allowed. The normative bounds remain:

- snapshots: at most `100_000`;
- classifications: at most `100_000`;
- evidence: at most `100_000`;
- evidence per snapshot: at most `100`;
- total rows: at most `300_002`;
- relevance tokens: at most `256`;
- ordinary payload: at most `1 MiB`;
- strict Task 36 canonical Investigation Plan binary identity: at most
  `2 MiB`;
- strict persisted Investigation Plan `DomainJSON`: at most `4 MiB`;
- Space Ledger payload: at most `16 MiB`;
- aggregate exact source payload: at most `256 MiB`;
- complete canonical SourceProjection digest input: at most `512 MiB`.

Overflow blocks planning/persistence with a typed error. It never produces a
partial fingerprint presented as complete.

The 2 MiB canonical and 4 MiB persisted-JSON allowances are independent and
role-specific to the exact strict Plan record. They do not raise the generic
1 MiB Investigation payload limit. Task 37 verifies each representation
against its own bound; a Plan that fits one but not the other is rejected.
The source-row manifest and relevance tokens remain normalized rows and do not
consume the generic aggregate-payload allowance as one synthetic payload.

### 4.2 Store-owned recomputation

`EvidenceStore` exposes one closed source-rejoin service that:

1. starts one Store-owned `BEGIN IMMEDIATE` transaction on the serialized
   `EvidenceStore` connection before reading either current source or persisted
   manifest;
2. loads session/scope/fingerprint/count identities from
   `investigation_sessions` by typed `InvestigationID`;
3. streams persisted normalized manifest rows in exact ordinal order and
   current source rows in canonical candidate order from that one pinned
   SQLite snapshot;
4. validates each current identity column, strict-decodes one payload,
   byte-identically re-encodes `DomainJSON`, computes row metadata/digest, then
   releases that payload before advancing;
5. compares each streamed row with the persisted normalized row and verifies
   exact membership, counts, canonical order, checked byte totals and
   relevance tokens;
6. incrementally recomputes the complete source fingerprint without building
   a full manifest/payload/canonical buffer;
7. commits the read-only transaction only after the typed result is complete,
   or keeps the same transaction open for insertion/terminal write commit.

Rejoin callers supply only a typed `InvestigationID` and one closed
`InvestigationRejoinBarrier` enum value. They cannot supply retained IDs,
expected manifest rows/fingerprint, a caller-computed “verified” boolean or a
source cursor.

Initial creation is one Store-owned `createInvestigation` operation. Its public
command contains only caller-created Investigation ID and initial run ID,
typed retained Scan session/scope IDs, budget preset, injected planning time
and bounded relevance tokens. It contains no Plan, target, source row, cursor,
digest or freshness field. Inside one `BEGIN IMMEDIATE` transaction,
`EvidenceStore`:

1. creates an actor-confined production cursor factory over the pinned source;
2. invokes the pure Task 36 `InvestigationCandidatePlanner`;
3. if the Planner returns zero targets, rolls the transaction back and returns
   typed `noEligibleTargets`; no session/run/manifest row persists;
4. verifies the non-empty Plan's source fingerprint against that same cursor
   generation;
5. inserts session, normalized source/relevance rows, targets, initial
   run-owned Plan and ordered run-target membership through reused prepared
   statements;
6. re-verifies counts, canonical order, fingerprints and foreign keys before
   commit.

The cursor factory and cursors are non-escaping closure arguments and are
invalid after the transaction closure returns. No Store API returns them.

`BEGIN IMMEDIATE` is deliberate: it pins one snapshot and serializes against
retention, exact deletion and source mutations for the full bounded rejoin.
No source or manifest query may escape that transaction. For terminal
normalization, recovery promotion, continuation construction and insertion,
the verification and owned writes/commit occur in that same transaction, so
source mutation cannot occur between “matching” and durable truth. Read-only
Review projection uses a matching result only in the returned transaction
scope to materialize its bounded DTO; no reusable freshness token escapes.

Every full-size Store operation has one injected monotonic deadline and
cancellation source. The closed v4 policy is:

- `sqlite3_busy_timeout` is at most `2,000 ms`; failure to acquire the writer
  lock returns typed `storeBusy` and starts no work;
- insertion, rejoin, terminal commit, recovery promotion and continuation
  each have a hard `90` monotonic-second deadline, independently of wall
  calendar and the Investigation/model budget;
- a SQLite progress handler checks cancellation/deadline at most every
  `1,000` virtual-machine instructions, and Swift checks again before every
  source payload decode and prepared-statement step;
- typed ephemeral progress reports phase, checked rows and bytes at least
  every `1,024` rows or `16 MiB`; it persists nothing and grants no authority;
- cancellation/deadline interrupts SQLite, stops requesting source rows and
  rolls the transaction back; no partial manifest, report, counter or terminal
  state may become visible;
- the API does not return until rollback/connection close is complete. If
  cleanup cannot be proved within a separate `5` monotonic-second cleanup
  window, the connection is quarantined, Store health becomes
  `rollbackUnconfirmed`, and all new Scan/Investigation/retention/execution
  mutations fail closed until reopen + `integrity_check` +
  `foreign_key_check` succeed;
- no automatic retry occurs after busy, cancellation, timeout or unconfirmed
  rollback.

The 90-second ceiling remains a denial bound only if Task 37 first supplies
fresh maximum-size Store evidence. Before implementation admission, one
Release-build benchmark on the supported Apple Silicon machine creates
generated, noncompressible fixtures at every applicable maximum and measures
three serial samples of each complete operation:

1. initial Store-owned planning plus 300,002-row / 256 MiB source insertion
   and 512 MiB canonical hash stream;
2. unchanged eight-barrier rejoin over that maximum source;
3. maximum terminal transaction with 512 evidence rows / 8 MiB, 64
   degradations / 512 KiB and the admitted run budget-event ceiling;
4. crash-recovery verification and promotion of the same maximum retained
   shape;
5. continuation construction with a verified partial parent and a new
   512-target run-owned Plan.

Each timing begins before lock acquisition/source cursor creation and ends
only after commit plus integrity/foreign-key/cross-row verification. Fixture
generation is excluded, but decode, both source passes, hashing, SQLite
binding/stepping and verification are included. The maximum of all fifteen
samples must be at most 75 monotonic seconds, preserving at least 15 seconds
of measured margin below the 90-second deadline. The report records machine,
build, database/journal settings, fixture hashes, per-sample timings, peak
resident memory and database size.

If any sample exceeds 75 seconds or the operation cannot remain within the
Task 36 memory contract, Task 37 is `capacityBlocked`: stop, retain production
Deep Dive as unavailable and revise the size/deadline contract through the
ADR and user review. The implementation may not raise the deadline, weaken
source limits, silently truncate, retry or split one identity decision across
snapshots to pass.

The service returns a typed result:

- `matching`;
- `stale` for valid source membership/content drift;
- `corrupt` for decode, identity, canonical or Store integrity failure;
- `expired` for retention expiry;
- `missing` for absent required records.

IDs matching while bytes or membership differ is never accepted.

### 4.3 Eight normative barriers

Task 37 implements or exposes an API that is invoked at all eight barriers:

1. Investigation insertion;
2. Task 38 runtime admission immediately before ephemeral `thread/start`;
3. explicit active-run refresh;
4. terminal advisory normalization before report/session atomic commit;
5. crash recovery before a partial report is promoted;
6. continuation creation;
7. Task 40 Review projection;
8. Agent proposal to existing `CleanupPlanBuilder` join.

Task 37 directly tests insertion, refresh, terminal commit, recovery and
continuation. Tasks 38 and 40 must later prove they call the same API at their
owned barriers. No duplicate rejoin implementation is allowed.

## 5. Persistence Contracts

### 5.1 Insert Investigation

One transaction plans and inserts:

- session identity and source bindings;
- complete normalized source rows and relevance-token rows;
- source/target-set/plan fingerprints;
- exact initial run-owned strict Plan JSON within the independent 4 MiB bound;
- exact run-owned budget limits and stop policy;
- all admitted targets in deterministic order;
- exact initial session/run/report/evidence/degradation/budget count and byte
  counters, including one initial run;
- creation/expiry timestamps.

The Store computes the Plan and source projection from its own pinned rows.
The transaction rejects:

- expired/non-terminal source Scan;
- any source mismatch;
- legacy v1 target;
- duplicate target/source identity;
- plan/fingerprint mismatch;
- bounds violation;
- empty Planner output, returned as typed `noEligibleTargets` after complete
  rollback rather than a persisted zero-target run;
- unknown schema/token/state;
- insertion over an existing non-identical Investigation ID.

An exact idempotent replay may return the existing record without mutation.
A conflicting replay fails. The insertion path uses one prepared source-row
statement and one prepared relevance-token statement, resets/binds/steps each
row, and never accumulates a 300,002-row bindings array. It verifies canonical
order and checked count/byte totals before commit. On rollback, no session,
normalized row, target or run residue remains.

Continuation is a separate Store-owned transaction accepting only typed
Investigation ID, verified parent run/report IDs, new caller-created run ID,
selected closed budget preset and injected planning time. After the
continuation rejoin returns `matching`, Store builds a new strict Plan from
the retained unresolved target subset, inserts the new run-owned Plan and
ordered membership, and preserves the parent Plan unchanged. It cannot accept
a caller Plan, target array, fingerprint or freshness token.

### 5.2 Budget events

Persist normalized typed aggregate budget events only:

- hard reservation/commit/release facts;
- identity-bound observed direct-tool count;
- identity-bound observed token total or typed unavailable;
- verified gain/no-gain transition;
- stop evaluation;
- terminal accounting summary.

Do not persist raw App Server events, model prose, prompts, stdout/stderr,
tool arguments, file content, response bodies or hidden reasoning.

Event keys and serial coordinator ordinals reject conflicting replay.
Equal replay is a no-op. Counters cannot decrease or overflow.

### 5.3 Terminal transaction

The App-internal coordinator obtains one typed `InvestigationReportID` from
its injected ID provider when it first constructs a completed/partial terminal
command. The typed terminal API accepts that ID only for completed/partial;
blocked/failed commands must omit it. UI, Codex/model output, runtime events
and Store payloads cannot supply or rewrite the ID. The coordinator retains
the same terminal command, including report ID, for retry/recovery; it does
not allocate a new ID per attempt.

One transaction must atomically:

- rejoin the complete current source manifest;
- validate terminal run/session identity;
- for completed/partial only, insert exactly one immutable final/partial
  report plus bounded normalized evidence/proposals/degradations;
- for blocked/failed, insert no report and no promoted evidence;
- insert the terminal budget summary;
- update session/run terminal state, stage, stop/failure reason and
  continuation eligibility;
- preserve the previous valid state if any operation fails.

A report payload cannot be updated or replaced. Exact idempotent replay
requires the same Investigation/run/report IDs, report kind, terminal cause,
budget summary and byte-identical report/evidence/degradation payloads. A
different report ID for an already-terminal run is a conflicting replay and
fails without mutation.
Blocked/failed replay proves the same zero-report outcome and identical run
state/cause/budget summary. No report or terminal run state becomes visible
before the transaction commits.

Task 37 provides the transaction API. Task 38 later owns when it is called.

## 6. Persisted Web Provenance

### 6.1 Closed representation

No public Store API accepts `URL` or arbitrary URL `String`. It accepts only a
validated `PersistedWebProvenance` created by the canonical v1 parser.

The only persisted accepted origin form is:

```text
https://<lowercase-ASCII-public-DNS-host>/
```

Accepted origins:

- scheme exactly HTTPS;
- lowercase ASCII DNS host;
- public, non-local, non-private, non-link-local, non-reserved host;
- default HTTPS port only;
- root path only in the persisted value.

If an otherwise acceptable source had a path/query/fragment/non-root
component, persist only the root origin plus typed redaction reasons. Never
persist removed bytes.

Reject without storing a URL:

- HTTP or another scheme;
- IP literal, including encoded/alternate IPv4 or IPv6 forms;
- localhost, `.local`, private, link-local, loopback, multicast, reserved or
  single-label destinations;
- userinfo or embedded credentials;
- non-default port;
- malformed/ambiguous host;
- non-ASCII or IDN bytes;
- percent-encoded local/Home path;
- secret-bearing or signed URL whose safe public origin cannot be admitted.

Rejected input persists only a closed rejection category. It must not persist
the raw rejected value, host, path, query, fragment or secret-like token.

### 6.2 Adversarial fixtures

Tests include:

- signed cloud URL;
- basic-auth/userinfo URL;
- API key/token in query and fragment;
- token-like path segment;
- percent-encoded `/Users/<name>` and `~`;
- decimal, octal, hexadecimal and shortened IPv4 spellings;
- bracketed and mapped IPv6;
- localhost/private/link-local/reserved DNS and literals;
- trailing dot, mixed case, Unicode/IDN and punycode ambiguity;
- non-default port;
- redirect-shaped URL;
- malformed percent encoding;
- duplicate separators and empty host.

Assertions inspect raw SQLite bytes to prove removed/rejected sensitive
substrings are absent.

## 7. Retention, Paging and Deletion

### 7.1 Seven-day Investigation retention

At initial session creation, Store computes one immutable
`retention_expires_at_ms`:

```text
min(retained ScanSession.expires_at_ms, created_at_ms + 604_800_000)
```

The addition is checked signed-Int64 arithmetic. Creation rejects overflow or
an expiry not strictly after `created_at_ms`. The value is stored in the
session `expires_at_ms` column and is never recomputed or extended. The exact
expiry boundary is `now_ms >= expires_at_ms`; at that instant planning,
runtime admission, continuation and projection return `expired`, and the
retention transaction may remove the whole Investigation.

Continuation runs/reports inherit the same immutable session expiry. A parent
partial report cannot expire independently while a child run remains; the
entire lineage expires atomically. Loading, paging, runtime terminal time,
continuation creation and UI access never refresh the anchor. Retention:

- is independent of 90-day Cleanup Manifest retention;
- cannot be extended by loading, paging, continuation or UI access;
- does not delete linked Cleanup Manifests;
- removes expired Investigation records transactionally;
- preserves corrupt-row isolation long enough to report the exact corrupt
  record ID before deletion.

Raw runtime workspaces remain outside SQLite and retain the existing normal
terminal deletion / crash residue maximum 24-hour contract. Task 37 does not
manage those workspaces.

### 7.2 Paging

Bounded stable pages exist for:

- Investigation sessions ordered by terminal/update time then ID;
- reports for one session/run;
- evidence for one report ordered by retained target/order then ID;
- budget events ordered by serial ordinal then ID.

Limits and offsets/cursors are validated. A corrupt row is isolated and
reported without erasing valid siblings. Foreign or cross-session records are
never returned.

### 7.3 Exact local-record deletion

The only public deletion API accepts one typed `InvestigationID` and removes
that entire local Investigation lineage in one transaction. There is no
public report/run/target/evidence/degradation/budget delete. Internal direct
child deletion is rejected by deferred `NO ACTION` ownership whenever it
would sever terminal truth or continuation lineage. The whole-session delete
must not:

- touch a scanned filesystem path;
- call Trash or permanent deletion;
- invoke Codex or modify Codex auth/config;
- delete Cleanup Manifests;
- modify Local Knowledge, Settings or Quick Scan source records;
- follow a model-provided path or identifier.

Deleting one Investigation does not delete another session sharing a source
Scan. It also does not delete linked Cleanup Manifests; those retain only
their own bounded receipt and project Investigation evidence as expired or
locally removed.

## 8. Tests First

Write failing tests before implementation.

### 8.1 Migration

- clean v0/v1/v2/v3 fixtures migrate to v4;
- v3 Scan/Plan/Policy/journal/Manifest rows remain byte-identical in meaning;
- application ID, foreign keys, journal mode and integrity remain valid;
- injected failure rolls back without partial v4 tables/version;
- future version refuses;
- wrong application role refuses;
- malformed existing schema refuses;
- every required table/index/check/foreign key is verified;
- source-row row-kind/NULL-shape checks and both manifest uniqueness
  constraints are verified;
- exact `STRICT` affinity, BLOB digest length, TEXT byte-length, enum, ordinal
  and aggregate-count constraints are verified from `sqlite_master`;
- invalid/empty/oversized/non-ASCII `ScanSessionID` and `ScanScopeID`,
  including wrong `scan-` / `scope-` prefixes, reject in the executable DDL;
- session/run/report quota counters equal direct aggregate queries before each
  relevant commit; stale-lower and stale-higher counters reject even when
  numerically inside `CHECK` bounds;
- every same-Investigation composite foreign key, session-owner cascade,
  lineage `NO ACTION`, quota trigger and owner-delete trigger is verified;
- the private connection authorizer denies raw Investigation writes in default
  mode, wrong-table/wrong-column writes in every typed mode, nested mode entry,
  generic SQL preparation, schema mutation outside migration and escaped
  prepared statements;
- v1 Investigation fixture cannot become a v4 product target.

### 8.2 Source manifest/rejoin

- complete insertion succeeds;
- empty Planner output returns `noEligibleTargets` and leaves zero session,
  manifest, target and run rows;
- each row family and every non-payload column affects the fingerprint;
- payload byte change, membership add/remove, reorder/canonical failure and
  ID-only match fail;
- manifest rows contain no copied source payload bytes;
- every row-kind nullable-column shape passes only at its exact canonical
  shape; missing, extra and wrong-kind values reject;
- direct SQLite attempts with wrong affinity, 31/33-byte digest, negative or
  oversized payload count, invalid disposition, noncanonical ordinal, ordinal
  gap and wrong token order reject or fail pre-commit verification;
- corrupt payload and storage identity mismatch are distinct;
- all eight barrier tokens are closed and covered;
- bounds at N−1/N/N+1;
- 100-evidence-per-snapshot, 256 MiB raw aggregate and 512 MiB canonical
  SourceProjection boundaries;
- 2 MiB canonical Plan and independent 4 MiB strict Plan JSON boundaries,
  including fits-one/exceeds-the-other fixtures;
- no top-N truncation;
- concurrent retention/deletion/source mutation cannot interleave with the
  pinned rejoin; injected mutation becomes visible only before the snapshot or
  after commit, never as a hybrid;
- busy lock acquisition returns `storeBusy` by 2 seconds and starts no source
  work;
- insertion/rejoin/terminal/recovery/continuation cancellation and the exact
  90-second deadline interrupt through the SQLite progress handler, roll back
  every write and return only after cleanup; terminal settlement begins the
  Store operation by T0+45, commits by T0+135 or finishes cleanup/quarantine by
  T0+140;
- progress checks occur within 1,000 SQLite VM instructions and before every
  payload/statement step; reported progress is ephemeral and monotonic;
- rollback cleanup succeeds within 5 seconds or quarantines the connection as
  `rollbackUnconfirmed`; no new mutation proceeds until reopen plus
  integrity/foreign-key checks;
- no busy/timeout/cancel/rollback retry and no split-snapshot fallback;
- rejoin API accepts only Investigation ID + closed barrier and has no expected
  manifest/fingerprint/cursor/freshness argument;
- create API accepts only Investigation ID, initial run ID, retained Scan
  session/scope, budget preset, injected planning time and bounded relevance
  tokens; it has no Plan/target/source-row/digest/cursor/freshness argument;
- 300,002-row insertion/rejoin uses reset/bind/step prepared statements and
  retains no bindings/full-manifest/full-payload/canonical byte array;
- exact idempotent insertion and conflicting replay;
- completed/partial terminal command accepts one App-internal typed report ID,
  equal replay reuses it, alternate-ID replay fails, and blocked/failed reject
  any report ID;
- strict decoded run-owned Plan target IDs/order/count exactly equal
  `investigation_run_targets`; extra, missing, reordered, foreign or duplicate
  membership rejects pre-commit;
- adversarial low-level tests attempt a target-count/membership mismatch,
  stale-lower/stale-higher session aggregates, budget-counter/event mismatch,
  running-to-terminal mutation, terminal-field rewrite and illegal terminal
  regression through the production connection; the authorizer or typed
  pre-commit verifier rejects every case;
- continuation requires verified partial parent and new run ID.

### 8.3 Terminal truth

- partial/final report insert is atomic with session terminal state;
- completed/final and partial runs have exactly one report; a paused session
  aggregates a terminal partial run and never contains a paused run;
- blocked/failed runs have zero reports/evidence and retain typed run cause;
- failed durable terminal commit leaves prior recoverable state and does not
  fabricate a failed report;
- report is immutable;
- per-report/per-run/per-Investigation row and aggregate-byte quotas at
  N−1/N/N+1, including session counter mismatch under the numeric maximum;
- report-scoped degradation accepts only its closed no-target kinds and cannot
  be inserted as target-scoped evidence or linked to a synthetic target;
- failure at every write point rolls back;
- evidence cannot orphan;
- same-Investigation evidence for a target admitted only by another run fails
  the composite run-target membership foreign key and typed pre-commit
  verifier;
- cross-Investigation run/report/target/evidence/budget and continuation-parent
  combinations fail composite foreign keys;
- budget event replay deduplicates and conflict rejects;
- no terminal visibility before commit;
- source drift immediately before terminal commit rejects;
- crash recovery cannot promote unverified evidence.

### 8.4 Privacy

- every accepted/redacted/rejected URL fixture;
- raw SQLite scan proves no removed path/query/fragment/userinfo/secret bytes;
- no raw prompt, JSONL, stdout/stderr, file snippet or model reasoning fields
  exist in schema or encoded payloads;
- Store API does not accept raw URL/path-content payload;
- malformed provenance fails closed.

### 8.5 Retention/history

- seven-day exact boundary;
- immutable expiry equals
  `min(source expires_at_ms, created_at_ms + 604_800_000)`, expires when
  `now_ms >= expires_at_ms`, rejects checked-add overflow and is not extended
  by continuation, terminal time, loading or paging;
- parent partial and every continuation descendant expire/delete atomically;
- 90-day Manifest survives Investigation expiry/deletion;
- linked Manifest projection reports expired Investigation evidence;
- stable paging and corrupt sibling isolation;
- exact Investigation deletion affects no disk target or unrelated Store
  domain;
- direct report/run/target deletion is rejected and cannot cascade through a
  continuation lineage; whole-Investigation deletion removes its complete
  lineage with no foreign-key residue;
- record counts remain truthful after expiry/deletion;
- Cleanup History regressions remain unchanged.

### 8.6 Structural

Extend `scripts/verify-investigation-boundaries` to reject from Task 37 Store
and domain code:

- `ActionExecutor`;
- `CleanupExecutionRuntime`;
- `ExecutionAuthorization`;
- `TrashMoving` / `trashItem`;
- `RegisteredActionRunner`;
- `Process`;
- `StornautCodex`;
- `StornautLifecycle`;
- arbitrary URL persistence APIs;
- raw JSONL/prompt/stdout/stderr columns.
- public/internal generic SQL execution or statement preparation;
- escaped `OpaquePointer`/SQLite handle or mutable connection;
- Investigation table writes outside the closed persistence owner;
- authorizer disable/bypass after connection open.

### 8.7 Maximum-size Store benchmark

- run all five end-to-end operations from §4.2 in Release configuration;
- use exact maximum row/byte/target/report fixtures and record their hashes;
- execute three serial samples per operation with no overlapping SwiftPM/Xcode
  work;
- include lock/source/decode/hash/bind/step/verify/commit time and exclude only
  fixture generation;
- require every sample `<= 75` monotonic seconds and report at least 15 seconds
  of margin below the immutable 90-second deadline;
- preserve Task 36's projection memory bound and record peak RSS/database size;
- any miss yields `capacityBlocked` and requires ADR/user review rather than a
  relaxed test, larger deadline, truncation, retry or split snapshot.

## 9. Expected Files

Expected scope:

```text
Sources/StornautCore/Evidence/EvidenceStore.swift
Sources/StornautCore/Evidence/SQLiteConnection.swift
Sources/StornautCore/Investigation/InvestigationPersistence.swift
Sources/StornautCore/Investigation/PersistedWebProvenance.swift
Tests/StornautCoreTests/InvestigationStoreV4Tests.swift
Tests/StornautCoreTests/InvestigationMigrationTests.swift
Tests/StornautCoreTests/InvestigationSourceRejoinTests.swift
Tests/StornautCoreTests/InvestigationStorePerformanceTests.swift
Tests/StornautCoreTests/PersistedWebProvenanceTests.swift
Tests/Fixtures/EvidenceStore/v3-evidence.sql
Tests/Fixtures/Investigation/...
scripts/verify-investigation-boundaries
docs/plans/active/task-37-implementation-brief.md
docs/reports/phase-d-task-37-review.md
docs/agent/coding-agent-handoff.md
docs/plans/active/README.md
docs/plans/roadmap.md
AGENTS.md
```

Exact filenames may follow repo style. No App, Codex runtime, Lifecycle or UI
source is in scope.

## 10. Focused Validation

Run serially:

```text
swift test --filter InvestigationStoreV4
swift test --filter InvestigationMigration
swift test --filter InvestigationSourceRejoin
swift test --filter InvestigationStorePerformance
swift test -c release --filter InvestigationStoreCapacityBenchmark
swift test --filter PersistedWebProvenance
swift test --filter CleanupHistoryStore
swift test --filter RetentionPolicy
scripts/verify-investigation-boundaries
scripts/check-doc-links
git diff --check
```

Then:

```text
swift test --parallel false
scripts/verify --full
```

Heavy SwiftPM/Xcode work must not overlap.

## 11. Independent Review

Review the complete Task diff for:

- incomplete migration or rollback;
- legacy v1 target admission;
- trusting caller fingerprints;
- missing source rows/columns;
- ID-only rejoin;
- unpinned/hybrid SQLite snapshot or freshness token escaping transaction;
- caller-provided expected manifest/fingerprint/cursor;
- full source payload/manifest/bindings accumulation at maximum size;
- incomplete `STRICT` row-shape/BLOB/ordinal/count checks;
- decoded Plan versus run-target membership mismatch or empty persisted run;
- quota/update/delete trigger bypass and stale aggregate counters;
- missing/private-connection authorizer coverage or generic SQL/handle escape;
- DDL claims that overstate cross-row/lifecycle enforcement;
- missing transaction cancellation/deadline/rollback quarantine;
- missing maximum-size Store benchmark or less than 15 seconds measured
  deadline margin;
- cross-session child/composite-FK mismatch;
- blocked/failed run fabricating a report or evidence;
- mutable terminal reports;
- foreign-key/orphan errors;
- stale/expired/corrupt conflation;
- raw secret/path/query/fragment persistence;
- URL parser ambiguity and IP/private bypass;
- retention accidentally deleting Manifests;
- local-record deletion reaching disk/Codex/Settings;
- Task 38/App/UI scope creep;
- second execution or authorization path;
- stale docs or broken links.

Fix all P0–P2 findings and rerun affected focused checks before the final full
verifier.

## 12. Explicit Non-Goals

- real or fake Codex launch;
- `StornautInvestigation` coordinator;
- App Server event decoding;
- runtime receipt/capability admission;
- lifecycle/proxy orchestration;
- prompt construction;
- report-to-Review projection;
- App dependencies/state/UI;
- first-use disclosure;
- Deep Dive availability changes;
- Cleanup Plan, Policy, selection, authorization or execution;
- filesystem writes outside the SQLite database;
- Adapters or Registered Actions.

## 13. Completion and Git

Task 37 completes only when:

- Store v4 and all v0/v1/v2/v3 migrations pass;
- source-manifest rejoin and privacy fixtures pass;
- retained Phase C records and Manifest behavior are unchanged;
- structural boundary verifier passes;
- independent review has zero unresolved P0–P2;
- one uninterrupted authoritative `scripts/verify --full` exits `0`;
- docs accurately state production Deep Dive remains unavailable;
- a docs-freshness audit verifies every referenced normative document, task
  dependency/status router, ownership/non-goal claim and product-availability
  claim matches the committed diff and canonical contract;
- docs links, credential/artifact hygiene and `git diff --check` pass;
- one independent commit contains no Coding Agent co-author trailer;
- `GITHUB_TOKEN` and `GH_TOKEN` are unset before push;
- `HEAD == origin/main` after push.
