PRAGMA application_id = 1398033989;
PRAGMA user_version = 3;

CREATE TABLE scan_sessions (
    id TEXT PRIMARY KEY NOT NULL,
    started_at_ms INTEGER NOT NULL,
    finished_at_ms INTEGER NOT NULL,
    expires_at_ms INTEGER NOT NULL,
    payload TEXT NOT NULL
) STRICT;

CREATE TABLE path_snapshots (
    id TEXT PRIMARY KEY NOT NULL,
    session_id TEXT NOT NULL REFERENCES scan_sessions(id) ON DELETE CASCADE,
    relative_path TEXT NOT NULL,
    observed_at_ms INTEGER NOT NULL,
    payload TEXT NOT NULL
) STRICT;

CREATE TABLE classifications (
    id TEXT PRIMARY KEY NOT NULL,
    snapshot_id TEXT NOT NULL REFERENCES path_snapshots(id) ON DELETE CASCADE,
    disposition TEXT NOT NULL,
    classified_at_ms INTEGER NOT NULL,
    payload TEXT NOT NULL
) STRICT;

CREATE TABLE evidence (
    id TEXT PRIMARY KEY NOT NULL,
    snapshot_id TEXT NOT NULL REFERENCES path_snapshots(id) ON DELETE CASCADE,
    observed_at_ms INTEGER NOT NULL,
    payload TEXT NOT NULL
) STRICT;

CREATE TABLE space_accounting (
    id TEXT PRIMARY KEY NOT NULL,
    session_id TEXT NOT NULL REFERENCES scan_sessions(id) ON DELETE CASCADE,
    payload TEXT NOT NULL
) STRICT;

CREATE TABLE cleanup_plans (
    id TEXT PRIMARY KEY NOT NULL,
    session_id TEXT NOT NULL REFERENCES scan_sessions(id) ON DELETE CASCADE,
    created_at_ms INTEGER NOT NULL,
    expires_at_ms INTEGER NOT NULL,
    payload TEXT NOT NULL
) STRICT;

CREATE TABLE policy_decisions (
    id TEXT PRIMARY KEY NOT NULL,
    plan_id TEXT NOT NULL REFERENCES cleanup_plans(id) ON DELETE CASCADE,
    payload TEXT NOT NULL
) STRICT;

CREATE TABLE cleanup_manifests (
    id TEXT PRIMARY KEY NOT NULL,
    plan_id TEXT NOT NULL,
    created_at_ms INTEGER NOT NULL,
    expires_at_ms INTEGER NOT NULL,
    payload TEXT NOT NULL
) STRICT;

CREATE TABLE volume_baselines (
    session_id TEXT NOT NULL REFERENCES scan_sessions(id) ON DELETE CASCADE,
    scope_id TEXT NOT NULL,
    sampled_at_ms INTEGER NOT NULL,
    payload TEXT NOT NULL,
    PRIMARY KEY (session_id, scope_id)
) STRICT;

CREATE TABLE cleanup_run_journals (
    id TEXT PRIMARY KEY NOT NULL,
    plan_id TEXT NOT NULL,
    stage TEXT NOT NULL
        CHECK (
            stage IN (
                'prepared',
                'actionStarted',
                'actionOutcomeRecorded',
                'manifestPending',
                'auditPending',
                'finalized'
            )
        ),
    retention_class TEXT NOT NULL
        CHECK (retention_class IN ('evidenceLinked', 'audit')),
    updated_at_ms INTEGER NOT NULL,
    expires_at_ms INTEGER NOT NULL,
    payload TEXT NOT NULL
) STRICT;

CREATE INDEX idx_scan_sessions_finished
ON scan_sessions(finished_at_ms DESC, id);
CREATE INDEX idx_path_snapshots_session_relative
ON path_snapshots(session_id, relative_path, id);
CREATE INDEX idx_classifications_snapshot
ON classifications(snapshot_id, classified_at_ms, id);
CREATE INDEX idx_classifications_disposition
ON classifications(disposition, classified_at_ms DESC, id);
CREATE INDEX idx_evidence_snapshot
ON evidence(snapshot_id, observed_at_ms, id);
CREATE INDEX idx_scan_sessions_expiry
ON scan_sessions(expires_at_ms);
CREATE INDEX idx_cleanup_plans_expiry
ON cleanup_plans(expires_at_ms);
CREATE INDEX idx_cleanup_manifests_expiry
ON cleanup_manifests(expires_at_ms);
CREATE INDEX idx_volume_baselines_session_scope
ON volume_baselines(session_id, scope_id);
CREATE INDEX idx_cleanup_run_journals_expiry
ON cleanup_run_journals(retention_class, expires_at_ms, id);
CREATE INDEX idx_cleanup_run_journals_stage
ON cleanup_run_journals(stage, updated_at_ms DESC, id);
