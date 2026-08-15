# Task 41 Implementation Brief — First-Use Disclosure and Runtime Admission State

> **Status:** Approved; blocked on pushed Task 40 baseline.
>
> **Parent plan:**
> [Phase D Conditional Deep Dive](phase-d-conditional-deep-dive.md)

## 1. Objective

Task 41 makes Deep Dive's product admission dimensions explicit and gives the
user one versioned, aggregate first-use disclosure:

```text
retained terminal Quick Scan
+ Codex discovery/auth
+ exact fresh runtime receipt
+ current disclosure acceptance
+ production Investigation dependencies
+ no conflicting workflow
+ valid budget preset
→ typed Deep Dive availability
```

The disclosure covers direct read, model context, public internet and the
no-write/no-cleanup boundary. It is accepted once per disclosure version, not
once per file, command, tool, public destination or Investigation.

Acceptance is informed consent, not technical containment. It cannot replace
the Task 39 signed runtime receipt. Runtime success cannot replace acceptance.
Decline or obsolete acceptance keeps Quick Scan fully available and Deep Dive
unavailable.

Task 41 updates Settings and disclosure UI only. It does not start an
Investigation, add the App workflow, replace the Investigations placeholder,
enable normal Deep Dive, project a report, or expose cleanup authority.

## 2. Admission Dimensions

Add one closed product availability model with independent dimensions:

1. **Source** — latest retained Quick Scan is terminal, current and usable.
2. **Disclosure** — current version accepted, declined, not presented or
   obsolete.
3. **Codex** — installed, syntax-compatible and authenticated/available.
4. **Runtime receipt** — exact Task 39 current signed-App receipt is fresh and
   admitted.
5. **Production dependencies** — Task 38 facade and Store/lifecycle
   dependencies are present.
6. **Workflow** — no conflicting Quick Scan, cleanup execution or mutating
   History/Settings operation.
7. **Budget** — selected Task 36 preset and limits are valid.

Each dimension is typed and visible separately. The aggregate state may be:

- `available`;
- `needsBaselineScan`;
- `needsDisclosure`;
- `disclosureDeclined`;
- `codexUnavailable`;
- `runtimeBlocked`;
- `runtimeStale`;
- `dependenciesUnavailable`;
- `workflowBusy`;
- `invalidBudget`.

Precedence is for presentation/recovery only; it must not erase the underlying
dimension values. Safety/runtime failure is never hidden behind disclosure or
source convenience.

## 3. Versioned Disclosure

### 3.1 Fixed aggregate content

The current disclosure version is a closed domain token, initially:

```text
deep-dive-disclosure-v1
```

English and `zh-Hans` content communicates:

- authorized scan-scope files may be read directly by the installed Codex;
- selected metadata, manifests, README/config/log fragments and other
  necessary read-only evidence may enter model context;
- investigation queries, public URLs and necessary evidence may be sent to
  public internet services;
- shell/unified exec, live search, browser/direct fetch, image, skills,
  subagents and Probe Broker may be used autonomously;
- Stornaut does not ask again per file, command, tool or public destination;
- Codex and descendants have no write, cleanup, Policy, authorization or
  Executor authority;
- all later cleanup still requires Swift rejoin, existing deterministic Plan,
  explicit selection, exact confirmation, one-shot authorization and fresh
  Policy;
- no guarantee that every unknown will be explained;
- Quick Scan remains local/deterministic and available if declined.

Do not state that prompt text or user acceptance creates OS isolation. Refer to
the separately verified runtime safety status.

### 3.2 Acceptance record

Persist only a bounded local record:

- schema version;
- disclosure version;
- status: accepted or declined;
- accepted/declined timestamp;
- exact localized content fingerprint independent of locale display;
- product/runtime profile version expected by the disclosure.

Do not persist:

- a generic trust flag;
- credentials;
- model/provider choice;
- arbitrary CLI flags;
- per-tool permission toggles;
- per-path/domain grants;
- a bypass token;
- execution authority.

Acceptance is obsolete when the disclosure version/content fingerprint or
meaningful data-boundary profile changes. Runtime receipt refresh alone does
not invalidate unchanged consent, but a broader data/tool boundary does.

### 3.3 Storage

Use the existing closed Settings preferences store or a dedicated bounded
local preference if that avoids coupling editable scan preferences to
consent. The owner must:

- strict-decode unknown keys/versions;
- write atomically;
- expose no generic dictionary/string preference;
- preserve decline explicitly;
- support exact forget/reset from Privacy & Data;
- never synchronize remotely;
- never enter Local Knowledge or Evidence Store report payloads.

