# ADR 0006: Trash and Registered Action Lifecycle

> Status: Accepted for the Epic 1 Task 7 Spike
> Date: 2026-08-09
> Decision owners: Stornaut maintainers
> Related study: [`../upstream-studies/epic-1-actions.md`](../upstream-studies/epic-1-actions.md)

## Context

Stornaut must eventually close the deterministic path from a reviewed cleanup
plan to a measured result without becoming a shell-cleaner GUI. The approved
boundary permits exactly:

- `MoveToTrash(PathAction)`;
- a fixed action from `ActionRegistry`.

The Spike therefore needs executable evidence that:

- the Policy Gate rejects protected, stale and active paths;
- execution revalidates path identity and current activity immediately before
  writing;
- Foundation Trash preserves its platform destination and never falls back to
  permanent deletion;
- Agent-facing requests cannot provide an executable or raw argument array;
- a registered process can dry-run, execute, time out and report a partial
  failure through typed results;
- timeout terminates the registered process tree rather than only its leader;
- moved bytes are not mislabeled as free space released.

## Decision

**The constrained action lifecycle is viable for later Epic 8 production
development.**

Accept the following Task 7 contracts while keeping this implementation a
Spike:

### Action shapes and registry

`CleanupAction` contains only `moveToTrash(PathAction)` and
`runRegisteredAction(RegisteredActionRequest)`.

The registered request serializes only:

- a definition ID;
- an enum mode.

`RegisteredActionDefinition` owns the absolute executable URL, fixed
mode-to-argument mapping, sanitized environment, timeout and output limits.
The registry resolves an immutable invocation; the Agent cannot supply any of
those fields. Epic 1 registers only `fixture.fake-cleaner`; no Homebrew, uv,
pnpm, Docker or other real destructive action exists.

### Policy and revalidation

`ActionPolicyGate.preflight` rejects:

- filesystem root, HOME and mount roots;
- symlinks and denylisted paths;
- missing or outside-root targets;
- active targets and active descendants/ancestors;
- device, inode, mode, size, allocated-byte or mtime drift;
- missing, duplicate or invalid registered definitions.

Path preflight tokens retain the approved identity. Registered-action tokens
retain the resolved invocation and executable identity. `revalidate` repeats
these checks and accepts a fresh `ActionPolicyContext`; callers must provide
current activity evidence immediately before execution.

This narrows, but does not eliminate, filesystem TOCTOU. The current Spike
revalidates immediately before Foundation receives a path. A later production
executor should use descriptor-relative operations wherever the platform API
allows them and preserve this fail-closed identity check where Trash remains
URL-based.

### Trash

Production `FileManagerTrashAdapter` calls
`FileManager.trashItem(at:resultingItemURL:)`. `TrashMoving`:

- checks cancellation before adapter invocation;
- binds the call to the expected file identity;
- maps permission failures distinctly;
- verifies the original path no longer names the approved identity;
- verifies a returned destination names that identity;
- returns original/destination URLs, identity, timestamp, logical bytes moved
  and allocated bytes moved.

The public and internal Trash APIs have no permanent-delete closure. Failure
leaves the original path in place, and there is no fallback implementation to
invoke.

The receipt deliberately has no `freedBytes`. Moving to Trash is not permanent
reclamation, and free-space delta must be measured separately.

### Registered process

`ActionExecutor` performs:

```text
preflight → revalidate with current context → dry-run or execute → postflight
```

The default runner uses direct `posix_spawn`, never `sh -c`, and launches an
isolated process group with `POSIX_SPAWN_CLOEXEC_DEFAULT` and bounded
stdout/stderr. Timeout terminates the entire group and reaps the leader.
Postflight accepts only bounded fixture JSON whose status, exit code and
counts agree:

- success requires exit `0`, `succeeded`, and no failed items;
- partial failure requires a nonzero exit, `partiallyFailed`, and at least one
  failed item;
- malformed, truncated or contradictory output fails closed.

## Evidence

### Environment

- macOS 26.5.1, build `25F80`;
- Apple Silicon `arm64`;
- Xcode 26.6, build `17F113`;
- Apple Swift 6.3.3;
- probes ran as UID 501 in a SwiftPM test CLI process.

No TCC, FDA, Accessibility, Event Synthesizing or other system permission was
granted, reset or automated.

### Tests first

The first focused run failed at compile time because the planned Task 7
production types did not exist. This established the action contracts before
implementation.

The final focused suite contains 19 discovered entries:

- 18 deterministic Policy Gate, Trash and Registered Action tests pass;
- one real-platform diagnostic is default-skipped and requires explicit
  `STORNAUT_RUN_PLATFORM_TRASH_DIAGNOSTIC=1`.

