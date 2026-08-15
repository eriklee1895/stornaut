# Task 43 Implementation Brief — Investigations UI and Navigation

> **Status:** Approved; blocked on pushed Task 42 baseline.
>
> **Parent plan:**
> [Phase D Conditional Deep Dive](phase-d-conditional-deep-dive.md)

## 1. Objective

Task 43 replaces the Investigations placeholder with the approved native
Deep Dive workspace:

```text
empty / start
→ 10/30/60-minute preset
→ first-use disclosure when required
→ baseline preparation when required
→ Prioritize → Identify → Verify → Build Plan
→ partial/final report
→ Investigation Details Inspector
→ continuation or existing Review route
```

The UI consumes Task 42 App state and cannot invent progress, findings,
coverage, budget or terminal truth. Normal production Deep Dive remains behind
the Task 44 final feature gate; Task 43 uses deterministic DEBUG fixtures and
closed injected flows for full UI validation.

No chat, console, hidden reasoning, raw JSONL, shell transcript or arbitrary
prompt editor is added.

## 2. Approved Visual/Product Contract

Follow `docs/design/ui-ux.md` and approved concepts:

- default composition: Deep Dive round-two B `Guided Journey`;
- on-demand Inspector: round-two C;
- Probe/current-target emphasis: round-two A;
- functional storage/coverage ring only, no decorative constellation/star map;
- native macOS materials/controls and existing Stornaut design system;
- concept images guide hierarchy/atmosphere, not pixel-exact implementation.

The default page must answer:

1. What source snapshot is being investigated?
2. Which of four stages is current?
3. What target is being verified now?
4. How much Unknown/coverage remains?
5. Which budget dimensions are hard, observed or unavailable?
6. What valid evidence/report remains if work stops or fails?
7. What safe next action exists?

## 3. Navigation and Entry Points

### 3.1 Investigations workspace

`AppDestination.investigations` renders the real workspace and remains the
selected sidebar destination throughout start/running/partial/final flows.

Workspace states:

- empty/no retained Investigation;
- unavailable/repair;
- first-use disclosure;
- preparing baseline Quick Scan;
- planning;
- ready/preset selection;
- running;
- pause/stop/cancel requested;
- terminalizing;
- paused/partial;
- safety blocked;
- failed;
- final;
- expired/corrupt historical report.

Stop and cancellation remain distinct requests/primary causes. After
verified drain and atomic commit, the workspace renders canonical
`partial(userStopped)` or `partial(userCancelled)`; it never renders
standalone terminal `stopped` or `cancelled` states.

The workspace preserves valid prior report content when a later attempt fails.

### 3.2 Overview entry

Replace the static implementation-unavailable secondary Deep Dive affordance
with a typed entry:

- if Task 44 gate is closed: show precise product-flow pending state and open
  Investigations for status, never start production runtime;
- after Task 44 admission: open Investigations and begin/prepare the normal
  start flow;
- if no baseline: state that Quick Scan baseline will run first;
- if blocked: show the exact highest-priority recovery action;
- Quick Scan remains the primary action.

### 3.3 Scan row entry

Add `Investigate with Codex` only on eligible Unknown/rule-miss rows:

- row binds current retained snapshot/classification/Investigation target ID;
- does not pass a path/action/prompt;
- opens Investigations with a typed focus intent;
- Task 42/Task 36 planner decides actual admitted targets;
- hidden for Protected, deterministic Ready and ineligible/stale/corrupt rows;
- disabled with a reason when runtime/disclosure/source is blocked.

### 3.4 Keyboard

Implement:

- `⇧⌘R` open/start Deep Dive flow when admitted;
- `⌥⌘I` toggle Investigation Details Inspector;
- `Esc` dismiss sheet/Inspector or request safe stop confirmation according
  to current state;
- full keyboard traversal and visible focus;
- no shortcut bypasses admission/disclosure/confirmation.

## 4. Start and Empty States

### 4.1 Empty

Show:

- Deep Dive purpose;
- latest Quick Scan source status;
- three budget presets;
- capability/data-boundary summary;
- current runtime/disclosure status;
- primary `Start Deep Dive` or reason-specific safe recovery;
- Quick Scan fallback.

