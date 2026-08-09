# Epic 2–4 Task 10 Code Review — 2026-08-10

> 状态：All confirmed findings fixed; no open P0–P2 finding
>
> 范围：Task 10 domain contracts、anonymous fixtures、Surveyor transport
> migration、shared file identity
>
> 方法：`bits-code-guard` diff scope + 7-dimension manual review +
> adversarial decode tests + focused regression/benchmark

## 1. Review Scope

- 24 source/test/fixture files in the initial review scope;
- stable typed IDs and schema/JSON primitives;
- ScanSession, PathSnapshot, Classification, Evidence and InvestigationTarget;
- non-executable CleanupPlan and PolicyDecision;
- minimal CleanupManifest and accounting contracts;
- unified `FileIdentity`;
- `SurveyorObservation` transport separation;
- anonymous developer-tree fixtures.

`bits-code-guard` found all source/test/JSON files and no repository custom
workflow. Because subagent delegation was not available for this iteration,
the general workflow used its manual fallback across logic, business semantics,
security/privacy, concurrency, robustness, performance and quality.

## 2. Confirmed Findings and Fixes

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P1 | Synthesized `Decodable` bypassed throwing initializer invariants for sessions, plans, manifests and accounting | Added fail-closed custom decoding through validating initializers | JSON mutation tests for timelines, terminal states, expiry, result/error and accounting status |
| P1 | `ByteCount` accepted values above `Int64.max`, which cannot round-trip through SQLite INTEGER; `FileIdentity` could be manually constructed with negative sizes | Restricted bytes to SQLite-safe range and made identity creation throwing | negative/overflow JSON plus identity decode tests |
| P1 | Persisted snapshots could encode path traversal, kind/mode mismatch, byte/identity mismatch or contradictory measurement status | Added bounded relative-path, kind/mode, byte, status and mtime consistency validation | adversarial snapshot mutation tests |
| P1 | Manifest/evidence identifiers, reason keys and error fields accepted arbitrary strings that could persist paths or content beyond intended boundaries | Added bounded ASCII `DomainToken`, typed action IDs and bounded `DomainLabel`/`PersistedPath` | token/label/path control, path and length tests |
| P1 | Policy decision initially allowed only `Ready to Reclaim`, conflicting with the approved individually confirmed `Review Recommended` flow | Allow only Ready or explicit Review; keep Protected/Unknown denied; require decision reasons | disposition matrix tests |
| P1 | Minimal Manifest lacked action pre/post measurement and source-bearing system before/after observations | Added action before/after/processed logical+allocated values and typed system observation | fixture round-trip and minimal-field assertions |
| P1 | Manifest accepted success without postflight, success with errors, protected actions and inconsistent free-space delta | Added result/error/disposition/postflight/delta invariants | JSON mutation tests for each contradiction |
| P1 | Snapshot omitted PRD FR-1 owner and symlink-target facts | Unified UID/GID into `FileIdentity` and added bounded best-effort link-target observation without following links | real fixture owner and symlink target assertions |
| P1 | Classification accepted missing evidence outside requirements, Protected/category drift and unbounded producer labels | Added set/subset, Protected/category and bounded-label validation | classification mutation tests |
| P1 | Plan/accounting/session contracts allowed paired byte gaps, unknown-with-known-bytes, invalid scope times or empty policy reasons | Added paired-byte, status/byte, scope timeline and non-empty reason invariants | plan/accounting/session mutation tests |

## 3. Architecture and Safety Review

### Type boundaries

- Aggregate IDs are phantom typed and prefix validated.
- Persistent byte counts are nonnegative and SQLite INTEGER safe.
- Risk, confidence and disposition remain independent.
- The four disposition raw values exactly match the approved contract.

### Scanner migration

- `PathSnapshot` contains immutable persisted facts only.
- `ScanProgress` moved to non-Codable `SurveyorObservation`.
- No-follow and same-device behavior is unchanged.
- Permission/race/mount failures remain typed partial observations.
- Existing Action Policy and Trash use the same unified file identity.

### Execution boundary

- `CleanupPlan` stores proposals, not target URLs, executables or arguments.
- Existing `CleanupAction` remains the separate runtime request type.
- Plans/manifests do not call or hold `ActionExecutor`.
- Protected/Unknown cannot appear as an executed Manifest record.

### Privacy

- Manifest has no path, evidence payload, probe record, snippet or raw content.
- Persisted display/identifier fields are bounded and typed.
- Fixtures contain relative synthetic paths only.
- No copied upstream output, credential or machine-specific path is present.

## 4. Verification

Focused checks after review fixes:

- 20 Domain contract tests passed;
- 12 Surveyor tests passed;
- 8 Action Policy tests passed;
- 5 Trash tests passed.

Three production-compatible synthetic Surveyor runs stayed deterministic:

| Run | Entries | Logical bytes | Allocated bytes | Elapsed | Peak RSS |
| --- | ---: | ---: | ---: | ---: | ---: |
| 1 | 1,356 | 68,167,269 | 4,349,952 | 50.92 ms | 10,256,384 |
| 2 | 1,356 | 68,167,269 | 4,349,952 | 58.86 ms | 10,600,448 |
| 3 | 1,356 | 68,167,269 | 4,349,952 | 46.58 ms | 10,616,832 |

Two full parallel runs exposed an existing Codex test's load-sensitive
wall-clock assertion (`4.045s` and `4.456s` versus a hard-coded `4.0s`), while
the focused case completed in `0.320s`. The test was strengthened rather than
relaxed: the fake runtime now emits malformed JSON and remains alive, so
receiving `protocolViolation` instead of the configured `timedOut` result proves
early protocol failure directly. The test also verifies the process exits.
This correction changes test determinism, not the production runtime boundary.

The first full verifier after that correction exposed a real scheduling issue:
blocking stdin/stdout/stderr POSIX I/O ran on Swift cooperative tasks. Under
parallel Codex and Surveyor tests, those reads exhausted cooperative executor
threads, delaying cancellation and producer completion. Moving the fixed three
blocking I/O operations per runtime onto dedicated short-lived utility Threads
made three consecutive eight-scenario stress runs pass without surviving
processes. A global GCD queue bridge was measured first and rejected because it
could still delay I/O start under full-suite load.

The output-limit test also inherited an unrelated two-second overall timeout,
allowing process startup scheduling to win before the 2 KiB fixture reached the
reader. Its two output-limit requests now use a test-local ten-second ceiling;
they still require the exact stdout/stderr byte-limit error. Timeout behavior
continues to be covered by dedicated one/two-second timeout tests. No production
timeout default or error mapping was relaxed.

## 5. Remaining Boundaries

- `SpaceAccounting` is only the stable Task 10 domain contract; Task 13 defines
  reconciliation formulas.
- SQLite persistence and migrations are Task 11.
- Production Surveyor events/session writing are Task 12.
- Rule/activity validation is Tasks 14–19.
- Cleanup execution and production Manifest creation remain Phase C.
- Deep Dive remains no-go/paused.
