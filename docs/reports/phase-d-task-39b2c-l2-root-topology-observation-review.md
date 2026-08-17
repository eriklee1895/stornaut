# Phase D Task 39B2c-L2 Root Topology Observation Review

> Status: Complete; read-only prerequisite before machine-driver execution
>
> Date: 2026-08-17
>
> Baseline: `eb8502fca9bb889ec2a62e3502f14eac82bd19fb`
>
> Scope: exact fixed App/helper/plist/service/process/runtime-root/lease-root
> observation; no install, uninstall, model run, machine verdict or product
> availability change

## 1. Decision

This prerequisite is complete. The future root-owned machine driver now has a
package-closed, read-only observer for the fixed local lifecycle topology. It
distinguishes installed and post-teardown phases and fails closed instead of
converting lookup, permission, identity or filesystem failures into absence.

The observation is an in-memory, non-`Codable` value. Its initializer is
file-private, so another package target cannot synthesize trusted topology
evidence. A machine-driver target may construct only the strict request, supply
the fixed-service probe and invoke the concrete Darwin artifact/process
observer. JSON, shell status and model output cannot create this authority.

This checkpoint does not invoke a model, run the Task 38 failure matrix, mutate
the installed topology, assemble a machine report, claim
`signedInvestigationRuntimeReady` or enable product Deep Dive.

## 2. Closed Trust Gap

L1 proves only per-Investigation audit-session, lease and diagnostic-root
cleanup inside one helper retire. L2 independently covers the remaining fixed
machine topology:

- installed root, diagnostic App and exact App executable;
- exact helper executable and launchd plist;
- fixed service identity supplied by an external root-owned probe;
- App and helper process identities, including PID version, audit session,
  effective UID and complete audit token; and
- the complete `R5Runtime` and lease roots.

The observer represents artifact state as `absent`, `presentValid`, `invalid`
or `unavailable`; process state as `absent`, `sameIdentityAlive`,
`identityReused` or `unresolved`; and service state with the same fail-closed
distinctions. Installed evidence cannot substitute for post-teardown evidence.

Only the first `lstat == ENOENT` can prove a fixed node absent, and only the
first exact PID identity lookup returning `ESRCH` can prove the captured process
absent. A later disappearance is unresolved. PID reuse is explicit and proves
only that the original captured identity is no longer alive.

## 3. Darwin Read-Only Evidence

Fixed nodes use `lstat → O_NOFOLLOW open → fstat → bounded read → final lstat`.
The observer binds device, inode, generation, owner, group, mode, link count,
size, modification time and change time. Executables additionally bind SHA-256.
The launchd plist is read through the validated descriptor and must match the
closed ten-field manifest exactly. App/helper signing reads are surrounded by
fixed-node validation before and after the Security query.

Process observation uses the exact captured identity, fixed executable path,
Security signing identity and a second full identity read. It does not use
`pgrep`, `ps -U`, process names, global UID coordination or PID-only
`kill(0)`. The launchd service probe remains injected because `launchctl print`
text is not a stable evidence schema; command execution and exit classification
remain machine-driver responsibilities.

## 4. Tests First

The initial contract and Darwin tests failed to compile because the L2 types did
not exist. They then exercised:

- installed/post-teardown phase separation and exact fixed descriptors;
- invalid, unavailable, foreign, stale, future and over-window evidence;
- symlink, hard-link, owner, group, mode, type, size, hash and metadata drift;
- path-to-descriptor and post-read identity changes;
- strict plist shape and signing mismatch;
- initial absence versus mid-observation disappearance;
- full PID-version/audit-token identity reuse;
- package-closed, non-serializable and non-forgeable observation authority;
- no mutation, readiness or Investigation-report dependency; and
- root-helper signing without widening App or peer authorization.

## 5. Independent Review

The first independent review found one P1: the process observer passed the root
helper's effective UID `0` into the existing PID+UID signing verifier, whose
admission guard intentionally rejects root. A real installed helper therefore
could never become `sameIdentityAlive`.

The tests-first fix makes topology process observation query Security with the
already captured complete audit token. The audit-token reader may now resolve a
root identity, while `LifecycleAppAuthorizationPolicy`,
`LifecyclePeerAdmissionPolicy` and the PID+UID verifier continue to reject UID
`0`. Exact tests prove the root helper token is consumed and that a root App
caller is rejected before the signing verifier is called.

The narrow post-fix review conclusion is:

`No unresolved P0-P2 findings.`

## 6. Validation

| Gate | Result |
| --- | --- |
| exact topology contract and Darwin tests | 27 tests passed after final additions |
| Lifecycle-focused suite | 117 tests in 12 suites passed |
| exact `source-boundaries` stage | passed in 4.219 seconds; diagnostic-only |
| targeted Debug diagnostic App/helper build | passed in 7.8 seconds |
| independent review | one P1 fixed tests-first; post-fix review clean |
| final clean staged-only serial SwiftPM regression | 981 tests in 41 suites passed |
| serial test execution | 109.997 seconds after a 38.60-second clean build |
| diff hygiene and forbidden-authority scan | passed |

The final serial ran once from an exact staged commit in a clean physical
`/Users/.../stornaut-validation.*/worktree` and exited `0`. The validation
worktree and process group were removed afterward.

This six-path non-document checkpoint adds 3,166 lines and removes 10, below
both scope split limits. It intentionally does not run XCUITest or
`scripts/verify --full`: it changes no UI, does not mutate the fixed topology,
does not assemble a readiness verdict and does not execute a model. The
enclosing 39B2c machine/security checkpoint still owns its single uninterrupted
authoritative full-verifier run.

## 7. Safety Audit

This prerequisite does not:

- trust a JSON, shell or worker self-report as topology evidence;
- enumerate or coordinate unrelated same-UID processes;
- execute `launchctl`, install, uninstall, bootout or remove any fixed path;
- add cleanup, Trash, Policy, authorization or Executor authority;
- modify `~/.codex/config.toml`;
- broaden filesystem, network or socket access;
- create a machine-admission receipt; or
- enable product Deep Dive.

No dependency or license was added.

## 8. Next Gate

39B2c machine-driver work may now combine L1 helper-sealed per-run residue with
L2 installed/post-teardown fixed-topology evidence inside one bounded sealed
window. It must still implement the signed build/install/run/bootout/uninstall
driver, real bounded Task 38/model execution, failure matrix, three-plane report
assembly and final machine admission. Only that enclosing gate may consume the
remaining authoritative full-verifier run or make a readiness claim.
