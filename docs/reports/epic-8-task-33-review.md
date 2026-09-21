# Epic 8 Task 33 Code Review and Completion Audit

> Status: Complete; independent review and authoritative full verifier passed
>
> Date: 2026-08-14
>
> Baseline:
> `2ce21ce6cac4c89ee3936fff16dd9f7f4d44851b`
>
> Scope: Scan-owned Cleanup Result, immutable Manifest/journal projection,
> typed Evidence enrichment, read-only Manifest detail and recovery-safe local
> actions

## 1. Delivered Boundary

Task 33 implements:

```text
Review preflight + exact confirmation
→ closed progress/terminal event stream
→ exact Plan/selection/Policy/identity terminal admission
→ immutable Core CleanupExecutionResult
→ typed retained-or-expired display enrichment
→ Reversible First Cleanup Result
→ read-only Manifest detail
→ Done returns to Scan Results
```

Production `AppDependencies` remains `ReviewExecutionAvailability.writeDisabled`.
The production graph does not construct `CleanupExecutionCoordinator`,
`ActionExecutor`, `TrashMoving` or `FileManagerTrashAdapter`.

Normal DEBUG Cleanup fixtures now execute the same Review
preflight/confirmation/terminal route used by the App model. Only the corrupt
record fixture directly enters an isolated corrupt presentation.

## 2. Truth and Recovery Contracts

- only the first manifest-bearing Core terminal state can route to Cleanup
  Result;
- terminal admission binds the exact Plan ID, selection generation and
  fingerprint, ordered item IDs, confirmation totals/action, preflight
  `PolicyDecision` IDs/reasons/dispositions, expected identities and candidate
  measures;
- stream completion without an accepted terminal remains
  `missingTerminal`;
- one accepted terminal ends the consumer even if the producer stays open;
- typed enrichment carries an explicit retained/expired state and exact Plan
  identity/Evidence fingerprint binding;
- the immutable Manifest supplies all rows, counts and byte measures;
- Trash, permanent release and system-observed free-space delta remain
  separate;
- unknown outcome outranks audit durability and never offers retry;
- audit retry accepts only a valid journal transition for the exact immutable
  Manifest;
- Open Trash is an App-owned navigation dependency and never changes execution
  truth;
- there is no restore, Empty Trash, permanent-delete fallback or blind retry.

## 3. Native UI

The Scan-owned page contains:

- terminal outcome, Manifest persistence and a bilingual terminal count/byte
  summary;
- literal moved-to-Trash bytes and moved-item count;
- independent Processed, Permanently Released and System Observation metrics;
- a five-column native result Table;
- collapsed Accounting Details;
- one Open Trash, one View Manifest and one primary Done;
- a read-only Manifest detail with identity, ordered actions, closed Policy
  reasons, recovery context, Evidence lineage, candidate/processed/Trash/
  permanent measures and signed system deltas.

The actual `1180 × 760` App window has no horizontal Table scrollbar. Dynamic
outcome/result/recovery localization uses closed pre-resolved strings, so raw
localization keys are not exposed through AX.

## 4. Tests-First Evidence

The initial Task 33 tests were written before implementation and failed to
compile:

```text
/tmp/stornaut-task33-red-tests.log
SHA-256 61ddd3e55d4ac828601b2d0f09bb370ec04d7aff3ee3ebaed722839d38f5efaf
```

Independent review findings also received a post-review red witness before
their implementation:

```text
/tmp/stornaut-task33-review-red.log
SHA-256 db30d566120b96d8c3cfdeb65cd4e0403dd52225d876580158b979005c926b34
```

The latter failed at the missing typed `CleanupResultEnrichment` contract and
new regression assertions before the fixes existed.

## 5. Independent Review Findings

Review used:

- `bits-code-guard` seven-dimension local fallback over tracked and untracked
  Task 33 files;
- read-only `codex exec` with official `openai` `gpt-5.6-luna`, high reasoning,
  no approvals and ephemeral session;
- manual terminal/concurrency/accounting/UI audit;
- actual App/Peekaboo screenshot and AX inspection.

The initial independent review found `0 P0`, `6 P1` and `4 P2`.

