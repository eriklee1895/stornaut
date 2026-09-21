# Phase D Task 39B2c ii-c-c v14 replacement campaign authorization

> Status: superseded before launch / unconsumed / reauthorization required
>
> Authorized source baseline: `d5a7df38c9ed360da35c0e9a4929f0dd0b7a02a7`
>
> Authorized source tree: `c9633494bafce8ca56e1987e269c5669467b7e82`

## Authorization

The user explicitly authorized one fresh privileged Task 39 ii-c replacement
machine campaign based on the pushed authorization-hardening baseline above.
This new one-shot authorization is named v14 only to distinguish it from
consumed campaigns v8 through v13. It permits the sealed zero-argument campaign
executable to generate one fresh nonzero campaign UUID, one fresh nonzero
attempt UUID and one fresh owner-private evidence root at the unique launch.

The authorization-only descendant may change only this authorization record,
status documentation, structural status assertions and exact digest pins. It
must not change production Swift, campaign/App/helper/driver/Gate/coordinator
binaries, lifecycle script, fixed prompts, the 120-second authorization bound,
the 1,400-second campaign horizon or any containment boundary. Its exact
HEAD/tree must be clean, reviewed and pushed before the executable is launched.

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
controlling-TTY paths, and the bounded single-attempt relay clears its buffer on
every path.

No Codex write authority, localhost/private/link-local/Unix access, Executor,
Trash, Policy, Registered Action, release/notarization, Task 40 start, product
Deep Dive availability, L3c3d or L3c4 is authorized here.

## One-shot and stop rules

- Before `armedConsumed`, a failure may continue only through exact uninstall
  and zero-residue proof. Installed-state uncertainty stops.
- Once v14 durably records `armedConsumed`, the attempt is consumed. Any failure,
  uncertainty, cancellation, timeout or verifier rejection stops and forbids
  automatic retry or another campaign.
- No v8-v13 artifact, receipt, evidence root or historical Gate state may be
  modified, deleted, reconstructed, appended to or reinterpreted.
- A green independently verified v14 cohort may unblock L3c3d. It does not by
  itself complete Task 39 or enable product Deep Dive.
- L3c3d remains the sole authenticated real-model step. L3c4 remains the sole
  readiness/full-verifier admission step. Task 40 remains blocked until Task 39
  produces and pushes its Ready baseline.

## Preflight order

Before root/install/sudo action, the authorization-only descendant must be clean
and pushed; historical v8-v13 evidence stays read-only; the fixed runtime is
absent; the Application Support Gate contains exactly its verified permanent
owner lock; the historical Caches Gate is absent; and the narrow structural,
aggregate, component and review gates remain green. The campaign is then
launched exactly once from an interactive controlling Terminal.

No campaign UUID, attempt UUID or evidence root exists at authorization time.
All are generated and durably bound only by the unique executable launch.

## Pre-arm suspension

The launch seal `e717b586cb430d1866249ddb13ac2d04e81e6519` was never
executed. A read-only pre-arm inspection found that its production coordinator
would not preserve the exact v13 Application Support Gate capsule. Launching it
would have violated the historical-evidence boundary above. No campaign UUID,
attempt UUID, launch claim, install, sudo invocation or root action occurred.

The authorization is therefore unconsumed but superseded by the required
preservation prerequisite. It cannot be transferred to changed source. A fresh
explicit authorization bound to the pushed prerequisite commit is required.
