# Epic 2–4 Native UI Upstream and Approved-Asset Study

> 状态：Accepted as the study gate for Phase B UI Tasks 21–25
>
> 日期：2026-08-09
>
> Coding Agent：TRAE CLI
>
> 目标模块：App state composition、Overview、Quick Scan/Results、History、Settings、resilience

## 1. Executive Conclusion

Phase B UI should use the repository's already approved canonical concepts and
the normative UI/UX specification. No new generated artwork is currently
needed.

Implementation priorities:

- native SwiftUI/AppKit hierarchy rather than raster-background imitation;
- typed ViewModel/reducer state and DEBUG-only deterministic fixtures;
- Overview reads from the latest real snapshot;
- Quick Scan uses the approved five-stage rail and results-in-place layout;
- Scan Results is read-only and does not expose Phase C cleanup;
- History shows only records that really exist in Phase B;
- Settings adopts the approved six-section native shell;
- page-preserving partial/limited/error behavior;
- Light/Dark, English/`zh-Hans`, VoiceOver, keyboard and Reduce Motion;
- every UI Task closes with real `.app`, Peekaboo and XCUITest evidence.

## 2. Authoritative Inputs

| Input | Role |
| --- | --- |
| [UI/UX specification](../design/ui-ux.md) | normative behavior, hierarchy, copy, accessibility and non-goals |
| [Overview Round 2](../assets/ui-concepts/OVERVIEW-ROUND-2.md) | approved Orbit Ledger composition |
| [Quick Scan Round 1](../assets/ui-concepts/QUICK-SCAN-ROUND-1.md) | approved results-taking-shape + stage rail |
| [Scan Results Round 1](../assets/ui-concepts/SCAN-RESULTS-ROUND-1.md) | approved grouped outline + read-only Inspector |
| [History Round 1](../assets/ui-concepts/HISTORY-ROUND-1.md) | approved master-detail/date groups/trend substate |
| [Settings Round 1](../assets/ui-concepts/SETTINGS-ROUND-1.md) | approved six-section shell and Phase B settings semantics |
| [Resilience States](../assets/ui-concepts/RESILIENCE-STATES-ROUND-1.md) | limited coverage, safety blocked and history degradation behavior |
| [UI Testing Guide](../agent/ui-testing-guide.md) | build/run/screenshot/XCUITest acceptance loop |
| [Development Automation](../agent/development-tooling.md) | fixed XcodeBuildMCP and read-only Peekaboo boundary |

The PRD and architecture remain above every concept image in authority.

## 3. Asset Provenance and Current Sufficiency

The canonical raster references were generated with
`$erik-gpt-image-2` / OpenAI `gpt-image-2`. Their prompt direction and selection
notes are preserved in:

- `docs/assets/ui-concepts/PROMPTS.md`;
- each round's Markdown study;
- paired dark/light PNGs.

The primary Phase B references are present:

```text
overview-canonical-dark/light.png
quick-scan-canonical-dark/light.png
scan-results-canonical-dark/light.png
history-canonical-dark/light.png
settings-general-canonical-dark/light.png
settings-local-knowledge-canonical-dark/light.png
resilience-limited-coverage-canonical-dark/light.png
resilience-history-expired-canonical-dark/light.png
```

Most canonical images are `1536 × 1024`; Settings Local Knowledge is
`1567 × 1004`. Dimensions, sample numbers, paths, line wraps and icon drift are
non-normative.

No production App image asset is required to implement the Phase B pages:
Space Ledger, stage rail, tables, badges and empty states should be code-native
SwiftUI/AppKit/SF Symbols for accessibility and dynamic data.

## 4. Future Image Generation Rule

If a later UI Task proves a missing raster asset is necessary:

1. prefer existing repository-native assets;
2. if current web material is considered, record source URL, author/copyright,
   license and allowed use before download;
3. for original raster concepts use `$erik-gpt-image-2`;
4. run a prompt dry-run for complex UI concepts;
5. preserve the final prompt and sibling metadata JSON;
6. never commit credentials;
7. inspect generated output and record model drift;
8. treat the result as composition/mood reference, not a pixel specification.

