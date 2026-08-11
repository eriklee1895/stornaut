# ADR 0015: Headless CI and Full Local Verification

> Status: Accepted
>
> Date: 2026-08-11
>
> Decision owners: Stornaut maintainers
>
> Supersedes the manual-only Epic 0 GitHub workflow. Amends the verification
> responsibilities in [`../agent/development-tooling.md`](../agent/development-tooling.md)
> and [`../agent/ui-testing-guide.md`](../agent/ui-testing-guide.md).

## Context

The repository had one unified verifier and one GitHub workflow, but they did
not form an effective regression net. The workflow was named `Epic 0
Verification`, ran only through `workflow_dispatch`, allowed fifteen minutes,
and invoked the full local verifier. That verifier immediately entered the
host-specific Automation Mode/XCUITest path. A GitHub-hosted runner does not
represent the awake, unlocked, explicitly authorized desktop required by the UI
evidence contract.

The same verifier also repeated common evidence. `verify-phase-b-gate` ran the
SwiftPM tests, seven source-boundary checks and the rule compiler; the parent
then ran those checks again. Every command ran serially without a persisted
duration, so the highest-frequency quality gate had no cost baseline.

CI does not need to prove every local acceptance property. It needs a reliable,
automatic baseline on pull requests and `main`: compilation, deterministic
tests and safety/build contracts. Live UI behavior and host permission evidence
remain important, but belong to the local completion loop or a future dedicated
UI lab.

## Evidence

- The former workflow had only a `workflow_dispatch` trigger and called bare
  `scripts/verify` with a fifteen-minute timeout.
- The former `scripts/verify` started with
  `verify-ui-automation-mode --allow-auth-prompt`, then XCUITest and `.xcresult`
  screenshot export.
- The accepted view snapshot harness renders in `StornautAppTests` without an
  `NSWindow`, display, Automation Mode or TCC grant; see [ADR 0014](0014-view-snapshot-regression.md).
- GitHub's macOS 26 arm64 hosted image documents the `macos-26` label and
  `/Applications/Xcode_26.6.app`, matching the repository's validated Xcode
  generation: <https://github.com/actions/runner-images/blob/main/images/macos/macos-26-arm64-Readme.md>.
- A verifier contract test executes the CLI help/list/error paths and statically
  prevents the ordinary CI workflow from referencing UI/host-only gates.
