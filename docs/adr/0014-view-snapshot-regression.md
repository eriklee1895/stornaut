# ADR 0014: Deterministic View Snapshot Regression

> Status: Accepted for the test architecture workstream
>
> Date: 2026-08-11
>
> Decision owners: Stornaut maintainers
>
> Supersedes nothing. Amends the evidence standard in
> [`../agent/ui-testing-guide.md`](../agent/ui-testing-guide.md).
> Ordinary CI execution scope is amended by
> [ADR 0015](0015-headless-ci-verification.md): golden comparisons run in the
> full local verifier, not the portable headless gate.

## Context

UI regression evidence had one mechanised layer and one human layer, with
nothing in between.

`scripts/verify-ui-screenshots` computes mean luminance and luminance standard
deviation over seventeen XCUITest attachments and asserts relationships such as
`light - dark >= 40`, `standard deviation >= 20` and `160...250` bands. Those
assertions detect an inverted appearance, a blank window and a missing
attachment. They cannot detect a shifted layout, truncated text, overlapping
controls, wrong spacing or a wrong rendered value, because none of those change
the aggregate statistics of a window.

Everything the luminance check cannot see was delegated to a Coding Agent
looking at a Peekaboo capture. That judgement is not repeatable, is not
reviewable after the fact, cannot run in CI, and by the guide's own rules is not
committed. The strictness the guide claimed was therefore not the strictness the
repository actually enforced.

## Spike Evidence

Recorded on macOS 26.5.1, Xcode 26.6, Swift 6.3.3, Apple Silicon.

### Off-screen SwiftUI rendering is viable

A throwaway package rendered SwiftUI content under plain `swift test` with
`NSApp == nil`, no `NSWindow` and no active display requirement. Both
`NSHostingView` + `cacheDisplay(in:to:)` and `ImageRenderer` produced non-blank,
content-differentiated PNGs. Rendering therefore does not need the display, UI
Automation Mode, Screen Recording or any TCC grant.

`NSWindow` was deliberately excluded: a hosting window contributes a title bar
whose height varies between a physical Mac and a virtual machine, which is a
known source of environment-dependent snapshot drift.

### SwiftUI ignores the module bundle for implicit localization

The same spike placed `en.lproj/Localizable.strings` in the module's own
resources and confirmed `Bundle.module` carried it. `Text("spike.key")`
authored inside that module still rendered the literal key, byte-identical to
`Text(verbatim: "spike.key")`. `Text("spike.key", bundle: .module)` rendered the
translated value.

Implicit `LocalizedStringKey` lookup therefore resolves against `Bundle.main`,
not the defining module. Two consequences follow:

- snapshots hosted by `StornautAppTests` inherit the real app bundle and render
  genuine `en` and `zh-Hans` product strings;
- a future move of the views into a SwiftPM module cannot rely on implicit
  lookup, because a SwiftPM test runner has no app bundle.

`StornautApp/` currently contains 180 implicit localization call sites across
28 files. Only the 56 `Text(_:)` uses accept a `bundle:` argument; `Section`,
`Button`, `Label`, `Picker`, `TextField`, `navigationTitle`, `help` and
`accessibilityLabel` would each need a structural rewrite into their
`Text`-taking or label-closure forms. That cost is recorded here so the module
extraction is planned with it in view rather than discovering it midway.

## Decision

### Render off-screen at a fixed scale

`SnapshotHarness` renders through a free-standing `NSHostingView` with an
explicit `NSAppearance`, an injected `colorScheme` and an injected `locale`,
into an `NSBitmapImageRep` allocated explicitly at 1x. Fixing the bitmap
removes the host's backing scale factor from the result.

### Host the snapshots in the app test target

Snapshots live in `StornautAppTests`, whose `TEST_HOST` is `Stornaut.app`.
`Bundle.main` is therefore the real product bundle and implicit localization
resolves normally, so a snapshot exercises the same strings a user sees. This
keeps the harness independent of the module extraction rather than blocked
behind it.

### Build the harness in-repo

`swift-snapshot-testing` publishes no SwiftUI image strategy for macOS; the
maintainers direct users to supply their own. The rendering step — the only
hard part — would be written either way. What remains is golden file
management, a tolerance rule and failure artefacts, and Swift Testing's
attachment support already covers the last of those. Taking the package would
add the repository's first external dependency and require hand-editing a
hand-authored `project.pbxproj`. The harness is therefore written in-repo and
includes its own difference visualiser.

### Tolerance

A pixel counts as changed when any channel moves more than two levels; a
snapshot fails when more than 0.1% of pixels changed. Text antialiasing moves
single channels by one or two levels and stays far below the ratio.

