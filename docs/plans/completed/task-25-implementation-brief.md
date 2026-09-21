# Task 25 Implementation Brief — Phase B Settings

> **Historical-brief notice (2026-08-11):** Deep Dive paused/no-go wording
> below records the completed Phase B Settings state, not current Codex policy.
> See capability-first
> [ADR 0004](../../adr/0004-codex-file-read-isolation.md).

> 状态：Completed
>
> 日期：2026-08-10
>
> 上位计划：[Epic 2–4 Deterministic Product Core](epic-2-4-deterministic-product-core.md)
>
> Study gate：[Epic 2–4 Native UI Study](../../upstream-studies/epic-2-4-ui.md#15-task-25-phase-b-settings-refresh)

## 1. Objective

Replace the foundation two-row Settings form with the approved independent
six-section macOS Settings workspace and wire every Phase B control to a typed,
tested behavior.

Task 25 is complete only when:

- Settings remains an independent scene opened by both Sidebar gear and `⌘,`;
- General changes English/`zh-Hans` and System/Light/Dark immediately across
  main and Settings windows;
- the next Quick Scan resolves one real Primary Scan Root bookmark and bounded
  exclusions instead of the launch-time home constant;
- exclusions are explicit unmeasurable coverage boundaries, never silent
  omissions or measured zero;
- Permissions separates measured scan coverage, current unverified FDA status
  and user-selected folder access without exposing a TCC/denylist bypass;
- Codex installation/version syntax facts come from fixed read-only discovery
  probes while Deep Dive remains independently paused/no-go;
- Privacy & Data shows truthful fixed lifecycle facts and separately confirms
  typed Evidence/Manifest clears;
- Local Knowledge loads a bounded typed page, isolates corrupt records and
  supports confirmed single/all forgetting;
- active Quick Scan blocks configuration/store mutations that would race its
  evidence lifecycle;
- no model provider, Shell/CLI flags, background behavior, retention override,
  free-text memory or policy override is added;
- English/`zh-Hans`, Light/Dark, keyboard and VoiceOver are verified in the
  actual `.app`.

## 2. Plan Corrections

### 2.1 One Primary Scan Root, not fake multi-root

The normative architecture sketches `roots: [URL]`, but accepted Phase B code
has one `ScanRequest.rootURL`, one scope and one `SpaceLedger`. Task 25 will
display and persist exactly one **Primary Scan Root** with multiple exclusions.
It will not present an Add Root list whose additional rows are ignored.

Task 26 must record this remaining architecture/spec drift and decide whether
multi-scope accounting is required before Phase B closes.

### 2.2 Exclusion truth

User exclusions are real traversal boundaries. The excluded directory itself is
persisted as a typed `.userExcluded` coverage gap; descendants are not read.
Space accounting remains partial and keeps those bytes in Unknown. Exclusions
never make coverage look complete and never become `0 B`.

### 2.3 Permission status is evidence-limited

The public macOS SDK has no supported general Full Disk Access status query.
Current signed-App evidence proves only that Mail access was denied on this
machine; packaged-App full-scope FDA remains Task 26.

Settings therefore shows `Limited / not fully verified`, real latest-scan
coverage gaps and the official System Settings route. `Check Again` refreshes
only the available local evidence; it does not read TCC or manufacture a
private-file canary.

### 2.4 JSONL lifecycle copy follows implementation

The current Codex wrapper keeps raw JSONL bounded in memory and never writes it
to disk. No 24-hour crash-remnant cleaner exists. Settings states the verified
memory-only/no-persistence fact instead of claiming the concept asset's
unimplemented crash-remnant SLA.

## 3. Files

Create:

```text
Sources/StornautCore/Settings/SettingsPreferences.swift
Tests/StornautCoreTests/SettingsPreferencesTests.swift
Tests/StornautCoreTests/SurveyorExclusionTests.swift
StornautApp/AppState/StornautLocalization.swift
StornautApp/Settings/SettingsState.swift
StornautApp/Settings/SettingsModel.swift
StornautApp/Settings/SettingsComponents.swift
StornautApp/Settings/GeneralSettingsView.swift
StornautApp/Settings/ScanningSettingsView.swift
StornautApp/Settings/PermissionsSettingsView.swift
StornautApp/Settings/CodexSettingsView.swift
StornautApp/Settings/PrivacyDataSettingsView.swift
StornautApp/Settings/LocalKnowledgeSettingsView.swift
StornautAppTests/SettingsModelTests.swift
StornautAppTests/SettingsAppModelTests.swift
scripts/verify-settings-boundaries
docs/reports/epic-2-4-task-25-review.md
```

Modify:

```text
Sources/StornautCore/Surveyor/ScanRequest.swift
Sources/StornautCore/Surveyor/PathSnapshot.swift
Sources/StornautCore/Surveyor/Surveyor.swift
Sources/StornautCore/Accounting/SpaceLedgerReconciler.swift
Sources/StornautCore/QuickScan/ScanSessionWriter.swift
Sources/StornautCore/QuickScan/QuickScanCoordinator.swift
Sources/StornautCore/Evidence/EvidenceStore.swift
Sources/StornautCore/Evidence/LocalStoreConfiguration.swift
Sources/StornautCore/LocalKnowledge/LocalKnowledgeStore.swift
StornautApp/AppState/AppDependencies.swift
StornautApp/AppState/StornautAppModel.swift
StornautApp/AppState/DebugAppFixtures.swift
StornautApp/DesignSystem/StornautFormatters.swift
StornautApp/History/HistoryNavigator.swift
StornautApp/Overview/SpaceLedgerView.swift
StornautApp/Scan/ScanFlowState.swift
StornautApp/Scan/ScanResultsTable.swift
StornautApp/StornautApp.swift
StornautApp/Settings/StornautSettingsView.swift
StornautAppTests/AppFixtureTests.swift
StornautAppUITests/StornautAppUITests.swift
Tests/StornautCodexTests/CodexProcessTests.swift
Tests/StornautCoreTests/QuickScanIntegrationTests.swift
StornautApp/Resources/en.lproj/Localizable.strings
StornautApp/Resources/zh-Hans.lproj/Localizable.strings
scripts/verify
scripts/export-ui-screenshots
scripts/verify-ui-screenshots
scripts/verify-app-release-boundaries
scripts/verify-app-state-boundaries
docs/agent/ui-testing-guide.md
docs/upstream-studies/epic-2-4-ui.md
docs/plans/active/epic-2-4-deterministic-product-core.md
docs/README.md
docs/reports/README.md
docs/plans/active/README.md
docs/agent/coding-agent-handoff.md
AGENTS.md
```

File-system-synchronized Xcode groups include new Swift files without project
file edits.

## 4. Closed Preference Contract

```text
SettingsPreferences
  language: systemEnglish | zhHans
  appearance: system | light | dark
  primaryRoot: security-scoped bookmark? (nil = current HOME fallback)
  exclusions: unique canonical descendants of current root, max 64
  investigationBudget: focused | balanced | thorough
```

- preference payload is versioned, size-bounded and atomically saved in
  Stornaut-owned Application Support, not a generic dictionary;
- invalid, future, oversized, symlink-escaping or non-directory values fail
  closed to the last valid/default preference;
- bookmark resolution is without UI; stale bookmarks are reported and can be
  refreshed only after a new user selection;
- access starts immediately before a Scan and stops only after the product
  stream terminates;
- changing root removes exclusions outside the new root;
- duplicate/nested exclusions are normalized deterministically;
- no preference can alter denylist, Policy Gate, Executor or retention.

Language is a closed app-local override rather than an `AppleLanguages`
mutation. Dynamic localization helpers and environment locale update the
visible App immediately. Appearance uses a closed preferred color scheme and
AppKit window appearance bridge; DEBUG screenshot overrides remain separate and
take precedence only in Debug.

## 5. Typed Settings Runtime

`AppDependencies` adds typed operations:

```text
load/save SettingsPreferences
select Primary Root / select Exclusion via native folder panel
load Settings runtime facts
clear Evidence
clear Manifests
load/forget/forget-all Local Knowledge
open Full Disk Access System Settings
```

Views never instantiate `EvidenceStore`, `LocalKnowledgeStore`, `CodexLocator`,
`CodexCapabilityDetector`, `NSOpenPanel`, `NSWorkspace` or `UserDefaults`.

One actor-owned runtime reuses the existing Evidence coordinator and separately
owns the Local Knowledge store and preference store. Data operations are
serialized and return only after persistence completes.

## 6. Settings State and Projection

`SettingsState` is App-owned and page-preserving:

```text
idle
loading(retained snapshot?)
loaded(snapshot)
mutating(operation, retained snapshot)
error(retained snapshot?, reason, recovery)
```

`SettingsSnapshot` contains:

- closed preferences and resolved primary-root state;
- latest-scan coverage/FDA evidence;
- Codex unavailable/installed/report/error state;
- fixed Deep Dive safety paused status;
- Evidence and Manifest local record counts;
- Local Knowledge page plus corrupt IDs;
- immutable policy facts.

Stale async refresh cannot overwrite later preference/clear/forget mutations.
Settings mutations are refused while Quick Scan is active. A successful clear
updates Overview/Scan/History only through typed reload/invalidation; a reload
failure never restores deleted records.

## 7. Six-Section UI Contract

### General

- Language: English / Simplified Chinese;
- Appearance: System / Light / Dark;
- compact Setup Status: Disk Access, Codex Installation, Deep Dive Safety;
- fixed non-interactive `Runs only when you open Stornaut`.

### Scanning

- one Primary Scan Root row with Choose/Reset;
- exclusions list with Add/Remove;
- current resolved/stale/unavailable status;
- permanent protected locations as a locked policy summary, not an editable
  path list or exception control;
- built-in 67-rule catalog/provenance summary;
- Adapter/overlay controls absent because Phase B has no runtime implementation.

### Permissions

- Full Disk Access: Limited/not fully verified plus latest coverage evidence;
- `Open System Settings` and `Check Again`;
- granted Primary Root bookmark status;
- immutable permanent protected-locations/denylist statement.

### Codex & Deep Dive

- installation path/version/source and syntax report when available;
- independent `Deep Dive Safety: Paused / Required`;
- fixed no-go explanation and Quick Scan unaffected statement;
- budget segmented control: Focused/Balanced/Thorough;
- disclosure shows preset wall-clock and currently implemented Probe budget
  ceilings as product configuration facts;
- no model/provider, arbitrary flag, Shell or Run Safety Check fake action.

### Privacy & Data

- local-only and closed-store statement;
- Evidence 7 days and minimal Manifest 90 days;
- raw controlled content/JSONL memory-only and not persisted;
- separate `Clear Evidence Now…` / `Clear Manifests Now…` confirmations;
- confirmation states files, Trash, prior cleanup effects and Local Knowledge
  are unchanged as applicable.

### Local Knowledge

- bounded structured rows: kind, scope, payload summary, user-confirmed
  provenance, updated time and conservative Current/Stale/Context unavailable;
- single selection Review detail and confirmed Forget;
- confirmed Forget All;
- corrupt rows isolated with raw ID only;
- no free-text editing or creation in Task 25.

## 8. Tests First

Initial tests must fail on missing Task 25 types/APIs and cover:

1. closed preference defaults, round-trip, future/oversized corruption;
2. security-scoped bookmark resolution/staleness and access lifetime;
3. root replacement and exclusion containment/deduplication/bounds;
4. Surveyor skips excluded descendants and emits `.userExcluded`;
5. ledger marks exclusion partial/unmeasurable without guessed bytes;
6. next Quick Scan uses the latest resolved root/exclusions;
7. active Scan rejects settings mutations and store clears;
8. concurrent initial loads share one runtime and stale completions lose;
9. Evidence/Manifest clears remain separate and preserve target/Trash/knowledge;
10. Local Knowledge page/corruption/forget/forget-all behavior;
11. no-context knowledge is not labeled Current;
12. Codex installed versus capability versus safety remain independent;
13. every section's editable/status/policy surfaces are closed;
14. English/`zh-Hans` key parity and dynamic language projection;
15. DEBUG Settings fixtures never call production services;
16. View/source gate forbids direct store, Surveyor, Codex process, TCC,
    NSOpenPanel, NSWorkspace and UserDefaults access.

## 9. Verification

```text
red Core/App Settings tests + source gate
→ implement preference/bookmark/exclusion/store services
→ implement pure projections and six-section views
→ focused Core/App tests
→ temporary-store target/Trash/knowledge audits
→ build/sign/launch actual Debug App
→ XCUITest section navigation, confirmation and mutation contracts
→ read-only Peekaboo General/Scanning/Codex/Privacy/Knowledge Light/Dark
→ grouped bits-code-guard review and fixes
→ scripts/verify
→ docs/provenance update
```

Task 25 uses one reviewed commit:

```text
feat: add deterministic scan settings
```

## 10. Explicit Non-goals

- no fake multi-root/multi-ledger orchestration;
- no Deep Dive start, safety-check bypass or investigation UI;
- no Adapter/overlay implementation or provider selector;
- no background monitor, schedule, login item or automatic cleanup;
- no retention customization;
- no TCC database read/reset or private-file canary;
- no free-text Local Knowledge create/edit;
- no real cleanup, Trash or Registered Action;
- no release/notarization work;
- no new dependency, entitlement, telemetry or remote service.

## 11. Completion Evidence

Task 25 completed on 2026-08-10. The final implementation and review evidence
is recorded in
[Task 25 Code Review](../../reports/epic-2-4-task-25-review.md).

Final acceptance:

- SwiftPM: 269 functional/security tests plus three independent matcher
  Benchmarks, all passing under their original `< 2 s` gates;
- App tests: 95/95;
- XCUITest: 9/9;
- screenshot contract: 17/17;
- signed real-App Peekaboo: Scanning Light and Local Knowledge Dark, `900 ×
  648`, no visible raw localization keys;
- post-fix grouped review: no open P0–P2 finding;
- complete `scripts/verify`: exit 0.
