# Epic 2–4 Task 25 Code Review — 2026-08-10

> 状态：All confirmed code-review and UI-review findings fixed; final automatic
> review has no open P0–P2 finding; unified verification passed
>
> 范围：closed Settings preferences、Primary Scan Root bookmark、user
> exclusions、Evidence/Manifest clear、Local Knowledge lifecycle、Codex
> discovery status、六区原生 Settings、app-local language/appearance、
> accessibility、Light/Dark 与 screenshot gates
>
> 方法：tests-first red baselines + current Apple Settings/bookmark study +
> five-group `bits-code-guard` fallback review + real App/XCUITest/Peekaboo

## 1. Delivered Contract

Task 25 replaces the foundation form with an independent six-section macOS
Settings scene:

1. General;
2. Scanning;
3. Permissions;
4. Codex & Deep Dive;
5. Privacy & Data;
6. Local Knowledge.

Only closed typed preferences are persisted:

- English or `zh-Hans`;
- System, Light or Dark;
- one Primary Scan Root bookmark;
- at most 64 normalized descendant exclusions;
- Focused, Balanced or Thorough investigation budget.

The next Quick Scan resolves the latest bookmark immediately before starting.
No configured bookmark means the explicit Home default. A configured stale or
unavailable bookmark blocks Scan instead of silently expanding to Home.
Security-scoped access is acquired only for Scan and retained until the product
stream terminates; Settings inspection does not acquire a lease.

User exclusions are explicit `.userExcluded` directory boundaries. The
boundary is persisted, descendants are not traversed, the session remains
partial and accounting keeps unavailable bytes in Unknown. Excluded paths are
never classified, assigned to an owner or represented as measured zero.

## 2. Confirmed Findings and Fixes

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P1 | Settings status/config reads acquired security-scoped access even though the approved lifetime starts immediately before Scan | Add non-acquiring bookmark inspection and use it for Settings/configuration; only `start()` owns a lease | bookmark inspect/Scan integration tests |
| P1 | Stale/unavailable bookmark copy claimed Home fallback while the runtime correctly failed closed | Change status and Permissions copy to `Scan blocked`; expose the actual root path/status | projection/localization/XCUITest |
| P1 | An exclusion chooser could use Home while a configured root was unavailable, then persist a relative path for the wrong root | Reject exclusion selection unless root status is Available or fallback-Home; disable the control otherwise | unavailable-root projection test |
| P1 | Exclusion matching used case-sensitive strings on default case-insensitive APFS volumes | Carry root-volume case sensitivity through Surveyor jobs and compare normalized components accordingly | case-sensitive/insensitive exclusion tests |
| P1 | A Settings refresh invalidated by Scan start could remain permanently Loading | Restore the retained snapshot and clear the stale refresh flight before starting Scan | suspended refresh/Scan test |
| P1 | Forgetting one Local Knowledge row set the total count to the bounded page size, corrupting totals above 100 rows | Decrement the persisted total only when the selected row was present | 101-row count regression |
| P1 | Root bookmark persistence could succeed and a subsequent facts reload fail, causing UI state to show the old root while Scan used the new root | Publish persisted preferences/root status before reload and preserve them in the error state | reload-failure root test |
| P2 | Dynamic confirmation action text and one Scan formatter bypassed app-local language selection | Route dynamic strings through `StornautLocalization` and add stable confirmation identifiers | Chinese mutation XCUITest |
| P2 | Window appearance probes sampled only at attach/update and could stay stale after an immediate preference change | Re-sample in `viewDidChangeEffectiveAppearance`; verify main and Settings windows | immediate appearance XCUITest |
| P2 | One-pixel/background AX probes and redundant navigation clicks produced false UI failures under macOS window restoration and external focus changes | Use full-page non-hittable probes and page-marker-aware XCUITest navigation | 9/9 final UI suite |
| P2 | App-state source gate rejected the word `Codex`, including pure Settings models, instead of only runtime services | Narrow the gate to Locator/Detector/Process/Bridge/service types | App-state and Settings source gates |

## 3. Data and Safety Boundaries

- Settings views send typed intents only. They do not construct stores,
  Surveyor, coordinator, Codex runtime, `NSOpenPanel`, `NSWorkspace`,
  `UserDefaults`, TCC or processes.
- Preferences use a versioned, size-bounded JSON payload in Stornaut-owned
  Application Support. The file is owner-only `0600` and replaced atomically.