- The first real hosted run, [GitHub Actions run 31506014347](https://github.com/eriklee1895/stornaut/actions/runs/31506014347),
  built the package in 49.082 seconds, then launched the Swift Testing cases in
  parallel. A process-runner test timed out under contention and many unrelated
  process/cancellation/scan tests remained unfinished until the thirty-minute
  job limit cancelled the run. This was test-level resource contention, not a
  slow compile or UI dependency.
- Apple documents that Swift Testing runs tests in parallel by default and that
  `swift test --no-parallel` disables this globally:
  <https://developer.apple.com/documentation/Testing/Parallelization>.
  The same 303 non-benchmark tests passed locally and sequentially in 34.75
  seconds.
- The serialized replacement, [GitHub Actions run 31510609858](https://github.com/eriklee1895/stornaut/actions/runs/31510609858),
  completed all 303 tests in 39.988 seconds rather than hanging. One test still
  failed because it used the Xcode-provided `/usr/bin/python3` process merely
  to emit eight stderr bytes, and that interpreter's cold start exceeded the
  test's two-second timeout. The fixture now launches `/bin/ls` directly
  against a unique nonexistent path, preserving the stderr truncation and
  timeout contract without measuring interpreter startup.
- The replacement run also surfaced a Node.js 20 deprecation warning from
  `actions/upload-artifact@v4`. The workflow uses the current Node.js 24 action
  majors, `actions/checkout@v6` and `actions/upload-artifact@v7`; upstream usage
  is documented at <https://github.com/actions/checkout> and
  <https://github.com/actions/upload-artifact>.
- A third hosted run, [GitHub Actions run 31512216719](https://github.com/eriklee1895/stornaut/actions/runs/31512216719),
  passed all 303 tests in 37.164 seconds and then failed immediately because the
  hosted image did not provide `rg`, which the seven boundary scripts,
  verifier contract and documentation checks use. The workflow now installs
  ripgrep only when absent and records `rg --version` before verification.

## Decision

### Two explicit modes, with a compatible default

`scripts/verify --headless` is the ordinary CI contract. It runs:

- SwiftPM build and the non-benchmark SwiftPM tests, with test functions
  serialized via `--no-parallel` to avoid process/pipe exhaustion on the
  lower-resource hosted runner;
- all seven current source-boundary checks and the Automation Mode parser's
  pure self-test;
- App-host tests, including committed Design System and Overview snapshots;
- Debug App build, local signing/bundle checks and the Debug/Release fixture
  boundary build;
- localization, rule compiler, verifier-contract and documentation/diff checks.

It does not run XCUITest, window screenshot export, Automation Mode readiness,
Peekaboo/TCC checks, strict matcher benchmarks or Phase B product/cancellation
performance evidence.

`scripts/verify --full` adds those XCUITest/window and performance gates and
retains Swift Testing's default cross-test parallelism as local concurrency
stress. Bare `scripts/verify` remains an alias for full mode so the existing
repository completion contract fails safe rather than silently becoming weaker.

### One owner for each repeated check

The full verifier runs the common SwiftPM, boundary and rule-compiler checks
once. `verify-phase-b-gate --product-only` retains the product/cancellation
benchmark and safety evidence without repeating the common checks. The phase
gate's no-argument behavior remains available for historical or focused use.

### Persist step timings

Every verifier step prints start/pass/fail plus elapsed seconds and writes a TSV
record to `.derivedData/verification/<mode>-timings.tsv`. The file is persisted
after every completed step and includes an ordinary failing step when
verification stops. CI attempts to upload the headless record even after a
failure or cancellation. This makes later timeout or parallelization changes
evidence-driven.

### Conventional GitHub Actions baseline

`Stornaut CI` runs on pull requests, pushes to `main`, and manual dispatch. It
uses the pinned macOS 26 arm64/Xcode 26.6 hosted image, read-only repository
permission, concurrency cancellation and a thirty-minute timeout. Its only
project gate is `scripts/verify --headless`. A setup step supplies ripgrep when
the runner image does not already include it because the repository's static
fitness functions intentionally use `rg`.

No ordinary GitHub-hosted job runs XCUITest, Peekaboo, Screen Recording/TCC or
Automation Mode. A future dedicated UI runner requires its own approved host
security, session lifecycle and evidence policy.

## Consequences

- Every pull request receives an automatic compile/test/safety baseline without
  pretending a hosted worker is a trusted live desktop.
- View snapshots make meaningful visual regressions part of that baseline while
  window interaction and runtime inspection stay local.
- Local task completion still requires full verification under the repository
  working loop; a green headless job is necessary but not sufficient for a UI
  change.
- CI cost and failures become attributable to named steps.
- The source-boundary scripts remain regex/static fitness functions. Replacing
  them with compiler-enforced module boundaries is a separate architecture
  change, not hidden inside this CI refactor.

## Residual Risks

- The first hosted run may expose snapshot rasterization or signing behavior
  that differs from the development host despite the pinned OS/Xcode image.
  Such a failure is evidence to diagnose, not a reason to disable the suite.
- GitHub can update a runner image behind a stable label. The explicit Xcode
  path and recorded toolchain fail or expose drift, but do not make the image
  immutable.
- Ripgrep is a CI-only Homebrew dependency and its resolved version is recorded
  rather than pinned to a shipped application artifact. A semantic CLI drift
  will fail the boundary/contract steps and is reviewed as verifier-tooling
  evidence.
- The headless suite is still serial and includes multiple Xcode builds. The
  initial timing artifact must be collected before adding caching or parallelism.
- Serializing test functions in headless CI reduces cross-test race stress.
  Full local verification remains parallel; individual concurrency tests still
  exercise their own workers, actors, cancellation and process trees in both
  modes.
- The full verifier still depends on an awake, unlocked local session and user-
  authorized UI Automation. CI does not close that host-specific evidence gap.

## Validation

Local acceptance on the recorded macOS 26.5.1 / Xcode 26.6 Apple Silicon host
confirmed:

- `scripts/verify-contract` passes, including negative CLI argument checks and
  the workflow prohibition on host/UI-only gates;
- a fresh `scripts/verify --headless` exits zero with fourteen unique timing
  rows in 229.308 seconds. Its serialized SwiftPM step ran all 303
  non-benchmark tests in 47.332 seconds, with the test run itself completing in
  34.684 seconds;
- a fresh `scripts/verify --full` exits zero with nineteen unique timing rows in
  479.597 seconds, including 9/9 XCUITest methods, all seventeen window
  attachments, the three matcher benchmarks and the 7.568-second deduplicated
  Phase B product/cancellation step;
- a prior full attempt failed two UI methods while its `.xcresult` recorded
  unrelated foreground windows obstructing the target and one transient
  windowless launch. Both methods then passed in focused reproduction, no retry
  or test-code change was added, and the fresh uninterrupted full invocation
  above passed. This is direct evidence for keeping live-desktop UI work out of
  ordinary hosted CI.

The first three hosted runs were intentionally retained as evidence: the first
reached the thirty-minute timeout inside the parallel SwiftPM test step; the
second proved serialization removed that hang and isolated the heavyweight
Python fixture; the third proved the portable test suite passes and exposed the
missing static-analysis dependency. Final hosted timing and outcome are
recorded by the replacement pull-request run.

Final acceptance also requires the pull request's real `Stornaut CI` run to
exit zero on GitHub's hosted `macos-26` arm64 runner.
