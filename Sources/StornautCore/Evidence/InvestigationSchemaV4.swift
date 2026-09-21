let evidenceSchemaV4Statements: [(String, String)] =
    investigationSchemaV4TableStatements
    + investigationSchemaV4IndexStatements
    + investigationSchemaV4TriggerStatements

private let investigationSchemaV4TableStatements: [(String, String)] = [
    (
        "schema.investigationSessions",
        """
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
                CHECK (
                    evidence_payload_byte_count BETWEEN 0 AND 67108864
                ),
            degradation_row_count INTEGER NOT NULL DEFAULT 0
                CHECK (degradation_row_count BETWEEN 0 AND 1024),
            degradation_payload_byte_count INTEGER NOT NULL DEFAULT 0
                CHECK (
                    degradation_payload_byte_count BETWEEN 0 AND 4194304
                ),
            budget_event_count INTEGER NOT NULL DEFAULT 0
                CHECK (budget_event_count BETWEEN 0 AND 65536),
            budget_payload_byte_count INTEGER NOT NULL DEFAULT 0
                CHECK (
                    budget_payload_byte_count BETWEEN 0 AND 33554432
                ),
            created_at_ms INTEGER NOT NULL,
            updated_at_ms INTEGER NOT NULL,
            expires_at_ms INTEGER NOT NULL,
            UNIQUE (id, scan_session_id)
        ) STRICT
        """
    ),
    (
        "schema.investigationSourceRows",
        """
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
                    length(CAST(source_relative_path AS BLOB))
                        BETWEEN 1 AND 16384
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
                    'readyToReclaim', 'reviewRecommended',
                    'protected', 'unknown'
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
        ) STRICT, WITHOUT ROWID
        """
    ),
    (
        "schema.investigationRelevanceTokens",
        """
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
        ) STRICT
        """
    ),
    (
        "schema.investigationTargets",
        """
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
        ) STRICT
        """
    ),
    (
        "schema.investigationRuns",
        """
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
            plan_json TEXT NOT NULL CHECK (
                length(CAST(plan_json AS BLOB)) BETWEEN 1 AND 4194304
            ),
            budget_preset TEXT NOT NULL
                CHECK (budget_preset IN ('focused', 'balanced', 'thorough')),
            plan_created_at_ms INTEGER NOT NULL,
            plan_expires_at_ms INTEGER NOT NULL
                CHECK (plan_expires_at_ms > plan_created_at_ms),
            target_count INTEGER NOT NULL
                CHECK (target_count BETWEEN 1 AND 512),
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
                CHECK (
                    budget_payload_byte_count BETWEEN 0 AND 4194304
                ),
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
                investigation_id, terminal_report_id,
                run_id, expected_report_kind
            ),
            FOREIGN KEY (investigation_id)
                REFERENCES investigation_sessions(id) ON DELETE CASCADE
                DEFERRABLE INITIALLY DEFERRED,
            FOREIGN KEY (
                investigation_id, parent_report_id,
                parent_run_id, parent_report_kind
            ) REFERENCES investigation_reports(
                investigation_id, report_id, run_id, report_kind
            ) ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED,
            FOREIGN KEY (
                investigation_id, terminal_report_id,
                run_id, expected_report_kind
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
        ) STRICT
        """
    ),
    (
        "schema.investigationRunTargets",
        """
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
        ) STRICT
        """
    ),
    (
        "schema.investigationReports",
        """
        CREATE TABLE investigation_reports (
            investigation_id TEXT NOT NULL,
            report_id TEXT NOT NULL CHECK (
                length(CAST(report_id AS BLOB)) BETWEEN 22 AND 128
                AND report_id GLOB 'investigation-report-?*'
                AND report_id NOT GLOB '*[^A-Za-z0-9._-]*'
            ),
            run_id TEXT NOT NULL,
            report_kind TEXT NOT NULL
                CHECK (report_kind IN ('final', 'partial')),
            created_at_ms INTEGER NOT NULL,
            evidence_row_count INTEGER NOT NULL
                CHECK (evidence_row_count BETWEEN 0 AND 512),
            evidence_payload_byte_count INTEGER NOT NULL
                CHECK (
                    evidence_payload_byte_count BETWEEN 0 AND 8388608
                ),
            degradation_row_count INTEGER NOT NULL
                CHECK (degradation_row_count BETWEEN 0 AND 64),
            degradation_payload_byte_count INTEGER NOT NULL
                CHECK (
                    degradation_payload_byte_count BETWEEN 0 AND 524288
                ),
            payload TEXT NOT NULL CHECK (
                length(CAST(payload AS BLOB)) BETWEEN 1 AND 1048576
            ),
            PRIMARY KEY (investigation_id, report_id),
            UNIQUE (investigation_id, run_id),
            UNIQUE (investigation_id, report_id, run_id),
            UNIQUE (investigation_id, report_id, run_id, report_kind),
            FOREIGN KEY (
                investigation_id, report_id, run_id, report_kind
            ) REFERENCES investigation_runs(
                investigation_id, terminal_report_id,
                run_id, expected_report_kind
            ) ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED,
            FOREIGN KEY (investigation_id)
                REFERENCES investigation_sessions(id) ON DELETE CASCADE
                DEFERRABLE INITIALLY DEFERRED
        ) STRICT
        """
    ),
    (
        "schema.investigationEvidence",
        """
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
                REFERENCES investigation_reports(
                    investigation_id, report_id, run_id
                ) ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED,
            FOREIGN KEY (investigation_id, run_id, target_id)
                REFERENCES investigation_run_targets(
                    investigation_id, run_id, target_id
                ) ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED,
            FOREIGN KEY (investigation_id)
                REFERENCES investigation_sessions(id) ON DELETE CASCADE
                DEFERRABLE INITIALLY DEFERRED
        ) STRICT
        """
    ),
    (
        "schema.investigationReportDegradations",
        """
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
                REFERENCES investigation_reports(
                    investigation_id, report_id, run_id
                ) ON DELETE NO ACTION DEFERRABLE INITIALLY DEFERRED,
            FOREIGN KEY (investigation_id)
                REFERENCES investigation_sessions(id) ON DELETE CASCADE
                DEFERRABLE INITIALLY DEFERRED
        ) STRICT
        """
    ),
    (
        "schema.investigationBudgetEvents",
        """
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
                'reservation', 'commit', 'release',
                'direct-tool-observation', 'token-observation',
                'usage-unavailable', 'evidence-gain',
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
        ) STRICT
        """
    ),
]

