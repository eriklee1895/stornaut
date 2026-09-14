# Phase D Task 39B2c ii-c fresh replacement campaign preflight

> Status: v16 consumed / non-admitting / non-retryable
>
> Date: 2026-09-13
>
> P2 implementation: `783770515ac20d364ac698f7f4a291422606d71f`
>
> P2 implementation tree: `06c8454f54c99dcb1d76637d13706d85c102ba9d`
>
> P2 completion audit baseline: `1d4faa53385f4f2f9b749257482e9424280b74da`
>
> Current authorization: v17 / `a69bd33df8b27e0660e628ec59be308342141625` / superseded before launch and unconsumed

## Purpose

Persistent Gate P2 is complete/non-admitting and pushed. Historical campaigns
v8 through v12 are consumed, non-admitting and non-retryable. This preflight
freezes the next legal machine step without authorizing or launching it. No new
campaign UUID, attempt UUID or evidence root exists yet.

Historical update: the user later authorized v13, which ran once from
`8885161` and is now consumed/non-admitting/non-retryable after one
closed post-arm failure. See the v13 failure disposition.
The v14 authorization based on pushed authorization-hardening baseline
`d5a7df38c9ed360da35c0e9a4929f0dd0b7a02a7` was stopped before launch by the
exact v13 preservation P0. It remains unconsumed but is superseded; fresh
authorization bound to the pushed prerequisite was required. The user has now
authorized one fresh v15 campaign from pushed prerequisite
`facf3eae2fbee83056189e2cfd54cf974ae1421b`. Independent pre-arm review then
found aggregate staged-scope enforcement and xattr no-mutation evidence gaps.
No launch occurred; v15 is unconsumed but superseded.
The evidence-closure checkpoint is pushed at
`103a4836f4aa80c5d3739ca357364ad5c9200cf6`; the user explicitly authorized
one fresh v16 campaign from that exact commit. That campaign subsequently ran
once, durably armed and closed as `receiptInvalid/exited-82/cleanup-02`; the
checked failure disposition supersedes this pre-launch statement.
The status-82 identity and cleanup-02 typed-attribution repairs were then pushed
as `a69bd33df8b27e0660e628ec59be308342141625`. The user explicitly authorized
one fresh v17 campaign from that exact commit. Before launch, the nine v13 raw
evidence files under TMPDIR were found missing in the same time window as a
macOS low-disk purge; the exact deleting actor is not independently bound. No
v17 launch occurred; v17 is superseded/unconsumed and cannot be reused.

## Read-only machine state

- the authorized repair baseline
  `a69bd33df8b27e0660e628ec59be308342141625` was pushed and matched
  `origin/main` before this authorization-only descendant;
- the authorization-only descendant must be clean and pushed before launch;
- the fixed diagnostic App, launchd plist and fixed runtime/lease roots are
  absent;
- the persistent Gate exists only at
  `~/Library/Application Support/com.eriklee.stornaut.task39-machine-gate`;
- the Gate base is UID/GID `501:20`, mode `0700`;
- its exact inventory is `.owner-lock-v1` plus the retained v13 attempt
  `a77c4d21-9bba-46f6-b694-3d1d1e55209d` and v16 attempt
  `fa83c861-a7e2-4903-bf64-9eb08c757f74`; each attempt contains only its
  checked capsule. The v13 capsule remains 28,997 bytes with SHA-256
  `1567a7fc8f13da51b69c134bb79ac132d383ae30496bb5ae86674ac3fa9f8a17`,
  and the v16 capsule remains 29,029 bytes with SHA-256
  `0858c551d0741e066e46e79b5317fb19da11c32a4064b3ef49e7e0377e5f2f1a`;
- the historical Caches Gate path is absent;
- preservation aggregate, Debug/Release binary boundary, final 1,974-test
  serial and both
  independent reviews are green with no unresolved P0–P2.

## Proposed one-shot authority

The user explicitly approved one fresh privileged replacement campaign based on
the pushed repair checkpoint `a69bd33`. This one-shot v17 authority does not
revive or transfer the consumed v16 or superseded v14/v15 authorizations.
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
  v8-v16 evidence root, receipt or historical Gate artifact. The exact v13 Gate
  attempt/capsule must remain byte- and identity-stable.
- A green independently verified cohort may unlock L3c3d. It does not by itself
  complete Task 39 or enable production Deep Dive.
- L3c3d remains the sole real Codex App Server/model step. L3c4 remains the sole
  final readiness and authoritative full-verifier step.

## Authorization state

The user explicitly approved one fresh privileged replacement machine campaign
based on pushed preservation prerequisite
`facf3eae2fbee83056189e2cfd54cf974ae1421b`. It is recorded as v15 to
distinguish it from consumed v8-v13 and superseded/unconsumed v14. The
authorization is unconsumed but superseded: no campaign UUID, attempt UUID,
launch claim, install, sudo invocation or root action exists for v15. The user
has now authorized v16 from pushed evidence-closure commit
`103a4836f4aa80c5d3739ca357364ad5c9200cf6`; that one-shot authority is now
consumed/non-admitting/non-retryable.
The status-82 and cleanup-attribution repair checkpoint was subsequently pushed
as `a69bd33df8b27e0660e628ec59be308342141625`. The user has now authorized
exactly one fresh v17 campaign from that commit. The pre-launch external v13
evidence loss invalidated its historical-evidence premise. v17 is
superseded/unconsumed; no
v17 UUID, launch claim, install, sudo invocation or root action exists.