Do not show finding count, explained gain, stage progress or Ready rows before
an Investigation starts.

### 4.2 Preset picker

Use:

- `10 min · Focused`;
- `30 min · Balanced` (default);
- `60 min · Thorough`.

State that duration is a maximum, not guaranteed duration. Advanced disclosure
shows exact Task 36 limits and distinguishes:

- hard admission/reservation;
- event-time observed stopping ceiling;
- usage unavailable.

No custom number fields, provider/model picker, per-tool toggles or safety
bypass.

### 4.3 Disclosure

Present the Task 41 native aggregate disclosure sheet. The workspace does not
duplicate disclosure persistence or start work from sheet acceptance alone.

## 5. Guided Journey

### 5.1 Four stages

Display fixed stages:

1. `Prioritize`;
2. `Identify`;
3. `Verify`;
4. `Build Plan`.

Each stage is one of:

- not started;
- active;
- completed;
- partially completed;
- blocked.

State comes only from Task 42 persisted/coordinator truth. Safety block before
start leaves all stages `not started`.

### 5.2 Functional coverage visualization

Show a functional ring/compact ledger for:

- source Unknown bytes when measurable;
- investigated/covered bytes;
- unresolved measurable Unknown;
- unmeasurable Unknown separately;
- coverage percentage only when denominator is valid;
- permission/measurement gaps as unavailable, never `0 B`.

The ring cannot imply reclaimed space or cleanup completion. It is not a
constellation/brand ornament.

### 5.3 Current target card

Show:

- bounded target summary;
- retained source kind;
- expected allocated bytes or `Unmeasurable`;
- why it was prioritized;
- current stage;
- evidence source currently being verified;
- uncertainty/counter-evidence;
- no raw absolute path beyond already approved bounded product path display;
- no shell command or model reasoning.

If no current target, show an honest stage-specific message rather than stale
prior target content.

### 5.4 Probe/evidence activity

Show a bounded, typed activity trail:

- source label;
- high-level operation kind;
- status;
- timestamp/order;
- retained target ID/summary;
- budget impact quality.

Do not show:

- raw command lines/arguments;
- raw stdout/stderr;
- raw URLs beyond safe public origin;
- file snippets;
- tokens/credentials;
- hidden reasoning;
- chat bubbles.

## 6. Investigation Details Inspector

Inspector opens on demand at the right and contains:

- Investigation/run/source/report IDs in technical disclosure;
- source Quick Scan/session freshness;
- target/source binding;
- exact source labels;
- Probe/direct-tool distinction;
- evidence summaries;
- counter-evidence;
- unresolved targets;
- capability degradations;
- hard and observed budget ledger;
- usage unavailable/overrun truth;
- stop/block/failure reason;
- continuation lineage;
- safe persisted web origins/redaction reasons;
- technical receipt fingerprint where useful.

It must not contain:

- raw JSONL;
- prompt;
- system/developer instructions;
- model hidden reasoning;
- raw tool transcript;
- cleanup authority/action buttons;
- “proceed anyway”.

Inspector closure preserves workspace selection/state.

## 7. Controls and Recovery

### 7.1 Running

Controls:

- `Pause` only when Task 42 says requestable;
- `Stop` for graceful verified `partial(userStopped)` close;
- `Cancel` with concise consequence confirmation;
- `Investigation Details`;
- no direct cleanup.

Disable controls during terminalizing and show the truthful reason:

```text
Finishing the current turn and verifying runtime cleanup…
```

Do not show terminal success before Task 42 admits it.

### 7.2 Partial/paused

Preserve:

- verified evidence/findings;
- coverage;
- unresolved targets;
- stop/degradation reason;
- source/report freshness.

Offer:

- `Continue Deep Dive` only when Task 42 continuation is eligible;
- `Review Findings` through existing conservative projection;
- `Done`;
- exact repair action.

Continuation visibly creates a new run; it is not labeled process resume.

### 7.3 Safety blocked

Show:

- no stale success metrics for the blocked attempt;
- which dimension failed: source, disclosure, Codex, capability, write
  isolation, network/Unix containment, lifecycle, dependency, workflow or
  budget;
