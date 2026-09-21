# Epic 2 Domain and Persistence Upstream Study

> 状态：Accepted as the study gate for Epic 2 Tasks 10–11
>
> 日期：2026-08-09
>
> Coding Agent：TRAE CLI
>
> 目标模块：领域契约、SQLite Evidence Store、migration、retention、本地数据边界

> **2026-08-11 product-policy note:** Any Deep Dive no-go/paused statement below
> is Phase B historical state. Current capability policy is defined by amended
> [ADR 0004](../adr/0004-codex-file-read-isolation.md).

## 1. Executive Conclusion

Epic 2 使用 Apple 平台自带的 SQLite，通过仓库自有的窄 Swift/C 边界访问：

- `StornautCore` 不引入 ORM；
- Evidence 与 Local Knowledge 使用两个角色化数据库，每个数据库由独立
  Swift `actor` 拥有并串行访问一个 SQLite connection；
- SwiftPM target 显式链接系统 `libsqlite3`；
- 所有 SQL 都封装在 typed repository 内，调用方不拼 SQL；
- migrations 使用 `PRAGMA user_version`、`BEGIN IMMEDIATE` 和完整回滚；
- 每个 connection 显式启用并验证 `PRAGMA foreign_keys=ON`；
- 初始版本显式设置并验证 `journal_mode=DELETE`，不启用 WAL；
- durable database 位于 Stornaut 自有 Application Support 子目录；
- 只可重建衍生物进入 Caches；
- Evidence 数据库排除系统备份，Local Knowledge 按 Application Support
  语义正常备份；
- 不创建 `~/.stornaut`，不把数据库写到扫描目标。

ADR 0007 记录该 Proposed 决策。它只有在 Task 11 完成 fresh/migration/
rollback/future-version/corruption/retention 证据后才可变为 Accepted。

## 2. Execution-Time Baseline

| Item | Observed value |
| --- | --- |
| Git baseline | `11b9b79e9ed9df3bf75b7f976c1aa7b43d44a5df` |
| macOS | 26.5.1, build `25F80` |
| Architecture | `arm64` |
| Xcode | 26.6, build `17F113` |
| Swift | 6.3.3, Swift language mode 6 |
| System SQLite CLI/runtime | 3.51.0, 2025-06-12 |
| Swift package dependencies | none |
| App identity | `com.eriklee.stornaut` |
| Deep Dive | no-go/paused |

Observed values are Task 9 evidence, not permanent product constants.

## 3. Documentation and Library Snapshots