## 4. First-Use Flow

The first normal Deep Dive start request with all non-disclosure dimensions
ready presents one native sheet:

- concise purpose and four/five aggregate boundary sections;
- current 10/30/60 preset summary;
- `Accept & Continue`;
- `Not Now`;
- link/action to inspect current runtime safety status in Settings;
- no “trust Codex”, “proceed anyway”, per-tool toggles or bypass.

`Accept & Continue`:

1. atomically persists current acceptance;
2. refreshes all admission dimensions;
3. returns a typed `accepted` result to the future Task 42 caller.

It does not start a model turn itself. Task 42 must separately re-evaluate the
entire start admission.

`Not Now` persists decline or returns a typed decline according to the chosen
UX contract, keeps valid page state and never starts Investigation.

Obsolete acceptance presents the current full disclosure again; it is not
silently upgraded.

## 5. Settings Model

### 5.1 Replace static implementation state

Evolve the current Settings model from:

```text
SettingsDeepDiveAvailability.implementationUnavailable
SettingsRuntimeDisclosure(hasAction: false, persistsAcceptance: false)
```

to typed independent status:

- source readiness;
- disclosure status/version;
- Codex discovery/auth/syntax;
- Task 39 runtime receipt freshness/admission;
- production dependency presence;
- current workflow availability;
- selected budget preset/limits;
- aggregate Deep Dive availability.

Task 41 may show `available` as a configuration state, but normal App start
remains feature-gated until Task 44. The UI must distinguish:

```text
Safety/runtime verified
Product flow admission pending
```

until Task 44 removes the final feature gate.

### 5.2 Safe repair actions

Allowed actions:

- `Review Disclosure`;
- `Accept Disclosure` / `Review Again`;
- `Check Again` for Codex;
- `Run Safety Check` through the existing bounded diagnostic owner;
- `Run Quick Scan` / open Scan;
- select a fixed budget preset;
- `Forget Acceptance`;
- inspect technical receipt details.

No action may:

- edit Codex config;
- select arbitrary provider/model;
- add CLI flags;
- disable a required capability;
- weaken write/network/Unix/no-Executor controls;
- grant TCC/FDA/Accessibility;
- bypass stale source/runtime.

### 5.3 Budget details

Show:

- `10 min · Focused`;
- `30 min · Balanced` default;
- `60 min · Thorough`;
- wall-clock is a maximum, not expected duration;
- advanced exact turns, Probe calls/read/output/context/concurrency/no-gain;
- direct-tool and token values as observed stopping ceilings, not hard prepaid
  guarantees;
- token usage may be unavailable;
- no provider/model selector.

## 6. Runtime Receipt Freshness

Replace any hard-coded admitted receipt comparison with one exact current
admission projection owned by Task 39. Freshness binds:

- runtime profile/revision;
- report schema/fingerprint;
- current App/helper/service identity;
- provider/auth projection contract;
- nine capability matrix;
- twelve integrity/control matrix;
- verification timestamp/lifetime;
- canonical prompt/schema revisions.

Settings consumes a typed admitted/stale/failed/unverified result. It does not
reimplement the machine verifier or infer containment from Codex installation.

A stale receipt keeps Quick Scan available and offers only safe recheck. It
does not retain prior finding counts, explained gain or running stages.

## 7. Tests First

### 7.1 Disclosure domain/storage

- exact v1 content fingerprint;
- English and `zh-Hans` semantic item parity;
- accepted/declined/not-present/obsolete states;
- strict unknown key/version rejection;
- atomic persistence failure;
- forget/reset;
- content/profile version change invalidates;
- locale-only rendering change does not silently alter semantic fingerprint;
- no generic trust/bypass/execution fields;
- no remote sync/Store/Local Knowledge persistence.

### 7.2 Admission matrix

- every dimension independently false;
- all dimensions true;
- source baseline missing/stale/partial;
- disclosure absent/declined/obsolete;
- Codex missing/check failed/syntax unsupported/auth unavailable;
- runtime current/stale/failed/unverified;
- dependency missing;
- workflow busy;
- invalid budget;
- acceptance cannot substitute for runtime;
- runtime cannot substitute for acceptance;
- final Task 44 feature gate remains false.

### 7.3 First-use flow

- disclosure appears only at normal first-use request;
- Accept persists then requires fresh full admission;
- Not Now starts nothing and preserves Quick Scan;
- obsolete acceptance re-presents;
- concurrent acceptance/start requests single-flight;
- persistence failure starts nothing;
- no per-tool/path/domain prompts;
- no start closure hidden inside the disclosure store.

