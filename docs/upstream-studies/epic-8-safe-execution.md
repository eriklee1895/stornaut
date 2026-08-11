# Epic 8 Safe Execution Upstream Study

> Status: Accepted for Phase C Tasks 28–35
>
> Date: 2026-08-11
>
> Coding Agent: TRAE CLI
>
> Scope: Review, Policy, one-shot authorization, native Trash, crash journal,
> immutable Manifest, accounting and initial exact execution profiles

## 1. Executive Conclusion

Phase C may proceed with a narrower deterministic execution profile:

```text
Ready/default selected:
  cache-npm-content
  cache-pip

Review/unselected:
  cache-go-build

No execution profile:
  cache-uv
  every other catalog rule
```

The main plan's architecture is viable only with two explicit additions:

1. confirmation must mint a non-persistable, one-shot admission distinct from
   Plan, selection and Policy;
2. a write-ahead journal must precede each filesystem mutation and convert
   any started-without-outcome crash into immutable `outcomeUnknown`, never an
   automatic retry.

uv is removed from the execution profile. Its pinned official documentation
states that direct cache modification/removal is never safe because its own
commands coordinate cache locks. Phase C has no uv Registered Action.

No source code is copied from upstream projects and no dependency is added.

## 2. Reproducible Baseline

### Repository and machine

| Fact | Evidence |
| --- | --- |
| Baseline HEAD | `e4f936a99e257e55c000111833bd460277dc2bc9` |
| Baseline commit | `docs: adopt integrity-first Codex investigation boundary`; descendant of approved plan commit `4cb49aa` |
| Branch/remote | `main`, equal to `origin/main` before Task 27 edits |
| macOS | 26.5.1, build `25F80` |
| Architecture | Apple Silicon `arm64` |
| Xcode | 26.6, build `17F113` |
| Swift | Apple Swift 6.3.3 |
| macOS SDK | `MacOSX26.5.sdk` |
| SQLite CLI | 3.51.0 |

Task 27 changes architecture documentation plus verification-only accessibility
and XCUITest contracts. It does not invoke Foundation Trash, change TCC/FDA,
request Accessibility/Event Synthesizing or touch target data.

### Current Store

Source baseline:

- Evidence Store schema constant: `2`;
- application ID: `0x53544E45`;
- seven-day Evidence and 90-day Manifest limits;
- `journal_mode=DELETE`, `synchronous=FULL`, `trusted_schema=OFF`,
  `foreign_keys=ON` on Store connections;
- existing Cleanup Plan/Policy/Manifest tables;
- current Manifest save path is upsert-capable.

Read-only live database observation:

| PRAGMA/check | Value |
| --- | --- |
| `user_version` | `2` |
| `application_id` | `1398033989` |
| `journal_mode` | `delete` |
| `quick_check` | `ok` |

The standalone sqlite3 read-only connection reported `foreign_keys=0`; that
PRAGMA is connection-local. Runtime Store diagnostics/tests, not an unrelated
CLI connection, must prove the production connection has it enabled.

### Rule Catalog

Compiled built-in Catalog:

- version `builtin-runtime-tool-residue-v1`;
- schema `1`;
- 67 rules;
- 34 rules recommend `moveToTrash`;
- zero production rules have base `readyToReclaim`;
- runtime JSON SHA-256:
  `133b3829816fa951f03cb87473e03454c3e561b421c83e6c8efaf8ad89849e99`.

The four proposed rules are exact directory patterns and currently
`reviewRecommended`. Positive, active, configuration-lookalike and
runtime/source-lookalike fixtures exist for each.

### App identity

Current project settings:

- bundle identifier `com.eriklee.stornaut`;
- manual ad-hoc signing (`CODE_SIGN_IDENTITY = -`);
- App Sandbox disabled;
- hardened runtime disabled;
- source entitlement contains only
  `com.apple.security.app-sandbox = false`.

The repository-configured XcodeBuildMCP normal Debug build succeeded. Its App:

- verifies on disk;
- is an arm64 ad-hoc bundle with identifier `com.eriklee.stornaut`;
- has no Team identifier;
- carries App Sandbox disabled plus Debug `get-task-allow`;
- has no XCTest temporary file or mach-lookup exceptions.

The separate UI-test-built host also verifies on disk, but its embedded
entitlement set contains XCTest temporary exceptions and is not accepted as
the Task 35 normal signed-App Trash evidence. Neither build performs the Task
35 real Trash diagnostic.

## 3. Current Apple Platform Contract

### Foundation Trash

Xcode 26.6's `NSFileManager.h` declares:

```text
trashItemAtURL:resultingItemURL:error:
```

The header states:

- success means the item was moved to a Trash;
- collision handling may rename it;
- the resulting URL is returned by reference;
- failure means the item was not moved and returns an error;
- Trash membership can be checked with
  `getRelationship(... NSTrashDirectory ... toItemAtURL ...)`.