private let investigationSchemaV4IndexStatements: [(String, String)] = [
    (
        "schema.investigationSourcePathSnapshotCanonicalIndex",
        """
        CREATE INDEX idx_investigation_source_path_snapshots_canonical
        ON path_snapshots(
            session_id,
            json_extract(payload, '$.scopeID'),
            length(CAST(id AS BLOB)),
            CAST(id AS BLOB)
        )
        """
    ),
    (
        "schema.investigationSourceSnapshotMembershipIndex",
        """
        CREATE INDEX idx_investigation_source_snapshot_membership
        ON path_snapshots(
            id,
            session_id,
            json_extract(payload, '$.scopeID')
        )
        """
    ),
    (
        "schema.investigationSourceClassificationCanonicalIndex",
        """
        CREATE INDEX idx_investigation_source_classifications_canonical
        ON classifications(
            length(CAST(id AS BLOB)),
            CAST(id AS BLOB)
        )
        """
    ),
    (
        "schema.investigationSourceEvidenceCanonicalIndex",
        """
        CREATE INDEX idx_investigation_source_evidence_canonical
        ON evidence(
            length(CAST(id AS BLOB)),
            CAST(id AS BLOB)
        )
        """
    ),
    (
        "schema.investigationSessionExpiryIndex",
        """
        CREATE INDEX idx_investigation_sessions_expiry
        ON investigation_sessions(expires_at_ms, id)
        """
    ),
    (
        "schema.investigationSessionHistoryIndex",
        """
        CREATE INDEX idx_investigation_sessions_history
        ON investigation_sessions(updated_at_ms DESC, id)
        """
    ),
    (
        "schema.investigationRunStateIndex",
        """
        CREATE INDEX idx_investigation_runs_state
        ON investigation_runs(
            investigation_id, state, updated_at_ms DESC, run_id
        )
        """
    ),
    (
        "schema.investigationReportHistoryIndex",
        """
        CREATE INDEX idx_investigation_reports_history
        ON investigation_reports(
            investigation_id, created_at_ms DESC, report_id
        )
        """
    ),
    (
        "schema.investigationEvidenceTargetIndex",
        """
        CREATE INDEX idx_investigation_evidence_target
        ON investigation_evidence(
            investigation_id, run_id, target_id, ordinal
        )
        """
    ),
]

