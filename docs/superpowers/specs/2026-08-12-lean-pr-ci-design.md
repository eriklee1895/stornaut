# Lean Pull-Request CI Design

> Status: Implemented and validated
>
> Date: 2026-08-12
>
> Scope: ordinary GitHub-hosted pull-request and `main` verification only

## Problem

The first headless CI slice established a real automatic regression net, but
its contract is too close to a release acceptance gate. The recorded local
headless run took 233.265 seconds. The latest `main` run at design time,
[31536807588](https://github.com/eriklee1895/stornaut/actions/runs/31536807588),
spent 322.380 seconds inside the verifier. The largest costs were not the basic
test suites:

- `debug-release-fixture-boundary` rebuilt both Debug and Release products and
  consumed 35.2% of the local run and 116.219 seconds of that hosted run;
- `app-contract-tests` already built a Debug App test host, after which
  `debug-app-build` built the Debug App again in another DerivedData directory;
- `swiftpm-build` cleaned and built the package before `swift test` performed
  the test build;
- `clean-derived-data` discarded every reusable local build artifact even
  though GitHub-hosted jobs already start in a fresh checkout.

The result is a six-to-seven-minute hosted gate for a repository whose ordinary
CI requirement is intentionally modest: compile the code, run the deterministic
non-visual tests, and reject cheap safety or architecture drift.

## Goals

- Keep one macOS 26 arm64 job for each pull request, push to `main`, and manual
  dispatch.
- Target approximately three minutes from hosted job start to completion. This
  is an observed performance objective, not a flaky timing assertion.
- Preserve all current non-benchmark SwiftPM tests (330 at design time) and all
  current non-golden App contract tests (106 at design time).
- Preserve the inexpensive safety-critical source boundaries, rule compiler,
  localization, verifier contract, and documentation checks.
- Make each expensive compilation serve exactly one CI purpose.
- Keep `scripts/verify --full` as the canonical local completion gate.

## Non-goals

- No XCUITest, pixel golden, window screenshot, Peekaboo, TCC, Automation Mode,
  benchmark, or real-machine diagnostic work in GitHub-hosted CI.
- No Release product or DEBUG-fixture leakage claim in ordinary CI.
- No optimization of the full local verifier in this slice.
- No dependency or DerivedData cache, path-based test skipping, retry, test
  sharding, or multiple parallel macOS jobs.
- No branch-protection or coverage-policy change.

## Considered Approaches

### A. One deduplicated job

Keep one job and remove compilation that is redundant with a test action. This
retains the broad deterministic test surface, has one log and one required
check, and minimizes macOS runner consumption. This is the selected approach.

### B. Parallel SwiftPM and App jobs

Two jobs could reduce wall-clock latency below the selected design, but each
would pay checkout/toolchain setup and consume a separate macOS runner. The
repository does not yet need that cost or operational complexity.

### C. Change-aware path filtering

Skipping App or package tests based on changed paths can be faster, but the App
and package are coupled through project membership, generated catalogs, and
boundary scripts. Maintaining a sound dependency map would be more complex
than the current repository warrants.

## Selected Verification Contract

`scripts/verify --headless` remains the public CI entrypoint for compatibility.
It becomes an incremental, seven-step verifier:

1. `source-boundaries`
2. `localization-contract`
3. `verifier-contract`
4. `docs-and-diff`
5. `swiftpm-tests-serialized`
6. `rule-compiler`
7. `app-contract-tests`

The first four steps are ordered first so inexpensive structural failures stop
the job before a hosted runner spends time compiling. The SwiftPM test action
uses `swift test --no-parallel` and continues to skip only the three explicit
matcher benchmarks. It is the Swift package build evidence; headless CI no
longer runs `swift package clean` or a separate `swift build`.

The App contract action continues to skip `StornautAppUITests`,
`DesignSystemSnapshotTests`, and `OverviewSnapshotTests`. `xcodebuild test`
must compile and launch the Debug App test host before the 106 contracts can
pass, so it is the ordinary App compilation evidence. Headless CI does not run
a second `xcodebuild build` action.

An App test host is not a distributable product. The current test action injects
XCTest frameworks and `StornautAppTests.xctest`, and its designated requirement
differs from the locally re-signed standalone App. Therefore the lean job must
not pass that test host to `scripts/verify-app-bundle` or claim that it verified
a clean signed product. Standalone bundle/signing and Debug-versus-Release
fixture checks remain in `scripts/verify --full`.

`automation-parser-self-test`, `clean-derived-data`, `swiftpm-build`,
`debug-app-build`, `debug-app-sign`, `app-bundle`, and
`debug-release-fixture-boundary` are removed from the headless step list. Their
relevant evidence either comes from another selected step or belongs to the
full local gate.

## Workflow Behavior

`.github/workflows/ci.yml` continues to provide one read-only job on
`pull_request`, pushes to `main`, and `workflow_dispatch`. It keeps concurrency
cancellation, the pinned macOS 26 arm64/Xcode 26.6 environment, conditional
ripgrep provisioning, and timing-artifact upload.

The job invokes only `scripts/verify --headless`. Its timeout is reduced from
30 minutes to 10 minutes: the target runtime is approximately three minutes,
and a ten-minute ceiling leaves ample hosted-runner variance while bounding a
hang. No elapsed-time assertion fails an otherwise correct run.

## Failure and Evidence Policy

- Verification remains fail-fast and does not retry tests.
- Every completed step is persisted to
  `.derivedData/verification/headless-timings.tsv`; the workflow uploads the
  file on success or failure.
- A missing App test host, failed compilation, or failed contract remains an
  App-test failure. CI does not manufacture a standalone App after the fact.
- A hosted run above the performance target is investigated from its timing
  artifact. It does not justify silently dropping tests or adding a cache.
- A green headless job proves deterministic compilation/test and the listed
  static safety contracts. It does not replace the local full verifier.

## Contract and Documentation Changes

`scripts/verify-contract` will assert that the seven selected steps are present
and that headless CI omits the redundant build, clean, product-bundle, Release,
UI, visual, and performance steps. It will continue to assert workflow triggers,
read-only scope, pinned action majors, ripgrep provisioning, and the single
headless entrypoint.

ADR 0015 and the development-tooling/UI-testing documentation will be amended
to describe the lean contract. The implementation will record old and new
hosted timing evidence without rewriting the earlier failed-run history.

## Acceptance

Implementation is accepted only when all of the following hold:

1. `scripts/verify --headless --list-steps` prints exactly the seven ordered
   steps in this design.
2. `scripts/verify-contract` rejects reintroduction of the removed headless
   steps and passes on the selected workflow.
3. A fresh local `scripts/verify --headless` exits zero with every current
   non-benchmark SwiftPM test, every current non-golden App contract, and seven
   unique timing rows. The implementation report records the observed counts
   rather than treating the design-time 330/106 counts as permanent caps.
4. A fresh uninterrupted local `scripts/verify --full` still exits zero and
   retains standalone Debug/Release, bundle/signing, XCUITest, golden, and
   performance evidence.
5. A real pull-request run on GitHub exits zero. The first successful hosted
   timing is recorded; approximately three minutes is the target, with any
   material miss explained from per-step evidence rather than hidden by cache,
   retry, or test removal.