Coverage includes:

- root, HOME, mount, symlink, denylist and active-path rejection;
- missing/stale identity and adversarial replacement;
- current activity added between preflight and execution;
- unregistered action ID and Agent serialization without executable/arguments;
- successful Trash receipt and adapter collision behavior;
- permission failure, missing item, pre-call cancellation, identity replacement
  and phantom-success postcondition;
- zero permanent-delete calls on Trash failure;
- fixed registry mode arguments and structural dry-run;
- success and partial-failure measurement;
- timeout within the bound;
- verified exit of both the fixture leader and its spawned child.

The first timeout implementation used `Process.terminate`, which could have
left descendants alive. Self-review replaced it with a direct isolated process
group and added a parent/child exit regression test.

Full parallel verification then exposed two integration hazards that focused
tests could not show:

- independently spawned Codex and registered-action processes could inherit
  each other's pipe descriptors;
- blocking process waits scheduled on Swift's cooperative executor/global
  queue delayed unrelated timeout contracts.

Both runtimes now use macOS `POSIX_SPAWN_CLOEXEC_DEFAULT`, explicitly map only
their standard descriptors and keep blocking pipe reads on a dedicated GCD
queue. Timeout polling remains async and begins immediately after spawn. A
cross-runtime concurrent-spawn test and two consecutive full SwiftPM runs
prove the fix without loosening timing assertions.

### Real Foundation Trash probes

The opt-in diagnostic used only uniquely named disposable files and restored
returned Trash destinations before deleting the temporary root.

Same-volume CLI probe:

- Foundation returned a reachable resulting Trash URL;
- the original path disappeared;
- two `same-name` fixtures received distinct destinations, with the second
  platform-renamed;
- a 2,000-file directory moved successfully;
- cancellation requested immediately after the synchronous API call began was
  observed only after that call returned;
- a controlled POSIX non-writable parent produced permission denial.

Disposable mounted-volume probe:

- the probe created a temporary 32 MiB APFS disk image;
- Foundation moved its disposable item to a volume-specific `.Trashes`
  destination;
- the diagnostic restored the item;
- the image was detached and the temporary image directory removed.

No existing mounted user volume was modified.

### Undo semantics

The resulting URL is useful evidence and permits a best-effort Finder-like
restore while the destination still exists. It is not an undo guarantee:

- the user can empty Trash;
- the item can be moved or renamed;
- the original path can be occupied;
- permissions or volume availability can change.

Task 7 therefore records a receipt but does not implement persistent Undo or
claim guaranteed reversibility.

## Consequences

Positive:

- the Executor surface remains closed to arbitrary Shell and Agent arguments;
- Trash is native, collision-aware and has no destructive fallback;
- stale identity and current activity fail closed;
- dry-run cannot accidentally launch the fixture;
- registered output and partial failure remain typed and bounded;
- timeout does not leave the tested process tree alive;
- accounting distinguishes moved bytes from free-space delta;
- no third-party package or shipped destructive action is added.

Costs and limitations:

- this Spike has no user confirmation token, Cleanup Manifest persistence or
  dependency ordering; those remain Epic 8 work;
- Foundation Trash is synchronous and has no mid-call cancellation contract;
- the URL-based API leaves a narrow revalidate-to-call race;
- POSIX permission denial is API behavior evidence, not TCC/FDA evidence;
- output parsing currently models only the test action;
- registered-action cancellation after launch is represented by timeout in
  this Spike rather than a separate public cancellation result.

## Residual Risks and Follow-up

- Repeat real Trash behavior through the locally signed App/Executor context
  before any FDA/TCC or packaged-App release claim. The CLI probe cannot prove
  App entitlements or privacy-database behavior.
- Epic 8 must separate review approval, fresh activity collection,
  revalidation, execution, measurement and durable Manifest creation.
- Production registered actions need per-tool ADRs, version/capability checks,
  dry-run semantics, risk classification, license/provenance and golden
  fixtures. None is authorized by this ADR.
- Add a dedicated cancellation controller for long-lived real registered
  actions; never infer that terminating only a wrapper process is sufficient.
- Undo, original-path collision and expired Trash receipts require explicit UI
  and Manifest states before being exposed to users.
- Keep Deep Dive paused. This action result does not change ADR 0004's
  Broker-only no-go decision.

## Validation

Task 7 is accepted only after:

- focused action/safety tests pass;
- the opt-in same-volume and mounted-volume Trash probes pass;
- no fixture process, mounted image or temporary item remains;
- full `scripts/verify` passes;
- documentation links and `git diff --check` pass;
- no real destructive action, arbitrary Shell path or permanent-delete fallback
  is present.
