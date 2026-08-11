# Epic 2–4 Task 22 Code Review — 2026-08-10

> **Historical-scope notice (2026-08-11):** Deep Dive paused/no-go references
> record the reviewed Phase B scope, not current Codex policy. See capability-first
> [ADR 0004](../adr/0004-codex-file-read-isolation.md).

> 状态：All confirmed code-review findings fixed; final automatic review has
> no open P0–P2 finding; unified verification passed
>
> 范围：snapshot-first Overview projection、Space Ledger/Orbit、Top
> Opportunities、page-preserving states、DEBUG fixtures、VoiceOver、Light/Dark、
> English/`zh-Hans` 与 screenshot gates
>
> 方法：tests-first red baseline + current Apple accessibility study +
> grouped `bits-code-guard` fallback review + real App/XCUITest/Peekaboo

## 1. Study and Tests-First Baseline

- Current Apple SwiftUI documentation confirms custom Canvas charts should
  provide synthetic `accessibilityChildren`, while system semantic colors and
  native controls remain the default.
- The approved A+B canonical Overview supplies hierarchy only; no raster,
  sample number, path, raw palette or generated line wrap entered production.
- Initial App tests failed on the missing `OverviewModel`.
- `scripts/verify-overview-boundaries` failed on missing Overview source files.
- The first fixture attempt was rejected by real `PathSnapshot` invariants and
  fixed rather than bypassed.

## 2. Confirmed Review Findings and Fixes

| Severity | Finding | Fix | Regression evidence |
| --- | --- | --- | --- |
| P1 | App-state loading was initially described as an active Quick Scan | Separate App-owned `AppScanActivity`; store refresh is Loading and only typed active activity shows scan progress | loading/active projection tests + DEBUG loading fixture |
| P1 | Retained loading rendered a Quick Scan button whose action was nil | Disable the primary button when no safe action exists | action-state contract |
| P1 | `known > used` could be clamped to a fake 100% Explained value | Return Unknown ratio and render an explicit inconsistent-ledger state | inconsistent ledger regression |
| P1 | Ready bytes and opportunities trusted the persisted owner without rejoining classification truth | Require matching classification ID, target, category and disposition; fail Ready metric to Unknown on conflict | conflict regression |
| P1 | A Ready owner with no measured bytes could be silently dropped and shown as a smaller total or `0 B` | If any Ready owner is unmeasured, Ready metric is Unknown; only no Ready owner means measured zero | unmeasured Ready owner regression |
| P1 | Any activity/git record, including stale or provider-failure evidence, could show `Activity Checked` | Require current non-failure typed evidence; stale becomes Unknown and provider failure becomes Unavailable | activity freshness/failure regression |
| P1 | Overview had no production seam for scan-in-progress despite a test-only state | Move the closed scan activity enum into the App model and inject it into Overview | composition + fixture contract |
| P1 | Header omitted current coverage state | Add complete/limited localized icon+text Coverage badge backed by ledger truth | model/UI assertions |
| P1 | Orbit and Ledger visual totals used unchecked `UInt64` reduction | Use non-overflowing display ratios while retaining exact domain byte values | source review + existing Core overflow invariants |
| P1 | XCUITest window screenshots could capture another app behind transparent material while AX still reported the expected appearance | Use an opaque semantic page surface, bring the real main window frontmost through its selected Overview item, and require luminance plus standard deviation | six-image gate + PID Peekaboo captures |
| P1 | The initial screenshot gate accepted a nearly blank or wrong-window Light screenshot | Add Light range and minimum visual-content variance to all Overview screenshots | luminance/standard-deviation machine gate |
| P1 | DEBUG fixture isolation scanned only the old selector/value set | Add appearance selector and requested-appearance probe to Debug-positive/Release-negative App marker gate | Release boundary gate |
| P1 | Settings recovery attempted to click an obscured, non-hittable ScrollView after the shortcut path had already created the scene | Use the already verified Sidebar SettingsLink to bring the same Settings scene frontmost | final 4/4 XCUITest |
| P2 | VoiceOver byte values used rounded display units without the exact byte count | Include localized actual byte count in accessibility formatting | formatter regression |
| P2 | Ledger collapsed source metadata to kind plus one latest time | Preserve each source kind, identifier and sample time | exact source metadata regression |
| P2 | The functional Nautilus Probe required by the approved composition was missing | Add a static code-native locator at the Unknown boundary, labeled only `Safety Paused` | AX/XCUITest + screenshot review |
| P2 | Canvas accessibility representation swallowed the visual Probe element | Add Probe as a synthetic accessibility child and hide only the duplicate visual glyph | XCUITest Probe assertion |
| P2 | Orbit legend duplicated custom Canvas VoiceOver children | Hide the visual legend from accessibility; synthetic children remain authoritative | source review |