Swift 6.3.3 typechecked these imported shapes:

```swift
(URL, AutoreleasingUnsafeMutablePointer<NSURL?>?) throws -> Void

(
    UnsafeMutablePointer<FileManager.URLRelationship>,
    FileManager.SearchPathDirectory,
    FileManager.SearchPathDomainMask,
    URL
) throws -> Void
```

`NSWorkspace` also exposes `recycleURLs`, but it is asynchronous, may show
system UI and reports a batch dictionary. Phase C keeps the already tested
Foundation primitive so the Executor owns one typed item and exact receipt.

Opening Trash later may use a typed App dependency backed by system location
and `NSWorkspace.open`; Views do not call AppKit directly.

Context7 and ordinary web search did not expose an authoritative indexed
Foundation Trash page. The accepted API evidence is the current Xcode SDK
header plus compiled Swift witness, as in ADR 0006.

### SwiftUI

Context7 resolved Apple's current SwiftUI index as
`/websites/developer_apple_swiftui`. It and an Xcode SDK typecheck witness
confirmed the planned macOS surfaces:

- selectable `Table`;
- `.inspector(isPresented:content:)`;
- `.confirmationDialog`;
- `.sheet`;
- `@FocusState`;
- accessibility labels/input labels;
- `@Environment(\.accessibilityReduceMotion)`.

The witness is API evidence, not visual acceptance. Tasks 32–34 still require
actual `.app` launch, read-only Peekaboo inspection, XCUITest and screenshots.

## 4. Upstream Snapshots

