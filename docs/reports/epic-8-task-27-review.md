# Epic 8 Task 27 Code and Design Review

> Status: Passed after confirmed findings were corrected
>
> Date: 2026-08-11
>
> Scope: approved-plan routing, Epic 8 upstream study, ADR 0011, ADR 0012
> and Task 27 implementation brief

## 1. Review Scope

The final review covered all 16 Task 27 changed files:

```text
AGENTS.md
StornautApp/History/HistoryView.swift
StornautAppUITests/StornautAppUITests.swift
docs/README.md
docs/adr/README.md
docs/adr/0011-review-policy-authorization.md
docs/adr/0012-cleanup-execution-journal.md
docs/agent/coding-agent-handoff.md
docs/plans/active/README.md
docs/plans/active/epic-8-safe-execution-vertical-slice.md
docs/plans/active/task-27-implementation-brief.md
docs/plans/roadmap.md
docs/reports/README.md
docs/reports/epic-8-task-27-review.md
docs/upstream-studies/README.md
docs/upstream-studies/epic-8-safe-execution.md
```

Review inputs included:

- complete tracked diff;
- complete `/dev/null → new file` diff for the four untracked documents;
- current Action/Policy/Store/Rule/Activity source contracts;
- current SDK headers and compiled Swift API witnesses;
- pinned upstream source and official cache documents;
- Rule Catalog, signing and read-only Store diagnostics;
- failed full-verifier xcresult plus an independent focused UI rerun.

## 2. Review Method

The repository's preferred `bits-code-guard` workflow was invoked against the
working tree. Its `diff_and_filter.py` classified every Markdown file as
binary/media and omitted untracked files, producing zero review files. That
output was rejected as a coverage signal.

The documented no-subagent/filter fallback was then applied manually:

- logic and state-transition consistency;
- product/business semantics;
- disk-write/security boundary;
- concurrency/TOCTOU ordering;
- persistence and crash robustness;
- performance/boundedness assumptions;
- documentation quality only where it affected implementability.

The final manually assembled review input contained 2,390 diff lines across 11
tracked and five new files. No repository-specific custom workflow was
configured.

## 3. Confirmed Findings and Corrections

### 3.1 Direct uv Trash contradicted uv's lock contract

**Severity before fix:** P1 safety/business semantics
**Disposition:** Fixed

The approved draft proposed `.cache/uv` as default Ready. Current pinned uv
documentation explicitly says direct cache modification/removal is never safe
and that `uv cache` mutation waits on uv's own cache lock.

Correction:

- remove uv from the Phase C execution profile;
- keep it visible as non-executable Review classification context;
- defer a fixed, versioned `uv cache` Registered Action to Phase E.

### 3.2 Journal start was ordered before fresh Policy/preflight

**Severity before fix:** P1 crash/audit semantics
**Disposition:** Fixed

The initial Task 31 sequence grouped prepared/start persistence before fresh
context and Policy. A crash in that broad interval could produce an Unknown
action that had not reached the actual execution boundary.

Correction:

```text
prepared
→ fresh Policy
→ ActionPolicy preflight
→ actionStarted
→ ActionExecutor.execute(final revalidation → Trash)
```

The remaining crash window is conservative and intentional: any persisted
start without a durable result remains Unknown and is never replayed.

### 3.3 Configuration-override proof was not implementable in the closed profile

**Severity before fix:** P2 implementability/robustness
**Disposition:** Fixed

The first wording required proof that npm/pip/Go had no cache relocation while
also forbidding tool execution and arbitrary configuration reads. That could
not be generically satisfied.

Correction:

- profiles recognize only the checked-in exact built-in paths;
- they never follow an environment/configuration override to expand
  eligibility;
- an override path remains non-executable;
- no external tool is launched for path discovery.

### 3.4 Unresolved-journal retention terminology conflicted with recovery

**Severity before fix:** P2 lifecycle semantics
**Disposition:** Fixed

The plan referred to a 90-day `unresolved-journal`, while ADR recovery requires
an unresolved started action to become an immutable Unknown Manifest.

Correction:

- recover started-without-outcome into an Unknown Manifest;
- retain a journal to 90 days only when Manifest persistence itself is
  `auditPending`;
- align Clear Evidence/Clear Manifests behavior with this distinction.

## 4. UI Verifier Triage

The first current `scripts/verify` run failed one existing XCUITest:

```text
testQuickScanProgressResultsAndInspector
```

xcresult activity localized the failure to the shared `navigate` helper:

- the click synthesis for `sidebar.scan` took approximately 5.6 seconds;
- the helper then did not observe `scan.results.table` within its five-second
  post-click wait;
- no Scan content assertion had started.

An independent-process focused rerun passed `1/1` in 49.7 seconds with no
source change. This supports a load-sensitive runner/navigation event rather
than a deterministic product failure. Task 27 does not weaken assertions or
increase timeouts on that evidence alone.

The final Task gate still requires one fresh uninterrupted `scripts/verify`.
If the same navigation failure recurs, it must be fixed and repeated rather
than waived.