## 3. Final Projection Contract

```text
Free              = ledger.free
Used              = capacity - free, checked
Explained bytes   = ledger.known
Explained ratio   = known / used, only when measured and consistent
Ready bytes       = measured, classification-consistent Ready owners
Unknown           = ledger.unknown
Unmeasurable      = independent coverage row; never guessed or double-counted
```

- `unknownIncludesUnmeasurable` keeps one measured Unknown segment and an
  explicit unquantified coverage row.
- Top Opportunities require real joined Ready/Review owners, sort stably and
  cap at three.
- Protected and Unknown owners never become opportunities.
- Active scan is a closed App-owned state seam for Task 23; Task 22 never starts
  a coordinator.

## 4. Final UI and Safety Boundary

- Only Overview replaced its placeholder. Scan, Investigations and History
  remain placeholders.
- Quick Scan is the only filled primary action and navigates to Scan.
- Deep Dive stays safety-paused with no start callback, finding count, explained
  gain, progress stage or bypass.
- The code-native Storage Orbit, Space Ledger, metrics, coverage and
  opportunities use real typed values.
- The static Nautilus Probe marks only the Unknown boundary and announces
  `Safety Paused`.
- No chart dependency, generated product asset, new entitlement, telemetry,
  background task, scheduler or cleanup UI was added.

## 5. Verification Evidence

Final unified evidence:

- `scripts/verify`: exit 0;
- SwiftPM: 263/263;
- App tests: 33/33;
- XCUITest: 4/4;
- six stable screenshots: shell and Settings Light/Dark, limited coverage, and
  `zh-Hans`;
- screenshot theme/content gate:
  - shell Light `240.65`, sd `31.14`;
  - shell Dark `39.37`, sd `29.16`;
  - limited Light `241.56`, sd `30.46`;
  - Chinese Light `240.97`, sd `30.29`;
- read-only Peekaboo PID captures for English/Chinese Light: `2360 × 1520`,
  luminance about `241`, no other app content;
- App-state/Overview/Release source and binary gates pass;
- localization parity, plist lint, docs links and `git diff --check` pass;
- signed App bundle and the checked-in 67-rule catalog at
  `133b3829816fa951f03cb87473e03454c3e561b421c83e6c8efaf8ad89849e99`
  pass.

During final verification macOS reset Automation Mode to disabled. Several
runner attempts timed out before any UI test method. The user completed the
standard `Enable UI Automation` authentication, after which the final unified
run executed and passed all four UI tests. No root daemon,
`enable-automationmode-without-authentication`, TCC/SIP, Accessibility, Event
Synthesizing or other system permission was modified.

The final automatic review is retained at
`/tmp/stornaut_task22_final_review_1786340140/report.html`; it has no open P0–P2
finding.

## 6. Remaining Boundaries

- Task 23 owns actual Quick Scan start/stop/progress/results.
- Task 24 owns History.
- Task 25 owns full Settings and real Permissions navigation.
- Task 26 owns the Phase B real-machine gate.
- Deep Dive remains no-go/paused.