| Source | Commit/version | License | Files reviewed |
| --- | --- | --- | --- |
| [PureMac](https://github.com/momenbasel/PureMac) | `3e66888445f8896f89424eb951e3f94df095c5d3` | MIT | `AppState.swift`, `CleaningEngine.swift`, `FullDiskAccessManager.swift`, `OrphanSafetyPolicy.swift`, license |
| [ClearDisk](https://github.com/bysiber/cleardisk) | `1aaec92b91c40fdc0c2fce92fef20df08b5f5c43` | MIT | `DiskMonitor.swift`, license |
| [devklean](https://github.com/smurftyy/devklean) | `ce61a18343d67dc67d6e75bcab980a9954097a59` | MIT | deletion safety/trash/integrity/history, dry-run/safety/deletion/integrity tests, license |
| [Cluttered](https://github.com/gatteo/cluttered) | `03b38ad83df47adf0c6eba273e14a27b9f543258` | MIT | scanner, protection analyzer, cleaner service, IPC cleaner, confirmation/store, license |
| [Pearcleaner](https://github.com/alienator88/Pearcleaner) | `7724df7111bff82ae243301cf701992ef05ecf19` | Apache-2.0 + Commons Clause | `UndoManager.swift`, `UndoHistoryManager.swift`, history UI, license |
| Apple Foundation/AppKit/SwiftUI | Xcode 26.6 / macOS 26.5 SDK | Apple SDK terms | `NSFileManager.h`, `NSWorkspace.h`, compiled Swift witnesses, Apple SwiftUI docs index |

Selected source fingerprints:

| File | SHA-256 |
| --- | --- |
| PureMac `AppState.swift` | `79c08df2f97a29bd2410c2d72afbb8695d4e0a6fe1ac60f9d9664450d4841d2d` |
| PureMac `CleaningEngine.swift` | `4d80f9f8db0d43895cd9d0aae97e639d202a35b4f7b926e664d45db9c117aef2` |
| PureMac `FullDiskAccessManager.swift` | `4357fad4562e5517e7cf504aac9f5f16e80ca1c02514f233aae77bb51c965ed2` |
| ClearDisk `DiskMonitor.swift` | `4e0d766d3f6be1989e7d71efe2104461823c767fcb80735c10f08b18788cc7fb` |
| devklean `safety.py` | `54f2729d5cb489de3bf271836fa4f46c49e1b06d939b96c4f63ac8340976c782` |
| devklean `trash.py` | `063d688336c4884e0a1b7674157bfcb97847b11cb32a410a6aae49440213f28f` |
| devklean `integrity.py` | `9f06af223ab3fdea06fcebebaeb070af0b40921ac275ec68f6c4fda7d986f722` |
| Cluttered `cleaner.ts` | `bc3439c6485237085c067da1b27701c50270fbd71cbb7b47cc55d704d3072e8f` |
| Cluttered IPC `cleaner.ts` | `e1cc933440e0fe164c1cc2007ff7af95042ff2698960bf6a6a17574e7eaa6467` |
| Pearcleaner `UndoManager.swift` | `3d547170004dc73a3e511578b9ceff2fc86a0724cd1defee5830cdc4ce0a1ed0` |
| Pearcleaner `UndoHistoryManager.swift` | `7dbaec6cf920f50807704be84f5e3701f1d2d5e0a9ff3ee93ffa14239d8fcb1c` |

## 5. Upstream Findings

### 5.1 PureMac

Current PureMac explicitly calls `FileManager.trashItem` from its App process
because delegating to Finder attributes TCC behavior to Finder. It captures a
resulting URL and separates missing/permission/admin outcomes.

Useful:

- App process owns the privacy/signing context;
- distinguish permission from missing and generic failure;
- immediate path re-resolution before mutation;
- capture collision-aware Trash destination;
- Reduce Motion is considered in App state.

Rejected:

- treating missing as removed without expected identity;
- administrator permanent deletion;
- direct `removeItem`;
- emptying `~/.Trash`;
- `tccutil reset`;
- scheduler/login behavior;
- broad path allowlists.

PureMac is behavior evidence, not a safety template.

### 5.2 ClearDisk

ClearDisk:

- calls Foundation Trash;
- checks the original path afterwards;
- never falls back to permanent delete;
- rescans so a failed item reappears;
- records savings/history only for successful moves.

Its UI and variable names still call moved bytes `freed`. Stornaut adopts the
postcondition/no-fallback behavior but keeps Trash and free-space delta
separate.

### 5.3 devklean

devklean centralizes root/HOME/mount/symlink validation and makes dry-run return
before Trash or metadata persistence. Tests cover safety, no-write dry-run,
per-item failure, integrity and history.

Useful:

- structural no-write path;
- per-item outcome;
- partial failure remains explicit;
- history is not written for a failed item;
- integrity checks have dedicated regressions.

Rejected:

- generic cross-platform `send2trash` dependency;
- direct original deletion after a compressed archive reaches Trash;
- compression in Phase C;
- any symlink opt-out.

### 5.4 Cluttered

Cluttered proves why Stornaut needs one policy/execution contract:

- the scanner calculates Git/activity protection;
- one cleaner service rechecks protection;
- a separate global-cache IPC handler bypasses that service, allows stored
  command execution, directly trashes paths and calls moved size `bytesFreed`;
- UI confirmation promises “freeing” the selected size;
- basename-only AppleScript restore is collision-prone.

Stornaut therefore does not let UI, cache type or IPC route choose a different
Executor. Plan, Policy, authorization, coordinator and Manifest remain one
typed path.

### 5.5 Pearcleaner

Pearcleaner creates custom bundle folders in `~/.Trash`, persists exact
original↔Trash path pairs and cleans stale history when the bundle disappears.
This illustrates:

- collision-safe destination identity matters;
- persistent exact paths can enable best-effort restore;
- Trash changes make Undo history stale;
- restore can fail due to original-path collision or missing Trash state.

Stornaut does not copy this implementation, custom Trash layout, shell/helper
commands or persistent 90-day path pairs. The Commons Clause license makes it
behavior-reference-only.

## 6. Exact Cache Profile Study

### 6.1 npm `_cacache` — Ready after evidence

Pinned source:

- npm CLI commit `4cdcceac047f82571d0ec734e18b87d1d130e042`;
- Artistic-2.0;
- `docs/lib/content/commands/npm-cache.md`;
- document SHA-256
  `3d9c5739832541888eba6482b12ae7994b13e8dc1579fc57fc420f4b8cffe822`.

Official facts:

- `_cacache` is the opaque content-addressable cache under npm's configured
  cache;
- data is integrity-verified;
- missing/corrupt data is refetched;
- npm calls it strictly a cache and not a reliable persistent store;
- cleaning is unnecessary except for disk reclamation, but supported.

Accepted static evidence:

- exact built-in default path `.npm/_cacache`;
- directory kind;
- strict cache/tool-owned/reconstructible claims;
- low rebuild cost with network caveat.

Runtime evidence:

- exact path under the current Primary Root;
- current user ownership;
- no symlink/mount/root/denylist issue;
- complete identity/bytes/mtime/volume;
- inactive npm process family;
- no use of a configuration override to expand eligibility beyond this path.

Process-family candidates: `node`, `npm`, `npx`, `corepack`. A complete bounded
mapping is required; an unavailable process snapshot denies.

Lookalikes excluded: `.npmrc`, `.npm-global/lib`, `_npx` and the whole `.npm`
tree.

### 6.2 pip cache — Ready after evidence

Pinned source:

- pip commit `f399c3718970b1b0e2478dac5296eb62679a9b86`;
- MIT;
- `docs/html/topics/caching.md`;
- document SHA-256
  `92b8dfa54cd11f8c62381038455995a0c6c324c64254b9e52c795952b5cf5241`.

Official facts:

- pip caches HTTP responses and locally built wheels;
- `pip cache purge` clears wheel and HTTP caches;
- the macOS default is `~/Library/Caches/pip`;
- pip may use `XDG_CACHE_HOME`;
- internal cache structure is explicitly an implementation detail.

Accepted static evidence:

- exact default cache root `Library/Caches/pip`;
- root is tool-owned/reconstructible;
- do not inspect or classify internal sub-layout;
- low-to-medium rebuild/network cost.

Runtime evidence:

- exact default path, user ownership and complete filesystem identity;
- inactive Python/pip process family;
- no use of a cache-root override to expand eligibility;
- normal root/mount/symlink/denylist checks.

Process-family candidates: `python`, versioned Python basenames, `pip` and
versioned pip basenames. Exact normalization must be bounded and tested.

Lookalikes excluded: pip configuration and project `.venv`.

### 6.3 Go build cache — Review after evidence

Pinned source:

- Go commit `e5ec1263ca5e1428d233206b99dc21c38ea2a124`;
- BSD-3-Clause;
- `src/cmd/go/alldocs.go`;
- document SHA-256
  `09b0d7570c1695acc0ccad5593e3f5c2f888548cfc7f80a49933a19f3514aa69`.

Official facts:

- build outputs live in `go-build` under the OS user cache by default;
- `GOCACHE` can override the path;
- `go clean -cache` removes build cache;
- build cache is concurrency-safe and periodically pruned;
- test and fuzz caches share related cache semantics;
- rebuilds can be costly and cgo changes are a special case.

It remains `reviewRecommended`:

- the data is reconstructible;
- default path is exact;
- override and active toolchain risks require current evidence;
- build/test/fuzz performance cost deserves explicit selection.

Process-family candidates: `go`, `compile`, `link`, `asm`, `cgo`. Because these
helpers are generic names, Task 29 must prove an exact bounded strategy or fail
closed rather than accept substring matches.

Lookalikes excluded: `.config/go/env` and `go/pkg/mod`.

### 6.4 uv cache — no Phase C execution profile

Pinned source:

- uv commit `1881d30773386da77017f2ad5ceaf160535d65da`;
- MIT OR Apache-2.0;
- `docs/concepts/cache.md`;
- document SHA-256
  `5a5884336da9b2543edf898b53aab64aa22fba97d027e2f22ac398cd159a80f1`.

Official facts:

- cache path can be controlled by `--cache-dir`, `UV_CACHE_DIR` or settings;
- uv's cache is append-only, versioned and shared across concurrent commands;
- uv explicitly says direct cache modification/removal is never safe;
- `uv cache clean/prune` coordinates a cache lock and waits for active uv
  commands.

Moving `.cache/uv` directly to Trash would bypass uv's lock. Merely checking a
process snapshot cannot prove no operation starts after the check. Phase C
therefore gives uv no execution profile.

A future fixed, audited `uv cache` Registered Action may be considered in
Phase E with capability/version checks and its own confirmation semantics.

## 7. Decisions and Implementation Inputs

Task 27 accepts:

- [ADR 0011](../adr/0011-review-policy-authorization.md);
- [ADR 0012](../adr/0012-cleanup-execution-journal.md);
- exact profile: npm/pip Ready, Go Review, uv none;
- one shared evidence resolver for new Quick Scan and Review downgrade;
- no promotion of historical Protected/Unknown;
- one-shot 30-second admission;
- serial action execution and Stop After Current Action;
- write-ahead journal and immutable insert-only Manifest;
- seven-day path-rich recovery versus 90-day minimal audit;
- truthful non-causal accounting.

## 8. License and Provenance

- PureMac, ClearDisk, devklean and Cluttered are MIT behavior/test references.
- Pearcleaner is Apache-2.0 plus Commons Clause and remains source-available
  behavior reference only.
- npm docs are Artistic-2.0; pip docs are MIT; uv docs are MIT OR Apache-2.0;
  Go docs are BSD-3-Clause.
- Apple APIs are platform contracts under Apple SDK terms.
- No upstream code, assets or dependencies are copied.
- No new `ThirdPartyNotices` entry is needed for behavior-only links.

## 9. Validation and Limits

Task 27 validation:

- local SDK Trash and SwiftUI API witnesses typecheck;
- current Store/Catalog/App baseline is recorded;
- current upstream commits/licenses/files are pinned;
- the unified repository verifier is run after documentation changes;
- links and diff whitespace are checked;
- the final documentation diff receives an explicit review.

Limits:

- no real Trash was executed;
- no FDA claim is made;
- the UI-test host's XCTest entitlements are not product evidence;
- Task 35 remains the signed-App real Trash gate;
- process-family completeness is a Task 29 test obligation;
- performance thresholds remain Task 29/35 measurements.