### 5.1 Terminal result was not fully bound to Plan/Policy truth

**Severity before fix:** P1

**Disposition:** Fixed.

Admission now compares confirmation totals/action, exact selected Plan items,
preflight Policy decisions, identities and candidate measures.

### 5.2 DEBUG fixtures bypassed terminal admission

**Severity before fix:** P1

**Disposition:** Fixed.

Normal fixtures now require explicit preflight and confirmation and emit their
terminal through `ReviewExecutionEvent`. The corrupt fixture remains the only
direct isolated state.

### 5.3 Accepted terminal could leave an execution task alive

**Severity before fix:** P1

**Disposition:** Fixed.

The consumer breaks after the first accepted terminal; execution generations
guard late completion/error paths, and Done cancels any residual task.

### 5.4 Audit retry accepted a different run

**Severity before fix:** P1

**Disposition:** Fixed.

The reducer requires exact Manifest equality and
`CleanupRunJournal.canTransition(to:)`.

### 5.5 Unknown outcome could be masked by audit pending

**Severity before fix:** P1

**Disposition:** Fixed.

Unknown rows outrank durability presentation and suppress audit retry.

### 5.6 Evidence retention was inferred from non-empty facts

**Severity before fix:** P1

**Disposition:** Fixed.

`CleanupResultEnrichment` carries explicit retention state and Plan-bound
identity/Evidence fingerprints.

### 5.7 Negative system deltas lost their sign

**Severity before fix:** P2

**Disposition:** Fixed.

A closed signed formatter covers negative, zero and positive deltas.

### 5.8 Partially failed moved rows were not counted

**Severity before fix:** P2

**Disposition:** Fixed.

Moved-item count is derived from `.movedToTrash` recovery, and moved bytes make
the overall failed mix `Completed with Issues`.

### 5.9 Manifest detail omitted approved facts

**Severity before fix:** P2

**Disposition:** Fixed.

The detail now renders candidate/permanent measures, closed Policy reasons,
recovery context, Evidence lineage and signed observation deltas.

### 5.10 VoiceOver lacked one terminal summary

**Severity before fix:** P2

**Disposition:** Fixed.

A visible bilingual caption announces success/failure/cancelled/unknown counts
plus separate Trash and permanent bytes. A DEBUG AppKit probe makes the same
closed values stable for XCUITest.

Review artifacts:

```text
/tmp/stornaut_task33_code_review/report.html
/tmp/stornaut_task33_code_review/report.md
/tmp/stornaut-task33-codex-review-final.txt
SHA-256 0a1c522fbc9385dcf619002256c8f1e2b5536248f51c7dad0c1d5744c7c13964
```

The first post-fix pass found five additional P2 edges:

- a no-terminal infinite stream needed an explicit Stop Waiting exit;
- rejected enrichment could poison a later Review attempt;
- unknown audit-pending truth needed a reducer-level retry veto;
- missing system observation needed an explicit Manifest unavailable row;
- zero-byte moved items still needed Open Trash.

All five received tests-first fixes. A second post-fix red witness is:

```text
/tmp/stornaut-task33-postfix-red.log
SHA-256 8af9316c7b93f2cdb19342bf3ff615e69e1988599d1e6c468d3805985a39413f
```

It failed at the missing `cancelReviewExecutionWait` contract before the
implementation existed.

The final read-only `gpt-5.6-luna` review concluded:

```text
zero unresolved P0–P2 findings
```

It explicitly verified Stop Waiting, admission reset, unknown audit-retry
blocking, absent-observation presentation, zero-byte Trash navigation, the
original ten findings, Task 31 fresh PolicyDecision compatibility and the
production `writeDisabled` boundary:

```text
/tmp/stornaut-task33-postfix2-review-final.txt
SHA-256 e22e1097e9a5e3ee0f67b4d98604fed5ffd4b1148852d8dd5778644227479af0
```

## 6. Focused Verification

### App tests

```text
StornautAppTests
175/175 passed
```

This includes exact terminal binding, open-producer lifecycle, typed Evidence
expiry, exact audit transition, unknown/audit priority, signed deltas,
partially-failed moved rows, complete Manifest facts and DEBUG auto-terminal
argument isolation.

