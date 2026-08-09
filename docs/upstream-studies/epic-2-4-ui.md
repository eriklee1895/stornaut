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
