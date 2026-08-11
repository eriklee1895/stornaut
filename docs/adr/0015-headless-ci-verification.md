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

## Decision

### Two explicit modes, with a compatible default

`scripts/verify --headless` is the ordinary CI contract. It runs:

- SwiftPM build and the non-benchmark SwiftPM tests;
- all seven current source-boundary checks and the Automation Mode parser's
  pure self-test;
- App-host tests, including committed Design System and Overview snapshots;
- Debug App build, local signing/bundle checks and the Debug/Release fixture
  boundary build;
- localization, rule compiler, verifier-contract and documentation/diff checks.

It does not run XCUITest, window screenshot export, Automation Mode readiness,
Peekaboo/TCC checks, strict matcher benchmarks or Phase B product/cancellation
performance evidence.

`scripts/verify --full` adds those XCUITest/window and performance gates. Bare
`scripts/verify` remains an alias for full mode so the existing repository
completion contract fails safe rather than silently becoming weaker.

### One owner for each repeated check

The full verifier runs the common SwiftPM, boundary and rule-compiler checks
once. `verify-phase-b-gate --product-only` retains the product/cancellation
benchmark and safety evidence without repeating the common checks. The phase
gate's no-argument behavior remains available for historical or focused use.

### Persist step timings

Every verifier step prints start/pass/fail plus elapsed seconds and writes a TSV
record to `.derivedData/verification/<mode>-timings.tsv`, including the failing
step when verification stops. CI uploads the headless record even after a
failure. This makes later timeout or parallelization changes evidence-driven.

### Conventional GitHub Actions baseline

`Stornaut CI` runs on pull requests, pushes to `main`, and manual dispatch. It
uses the pinned macOS 26 arm64/Xcode 26.6 hosted image, read-only repository
permission, concurrency cancellation and a thirty-minute timeout. Its only
project gate is `scripts/verify --headless`.

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
- The headless suite is still serial and includes multiple Xcode builds. The
  initial timing artifact must be collected before adding caching or parallelism.
- The full verifier still depends on an awake, unlocked local session and user-
  authorized UI Automation. CI does not close that host-specific evidence gap.

## Validation

Local acceptance on the recorded macOS 26.5.1 / Xcode 26.6 Apple Silicon host
confirmed:

- `scripts/verify-contract` passes, including negative CLI argument checks and
  the workflow prohibition on host/UI-only gates;
- a fresh `scripts/verify --headless` exits zero with fourteen unique timing
  rows in 279.039 seconds;
- a fresh `scripts/verify --full` exits zero with nineteen unique timing rows in
  487.317 seconds, including 9/9 XCUITest methods, all seventeen window
  attachments, the three matcher benchmarks and the eight-second deduplicated
  Phase B product/cancellation step;
- a prior full attempt failed two UI methods while its `.xcresult` recorded
  unrelated foreground windows obstructing the target and one transient
  windowless launch. Both methods then passed in focused reproduction, no retry
  or test-code change was added, and the fresh uninterrupted full invocation
  above passed. This is direct evidence for keeping live-desktop UI work out of
  ordinary hosted CI.

Final acceptance also requires the pull request's real `Stornaut CI` run to
exit zero on GitHub's hosted `macos-26` arm64 runner.