The latest additions also prove Stop Waiting releases an infinite UI
consumer, unavailable admission resets before a new Review, unknown audit
retry is rejected by the reducer, zero-byte moved items retain Trash
navigation and legitimate Task 31 fresh per-item PolicyDecision bindings are
accepted without weakening Plan/identity/measure admission.

### Cleanup XCUITest

```text
testCleanupResultArrivesOnlyThroughTerminalReviewFlow
1/1 passed

testCleanupResultStatesAndManifest
1/1 passed

testReviewWorkflowStatesAndConfirmation
1/1 passed
```

The state matrix covers Completed Light/Dark, read-only Manifest detail,
partial, audit pending/retry, outcome unknown, Evidence expired, Trash-open
failure and `zh-Hans`. Every normal fixture first performs Review preflight and
confirmation and then accepts one terminal event.

### Structural and documentation gates

```text
scripts/verify-cleanup-result-boundaries
Cleanup Result boundary verification passed.

localization plist/key parity
passed

scripts/check-doc-links
passed

git diff --check
passed
```

## 7. Actual App Evidence

The signed Debug `.app` used the explicit DEBUG-only
`--stornaut-debug-auto-cleanup-terminal` harness, which still performs the real
Review preflight/confirmation/terminal flow before presentation.

```text
/tmp/stornaut-task33-postreview-actual.png
SHA-256 a5dfd3268a68e08c0a7f08ee9f66d77cc82374e8e1272ca99a2f3c5a4a3e6c15
window: 1180 × 760
```

Peekaboo confirmed:

- Scan remains the selected top-level destination;
- outcome is `Completed` and persistence is `Manifest Saved`;
- the visible/AX summary reports `2 succeeded`, zero failed/cancelled/unknown,
  300 kB moved to Trash and zero permanently released;
- five result columns fit without a horizontal scrollbar;
- rows say `Moved to Trash` and `Recoverable from Trash`;
- Open Trash, View Manifest and Done exist once;
- no permanent-delete, restore or Empty Trash action is present.

## 8. Scope Audit

Task 33 does not:

- enable real App Trash execution;
- construct an App Executor or authorization;
- add production Registered Actions;
- add restore, Empty Trash or permanent deletion;
- implement Manifest-aware History or Store v4;
- enable Deep Dive, Adapter or Shell cleanup;
- add background work, telemetry or a dependency;
- change release/notarization scope.

Task 35 remains the only owner of signed-App disposable real Trash admission
and still requires separate explicit user opt-in.

## 9. Final Gate

The final post-fix independent Codex review reported zero unresolved P0–P2.
The authoritative verifier then completed in one uninterrupted run:

```text
scripts/verify --full
exit 0
elapsed 757.406 s
log SHA-256 e33fbf40efb6ae38d49b3bb0658cb88b34657a0a03796ec93d9d550b2f9e8b70
```

Final evidence:

- XCUITest: 14/14 passed;
- canonical window screenshots: 30/30 exported and validated;
- SwiftPM: 610 tests in 21 suites passed;
- App tests and committed view snapshots passed;
- three matcher benchmarks passed;
- all Review/Cleanup/no-Executor/App UI source boundaries passed;
- Debug App build, local signing and bundle verification passed;
- Release fixture isolation passed;
- localization plist/key parity passed;
- rule/compiler/catalog parity passed;
- verifier contract, Markdown links and `git diff --check` passed.

The screenshot sanity gate now gives the intentionally sparse Review empty
state and native dimmed stale modal their own narrow non-blank variance bands.
The actual images and AX content were inspected before that change; all other
window thresholds remain unchanged.

During earlier UI attempts, Raycast/TOS Browser and user interaction stole
focus. The original failures were retained, the exact affected cases were
rerun, and no product change was made unless a retry reproduced the issue.
That process exposed and fixed one genuine Review Inspector horizontal
overflow. The final 14-case authoritative run completed without focus
interference.

Task 33 is complete. Production execution remains `writeDisabled`; Task 34 is
the next deterministic Epic 8 iteration. Task 35 still owns any signed-App
disposable real Trash diagnostic and requires fresh explicit user opt-in.