The rule was validated against a deliberate regression: changing `MetricTile`
padding from 16 to 18 points, a change that is hard to see by eye, moved 4.7%
to 5.6% of pixels across the four `metric-tile` variants — a margin of roughly
fifty times the threshold — while the three unrelated components stayed at zero
drift and passed.

### Goldens are committed

Goldens live in `Tests/Fixtures/Snapshots/` beside the existing domain and SQL
fixtures, and are committed. A committed reference image is what makes the
difference reviewable in a pull request rather than existing only on one
machine.

This narrows, and does not remove, the guide's prohibition on committing
screenshots. The prohibition exists because host captures carry real user
paths, window contents and TCC state. Snapshot goldens render synthetic
component and page fixtures. Page fixtures may render fixed synthetic paths,
but no value may be derived from the host filesystem or contain private user
data. The privacy reason therefore does not apply to them. Peekaboo captures
and raw `.xcresult` bundles remain uncommitted.

## Consequences

- Twenty-four initial goldens cover sixteen shared-design-system variants and
  eight representative Overview page variants across Light/Dark and
  `en`/`zh-Hans`. The two suites execute in under six seconds on the measured
  development host.
- The two pixel-comparison suites run in `scripts/verify --full`. Ordinary CI
  still runs the eight harness algorithm/state tests and all other App-host
  contracts, but skips the visual suites because their raster output changed
  across the observed macOS patch boundary.
- The luminance contract in `scripts/verify-ui-screenshots` is retained as a
  cheap window-level sanity check. It is no longer the only mechanised visual
  evidence, and should not be extended to carry weight it cannot bear.
- Re-recording is explicit: `TEST_RUNNER_STORNAUT_RECORD_SNAPSHOTS=1`. The
  prefix is required because `xcodebuild test` does not forward the ambient
  environment to the test process.
- A reviewer must look at a re-recorded golden. A silently re-recorded
  reference asserts nothing.
- The harness does not exercise window chrome, real scan data, navigation or
  the app lifecycle. XCUITest and `scripts/verify` remain the acceptance truth.

## Residual Risks

- Determinism has been demonstrated on the recorded Apple Silicon host, not
  across machines or macOS patches. GitHub Actions run 31512656250 used macOS
  26.5.2 (25F84) and the same Xcode 26.6 as the macOS 26.5.1 (25F80)
  development baseline; all 24 goldens drifted. Fixing scale, windowlessness
  and Xcode version therefore does not establish cross-host pixel identity.
- Font rasterisation or SwiftUI renderer changes can cause legitimate broad
  drift. Such a change requires visual review and an explicit golden update;
  weakening the tolerance to absorb it is not an acceptable default.
- A committed golden proves that rendering stayed stable, not that the
  original visual choice was good. Initial and re-recorded baselines still
  require human review.
- Localization is process-global. Snapshot suites are serialized, restore the
  prior language after every render, and fail if another writer changes it
  during rendering, but an uncoordinated future test could still trigger that
  fail-loud guard.
- Current page-level coverage is Overview only. Window chrome, navigation,
  Settings scenes, lifecycle and real runtime state remain outside this layer.

## Validation

The accepted implementation was checked on the spike host with:

- 8 focused harness contract tests covering state restoration, remediation
  text, decode/size failures, channel tolerance and ratio tolerance;
- 24 golden comparisons across the Design System and Overview suites;
- 10 consecutive runs of the three snapshot/harness suites without a drift or
  localization race;
- all 114 `StornautAppTests` passing in one App-test run after the harness and
  system-image fixes;
- a system API probe confirming the former
  `externaldrive.badge.magnifyingglass` name did not resolve and its shared
  `externaldrive` replacement does;
- a real `Stornaut.app` build-and-run plus read-only Peekaboo capture, followed
  by visual review of the fixed navigation and Quick Scan icons. The host
  screenshot remains ignored because it contains a real user path.
- a real GitHub-hosted macOS run proving the non-visual contracts pass while
  the same-Xcode, next-patch macOS raster output is not portable; ADR 0015 keeps
  those goldens in the full local evidence loop rather than weakening them.

A fresh uninterrupted `scripts/verify` completed after all review fixes with
exit 0 in 1,019.48 seconds. Its UI result bundle reports 9/9 XCUITest methods
passed and all 17 expected attachments were exported; the same invocation then
completed the SwiftPM, benchmark, boundary, App-test/snapshot, Debug/Release,
signing, localization, rule-compiler and documentation gates.