### 4.1 Screenshot gate caught the wrong foreground Settings window

**Severity before fix:** P1 verification reliability  \
**Disposition:** Fixed

The next full verifier passed all nine XCUITests and exported all 17 required
screenshots, but the theme gate rejected `stornaut-settings-dark`:

```text
mean luminance 168.88
```

The screenshot's OCR contained System Settings content such as Siri, iCloud,
Apple Pay and `testmanagerd`, while `settings.appearance` correctly reported
`dark`. XCUITest activity also showed `com.apple.systempreferences` interrupting
the teardown path. The test had activated Stornaut only when its Settings
window was not hittable; a hittable background window could therefore be
captured while System Settings remained foreground.

Correction:

- unconditionally activate Stornaut before the Settings screenshot;
- click the known Stornaut Settings sidebar element to establish foreground
  focus;
- wait again for both the window and sidebar to remain hittable;
- keep the existing semantic dark-appearance assertion and luminance gate.

Three independent-process focused repetitions passed. Each Settings screenshot
measured mean luminance `42.88` with standard deviation `22.14`; none contained
the external System Settings surface.

### 4.2 High-load AX clicks used stale or ambiguous nodes

**Severity before fix:** P1 verification reliability  \
**Disposition:** Fixed

With System Settings still open and the full suite under load, two additional
existing tests exposed the same class of automation defect:

- a language Picker menu item disappeared between lookup and click;
- History's footer and confirmation buttons shared the visible label
  `Delete Record`, so an App-global query could select the non-hittable footer
  node behind the sheet;
- external/main-window AX interruptions could consume a click while the cached
  node remained stale.

Correction:

- every critical action now activates Stornaut, re-queries the current node,
  clicks it, and waits for the intended typed state change, retrying once;
- Picker retries reopen the menu and reacquire the current menu item;
- History confirmation has the semantic identifier
  `history.delete.confirm.action`;
- History confirmation success is the record count decreasing, not merely the
  dialog disappearing;
- scrollable History footer actions may use an existing node so XCUITest can
  perform its normal scroll-to-visible behavior.

Focused evidence with System Settings left running:

- Dark Settings screenshot: `3/3` independent processes passed;
- immediate Settings preferences/deletion: `3/3` independent processes passed;
- History delete/trend: `3/3` independent processes passed.

### 4.3 Main-window screenshot also required foreground-state proof

**Severity before fix:** P1 verification reliability  \
**Disposition:** Fixed

After the interaction fixes, the full suite passed all nine XCUITests and
exported all screenshots, but `stornaut-shell-dark` measured only `4.45` mean
luminance with `8.46` standard deviation. OCR proved that the expected
Stornaut content existed, but the image represented a non-frontmost/occluded
window state rather than the historical Dark shell baseline near `39`.

Correction:

- screenshot focus helpers now require
  `XCUIApplication.state == .runningForeground`;
- each Overview/Scan/History/Settings screenshot reactivates Stornaut and
  clicks a known semantic sidebar element before capture;
- action retries also wait for Stornaut's public foreground state;
- the image contract is unchanged.

Three independent-process Dark repetitions then produced:

- shell Dark mean `38.88`, standard deviation `28.40`;
- Settings Dark mean `42.89`, standard deviation `22.15`.

## 5. Final Findings

After the corrections above, the fresh review found:

- P0: 0;
- P1: 0 unresolved;
- P2: 0 unresolved.

No Rule JSON, SQLite schema, App workflow or real Trash path was added by Task
27. One semantic accessibility identifier and state-driven XCUITest helpers
were added after the verifier proved the old harness could capture or interact
with the wrong AX node.

## 6. Validation Contract

Task 27 passes only when:

- `scripts/check-doc-links` succeeds;
- `git diff --check` succeeds;
- profile/Task structure assertions succeed;
- normal Debug XcodeBuildMCP build succeeds;
- focused Scan UI rerun succeeds;
- dark Settings screenshot focus passes three independent-process repetitions
  and the luminance contract;
- one final uninterrupted `scripts/verify` succeeds;
- commit/push range contains only the documented Task 27 changes.

The generated local `bits-code-guard` fallback HTML/Markdown report is
supporting review evidence in `/tmp/stornaut_task27_review/`; it is not
committed.

## 7. Final Gate

The final uninterrupted `scripts/verify` exited `0`.

- log SHA-256:
  `a634ca746cee1eef26ea66206281db8a96ea442b17fda48a64eb65b388e4b1e4`;
- XCUITest: `9/9`;
- screenshot contract: 17 stable files, including shell Dark
  `38.88 / sd 28.40` and Settings Dark `42.89 / sd 22.15`;
- SwiftPM: `279/279` twice, three opt-in diagnostics skipped;
- matcher benchmarks: `0.231 s`, `0.375 s`, `0.504 s`;
- Phase B evidence gate and all source boundaries passed;
- App contracts, ad-hoc signed bundle, Release fixture isolation,
  localization parity and documentation links passed.

Task 27 has no unresolved P0–P2 finding and may be committed/pushed as one
iteration.