- valid prior report separately if one exists;
- safe recovery (`Run Quick Scan`, `Review Disclosure`, `Check Again`,
  `Run Safety Check`, `Open Settings`);
- no bypass.

### 7.4 Final

Show:

- bounded findings and evidence coverage;
- unresolved Unknown;
- degradations;
- stop reason;
- Agent-only rows as Review Recommended/unselected;
- `Review Findings` only through existing Review route;
- `View Details`;
- `Done`.

Do not claim cleanup/reclaimed bytes from Investigation completion.

## 8. Localization, Accessibility and Motion

### 8.1 Localization

All user-facing text is in English and `zh-Hans`, including:

- presets;
- stages;
- source labels;
- hard/observed/unavailable usage;
- safety reasons;
- partial/final controls;
- disclosure;
- Inspector.

Avoid `AI says`, `junk`, `magic clean`, `100% safe`.

### 8.2 Accessibility

- stable accessibility identifiers for page, presets, stages, target, metrics,
  controls, Inspector sections and recovery actions;
- VoiceOver order follows page hierarchy;
- charts/rings have complete text alternatives;
- color is not the only state signal;
- status icons have labels;
- tables/lists expose row selection and source labels;
- keyboard focus remains visible;
- minimum native hit targets.

### 8.3 Motion

- running changes use restrained native transitions;
- no looping decorative animation;
- progress longer than 300 ms shows determinate/indeterminate functional state;
- Reduce Motion removes nonessential scale/movement;
- terminal completion uses at most one restrained 200–300 ms transition.

## 9. DEBUG Fixtures

Add typed fixture launch modes for:

- empty ready;
- disclosure required;
- baseline required;
- running in each stage;
- observed token usage unavailable;
- observed budget overrun terminalizing;
- pause requested;
- verified partial;
- safety blocked before start;
- lifecycle drain blocked;
- final with Agent-only Review Recommended proposal;
- expired/corrupt report.

Fixtures:

- use Task 42 state/reducer APIs;
- cannot directly manufacture a terminal UI state without a typed persisted
  terminal fixture;
- do not call real Codex unless a separate Task 39 diagnostic is invoked;
- are absent from Release activation strings/arguments.

## 10. Tests First

### 10.1 Model/state mapping

- every Task 42 state maps truthfully;
- no false metrics before start;
- hard/observed/unavailable budget labels;
- measurable/unmeasurable Unknown;
- current target cleared when absent;
- valid prior report preserved on later failure;
- terminal controls only after persisted truth;
- Agent-only proposal unselected/non-executable.

### 10.2 Navigation

- sidebar placeholder removed;
- Overview opens Investigations;
- Scan eligible row opens typed focused intent;
- ineligible/Protected/Ready/stale rows do not offer start;
- History report link opens Investigation detail;
- Review route uses existing Scan-owned Review;
- keyboard shortcuts obey admission.

### 10.3 Controls

- preset selection;
- disclosure accept/not now;
- start/baseline chaining;
- pause/stop/cancel request;
- terminalizing disables repeats;
- continuation creates new run;
- blocked recovery actions;
- Inspector open/close/selection.

### 10.4 Accessibility/localization

- identifiers and AX labels;
- VoiceOver chart alternatives;
- keyboard-only flow;
- English/`zh-Hans` string completeness;
- Light/Dark semantic contrast;
- Reduce Motion behavior;
- no chat/console/raw JSONL/reasoning strings.

### 10.5 Structural

- views import/use no Executor/Trash/authorization;
- no model path/command/action input;
- no direct runtime/process construction;
- normal production feature gate remains closed;
- Release has no DEBUG fixture activation.

## 11. Actual-App Verification

Follow:

```text
focused App tests
→ build current Debug .app
→ launch actual .app for each canonical fixture
→ Peekaboo image/see/inspect_ui
→ inspect screenshots and AX
→ focused XCUITest
→ authoritative full verifier
```

Required actual-window evidence in Light and Dark, with English/`zh-Hans`
coverage across the set:

- empty/start;
- disclosure;
- running;
- partial;
- safety blocked;
- final;
- Inspector;
- baseline preparation.

Inspect at minimum:

