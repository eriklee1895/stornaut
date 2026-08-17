# Phase D Task 39B2c-L1 Residue Observation Review

> Status: Complete; independently committed before machine execution
>
> Date: 2026-08-17
>
> Baseline: `d80354ef6516f8d6eda5fafe2e0a340d994c1234`
>
> Scope: helper-sealed per-Investigation audit-session, lease and runtime-root
> residue observation; no signed-App machine run or readiness verdict

## 1. Decision

This prerequisite is complete. A used interactive Investigation can no longer
promote the inner worker's `drained: true` response into enforced lifecycle
truth. The root helper now creates a strict outer residue observation only
after audit-session drain, worker reap, diagnostic-root removal and lease
removal, while the exact active Investigation slot is still retained.

The Investigation transport accepts that observation only when it is bound to
the exact nonce and App effective user, was produced during the same retire
operation, is not from the future, and reports zero residue.

This checkpoint does not observe final App/helper/service teardown, run the
real-model failure matrix, create a machine-admission receipt, claim
`signedInvestigationRuntimeReady` or enable product Deep Dive.

## 2. Closed Trust Gap

Before this checkpoint, `InvestigationRuntimeDiagnosticLifecycleOwner` mapped a
successful transport retirement directly to three `true` emptiness flags. The
wire response carried only an inner worker-owned Boolean and therefore could
not prove root-helper cleanup.

The implemented contract now:

- uses interactive response protocol v2 with a strict nested
  `LifecycleInvestigationResidueObservation`;
- binds the observation to Investigation UUID, audit-session ID, caller UID
  and completion time;
- reuses the existing PID-version, audit-token, audit-session and UID validator
  for a post-drain inventory observation;
- strictly enumerates the root-owned lease directory, rejecting unknown,
  malformed, linked, wrong-owner or wrong-mode entries;
- observes exact diagnostic-root absence and accepts only `ENOENT` as absent;
- constructs the outer response in the root helper instead of forwarding the
  inner worker response;
- requires observation generation after root/lease removal and before active
  state release;
- keeps the active slot and performs the existing second drain when the first
  observation is non-zero or fails; and
- rejects missing, foreign, stale, pre-retire, future or non-zero observations
  in the Investigation transport.

## 3. Tests First

The initial focused tests failed because the observation type, strict response
field, drainer observation, lease observation and transport admission did not
exist. They then passed after implementation. Coverage includes:

- strict round trip and unknown-field rejection;
- malformed identity and count bounds;
- exact audit-session identity validation;
- target-lease and complete lease-root counts;
- missing, foreign nonce, foreign UID, pre-retire, stale, future and non-zero
  transport rejection; and
- structural ordering of root removal, lease removal, observation and active
  state release.

## 4. Validation

| Gate | Result |
| --- | --- |
| exact new contract/identity/lease/transport/ordering tests | passed |
| Lifecycle-focused suite | 129 tests in 16 suites passed |
| Investigation lifecycle transport suite | 12/12 passed |
| structural source boundaries | passed |
| targeted Debug App/helper Xcode build | passed |
| final staged-only serialized SwiftPM regression | 949 tests in 39 suites passed |
| final serialized stage duration | 122.632 seconds |
| diff hygiene and credential/authority scan | passed |

The implementation changes nine non-document source/test paths with 904
additions and 68 deletions, below both checkpoint split limits. This
package/helper prerequisite intentionally does not run the authoritative full
verifier or XCUITest. The enclosing 39B2c product/security checkpoint still
owns its single final full run.

## 5. Independent Review

The first independent review found one P1: the initial staged snapshot released
active lifecycle state after a non-zero observation and left the lease-created
flag set after removing the lease. The fix keeps active identity until a zero
observation, updates lease state immediately after removal, and routes failure
through the existing second drain without attempting duplicate lease removal.

The post-fix review conclusion is `No unresolved P0-P2 findings.`

## 6. Safety Audit

This prerequisite does not:

- trust model or worker self-report as containment;
- observe or claim final App/helper/service topology absence;
- invoke a model or run Task 38 scientific turns;
- install, uninstall or mutate the fixed local lifecycle topology;
- add cleanup, Trash, Policy, authorization or Executor authority;
- modify `~/.codex/config.toml`;
- broaden network, filesystem or socket access; or
- enable product Deep Dive.

No new dependency or license is introduced.

## 7. Next Gate

39B2c machine-driver work may now consume the helper-sealed per-run observation.
The next checkpoint must still provide the independent root-owned topology
observer for exact App/helper/service teardown and combine it with this per-run
receipt before any machine readiness claim.