- Unknown top-level keys, future schema, malformed values, oversized bookmarks,
  oversized payloads and unsafe storage fail closed.
- Evidence clear removes the scan-session graph only. Manifest clear remains a
  separate operation. Neither operation addresses target files, Trash or Local
  Knowledge.
- Local Knowledge remains closed, structured and user-confirmed. Single/all
  forgetting is confirmed; corrupt rows are isolated; no free-text creation,
  policy override or Agent-inferred fact is added.
- Codex installation, syntax support and Deep Dive safety are separate facts.
  Discovery never changes `Paused · Required`; there is no fake safety-check,
  provider, arbitrary flag, Shell or bypass control.
- Quick Scan still has no model/Codex/Probe Bridge/cleanup/target-write path.
  Deep Dive remains no-go/paused.

## 4. UI and Automation Evidence

Final unified XCUITest result:

- App tests: 95/95;
- XCUITest: 9/9;
- 17 stable screenshots exported and validated;
- language changes immediately to `zh-Hans`;
- main and Settings windows both change appearance immediately;
- Sidebar gear and `⌘,` open the independent Settings scene;
- confirmed Evidence clear and Local Knowledge forget execute typed mutations;
- all six sections and representative populated states are reachable.

Task 25 screenshot statistics from the final verifier:

| Screenshot | Mean luminance | Standard deviation |
| --- | ---: | ---: |
| Scanning Light | 244.32 | 29.94 |
| Privacy & Data Light | 244.43 | 29.28 |
| Codex Dark | 46.45 | 23.18 |
| Local Knowledge Dark | 47.95 | 28.78 |

Final read-only Peekaboo inspection of the signed Debug App:

- Scanning Light: `900 × 648`, 234 AX elements, 163 interactable elements;
- Local Knowledge Dark: `900 × 648`, 234 AX elements, 159 interactable
  elements;
- no raw localization key appeared in visible AX label/title/description/value;
- Peekaboo performed no click, typing, hotkey or other mutation.

Automation Mode required user authentication on this host. UI test methods
executed normally after authentication. No no-authentication policy, root
daemon, TCC/SIP, Accessibility, Event Synthesizing or other system permission
was modified. Xcode emitted non-blocking `DebuggerVersionStore` /
`no debugger version` warnings during runner launches.

## 5. Unified Verification

Final `scripts/verify` exited 0 and proved:

- 269/269 functional/security SwiftPM tests;
- three matcher Benchmarks run independently with their original `< 2 s`
  assertions: approximately `0.72 s`, `1.92 s` and `1.44 s` in the final run;
- App tests 95/95;
- XCUITest 9/9;
- all 17 screenshot files, dimensions, content variance and Light/Dark
  luminance contracts;
- App/state/Overview/Scan/History/Settings boundaries;
- local signing and App bundle validation;
- Debug fixture markers absent from Release;
- localization plist lint and English/`zh-Hans` key parity;
- deterministic rule compiler and complete 67-rule catalog hash
  `133b3829816fa951f03cb87473e03454c3e561b421c83e6c8efaf8ad89849e99`;
- all local Markdown links and `git diff --check`.

The matcher Benchmarks remain hard 2-second gates. The unified verifier runs
them separately from the 269-way functional/security pool so wall-clock
measurements do not race other CPU-heavy tests. A load-sensitive fake Codex
nonzero-exit test retains its exact `.nonzeroExit(status: 7)` assertion and uses
a five-second test budget; focused execution remains about 0.4 seconds.

The final automatic review artifacts are retained at:

- `/tmp/stornaut_task25_review/report.html`;
- `/tmp/stornaut_task25_review/report.md`.

The grouped review covered 58 tracked/untracked files and approximately 6,221
changed lines after final fixes. Post-fix review has no open P0–P2 finding.

## 6. Remaining Boundaries

- Task 26 owns the Phase B real-machine evidence gate, final benchmark,
  architecture drift report and plan lifecycle closure.
- Phase B still has one root/scope/ledger. Task 25 does not pretend to deliver
  multi-root accounting.
- The public SDK still provides no general FDA-state query; Settings remains
  conservative and Task 26 owns packaged-App coverage evidence.
- Investigations remains a placeholder and Deep Dive remains no-go/paused.
- Real cleanup, Trash workflow, release signing, notarization, telemetry,
  background work and remote services remain outside Task 25.
