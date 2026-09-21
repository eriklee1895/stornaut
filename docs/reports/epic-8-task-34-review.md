# Epic 8 Task 34 Code Review and Completion Audit

> Status: Complete; authoritative full verifier passed
>
> Date: 2026-08-15
>
> Baseline:
> `435e2a050c516fa15f33b7fb8012610b7afc78e9`
>
> Scope: Manifest-aware typed History, independent retention clocks,
> privacy-bounded export and exact local-record deletion

## 1. Delivered Boundary

Task 34 extends History from scan-only records to one typed, read-only audit
union:

```text
Quick Scan session
Cleanup Manifest
isolated corrupt Quick Scan row
isolated corrupt Cleanup Manifest row
```

The implementation keeps Evidence Store schema v3. It joins the existing
seven-day Cleanup Plan to the existing ninety-day immutable Manifest only
while the exact Plan remains retained and identity-compatible. It creates no
duplicate History database and does not rewrite a Manifest.

Production execution remains `ReviewExecutionAvailability.writeDisabled`.
History has no `CleanupExecutionCoordinator`, `ActionExecutor`,
`TrashMoving`, restore, Empty Trash or permanent-delete surface.

## 2. Store and Lifecycle Contracts

- Manifest pages use stable `created_at_ms DESC, id ASC` ordering and continue
  across bounded pages.
- One coordinator read lease covers the complete multi-page scan/Manifest
  History snapshot, so Quick Scan and mutations cannot observe a partial join.
- Quick Scan records retain the existing seven-day clock; minimal Manifests
  use their independent ninety-day clock.
- Corrupt scan, ledger and Manifest rows are isolated by typed source.
- Plan enrichment requires the exact Manifest `planID`, compatible retained
  Plan, exact item membership and action/identity binding.
- Expired, missing, corrupt or mismatched Plan data exposes only minimal
  Manifest truth; no item name, path or Trash destination is reconstructed.
- Manifest deletion is one Store transaction. It removes only the selected
  Manifest and exactly matching audit/recovery journal.
- Scan deletion cannot delete a retained Manifest; Manifest deletion cannot
  delete a scan, Plan, Evidence, user file, Trash item or Local Knowledge.
- Clear Evidence and Clear Manifests remain separate lifecycle operations.

## 3. Native History and Export

History now provides:

- deterministic date/type/ID merge, filtering and selection;
- Quick Scan and Cleanup Manifest navigator rows;
- retained, Evidence-expired and corrupt Manifest states;
- immutable accounting with candidate, processed, moved-to-Trash, permanent
  and system-observed values kept separate;
- scan-only trend samples plus explicitly non-causal Manifest event markers;
- confirmed deletion of one local History record;
- a secondary native `Export Record…` action.

Export receives a typed `HistoryRecordID`, rebuilds the selected projection
from the current page and current clock, and refuses a fully expired record.
Quick Scan home prefixes are normalized to `~`; expired Manifest JSON contains
no item names, original paths or Trash destinations. Output is bounded to
1,000,000 bytes before the App-owned `NSSavePanel` write.

## 4. Tests-First Evidence

The initial Core tests were added before the Store APIs and failed to compile:

```text
/tmp/stornaut-task34-core-red.log
SHA-256 c87ff3abe6488f485a5a4275d7b968e78b2573272de34d696d1fe083015d93a1
```

Subsequent red witnesses covered:

- Manifest-pending audit journals omitted by Clear Manifests;
- complete multi-page History lease exclusion;
- Settings/Clear invalidation;
- stale delete success/failure completion;
- privacy-bounded export and typed default selection;
- closed Manifest error localization;
- refresh-versus-export generation ordering.

Representative post-review red evidence:

```text
/tmp/stornaut-task34-postfix-review-red.log
SHA-256 d20b8cd7827a9058acbd55bb3ed3e2d9531ccb188ea6aab0aea831d386daef44

/tmp/stornaut-task34-refresh-export-red.txt
SHA-256 a226e01503ebee5a1588e093f9a98605de218d1de2f15802474a03b09c349de6
```

The refresh/export witness passed 194 existing App tests and failed only the
new regression before the generation fix.

## 5. Independent Review Findings

Review used:

- read-only, ephemeral official `openai` `gpt-5.6-luna` with high reasoning;
- complete diff review against the Task 33 baseline;
- manual Store transaction, retention, concurrency, privacy, accounting and
  App composition audit;
- focused tests and actual App/Peekaboo evidence.

### 5.1 Export could retain stale Plan enrichment

**Severity before fix:** P1

**Disposition:** Fixed tests-first.

The App now exports by typed record ID and rebuilds the projection using the
current clock. Plan expiry therefore drops item names and paths even if the
loaded page was enriched earlier.

### 5.2 Default selection could choose a corrupt-ledger scan

**Severity before fix:** P2

**Disposition:** Fixed tests-first.

Typed-union fallback now preserves the Task 24 rule: keep an explicit valid
selection, otherwise prefer the first non-corrupt-ledger Quick Scan or valid
Manifest before falling back to an isolated corrupt row.

### 5.3 Export/delete completions could restore invalidated History

