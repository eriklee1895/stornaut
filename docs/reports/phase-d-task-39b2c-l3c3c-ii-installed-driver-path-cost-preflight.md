# Phase D Task 39B2c-L3c3c-ii Installed-Driver Path and Cost Preflight

> Status: Split frozen; external staging rejected, ii-a is the current frontier
>
> Date: 2026-08-19
>
> Baseline: `b15bd082a44b3e2895fc7f150e5018ef37d522df`
>
> Scope: plan and documentation only; no product implementation, install, sudo,
> App/driver launch, model call, serial regression or full verifier

## 1. Decision

The repository-external B4 staging branch is closed with NO-GO. Separate stock
macOS root commands cannot make a UID-controlled verify step an unskippable
prerequisite to a later root execution. The old `sudo -v` branch also creates
ambient cached authority. Neither branch may be staged or executed.

The only remaining candidate is the diagnostic-only Machine driver at the
fixed installed path already covered by the L3c3b installer and L2 contracts:

```text
/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautInvestigationMachineDriver
```

The driver is currently **not installed**. The future machine gate must first
re-establish the exact current-source root-owned topology through the already
accepted local-only R5 installation ceremony, then repeat static installed-
artifact and service-bootstrap admission before the driver starts. Full
installed-L2 additionally requires the exact App/helper processes and therefore
occurs only after the driver launches the App, before business transition or
`EXIT`. The existing whole-installer source seal, built/staging/installed
identity equality and post-install root ownership checks remain mandatory. This
local development ceremony trusts the
explicit user/Coding-Agent authorization that establishes the root-owned
topology; it does not claim resistance to an unrelated arbitrary concurrent
same-UID attacker before that transition. The contained Codex worker is not
started until after the transition and is never allowed to write the source or
installed topology.

This is explicitly a **trusted local-operator development gate**. The user, the
reviewed current checkout, the Coding Agent before contained-runtime launch and
the exact source-sealed install ceremony are trusted inputs. The adversary in
scope begins after the root-owned topology is established: the contained Codex
worker and descendants must not write either source or installed state or reach
root authority. ii-c does not claim resistance to a malicious administrator, a
malicious pre-install Coding Agent or arbitrary concurrent same-UID mutation.
Those require a distribution/notarization or exclusive root policy gate that is
outside the user's approved local-only scope. Any ADR acceptance from ii-c is
limited to this local-only threat model.

The authorization ceremony has one non-executing policy probe followed by one
zero-argument driver command. First, in the exact Terminal/TTY that will own the
attempt:

```text
/usr/bin/sudo -kNnv
```

This must return nonzero: cached credentials are ignored, no prompt is permitted
and no timestamp is updated. A zero result means validation did not require a
prompt (for example `NOPASSWD`) and ii-c must stop before the driver. A nonzero
result can also mean policy denial, so it is necessary but not sufficient. The
operator then invokes exactly:

```text
/usr/bin/sudo -kN -p 'Stornaut Task 39 ii-c administrator authorization: ' -- /Library/Application\ Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautInvestigationMachineDriver
```

With a command, `-k` makes that invocation ignore the applicable cached
credentials and not update them; `-N` independently states the no-update intent.
The operator must observe the exact fixed prompt before entering credentials and
record that manual fact in the checked machine-gate receipt. Driver/root evidence
cannot prove that a prompt occurred. If the prompt is absent, any accidental
execution is non-admitting and consumes the outer attempt. No preceding `sudo
-v`, environment override, configurable path, executable, driver argument, UID,
endpoint, signal or action is allowed.

Adding driver launch to the long-lived lifecycle helper is rejected. It would
create a persistent trigger that lacks fresh administrator authentication,
expand the helper/XPC/plist review surface and duplicate the driver's root
parent lifecycle authority.

ADR 0018 remains Proposed until the single ii-c machine gate succeeds.

## 2. Why Another Split Is Required

The current final driver links only the zero-dependency
`StornautInvestigationMachineDriverSupport` target. L3c3b-0 deliberately rejected
linking the complete Machine/Core graph because its final Mach-O carried
Cleanup/Policy/Registered Action typed surfaces. A live handoff cannot be added
by simply restoring that dependency graph.

Root self-observation, fixed App launch, socketpair protocol, credential drop,
lifecycle supervision and the real composition are independent review surfaces.
Combining them with install and the unique root run would exceed the repository
ceiling and make a failed machine attempt impossible to diagnose without
repeating privileged evidence.

## 3. Frozen Checkpoints

### L3c3c-ii-a — Authority-Closed Live Driver Runtime

Implement and test only the no-argument installed-driver self-observation and the
minimum typed runtime primitives needed by the accepted socketpair/lifecycle
design. The driver must fail before App launch unless all of these agree:

- real/effective root identity;
- exact fixed installed executable path;
- root-owned regular node, fixed owner/group/mode, one link, bounded size, no
  ACL observed directly by the driver and no mutable path transition;
- the actual executable SHA-256 computed through a held descriptor;
- strict static and live signing identifier, designated requirement and
  CodeDirectory hash; and
- fixed Machine-claim service identity.