Do not use generated raster assets for SF Symbols, vector icons, charts,
deterministic diagrams or dynamic product UI.

## 5. Phase B Page Contracts

### App state and fixtures

- Production composition receives real typed store/coordinator projections.
- SwiftUI Views send typed intents and never open SQLite or start Surveyor.
- DEBUG launch arguments may inject checked-in deterministic fixture state.
- Release builds and unknown arguments cannot enable fixtures.
- A local failure invalidates only dependent state.

### Overview

- latest reliable snapshot and sample time first;
- Free, Explained and Ready to Reclaim remain distinct;
- Known, Unknown, Unmeasurable and Free remain visible;
- one primary Quick Scan action;
- at most three real opportunities;
- Deep Dive is visible as paused/safety-blocked with no fake success metrics.

### Quick Scan and Results

- fixed stages: Index Volumes, Map Projects, Classify Artifacts, Check Activity,
  Finalize Snapshot;
- stable progress/results layout rather than a full page swap;
- Stop Scan is neutral and preserves partial results;
- grouped lifecycle rows and read-only Evidence Inspector;
- no checkbox, enabled Review CTA, Trash or Codex process;
- unknown items explain the paused Deep Dive state without an unsafe bypass.

### History

- date-grouped master-detail for real scan/snapshot records;
- terminal status, retention, coverage and lineage;
- one corrupt/expired record does not hide healthy records;
- deleting records does not alter scanned files, Trash or Local Knowledge;
- Storage Trend only after four real user-initiated snapshots;
- events are markers, not storage-change causality.

### Settings

Six sections remain:

1. General
2. Scanning
3. Permissions
4. Codex & Deep Dive
5. Privacy & Data
6. Local Knowledge

Phase B wires appearance/language, roots/exclusions, fixed retention facts,
separate clear operations and structured Local Knowledge. Permission and Codex
sections show evidence-backed status only; no toggle can grant FDA or bypass
Deep Dive safety.

## 6. Accessibility and Theme Contract

- use semantic colors/materials and system type;
- text/status/icon accompany every color;
- tabular byte values and exact accessibility summaries;
- missing/unmeasurable values use an em dash plus reason, never `0 B`;
- keyboard order follows visual order;
- support VoiceOver, Increase Contrast, Reduce Transparency and Reduce Motion;
- dark/light keep hierarchy identical but tune semantic surfaces independently;
- English/`zh-Hans` localization keys remain in parity.

## 7. Real-App Acceptance Loop

Each UI Task:

```text
focused reducer/ViewModel tests
→ xcodebuild real App
→ LaunchServices/App harness launch
→ read-only Peekaboo capture/inspection
→ XCUITest state and accessibility assertions
→ Light/Dark screenshots
→ scripts/verify
```

Do not automatically change Screen Recording, Accessibility, Event
Synthesizing or TCC. AutomationMode/LLDB initialization delay is runner
evidence, not permission failure by itself.

## 8. Rejected Upstream/Concept Drift

- no MenuBarExtra, scheduled/background scan or login item;
- no giant treemap or star-map decoration;
- no chat, terminal, raw JSONL or hidden reasoning;
- no AI badges on known-rule results;
- no generated example path/number/status in production defaults;
- no image-model sidebar selection or Recovery/Disposition drift;
- no Review/Cleanup Result implementation in Phase B;
- no rasterized inaccessible UI imitation.

## 9. Fixture and Review Plan

Required deterministic states:

- no/current/stale snapshot;
- active, partial, cancelled and permission-limited scan;
- completed grouped results with known/unknown/protected/unmeasurable items;
- empty/populated/expired/corrupt History;
- General, Scanning, Privacy & Data and Local Knowledge Settings;
- Deep Dive safety blocked with all investigation stages not started.

Every Task includes source review plus actual screenshot/AX review. Passing a
snapshot test alone is not visual acceptance.

## 10. Relative Improvement

The approved concepts provide a consistent Native Observatory visual language,
while typed production state and accessibility own the actual UI. This avoids
both generic placeholder SwiftUI and brittle pixel-copy implementation.