**Severity before fix:** P1

**Disposition:** Fixed tests-first.

Delete success, delete failure and export failure all verify the captured
History generation before writing UI state. Settings Clear and scan
invalidation cannot be overwritten by an older operation.

### 5.4 Refresh could be overwritten by an older export failure

**Severity before fix:** P1

**Disposition:** Fixed tests-first.

Every accepted History refresh now advances `historyGeneration` before it
starts loading. An export that captured page A therefore cannot replace an
accepted page B after its save dependency fails.

The first post-fix review that found this last race is:

```text
/tmp/stornaut-task34-post-fix-independent-review.txt
SHA-256 909023b14da98e356defb4eb0c78abae2eb58d65ad5793a34db43aa52888808b
```

The final complete read-only review concluded:

```text
zero unresolved P0–P2 findings
```

It explicitly rechecked refresh/export generation, stale refresh replacement,
scan/settings invalidation, exact typed IDs, Plan expiry, Store v3 retention,
Manifest deletion, export privacy, accounting, production `writeDisabled`
and production Deep Dive unavailability:

```text
/tmp/stornaut-task34-final-independent-review.txt
SHA-256 7c908beeae46bfa676f65fbb61d9333e2fa4c89e8d9c3c8306c99e18a6559fa8
```

## 6. Focused Verification

### Core

Focused Store and coordinator suites passed. The latest post-review run
included nine exact tests covering stable paging, retained exact Plan joins,
corrupt isolation, scan/Manifest independence, exact journal deletion and
complete History lease exclusion:

```text
/tmp/stornaut-task34-review-core-green.log
SHA-256 7be2ac6b45be21fa98a52fad0b03e77930189563911e5675a3ae89ae27e9df59
```

The broader Task 34 Core matrix passed 48/48 before final review.

### App

The final complete App target passed:

```text
StornautAppTests
195/195 passed
```

This includes typed merge/selection, retained/expired privacy, bounded JSON,
Clear lifecycle invalidation, stale delete/export completion, Plan-expiry
reprojection and refresh-versus-export ordering.

### History UI

Both focused History XCUITests passed:

```text
testHistoryPopulatedExpiredAndCorruptStates
testHistoryDeleteConfirmationAndStorageTrend
```

They cover retained/expired/corrupt Manifest states, English/`zh-Hans`,
confirmed typed deletion, scan preservation, secondary export and non-causal
Storage Trend.

### Structural checks

```text
scripts/verify-history-boundaries
Manifest-aware History UI/service boundaries verified.

scripts/verify-cleanup-result-boundaries
Cleanup Result boundary verification passed.

localization plist lint
passed

git diff --check
passed
```

## 7. Actual App Evidence

The locally signed Debug App was launched with the explicit DEBUG History
fixture and inspected through the repository's read-only Peekaboo harness:

```text
.derivedData/peekaboo/task34-history-final.png
SHA-256 029a7fe448719ca1073f632fa340616a5faa69add9130ab0536af3efdb58461c
pixels: 2680 × 1520
```

The actual window showed:

- History selected in the four-item top-level navigation;
- a Cleanup Manifest navigator row and Manifest detail;
- separate moved-to-Trash, permanent and system-observation facts;
- secondary Export and destructive local-record Delete actions;
- no Move to Trash, restore, Empty Trash or permanent-delete action;
- no raw localization keys or forced horizontal detail overflow.

Peekaboo evidence is supplemental. XCUITest and the authoritative verifier
remain the reproducible acceptance truth.

## 8. Scope Audit

Task 34 does not:

- enable the production `FileManagerTrashAdapter`;
- construct a production Executor or execution authorization;
- implement restore, Empty Trash or permanent deletion;
- persist exact paths beyond the seven-day linked Plan;
- create Store v4 or a second History database;
- expose the private execution journal as a History record;
- add Deep Dive, Adapter, Registered Action, telemetry or background work;
- change release, signing distribution or notarization scope.

Task 35 remains the sole owner of signed-App disposable real Trash evidence
and normal-App adapter admission. The user provided the required explicit
opt-in on 2026-08-15; its implementation and runtime evidence are not part of
Task 34.

## 9. Final Gate

The authoritative uninterrupted command passed:

```text
scripts/verify --full
```

Final evidence:

```text
exit: 0
elapsed: 826.52 seconds
XCUITest: passed in 551.818 seconds
UI screenshot contract: 30/30 exported and validated
SwiftPM: 619 tests in 21 suites passed
App target: 195/195 passed
log: /tmp/stornaut-task34-full-verify.log
SHA-256: a4e998d7dd81d4f4706b371c69e1e816da97120d936f6f87bc9833e5f5179af1
```

The same uninterrupted run also passed the matcher benchmarks, Phase B
product/cancellation evidence, all source boundaries, Automation Mode parser
self-test, signed Debug App bundle validation, Release fixture isolation,
localization, rule/compiler/catalog parity, verifier contract, local Markdown
links and diff hygiene.

Task 34 therefore closes with zero unresolved P0–P2 findings, production
execution still `writeDisabled`, production Deep Dive unavailable and no real
Trash operation performed.
