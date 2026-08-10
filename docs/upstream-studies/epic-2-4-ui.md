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
