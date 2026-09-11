# Phase D Task 39B2c ii-c fresh replacement campaign preflight

> Status: v14 authorized / pending / unconsumed
>
> Date: 2026-09-10
>
> P2 implementation: `783770515ac20d364ac698f7f4a291422606d71f`
>
> P2 implementation tree: `06c8454f54c99dcb1d76637d13706d85c102ba9d`
>
> P2 completion audit baseline: `1d4faa53385f4f2f9b749257482e9424280b74da`

## Purpose

Persistent Gate P2 is complete/non-admitting and pushed. Historical campaigns
v8 through v12 are consumed, non-admitting and non-retryable. This preflight
freezes the next legal machine step without authorizing or launching it. No new
campaign UUID, attempt UUID or evidence root exists yet.

Historical update: the user later authorized v13, which ran once from
`8885161` and is now consumed/non-admitting/non-retryable after one
closed post-arm failure. See the v13 failure disposition.
The user has now separately authorized one fresh v14 campaign based on pushed
authorization-hardening baseline `d5a7df38c9ed360da35c0e9a4929f0dd0b7a02a7`.

## Read-only machine state

- local `HEAD`, `origin/main` and the completion-audit baseline above are equal;
- the worktree is clean;
- the fixed diagnostic App, launchd plist and fixed runtime/lease roots are
  absent;
- the persistent Gate exists only at
  `~/Library/Application Support/com.eriklee.stornaut.task39-machine-gate`;
- the Gate base is UID/GID `501:20`, mode `0700`;
- its sole entry is `.owner-lock-v1`, UID/GID `501:20`, mode `0600`, zero bytes,
  one link and the same device as the base;
- the historical Caches Gate path is absent;
- P2 aggregate, Debug/Release binary boundary, final 1,964-test serial and both
  independent reviews are green with no unresolved P0–P2.

## Proposed one-shot authority

After a separate explicit user approval, one fresh privileged replacement
campaign may run from an authorization-only descendant of this pushed baseline.
The descendant may change only authorization/status documentation and exact
status-verifier pins. It must not change Swift production sources, campaign/App/
helper/driver/Gate/coordinator binaries, the lifecycle script, fixed prompts,
the 1,400-second horizon or any containment boundary.

The proposed authority is limited to the existing fixed ii-c workflow:

1. build the current Debug diagnostic App and package-only campaign executable;
2. install only the fixed App/helper/driver/Gate/coordinator and fixed lifecycle
   plist through the sealed lifecycle script;
3. run the non-executing `/usr/bin/sudo -knv` policy probe;
4. durably arm once, then launch the fixed installed driver at most once via the
   existing `/usr/bin/sudo -N -p` path;
5. run the eight-scenario no-model cohort, independent verifier, fixed uninstall
   and zero-attempt-residue observation while retaining the permanent owner-lock
   infrastructure.

The operator personally enters administrator credentials only in the controlling
Terminal after one of the exact fixed install, driver or uninstall prompts is
visible. The Coding Agent may not read, request in chat, record, paste, synthesize
or type the credential.

This proposal does not authorize Codex writes, private/localhost/link-local/Unix
network access, cleanup/Executor/Trash/Policy/Registered Action authority,
release/notarization, Task 40, production Deep Dive, L3c3d or L3c4.

## One-shot stop rules

- Before durable `armedConsumed`, a failure may proceed only through the existing
  exact uninstall and zero-residue proof; any installed-state uncertainty stops.
- Once `armedConsumed` is durable, success or failure consumes the attempt. Any
  cancellation, timeout, uncertainty, malformed receipt, containment failure or
  verifier rejection stops without automatic retry.
- The campaign must not modify, delete, reconstruct, append to or reinterpret any
  v8-v12 evidence root, receipt or historical Gate artifact.
- A green independently verified cohort may unlock L3c3d. It does not by itself
  complete Task 39 or enable production Deep Dive.
- L3c3d remains the sole real Codex App Server/model step. L3c4 remains the sole
  final readiness and authoritative full-verifier step.

## Authorization requirement

The user explicitly approved one fresh privileged replacement machine campaign
based on pushed authorization-hardening commit
`d5a7df38c9ed360da35c0e9a4929f0dd0b7a02a7`. It is recorded as v14 only to
distinguish it from consumed v8-v13 attempts. The authorization is pending and
unconsumed until the authorization-only descendant is pushed and the sealed
executable begins its unique launch.