The zero-argument executable cannot embed its own expected whole-file SHA without
a circular build and no root-owned binding sidecar currently exists. ii-a must
therefore return or seal a typed observed identity; it must not claim equality
with an unavailable expected SHA. Before first execution, trust comes from the
separate root-owned install plus static installed-artifact/service-bootstrap
admission. ii-c independently compares the driver's pre/post observed identity
with that frozen static binding; full installed-L2 follows each App launch before
transition/`EXIT`. Adding a root-owned binding sidecar would be a
new trust surface and requires another preflight rather than an implicit file.

The runtime may own fixed socketpair, `posix_spawn`, credential-drop and exact
process lifecycle primitives. It may not import or expose Core, Execution,
Cleanup, Policy, Trash, Executor, Registered Action, model, network or arbitrary
filesystem mutation authority. No install, sudo, App launch or model call occurs
in this checkpoint.

Estimated ceiling: at most ten non-document paths and 3,000 added non-document
lines:

1. `Package.swift`;
2. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDriverSupport.swift`;
3. up to three new DriverSupport runtime/identity/protocol files;
4. one focused DriverSupport test file;
5. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
6. `scripts/verify-investigation-boundaries`;
7. `scripts/verify-app-release-boundaries`; and
8. `Stornaut.xcodeproj/project.pbxproj` only if a fixed system-framework link
   setting cannot be inherited through the existing package product.

If implementation requires another path or approaches the line ceiling, split
self-observation from launch/lifecycle before coding further.

### L3c3c-ii-b — Fixed Installed-Driver Handoff Composition

Compose the exact fixed driver, prelaunch unnamed socketpair, fixed diagnostic
App, two-stage root-to-UID identity transition, one-shot opaque handle, helper
claim, installed-L2 barrier, typed transition and bounded retirement. Tests use
injected/fake or non-privileged processes only. The App must remain alive until
the driver completes installed-L2 observation. No handle may travel through
JSON, a file, configuration, helper reply or caller-selected endpoint.

Estimated ceiling: at most twelve non-document paths and 3,500 added
non-document lines across DriverSupport, the diagnostic App leaf/harness, focused
tests and structural/final-Mach-O gates. No sudo, live install or model call. If
the real App leaf and driver runtime cannot stay within that bound, split the App
inherited-FD leaf from transition composition.

### L3c3c-ii-c — Single No-Model Privileged Machine Gate

Freeze the exact current-source build and machine driver before mutation. Then:

1. prove the external B4 paths and old receipts remain absent;
2. build the exact current-source diagnostic App/helper/driver;
3. run the accepted local-only install ceremony once; require its ACL checks,
   exact built/staging/installed identity equality, root ownership and service
   bootstrap, without claiming full installed-L2 yet;
4. run the exact `sudo -kNnv` policy probe and require nonzero, then require the
   operator to observe and record the exact fixed prompt;
5. invoke only the fixed installed driver once with the exact no-cache,
   zero-driver-argument command above;
6. require root self-observation plus independent equality with the frozen
   installer/static-L2 binding; after each App launch require full installed-L2
   before transition/`EXIT`; then require the complete happy/replay/deadline/
   cancellation/crash/hang matrix, exact UID/groups, irreversible credential
   drop, strict EOF and zero PID/PGID/channel residue;
7. independently validate raw evidence; and
8. uninstall and prove App/plist/service/runtime/lease/process zero residue.

This is exactly one **outer installed-driver invocation**. That fixed outer
supervisor stays alive and runs a closed set of fresh, sequential, isolated
scenario epochs. Each epoch owns its own nonce, root scenario-parent, App/child,
channel and exact session. The `parent_crash` case crashes only its disposable
inner scenario-parent; the outer driver observes exact EOF/PID/PGID disappearance
and continues to the next epoch. The outer supervisor itself is never a fault
target. This matches the existing multi-scenario B3/B4 architecture without
requiring multiple sudo/driver invocations. A cancellation before the outer
driver starts creates no attempt. Once it starts, a failure is not retried;
implementation returns to ii-a or ii-b and a new gate requires a new explicit
checkpoint decision. No model authentication or model call occurs.

Only a green ii-c result may move ADR 0018 to Accepted. It still cannot make a
Task 39 readiness claim.

## 4. Validation Funnel

Each implementation checkpoint follows:

```text
structural/source boundary
-> exact focused tests
-> affected suites
-> one clean staged-only serial regression
-> targeted Debug/Release/final-Mach-O gates
-> independent review
```

The broad `swift test --filter Investigation` selector is forbidden because it
also selects maximum benchmarks. The single authoritative `scripts/verify
--full` remains unconsumed and reserved for L3c4. Pure documentation checkpoints
run only link and diff checks.

## 5. Remaining Order and Non-Claims

The strict order is now:

```text
L3c3c-i root-launch audit complete
-> L3c3c-ii-a authority-closed live driver runtime
-> L3c3c-ii-b fixed handoff composition
-> L3c3c-ii-c one no-model outer installed-driver gate
-> L3c3d one real-model pending candidate
-> L3c4 final admission and full verifier
```

This preflight does not implement or accept the candidate. It does not install
or launch a product artifact, execute root code, call a model, enable Deep Dive,
accept ADR 0018, claim readiness or consume a serial/full gate. Production Deep
Dive remains unavailable.
