# ADR 0001: Package-First Native macOS Shell

> Status: Accepted
> Date: 2026-08-09
> Decision owners: Stornaut maintainers
> Related study: [`../upstream-studies/epic-0-foundation.md`](../upstream-studies/epic-0-foundation.md)

## Context

Stornaut needs:

- testable platform-agnostic Core and Codex modules;
- a real macOS `.app` identity for later FDA/TCC and subprocess inheritance experiments;
- one native main window, an independent Settings scene, and no MenuBarExtra/background runtime;
- a deterministic local/CI verification path;
- no third-party project generator in Epic 0.

A SwiftPM executable can compile SwiftUI/AppKit code but is not by itself a complete App host contract. It does not define the checked-in Xcode App/Test target, bundle settings, test host, archive path, code-signing configuration, or stable App-context identity needed by later Spikes.

## Decision

Use a package-first hybrid:

```text
Stornaut.xcodeproj
├── StornautApp
├── StornautAppTests
└── StornautAppUITests

Package.swift
├── StornautCore
├── StornautCodex
├── StornautCoreTests
└── StornautCodexTests
```

- Check in `Stornaut.xcodeproj`; do not use xcodegen/Tuist.
- Link root local package products `StornautCore` and `StornautCodex` into `StornautApp`.
- Use bundle identifier `com.eriklee.stornaut`.
- Target macOS 26 and Apple Silicon only.
- Keep the App Sandbox disabled per the approved non-App-Store v1 architecture.
- Build App/Test targets through shared scheme `Stornaut`.
- Keep SwiftPM tests independently runnable.
- Use ad-hoc signing locally because the current keychain has no valid Apple Development or Developer ID identity.
- Re-sign the clean local App with an explicit designated requirement:

  ```text
  designated => identifier "com.eriklee.stornaut"
  ```

- Restrict the local signing and audit scripts to the exact repository-owned DerivedData App path.
- Treat this signature only as a repeatable local Spike identity. It is not a Developer ID, Gatekeeper, hardened runtime, notarization, or release result.

## App Shell Contract

The initial App contains only:

- one `Window` scene with ID `main`;
- four `NavigationSplitView` destinations:
  - Overview
  - Scan
  - Investigations
  - History
- a Sidebar-bottom Settings gear that opens the independent Settings scene without becoming a fifth destination;
- an independent SwiftUI `Settings` scene;
- English and `zh-Hans` localization resources;
- placeholder content with no scan simulation, Agent chat, MenuBarExtra, timer, background task, or cleanup action.

The New Window command is removed. Reopening the `.app` through LaunchServices reuses the same process.

## Evidence

### Tests-first result

The first App test run failed after the Xcode host and local packages resolved because `AppDestination` did not exist. Two unrelated project issues were found and corrected before accepting the red test:

1. App Debug needed `ENABLE_TESTABILITY=YES`.
2. The synchronized App folder needed exceptions for `Info.plist` and `StornautApp.entitlements`.

The accepted red state failed only on the missing `AppDestination` contract. After implementing the four cases, the Xcode test passed.

### Automated verification

`scripts/verify` performs:

1. clean SwiftPM build and tests;
2. App unit tests through `xcodebuild`;
3. a separate clean App build without XCTest injection;
4. local App re-signing with the explicit designated requirement;
5. bundle audit:
   - bundle ID `com.eriklee.stornaut`;
   - package type `APPL`;
   - executable `Stornaut`;
   - minimum macOS `26.0`;
   - architecture `arm64`;
   - App Sandbox entitlement `false`;
   - valid deep/strict signature;
   - expected designated requirement;
   - English and `zh-Hans` resources;
   - no embedded test PlugIns;
6. XCUITest Light/Dark shell and Settings flows;
7. four window-level screenshot attachments exported from `.xcresult`;
8. screenshot filename, dimension and theme checks;
9. local Markdown links and `git diff --check`.

Observed result: all automated checks passed.

### LaunchServices/window result

- The signed App launched through `open`.
- A second `open` reused the same PID.
- CoreGraphics window metadata showed one layer-0 Stornaut window.
- The main window measured `1180 × 760`.
- Default and forced Dark launches each produced one main window with the same geometry.
- XCUITest verified the four workspace identifiers and Sidebar Settings affordance in English.
- Both the Sidebar Settings button and `⌘,` opened the independent Settings window.
- XCUITest exported window-level Light/Dark screenshots for the shell and Settings as `.xcresult` attachments.
- Light/Dark state is asserted through the target App's `effectiveAppearance`; Settings screenshots additionally pass a luminance-difference threshold.
- Screenshot export normalizes attachment names under `.derivedData/ui-screenshots/`.

### Signing result

- Current valid Apple code-signing identities: `0`.
- Xcode initially emitted an ad-hoc signature whose designated requirement was a `cdhash`.
- `scripts/sign-local-app` replaced it with an ad-hoc signature and explicit identifier requirement.
- `scripts/verify-app-bundle` verified the final requirement and non-sandbox entitlement.

## Limitations

- Direct terminal `screencapture` remains unavailable because the terminal lacks Screen Recording permission. XCUITest window screenshots are the supported automated replacement; no system permission was changed automatically.
- Direct `osascript` UI scripting remains unavailable because the terminal lacks Accessibility permission. XCUITest now validates both Settings entry paths without granting that permission.
- XCUITest uses a Debug-only appearance override so AppKit window materials and SwiftUI content enter deterministic Light/Dark states. Release/System behavior remains unchanged.
- Pixel-diff baselines are intentionally deferred until the branded UI exists.
- Ad-hoc designated requirements are local Spike evidence. Whether the current macOS TCC database consistently keys FDA decisions to this identity must be measured in Task 5.
- Developer ID, hardened runtime, archive/export, Gatekeeper, and notarization remain Epic 9 work.
- No UI concept PNG is shipped in the App target at this stage.

## UI Acceptance

- The user confirmed that navigation labels resolve correctly and `⌘,` opens Settings.
- XCUITest provides repeatable Light/Dark shell and Settings screenshots for future automated inspection.
- The Sidebar Settings gear is an affordance to the independent Settings scene, not a fifth workspace destination.

## Consequences

Positive:

- Core/Codex can evolve under fast SwiftPM tests.
- App identity, scenes, resources, signing, and App tests use native Xcode mechanisms.
- Task 5 can launch Codex from a real App process rather than a terminal proxy.
- No project generator or third-party package is required.

Costs:

- `project.pbxproj` is checked in and must be reviewed carefully.
- Local validation invokes both SwiftPM and Xcode.
- Ad-hoc re-signing requires a small repository-owned script.
- Release signing remains unverified until a valid Developer ID identity is available.

## Follow-up Gates

- Task 3 must discover Codex from the GUI environment without a login shell.
- Task 5 must test App-context FDA/TCC inheritance and direct read canaries.
- Epic 9 must replace local ad-hoc evidence with Developer ID/hardened-runtime/notarization evidence before release.