private let investigationSchemaV4TriggerStatements: [(String, String)] = [
    (
        "schema.investigationRunsQuotaTrigger",
        """
        CREATE TRIGGER investigation_runs_quota
        BEFORE INSERT ON investigation_runs
        WHEN (
            SELECT count(*) FROM investigation_runs
            WHERE investigation_id = NEW.investigation_id
        ) >= 16
        BEGIN
            SELECT RAISE(ABORT, 'investigation run quota exceeded');
        END
        """
    ),
    (
        "schema.investigationEvidenceQuotaTrigger",
        """
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
        END
        """
    ),
    (
        "schema.investigationDegradationQuotaTrigger",
        """
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
        END
        """
    ),
    (
        "schema.investigationBudgetQuotaTrigger",
        """
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
        END
        """
    ),
    (
        "schema.investigationSourceRowsOwnerDeleteTrigger",
        ownerDeleteTrigger(
            name: "investigation_source_rows_owner_delete_only",
            table: "investigation_source_rows"
        )
    ),
    (
        "schema.investigationRelevanceTokensOwnerDeleteTrigger",
        ownerDeleteTrigger(
            name: "investigation_relevance_tokens_owner_delete_only",
            table: "investigation_relevance_tokens"
        )
    ),
    (
        "schema.investigationTargetsOwnerDeleteTrigger",
        ownerDeleteTrigger(
            name: "investigation_targets_owner_delete_only",
            table: "investigation_targets"
        )
    ),
    (
        "schema.investigationRunsOwnerDeleteTrigger",
        ownerDeleteTrigger(
            name: "investigation_runs_owner_delete_only",
            table: "investigation_runs"
        )
    ),
    (
        "schema.investigationRunTargetsOwnerDeleteTrigger",
        ownerDeleteTrigger(
            name: "investigation_run_targets_owner_delete_only",
            table: "investigation_run_targets"
        )
    ),
    (
        "schema.investigationReportsOwnerDeleteTrigger",
        ownerDeleteTrigger(
            name: "investigation_reports_owner_delete_only",
            table: "investigation_reports"
        )
    ),
    (
        "schema.investigationEvidenceOwnerDeleteTrigger",
        ownerDeleteTrigger(
            name: "investigation_evidence_owner_delete_only",
            table: "investigation_evidence"
        )
    ),
    (
        "schema.investigationDegradationsOwnerDeleteTrigger",
        ownerDeleteTrigger(
            name: "investigation_degradations_owner_delete_only",
            table: "investigation_report_degradations"
        )
    ),
    (
        "schema.investigationBudgetOwnerDeleteTrigger",
        ownerDeleteTrigger(
            name: "investigation_budget_owner_delete_only",
            table: "investigation_budget_events"
        )
    ),
    (
        "schema.investigationSourceRowsImmutableTrigger",
        immutableTrigger(
            name: "investigation_source_rows_immutable",
            table: "investigation_source_rows"
        )
    ),
    (
        "schema.investigationRelevanceTokensImmutableTrigger",
        immutableTrigger(
            name: "investigation_relevance_tokens_immutable",
            table: "investigation_relevance_tokens"
        )
    ),
    (
        "schema.investigationTargetsImmutableTrigger",
        immutableTrigger(
            name: "investigation_targets_immutable",
            table: "investigation_targets"
        )
    ),
    (
        "schema.investigationRunTargetsImmutableTrigger",
        immutableTrigger(
            name: "investigation_run_targets_immutable",
            table: "investigation_run_targets"
        )
    ),
    (
        "schema.investigationReportsImmutableTrigger",
        immutableTrigger(
            name: "investigation_reports_immutable",
            table: "investigation_reports"
        )
    ),
    (
        "schema.investigationEvidenceImmutableTrigger",
        immutableTrigger(
            name: "investigation_evidence_immutable",
            table: "investigation_evidence"
        )
    ),
    (
        "schema.investigationDegradationsImmutableTrigger",
        immutableTrigger(
            name: "investigation_degradations_immutable",
            table: "investigation_report_degradations"
        )
    ),
    (
        "schema.investigationBudgetImmutableTrigger",
        immutableTrigger(
            name: "investigation_budget_immutable",
            table: "investigation_budget_events"
        )
    ),
    (
        "schema.investigationSessionsImmutableSourceTrigger",
        """
        CREATE TRIGGER investigation_sessions_immutable_source
        BEFORE UPDATE ON investigation_sessions
        WHEN
            NEW.id IS NOT OLD.id
            OR NEW.scan_session_id IS NOT OLD.scan_session_id
            OR NEW.scan_scope_id IS NOT OLD.scan_scope_id
            OR NEW.source_fingerprint IS NOT OLD.source_fingerprint
            OR NEW.source_row_count IS NOT OLD.source_row_count
            OR NEW.relevance_token_count IS NOT OLD.relevance_token_count
            OR NEW.source_payload_byte_count
                IS NOT OLD.source_payload_byte_count
            OR NEW.source_canonical_byte_count
                IS NOT OLD.source_canonical_byte_count
            OR NEW.created_at_ms IS NOT OLD.created_at_ms
            OR NEW.expires_at_ms IS NOT OLD.expires_at_ms
        BEGIN
            SELECT RAISE(ABORT, 'immutable investigation source');
        END
        """
    ),
    (
        "schema.investigationRunsImmutablePlanTrigger",
        """
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
        END
        """
    ),
]

private func ownerDeleteTrigger(name: String, table: String) -> String {
    """
    CREATE TRIGGER \(name)
    BEFORE DELETE ON \(table)
    WHEN EXISTS (
        SELECT 1 FROM investigation_sessions
        WHERE id = OLD.investigation_id
    )
    BEGIN
        SELECT RAISE(ABORT, 'whole investigation delete required');
    END
    """
}

private func immutableTrigger(name: String, table: String) -> String {
    """
    CREATE TRIGGER \(name)
    BEFORE UPDATE ON \(table)
    BEGIN
        SELECT RAISE(ABORT, 'immutable investigation row');
    END
    """
}