## 11. Task 21 App-State Composition Refresh

Task 21 revalidated the Phase B UI gate on 2026-08-10 before changing App
state or shared components.

### Current upstream snapshots

| Source | Revision | License | Files/documents read |
| --- | --- | --- | --- |
| Apple SwiftUI documentation | Xcode 26.6 / Swift 6.3.3 installed documentation and current developer.apple.com pages | Apple documentation | `Managing model data in your app`, `Scene.environment(_:)`, `Environment`, macOS `Settings` scene |
| [ClearDisk](https://github.com/bysiber/cleardisk) | tag `v1.9.0`, `1aaec92b91c40fdc0c2fce92fef20df08b5f5c43` | MIT | `ClearDiskApp.swift`, `MainView.swift`, `LICENSE` |
| [PureMac](https://github.com/momenbasel/PureMac) | `e586b50bb30f68d0afff173e7d8389a50020095e` | MIT | `PureMacApp.swift`, `ViewModels/AppState.swift`, `PureMacTests/AppStateTests.swift`, `LICENSE` |

The two repository revisions are unchanged from the accepted Phase A studies.
Reviewed file SHA-256 values:

```text
ClearDisk ClearDiskApp.swift 86e4c1fd1d877a6976fb261a6df72e49806236436dbc0252f53d856241f8037b
ClearDisk MainView.swift      9314b5dce074d52cbbd87c3102e92a9344b196443c7167f4c3cdae877999b82f
PureMac PureMacApp.swift      f5a8494930d92038ee131d4005a6f8d50fe52c23a30179debfeb37c2f1b6ff08
PureMac AppState.swift        79c08df2f97a29bd2410c2d72afbb8695d4e0a6fe1ac60f9d9664450d4841d2d
PureMac AppStateTests.swift   beb5797032f1a72c402007de87116654352ccd7ba694d812d6eabd51521b178f
```

No upstream code, fixture, color value or layout constant is copied.

### Apple model-data decision

Current Apple guidance uses `@State` at the `App`/Scene ownership boundary for
an `@Observable` model and injects that model with `.environment(model)`.
Descendant Views read the model from the environment instead of constructing
services. Stornaut uses this current Observation path rather than adding
Combine-era `ObservableObject`, a global singleton or a third-party dependency
container.

### Upstream lessons and rejected patterns

PureMac demonstrates that App-owned model lifetime, environment injection and
state tests are useful. Its `AppState`, however, also owns a wide collection of
scan, clean, scheduler, menu-bar, permission and uninstall services. Views call
those mutation methods directly. Stornaut must keep the App model narrower and
must route filesystem work through typed dependencies and intents.

ClearDisk provides a useful macOS focus lesson: a visible but inactive window
can render washed-out material until explicitly made key. It also places many
presentation flags and direct scan/clean calls in one `MainView`. Stornaut
borrows the focus/test lesson only; it rejects the MenuBar lifecycle, timer,
login-item preference, direct cleaning calls and monolithic View state.

### Stornaut Task 21 composition

- `StornautApp` owns one `@MainActor @Observable StornautAppModel` in `@State`
  and injects it into the main and Settings scenes.
- `AppDependencies` exposes typed async operations to the model. Production
  composition creates `LocalStoreConfiguration.production()`,
  `EvidenceStore` and `QuickScanCoordinator`; SwiftUI Views never construct or
  call those types.
- A pure reducer maps latest `QuickScanProjection` values into empty, loading,
  partial, cancelled, success, limited-permission, stale and error phases.
  Loading, stale and error transitions preserve an existing valid projection.
- DEBUG fixture selection is a closed exact launch-argument enum. Unknown,
  malformed or duplicate selectors fall back to production composition. All
  sample projections and values compile only under `#if DEBUG`.
- Shared UI code is intentionally small: metric, disposition,
  coverage/retention badge, empty/recovery state and byte/status formatting
  primitives. It uses system/semantic colors, SF Symbols, system type and
  localized keys; it does not reproduce canonical image pixels.
- Task 21 leaves the four destination placeholders in place. Overview, Scan and
  History rendering remain Tasks 22–24.

### Verification additions

Task 21 must add:

- reducer tests for all eight phases and page-preserving transitions;
- production-live dependency composition against an in-memory store;
- closed DEBUG fixture selector and deterministic fixture tests;
- byte/status formatting and semantic mapping tests;
- a source/dependency gate proving View and DesignSystem files do not reference
  Surveyor, SQLite, Codex, Policy, Executor or action APIs;
- real App build, XCUITest/screenshot regression and read-only runtime capture.

## 12. Task 22 Snapshot-First Overview Refresh

Task 22 revalidated the Overview contract on 2026-08-10 before adding the first
real destination page.

### Current Apple accessibility sources

The current Apple SwiftUI documentation index was resolved as
`/websites/developer_apple_swiftui`. The first documentation request failed at
the provider, and the retry succeeded. The focused sources are:

- [accessibilityElement(children:)](https://developer.apple.com/documentation/swiftui/view/accessibilityelement%28children%3A%29);
- [accessibilityChildren(children:)](https://developer.apple.com/documentation/swiftui/view/accessibilitychildren%28children%3A%29);
- [AccessibilityChildBehavior](https://developer.apple.com/documentation/swiftui/accessibilitychildbehavior);
- [Color.primary](https://developer.apple.com/documentation/swiftui/color/primary).

Apple's current custom-Canvas example gives a visual graph an overall label and
adds synthetic accessible child shapes for each datum. Stornaut follows that
pattern for the code-native storage orbit: the Canvas is decorative to sighted
layout, while every real segment remains a separate VoiceOver child with a
localized label and exact formatted value. System semantic colors, text and
icons carry state together.

No Charts package, third-party visualization dependency or raster asset is
needed. The installed Xcode 26.6 / macOS 26.5 SDK and the existing SwiftUI App
target remain the implementation baseline.

### Domain-to-Overview mapping

Overview renders only `QuickScanProjection` and `SpaceLedger` facts:

```text
Free bytes             = ledger.free
Used bytes             = ledger.volumeCapacity - ledger.free
Explained bytes        = ledger.known
Explained ratio        = known / used, only when both are measured and used > 0
Ready to Reclaim bytes = sum(ledger.owners allocated bytes
                             where disposition == readyToReclaim)
Unknown                = ledger.unknown
Unmeasurable           = ledger.unmeasurable + coverage gap count
```

`Unknown` and `Unmeasurable` never collapse. When
`unknownIncludesUnmeasurable` is true, the measured Unknown residual remains the
only bar segment for those bytes and the unmeasurable row is explicitly
unquantified; the UI never double-counts or invents a byte estimate.

Orbit categories are deterministic aggregates of real ledger owners plus
Unknown and Free. Top Opportunities are the stable first three real
Ready/Review owners after joining their classification, ordered by disposition,
allocated bytes and path. Protected and Unknown owners are not opportunities.
Activity text is conservative: it says checked only when bounded activity/git
evidence exists, unavailable when an activity requirement is missing, and
Unknown otherwise.

The snapshot timestamp comes from the scan session. Measure source and sample
time come from each `SpaceLedgerMeasure.sources` entry. The scope label comes
from the completed or unfinished scan scope; no filesystem query occurs in a
View.

### State and action boundary

- no projection renders the code-native empty state and one `Run Quick Scan`
  action;
- a retained projection remains visible for partial, cancelled,
  permission-limited, stale and local-store failure states;
- `.loading` with retained projection is the reserved scan-in-progress
  presentation seam for Task 23 and claims no fabricated stage/count;
- stale is driven by typed App state, not an undocumented age threshold;
- `Quick Scan` and `Scan Again` only navigate to the Scan workspace in Task 22;
  Task 23 owns scan start/stop/progress;
- Deep Dive is visible as safety paused and has no executable action;
- no fake finding count, explained gain or investigation progress is shown.

### Upstream/concept boundary

The approved A+B Overview composition remains the source of information
hierarchy only. ClearDisk `v1.9.0` and PureMac
`e586b50bb30f68d0afff173e7d8389a50020095e` remain the reviewed MIT snapshots
from this study; Task 22 copies no code, fixture, color, path or numeric sample.
It rejects their direct scan/clean calls and wide App-state patterns.

The canonical image's sample `125 GB`, `87%` and `23.4 GB`, raw palette,
generated paths and decorative Probe do not enter production defaults.
Stornaut implements a medium functional orbit, full Space Ledger, one primary
action and calm native surfaces using real typed data. No new image generation
or web asset is required.

## 13. Task 23 Quick Scan Progress and Results Refresh

Task 23 revalidated the Phase B UI gate on 2026-08-10 before connecting the
real `QuickScanCoordinator` stream to the Scan workspace.

### Current Apple and design-system sources

The current Apple SwiftUI documentation index remains
`/websites/developer_apple_swiftui`. Focused documentation and installed SDK
interfaces were reviewed for:

- [`ProgressView`](https://developer.apple.com/documentation/swiftui/progressview);
- [`Table`](https://developer.apple.com/documentation/swiftui/table);
- [`TableColumnCustomization`](https://developer.apple.com/documentation/swiftui/tablecolumncustomization);
- [`inspector(isPresented:content:)`](https://developer.apple.com/documentation/swiftui/view/inspector%28ispresented%3Acontent%3A%29);
- [`inspectorColumnWidth(min:ideal:max:)`](https://developer.apple.com/documentation/swiftui/view/inspectorcolumnwidth%28min%3Aideal%3Amax%3A%29);
- [`accessibilityInputLabels(_:)`](https://developer.apple.com/documentation/swiftui/view/accessibilityinputlabels%28_%3A%29-9q3yf);
- [`accessibilityHint(_:)`](https://developer.apple.com/documentation/swiftui/view/accessibilityhint%28_%3A%29-3rdgs).

Current SwiftUI supports native macOS table selection, customizable columns
and a trailing Inspector with a bounded column width. Task 23 uses those
platform idioms where they preserve accessibility and keyboard behavior. It
does not add a custom floating panel, a web-style grid library or a third-party
View inspection dependency.

The `ui-ux-pro-max` SwiftUI and UX searches reinforced these applicable
constraints:

- long-running multi-step work needs an explicit stage indicator and loading
  feedback;
- collection rows need stable identifiers rather than array offsets;
- long paths require a deterministic truncation/full-detail path;
- state and errors require text/icon semantics rather than color alone;
- the stable results surface should not disappear during loading or recovery.

The approved Quick Scan E+A and Scan Results A+D canonical assets remain the
composition source. No image generation or external visual asset is required.
No pixel, generated sample value, path, palette or layout constant is copied.

### App-owned scan flow

`StornautAppModel`, not the Scan View, owns the producer task and a closed scan
flow state. Navigation away and back therefore cannot cancel or duplicate a
scan. `AppDependencies` exposes only typed start/cancel/load operations:
SwiftUI never constructs a `Surveyor`, store or coordinator.

Production composition creates one actor-owned coordinator and creates a
`ScanRequest` for the current user's home directory. This is an explicit Phase
B default until Task 25 owns configurable roots and exclusions. The root is
not discovered by a View. DEBUG and UI-test compositions use deterministic
event streams and never scan the real home directory.

The reducer consumes the existing closed `QuickScanProductEvent` stream:

- `stageChanged` advances only through the five fixed stages;
- `progress` updates scanned-entry count, measured allocated bytes and current
  summarized path without treating either as a percentage;
- classification/evidence/ledger events progressively fill typed results;
- `terminal` is authoritative for completed, partial, cancelled,
  permission-limited and store-failure outcomes;
- thrown start/stream errors preserve the last valid projection and expose a
  safe retry state.

Elapsed time is derived from the injected scan start clock. Candidates Found
counts distinct classified candidate snapshots. Scope Scanned remains an entry
count. Measured remains allocated bytes. These units are never added together
or presented as a fabricated percent complete.

### Stable progress/results surface

The Scan workspace keeps one structural surface through idle, active and
terminal states:

1. title, local/no-Codex explanation and safe primary/secondary action;
2. four metrics: Scope Scanned, Candidates Found, Measured and Elapsed;
3. five-stage rail with icon, label and explicit Complete/Current/Pending text;
4. one-line current-scope strip;
5. search/filter controls and the grouped lifecycle result outline;
6. separate Ready, Review, Unknown and Protected summary values.

Completed groups retain stable rows, the active group can grow, and empty
groups remain explicitly pending/empty without invented bytes. Stop Scan is a
neutral secondary action with text that a partial snapshot is retained.
Stopping never means deletion and never changes a result disposition.

The result rows use the approved independent fields: Item/Path Summary, Last
Active, Producer, Recovery, Allocated Size and Disposition. Missing or
unmeasurable values render an em dash with a reason; they never become `0 B`.
Known-rule rows have no AI decoration.

### Read-only Inspector and Phase B action boundary

Selection opens a native trailing read-only Inspector containing exact path,
producer, lifecycle, activity, recovery, supporting evidence, missing evidence
and disposition. Selection and disclosure do not mutate classification.

The broader UI specification describes Reveal, Copy, View Evidence,
Investigate and a filled Review CTA. The active Phase B plan is narrower and is
authoritative for Task 23:

- no Review, Trash, Registered Action or cleanup execution is enabled;
- no Codex process can start, including from Unknown rows;
- Deep Dive/Investigate is shown only as Safety Paused explanatory state;
- Reveal/Copy are not faked if no typed intent is implemented;
- the future Review affordance, if visible, is disabled and explicitly marked
  as unavailable in this phase.

This resolves the specification conflict without silently widening the safety
or write boundary. Phase C must separately approve any enabled Review or local
workspace action.

### Verification additions

Task 23 adds:

- reducer tests for idle, five stages, progressive facts, explicit stop,
  cancelled, partial, permission-limited, store failure and completion;
- model tests proving one active producer and navigation-independent lifetime;
- production-composition tests that use a temporary root, plus a source gate
  proving Views cannot reference scanner/store/Codex/policy/executor APIs;
- result projection tests for grouping, filtering, ordering, missing values,
  recovery/disposition separation and read-only Inspector evidence;
- deterministic DEBUG in-progress, partial and completed fixtures;
- real App XCUITest, Light/Dark screenshots and read-only Peekaboo inspection
  of all three representative states.

## 14. Task 24 Scan-Only History Refresh

Task 24 revalidated the Phase B UI and persistence gates on 2026-08-10 before
replacing the History placeholder.

### Current Apple and design-system sources

The current Apple SwiftUI documentation index remains
`/websites/developer_apple_swiftui`. Focused sources were reviewed for:

- selection-driven
  [`NavigationSplitView`](https://developer.apple.com/documentation/swiftui/navigationsplitview);
- macOS
  [`List(selection:content:)`](https://developer.apple.com/documentation/swiftui/list/init%28selection%3Acontent%3A%29);
- [`searchable`](https://developer.apple.com/documentation/swiftui/view/searchable%28text%3Aplacement%3Aprompt%3A%29);
- [`confirmationDialog`](https://developer.apple.com/documentation/swiftui/view/confirmationdialog%28_%3Aispresented%3Atitlevisibility%3Aactions%3Amessage%3A%29);
- selected-state accessibility traits.

The App already owns the outer four-workspace `NavigationSplitView`. History
therefore uses a native `HSplitView` for its 350–400 pt record navigator and
detail pane rather than nesting another app-style sidebar. Selection remains a
stable binding and keyboard navigation changes no file state.

The `ui-ux-pro-max` History searches reinforced:

- every destructive record deletion needs explicit confirmation;
- successful deletion needs an accessible result/focus transition;
- status and corruption require icon plus text, never color alone;
- system type and semantic native controls are preferred;
- no decorative motion is needed, so Reduce Motion never hides state.

The approved History E+A+C composition remains the information source. No
raster asset, generated path/date/size, raw palette or pixel constant is copied
and no new image generation is needed.

### Persistence and query boundary

Task 24 reuses ADR 0007's accepted actor-owned `EvidenceStore` and fixed
seven-day scan retention. The App dependency runtime resolves the same store
instance used by `QuickScanCoordinator`; it does not open a second production
connection or expose SQLite to a View.

History loads:

- paged `ScanSession` records in store order;
- corrupt scan-session IDs isolated by the existing typed page contract;
- matching `SpaceLedger` values in bounded batches of at most 100 session IDs;
- corrupt/missing ledger detail as a per-record issue, never an empty healthy
  record.

The batch ledger API avoids one SQLite query per session while retaining exact
payload/row identity validation. Session expiry is derived from the
store-validated `finishedAt + 7 days` contract. The coordinator now invokes the
accepted Evidence sweep before inactive latest/History reads, so a newly loaded
page cannot reuse expired truth. An already open fixture/page can still render
the explicit Expired presentation until refresh.

Quick Scan and History also share one coordinator-owned concurrency boundary.
Existing read projections may finish before a pending Scan starts; the pending
intent prevents new History reads from overtaking it. Active Scan rejects
History read/delete, while History delete is exclusive. This closes the actor
reentrancy window without discarding an explicit user Scan intent.

Deletion is a typed session-ID operation inside the Evidence actor. SQLite
foreign-key cascade removes only that session's Evidence-role descendants.
Tests prove deletion does not address the scan target, Trash or the independent
Local Knowledge database.

### Scan-only information architecture

Phase B History contains only real Quick Scan records. It does not synthesize
Deep Dive, report or Cleanup Manifest rows. Because a Type filter with one
value would be misleading and redundant, Task 24 uses:

- local search over session ID and scope;
- terminal-status filter: All, Complete, Partial, Stopped, Failed;
- date range: All Retained, Today, Last 7 Days.

The navigator groups records as Today, Yesterday and Earlier. Valid rows show
Quick Scan, finished time, terminal status, one ledger-backed metric when
available and exact retention/relative countdown. Corrupt rows show only
`Couldn't read this record`; missing metadata is not guessed.

Detail is an immutable projection of the selected record:

- terminal state and exact start/finish/duration;
- completed/unfinished scopes and coverage status;
- Known, Unknown, Unmeasurable and Free measures without collapsing them;
- ledger source/sample time and caveats;
- lineage wording that states relationship only and never causality;
- exact expiry and confirmed record deletion.

### Storage Trend and action boundary

Every production Quick Scan is user initiated in Phase B: entering Scan never
starts work and no scheduler/background monitor exists. `Storage Trend` is
therefore available only when at least four completed sessions have comparable
measured volume capacity/free ledgers at four distinct timestamps.

The optional substate shows exact Used and Free samples with direct labels,
different line styles plus semantic colors, keyboard/VoiceOver-accessible data
rows and the fixed non-causality caption. With fewer than four comparable
snapshots, the action is absent rather than showing a fake chart.

The broader UI specification includes `Export Record…`. The active Task 24
plan does not authorize a save-panel/export lifecycle, and path redaction is a
separate privacy contract. Task 24 neither implements nor displays a dead
export action. A future typed exporter must separately cover canonical-home
redaction, identifying residual segments, atomic destination writes and user
confirmation.

### Verification additions

Task 24 adds:

- pure projection tests for empty/current/partial/expired/corrupt states,
  grouping, status/date/search filters, retention and trend eligibility;
- Evidence Store batch-ledger and delete/isolation tests;
- App model tests for load, stale completion, confirmed delete and predictable
  next selection;
- deterministic DEBUG populated, expired, corrupt and trend fixtures;
- View/source gates proving History has no Surveyor, SQLite, Codex, Policy,
  Executor, Trash or Local Knowledge mutation reference;
- real App XCUITest, thirteen stable Light/Dark screenshot contracts and
  read-only Peekaboo inspection of populated, expired, corrupt and trend
  representative states.

Final implementation/review evidence is recorded in
[Task 24 Code Review](../reports/epic-2-4-task-24-review.md).