| Source | Version/commit | License | Material read |
| --- | --- | --- | --- |
| [SQLite documentation](https://www.sqlite.org/docs.html) | live documentation, queried 2026-08-09; runtime 3.51.0 | SQLite public domain | [transactions](https://www.sqlite.org/lang_transaction.html), [isolation](https://www.sqlite.org/isolation.html), [WAL](https://www.sqlite.org/wal.html), [foreign keys](https://www.sqlite.org/foreignkeys.html), [PRAGMAs](https://www.sqlite.org/pragma.html), [backup API](https://www.sqlite.org/backup.html) |
| Apple Foundation | Xcode 26.6 / macOS 26.5 SDK | Apple documentation terms | [Using the file system effectively](https://developer.apple.com/documentation/foundation/using-the-file-system-effectively), `URL.applicationSupportDirectory`, `URL.cachesDirectory`, `FileManager.urls(for:in:)` |
| [GRDB.swift](https://github.com/groue/GRDB.swift) | current main `0d8cf958b4b66a0473ec6e6986eb9da462171da9`; stable `v7.11.1` at `b83108d10f42680d78f23fe4d4d80fc88dab3212` | MIT | `Package.swift`, `LICENSE`, system-library target and package shape |
| [SQLite.swift](https://github.com/stephencelis/SQLite.swift) | current main `66640f82aec886f3f2a51b3ac240957d2a7bde4c`; stable `0.16.0` at `f3daa8b29a328b1de3fe37425d9db7c4c54047fb` | MIT | `Package.swift`, `LICENSE.txt`, traits and transitive package shape |

### Source fingerprints

| File | SHA-256 |
| --- | --- |
| GRDB `Package.swift` | `4118b6c48dcb87f91d95fe40420371b8a474a44b0b0be2bf0417e0be1ebf7853` |
| GRDB `LICENSE` | `9853f9dce81365fcc1d9b46004633354450164b8d17904e92e80c444545f7e87` |
| SQLite.swift `Package.swift` | `cc538693ce6f332243588da8a009762edb2c25ce677e2072ec52bfe90762f282` |
| SQLite.swift `LICENSE.txt` | `54309d83b514af75deacb70285d5debe8c74ddfd7ca2d1990ae14a0255aceeba` |

No code was copied from either wrapper.

## 4. Executable Feasibility Evidence

### 4.1 SDK and direct Swift import

The current macOS SDK contains:

```text
usr/include/sqlite3.h
usr/lib/libsqlite3.tbd
```

A disposable Swift program compiled and ran with:

```text
import SQLite3
xcrun swiftc <probe>.swift -lsqlite3
```

Observed result:

```text
result=0 version=3.51.0
```

This proves the selected toolchain can import and link system SQLite without a
third-party package or custom module map.

### 4.2 SwiftPM transaction and migration probe

A disposable Swift 6 package used:

```swift
linkerSettings: [.linkedLibrary("sqlite3")]
```

It opened an in-memory database with `SQLITE_OPEN_FULLMUTEX`, enabled foreign
keys, ran a `BEGIN IMMEDIATE` schema migration, set/read `user_version=1`,
rejected an invalid foreign key, and rolled the failed transaction back.

Observed output:

```text
sqlite=3.51.0 user_version=1 foreign_keys=ON rollback=verified
```

The probe directory was removed after execution and did not modify the repo.

### 4.3 Local storage API probe

Foundation returned:

```text
URL.applicationSupportDirectory = ~/Library/Application Support
URL.cachesDirectory = ~/Library/Caches
```

Apple's current guidance assigns required private support files to Application
Support and discardable/reconstructible files to Caches. Production code will
append the bundle-identifier subdirectory and tests will inject temporary
locations instead of touching the real user store.

## 5. Options Considered

### 5.1 System SQLite + repository-owned wrapper — selected

Benefits:

- already shipped and updated with macOS;
- no network/package dependency for the production store;
- exact control over schema, migrations, binding and error mapping;
- small API surface can be reviewed against Stornaut's privacy lifecycle;
- no ORM-generated schema or generic persistence escape hatch.

Costs:

- Stornaut must correctly own statement finalization, bindings and return-code
  mapping;
- more low-level tests are required;
- the wrapper must remain narrow rather than grow into a local ORM.

### 5.2 GRDB — not selected for Phase B

GRDB is mature, MIT and has a system SQLite target. It would reduce low-level
boilerplate and supplies strong migration/query abstractions. It is not needed
for the deliberately small Phase B schema, adds a large third-party production
surface, and would make the security/privacy review depend on substantially
more code.

Reconsider only if Task 11 demonstrates that the narrow wrapper is becoming an
unsafe home-grown ORM rather than a connection/statement boundary.

### 5.3 SQLite.swift — not selected

SQLite.swift is MIT and type-oriented, but its current package declares
additional CSQLite and SQLCipher package dependencies even when Apple defaults
to system SQLite. The extra resolution/build surface is not justified by the
Phase B schema.

### 5.4 JSON/plist files — rejected

Separate files do not provide the required atomic migrations, referential
integrity, paging, retention queries and partial-record isolation. Rewriting a
whole scan document would also conflict with incremental persistence and
bounded-memory goals.

### 5.5 Core Data / SwiftData — rejected for this phase

They provide Apple-native object persistence, but Stornaut needs explicit,
portable migration fixtures, exact TTL queries and a storage contract that can
be inspected with the SQLite CLI. Object-graph semantics also encourage loading
relationships that the paged scan architecture intentionally avoids.

## 6. Stornaut Persistence Brief

### Connection ownership

- Evidence and Local Knowledge each have one actor that owns the role's raw
  connection and every prepared statement.
- Callers use typed async repository methods.
- Each connection opens with read/write/create and full-mutex flags.
- No raw connection, SQL string or statement escapes its store module.
- Cancellation is observed between bounded batches; interrupted writes roll
  back rather than committing a falsely complete session.

### Configuration

Every connection verifies:

```text
PRAGMA foreign_keys = ON
PRAGMA synchronous = FULL
PRAGMA journal_mode = DELETE
PRAGMA application_id
PRAGMA user_version
```

Each role receives a distinct Stornaut-owned `application_id` in Task 11. A
zero ID is initialized only for a new empty database; a mismatched nonzero role
ID is rejected.

### Journal mode

Phase B starts with SQLite's DELETE rollback journal:

- each role uses one serialized connection;
- WAL's read/write concurrency benefit is not currently used;
- avoiding `-wal`/`-shm` files simplifies clear/export/corruption handling;
- bounded transactions prevent long writer monopolization.

Opening explicitly transitions and verifies `journal_mode=DELETE`, including a
database previously left in WAL mode. WAL may be reconsidered only with
measured UI-read/write contention and an ADR covering checkpoints, backup and
sidecar lifecycle.

### Migrations and downgrade behavior

- `user_version` is the authoritative schema version.
- Each migration validates its exact source version.
- Migrations run in order inside `BEGIN IMMEDIATE`.
- Any statement, foreign-key or validation failure rolls back the full step.
- A future schema version is opened only far enough to report
  `unsupportedFutureSchema`; it is not downgraded or mutated.
- No destructive "reset on migration error" occurs automatically.

### Corruption and backup

- Connection/open errors are typed and never converted to an empty history.
- Task 11 checks `quick_check` on opening fixtures and uses full
  `integrity_check` only for explicit diagnostics.
- Per-record decode failures isolate that record in query projections.
- Database-level corruption blocks writes and offers a separate export/reset
  path; it is not silently deleted.
- Evidence corruption remains independent from Local Knowledge corruption.
- Any migration backup uses SQLite's backup API, not a live file copy.

### Local data boundaries

Durable private directory:

```text
~/Library/Application Support/com.eriklee.stornaut/
```

It contains separate `Evidence.sqlite` and `LocalKnowledge.sqlite` roles. The
directory must be a current-user-owned non-symlink with mode `0700`; database
files must be current-user-owned non-symlinks with mode `0600`.

Discardable:

```text
~/Library/Caches/com.eriklee.stornaut/
```

The database never stores raw controlled snippets, raw Codex JSONL, free-text
Agent memory or generic blobs. Tests use injected temporary roots.

Evidence is excluded from system backup so a backup cannot silently extend its
seven/90-day lifecycle. Local Knowledge remains backup-eligible because it is
durable user-confirmed state and contains no raw Evidence payload.

Normal database operations do not need `NSFileCoordinator`: the stores are
private and actor-owned. Export uses SQLite's backup API to create a closed
snapshot before any coordinated/atomic destination write.

## 7. Tests and Fixtures Required by Tasks 10–11

- versioned anonymous domain JSON fixtures;
- fresh schema creation and exact schema snapshot;
- migration from every checked-in old version;
- transaction rollback under injected migration failure;
- future-version refusal without mutation;
- foreign-key and distinct role `application_id` checks;
- transition from WAL to verified DELETE journal mode;
- prepared-statement binding of null/text/integer/blob-rejection cases;
- per-record decode corruption isolation;
- role-separated database corruption diagnosis without silent reset;
- seven-day evidence and 90-day minimal Manifest expiry with injected clock;
- separate clear-evidence/clear-manifest behavior;
- Evidence backup exclusion and Local Knowledge backup eligibility;
- owner/no-symlink/`0700`/`0600` storage checks;
- Application Support/Caches path selection under injected roots;
- paged/indexed query-plan assertions.

## 8. License and Dependency Boundary

Task 9 adds no package or shipped dependency. SQLite is an Apple system
library. GRDB and SQLite.swift are comparison-only sources. Their license text
does not enter the product because no code is copied or linked.

## 9. Relative Improvement

The selected approach keeps SQLite's transaction and query strengths while
making retention, privacy and migration behavior explicit in a small,
Stornaut-owned boundary. It avoids both an opaque object graph and a generic
database abstraction that could accidentally persist raw investigation data.
