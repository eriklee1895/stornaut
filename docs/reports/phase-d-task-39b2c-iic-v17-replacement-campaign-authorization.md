# Phase D Task 39B2c ii-c-c v17 replacement campaign authorization

> Status: superseded before launch / unconsumed / reauthorization required
>
> Authorized source baseline: `a69bd33df8b27e0660e628ec59be308342141625`
>
> Authorized source tree: `f32d41c4a7bdf24519016666c942fe9ec5cf3789`

## Authorization

The user explicitly authorized one fresh privileged Task 39 ii-c replacement
machine campaign based on the pushed status-82 and cleanup-attribution repair
checkpoint above. This one-shot authorization is named v17. Campaigns v8
through v13 and v16 are consumed and non-retryable; v14 and v15 were
superseded before launch. No earlier authorization may be reused or transferred.

The authorization permits the sealed zero-argument campaign executable to
generate one fresh nonzero campaign UUID, one fresh nonzero attempt UUID and one
fresh owner-private evidence root at the unique launch. No v17 campaign UUID,
attempt UUID, launch claim or evidence root exists at authorization time.

The authorization-only descendant may change only this authorization record,
status documentation, structural status assertions and exact digest pins. It
must not change production Swift, campaign/App/helper/driver/Gate/coordinator
binaries, lifecycle scripts, fixed prompts, the 120-second authorization bound,
the 1,400-second campaign horizon, exact-v13 preservation or any containment
boundary. Its exact HEAD/tree must be clean, reviewed and pushed before launch.

## Post-authorization pre-launch invalidation

The campaign was not launched. Before the authorization-only descendant could
be accepted and pushed, its aggregate read-only check rejected the historical
v13 raw evidence root because the nine expected files in phases 01 through 03
were absent. The six phase directories and enclosing evidence root remain, and
the persistent Application Support Gate still contains the exact v13 and v16
attempt/capsule entries. The v16 raw evidence remains independently verifiable.

The affected v13 phase directories changed at `2026-09-14T03:35:36+08:00`.
macOS unified logging shows `com.apple.cache_delete` received a low-disk event at
`2026-09-14T03:35:18+08:00`, when free space was approximately 10.7 GB, and
started an urgency-1/2/3 purge. A clean staged SwiftPM regression was running at
the time, but its evidence tests had not yet reached the v13 opt-in cases; those
cases were skipped and the fixed-Gate physical fixture was also skipped. The
loss is strongly temporally consistent with that system purge, but the available
privacy-redacted log does not independently bind the exact deleting actor or
path. It was not a v17 launch or a Gate mutation.

No exact copy of the removed v13 raw files was found. They must not be
reconstructed. Because this authorization required every v8-v16 evidence root
to remain unchanged, the changed external state invalidates v17 before launch.
No v17 campaign UUID, attempt UUID, launch claim, install, sudo invocation or
root action exists. v17 remains unconsumed but is superseded and cannot be used.

The next prerequisite must first record the v13 external-evidence loss without
promoting it to success, then move future raw campaign evidence out of the
purgeable temporary directory into an owner-private Application Support path.
A new pushed repair checkpoint and fresh explicit authorization are required.

## Exact authority boundary

The authorization permits only the existing fixed ii-c workflow:

- build the current-source Debug diagnostic App and package-only campaign
  executable;
- install only the fixed Stornaut App/helper/driver/Gate/coordinator and fixed
  `com.eriklee.stornaut.lifecycle` plist through the sealed lifecycle script;
- run the non-executing `/usr/bin/sudo -knv` policy probe;
- after durable arm, launch the fixed installed driver at most once through the
  existing `/usr/bin/sudo -N -p` path;
- let the trusted operator personally enter administrator credentials only
  after seeing the exact fixed install, driver or uninstall prompt;
- run the existing eight-scenario no-model cohort, independent verifier, fixed
  uninstall and zero-attempt-residue observation while retaining the permanent
  owner lock and exact v13 attempt/capsule.

The Coding Agent must not read, request in chat, record, paste, synthesize or
type the administrator credential. Credentials are handled only by the fixed
controlling-TTY paths, and the bounded single-attempt relay clears its buffer on
every path.

No Codex write authority, localhost/private/link-local/Unix access, Executor,
Trash, Policy, Registered Action, release/notarization, Task 40 start, product
Deep Dive availability, L3c3d or L3c4 is authorized here.

## One-shot and stop rules

- Before `armedConsumed`, a failure may continue only through exact uninstall
  and zero-residue proof. Installed-state uncertainty stops.
- Once v17 durably records `armedConsumed`, the attempt is consumed. Any failure,
  uncertainty, cancellation, timeout or verifier rejection stops and forbids
  automatic retry or another campaign.
- No v8-v16 artifact, receipt, evidence root or historical Gate state may be
  modified, deleted, reconstructed, appended to or reinterpreted. The exact v13
  Gate attempt/capsule must remain byte- and identity-stable.
- A green independently verified v17 cohort may unblock L3c3d. It does not by
  itself complete Task 39 or enable product Deep Dive.
- L3c3d remains the sole authenticated real-model step. L3c4 remains the sole
  readiness/full-verifier admission step. Task 40 remains blocked until Task 39
  produces and pushes its Ready baseline.

## Preflight order

Before root/install/sudo action, this authorization-only descendant must be
clean, independently reviewed and pushed; historical v8-v16 evidence stays
read-only; the fixed runtime is absent; the Application Support Gate contains
exactly the permanent owner lock and retained exact-v13 and v16 attempts/
capsules; the historical Caches Gate is absent; and all narrow structural,
aggregate and component gates remain green. The campaign is then launched
exactly once from an interactive controlling Terminal.