- 1340×640 current minimum host;
- normal target window;
- text scaling/long `zh-Hans` and English strings;
- Sidebar/Inspector widths;
- no clipping/overflow;
- ring/chart text alternatives;
- keyboard focus.

Peekaboo is read-only. Do not request/change system permissions. If user screen
activity causes focus loss, retry the affected XCUITest/actual-window capture
before changing product code.

## 12. Expected Files

```text
StornautApp/AppShell/RootView.swift
StornautApp/Overview/OverviewView.swift
StornautApp/Scan/ScanResultsTable.swift
StornautApp/Investigations/InvestigationsView.swift
StornautApp/Investigations/InvestigationStartView.swift
StornautApp/Investigations/InvestigationJourneyView.swift
StornautApp/Investigations/InvestigationCoverageView.swift
StornautApp/Investigations/InvestigationTargetCard.swift
StornautApp/Investigations/InvestigationDetailsInspector.swift
StornautApp/Investigations/InvestigationRecoveryView.swift
StornautApp/Investigations/InvestigationModel.swift
StornautApp/AppState/DebugAppFixtures.swift
StornautApp/Resources/en.lproj/Localizable.strings
StornautApp/Resources/zh-Hans.lproj/Localizable.strings
StornautAppTests/InvestigationsModelTests.swift
StornautAppTests/InvestigationsSnapshotTests.swift
StornautAppUITests/InvestigationsUITests.swift
scripts/verify-ui-runtime
scripts/verify-investigation-boundaries
scripts/verify-app-release-boundaries
docs/plans/active/task-43-implementation-brief.md
docs/reports/phase-d-task-43-review.md
docs/agent/coding-agent-handoff.md
docs/plans/active/README.md
docs/plans/roadmap.md
AGENTS.md
```

Exact filenames may follow current view decomposition.

## 13. Focused Validation

Run serially:

```text
xcodebuild ... -only-testing:StornautAppTests/InvestigationsModelTests
xcodebuild ... -only-testing:StornautAppTests/InvestigationsSnapshotTests
xcodebuild ... -only-testing:StornautAppUITests/InvestigationsUITests
scripts/verify-investigation-boundaries
scripts/verify-app-release-boundaries
scripts/verify-ui-runtime
scripts/check-doc-links
git diff --check
```

Then:

```text
swift test --parallel false
scripts/verify --full
```

Heavy SwiftPM/Xcode/UI runs must remain serial.

## 14. Independent Review

Review for:

- UI inventing progress/findings/coverage;
- safety-blocked stale success metrics;
- terminal display before Task 42 truth;
- Agent-only executable/default selection;
- raw JSONL/prompt/reasoning/tool transcript;
- model path/action input;
- cleanup authority in Investigations;
- inaccurate hard token/tool claims;
- inaccessible chart/control;
- localization drift;
- focus/overflow/Light-Dark defects;
- normal production gate removed early;
- DEBUG fixture leakage;
- concept-art pixel copying/spec inference;
- stale docs/broken links.

Fix all P0–P2 findings and rerun affected actual-App/focused checks before the
final full verifier.

## 15. Explicit Non-Goals

- Task 44 normal production admission;
- changing runtime containment;
- Store schema/coordinator/report semantics;
- cleanup execution;
- chat/console/prompt editor;
- decorative brand animation;
- adapters/Registered Actions;
- release/notarization/distribution.

## 16. Completion and Git

Task 43 completes only when:

- real Investigations workspace replaces placeholder;
- all canonical states have actual-App screenshot/AX evidence;
- focused XCUITest and accessibility/localization contracts pass;
- normal product Deep Dive remains feature-gated;
- structural boundaries pass;
- independent review has zero unresolved P0–P2;
- one uninterrupted authoritative `scripts/verify --full` exits `0`;
- a docs-freshness audit verifies every referenced normative document, task
  dependency/status router, ownership/non-goal claim and product-availability
  claim matches the committed diff and canonical contract;
- docs links, credential/artifact hygiene and `git diff --check` pass;
- one independent commit has no Coding Agent co-author trailer;
- `GITHUB_TOKEN` and `GH_TOKEN` are unset before push;
- `HEAD == origin/main` after push.
