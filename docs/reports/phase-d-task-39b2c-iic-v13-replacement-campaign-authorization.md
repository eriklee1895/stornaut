# Phase D Task 39B2c ii-c-c v13 replacement campaign authorization

> Status: authorized / pending / unconsumed
>
> Authorized source baseline: `46e1f94a2e78b7f132a182c00c510a228a5d140f`
>
> Authorized source tree: `84adafc9cbaac23a061a083a35c01074c771186a`

## Authorization

The user explicitly authorized one fresh privileged Task 39 ii-c replacement
machine campaign based on the pushed P2 preflight baseline above. This new
one-shot authorization is named v13 only to distinguish it from consumed
campaigns v8 through v12. It permits the sealed zero-argument campaign
executable to generate one fresh nonzero campaign UUID, one fresh nonzero
attempt UUID and one fresh owner-private evidence root at the unique launch.

The authorization-only descendant may change only this authorization record,
status documentation, structural status assertions and exact digest pins. It
must not change production Swift, campaign/App/helper/driver/Gate/coordinator
binaries, lifecycle script, fixed prompts, the 1,400-second campaign horizon or
any containment boundary. Its exact HEAD/tree must be clean, reviewed and pushed
before the executable is launched.

## Exact authority boundary

The authorization permits only the existing fixed ii-c campaign:

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
  owner-lock infrastructure.

The Coding Agent must not read, request in chat, record, paste, synthesize or
type the administrator credential. Credentials are handled only by the fixed
controlling-TTY paths, and the bounded driver relay clears its buffer on every
path.

No Codex write authority, localhost/private/link-local/Unix access, Executor,
Trash, Policy, Registered Action, release/notarization, Task 40 start, product
Deep Dive availability, L3c3d or L3c4 is authorized here.

## One-shot and stop rules

- Before `armedConsumed`, a failure may continue only through exact uninstall
  and zero-residue proof. Installed-state uncertainty stops.
- Once v13 durably records `armedConsumed`, the attempt is consumed. Any failure,
  uncertainty, cancellation, timeout or verifier rejection stops and forbids
  automatic retry or another campaign.
- No v8-v12 artifact, receipt, evidence root or historical Gate state may be
  modified, deleted, reconstructed, appended to or reinterpreted.
- A green independently verified v13 cohort may unblock L3c3d. It does not by
  itself complete Task 39 or enable product Deep Dive.
- L3c3d remains the sole authenticated real-model step. L3c4 remains the sole
  readiness/full-verifier admission step. Task 40 remains blocked until Task 39
  produces and pushes its Ready baseline.

## Preflight order

Before root/install/sudo action, the authorization-only descendant must be clean
and pushed; historical v8-v12 evidence stays read-only; the fixed runtime is
absent; the Application Support Gate contains exactly its verified permanent
owner lock; the historical Caches Gate is absent; and the narrow structural,
aggregate, component and review gates remain green. The campaign is then
launched exactly once from an interactive controlling Terminal.

No campaign UUID, attempt UUID or evidence root exists at authorization time.
All are generated and durably bound only by the unique executable launch.