### 7.4 Settings model/UI

- all status combinations and reason-specific repair actions;
- runtime verified versus product-flow pending distinction;
- 10/30/60 labels and exact advanced limits;
- observed/hard/unavailable usage wording;
- no provider selector/arbitrary flags/safety bypass;
- Quick Scan unaffected in all blocked states;
- no stale success metrics in safety-blocked state;
- VoiceOver labels and keyboard flow.

### 7.5 Release/structural

- no DEBUG diagnostic activation in ordinary disclosure UI;
- disclosure code references no Executor/Trash/authorization;
- acceptance record cannot reach Investigation start directly;
- no system permission mutation;
- no Codex config write.

## 8. UI Verification

Follow the repository UI loop:

```text
narrow App build/tests
→ launch actual Debug .app
→ Peekaboo image/see/inspect_ui
→ focused XCUITest
→ authoritative full verifier
```

Capture actual Light/Dark English/`zh-Hans` evidence for:

- disclosure first use;
- declined;
- accepted/current;
- obsolete;
- runtime stale;
- Codex unavailable;
- verified safety but Task 44 product-flow pending;
- budget advanced details.

Peekaboo remains read-only. Do not request/change Accessibility, Event
Synthesizing, TCC or Automation Mode. Retry focus-related UI failures if user
screen activity caused them.

## 9. Expected Files

```text
Sources/StornautCore/Settings/DeepDiveDisclosure.swift
Sources/StornautCore/Settings/SettingsPreferences.swift
StornautApp/Settings/SettingsState.swift
StornautApp/Settings/SettingsModel.swift
StornautApp/Settings/CodexSettingsView.swift
StornautApp/Investigations/DeepDiveDisclosureSheet.swift
StornautApp/AppState/AppDependencies.swift
StornautAppTests/DeepDiveDisclosureTests.swift
StornautAppTests/SettingsModelTests.swift
StornautAppUITests/DeepDiveDisclosureUITests.swift
StornautApp/Resources/en.lproj/Localizable.strings
StornautApp/Resources/zh-Hans.lproj/Localizable.strings
scripts/verify-investigation-boundaries
scripts/verify-app-release-boundaries
docs/plans/active/task-41-implementation-brief.md
docs/reports/phase-d-task-41-review.md
docs/agent/coding-agent-handoff.md
docs/plans/active/README.md
docs/plans/roadmap.md
AGENTS.md
```

Exact filenames may follow current style. Task 41 may add a sheet host seam for
tests but must not implement Task 42 Investigation state or Task 43 workspace.

## 10. Focused Validation

Run serially:

```text
swift test --filter DeepDiveDisclosure
swift test --filter SettingsPreferences
xcodebuild ... -only-testing:StornautAppTests/DeepDiveDisclosureTests
xcodebuild ... -only-testing:StornautAppTests/SettingsModelTests
xcodebuild ... -only-testing:StornautAppUITests/DeepDiveDisclosureUITests
scripts/verify-investigation-boundaries
scripts/verify-app-release-boundaries
scripts/check-doc-links
git diff --check
```

Then:

```text
swift test --parallel false
scripts/verify --full
```

Heavy SwiftPM/Xcode runs must not overlap.

## 11. Independent Review

Review for:

- acceptance treated as containment;
- runtime receipt treated as consent;
- hard-coded/stale receipt admission;
- generic trust/bypass state;
- per-tool/path/domain prompts or toggles;
- arbitrary provider/model/CLI control;
- disclosure starting work before full re-admission;
- obsolete acceptance silently upgraded;
- stale runtime retaining success metrics;
- normal UI enabled before Task 44;
- system permission/Codex config mutation;
- execution authority reference;
- bilingual semantic drift;
- accessibility/keyboard defects;
- stale docs/broken links.

Fix all P0–P2 findings and rerun affected checks before final full verification.

## 12. Explicit Non-Goals

- Task 42 App Investigation actor/state machine;
- Task 43 Investigations workspace;
- actual normal product Deep Dive start;
- signed runtime diagnostic changes except typed receipt consumption;
- report-to-Review changes;
- cleanup Plan/Policy/selection/authorization/execution;
- provider/model selector;
- system permission onboarding changes;
- release/notarization/distribution.

## 13. Completion and Git

Task 41 completes only when:

- versioned acceptance and full admission matrix pass;
- actual-window bilingual Light/Dark evidence is captured;
- focused XCUITest passes;
- runtime/disclosure remain independent;
- normal Deep Dive remains feature-gated;
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
