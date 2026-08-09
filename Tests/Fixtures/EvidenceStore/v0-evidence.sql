PRAGMA user_version = 0;

CREATE TABLE legacy_scan_sessions (
    id TEXT PRIMARY KEY NOT NULL,
    started_at_ms INTEGER NOT NULL,
    finished_at_ms INTEGER NOT NULL,
    expires_at_ms INTEGER NOT NULL,
    payload TEXT NOT NULL
);

INSERT INTO legacy_scan_sessions (
    id,
    started_at_ms,
    finished_at_ms,
    expires_at_ms,
    payload
) VALUES (
    'scan-legacy-v0',
    1786233600000,
    1786233720000,
    1786838520000,
    '{"completedScopes":[],"finishedAt":1786233720000,"id":"scan-legacy-v0","schemaVersion":1,"startedAt":1786233600000,"terminalState":"partial","unfinishedScopes":[{"id":"scope-legacy-v0","reason":"permissionDenied","rootPath":"fixture-root/legacy"}]}'
);
