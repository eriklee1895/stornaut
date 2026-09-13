# Phase D Task 39B2c ii-c-c v16 replacement campaign authorization

> Status: consumed / non-admitting / non-retryable
>
> Authorized source baseline: `103a4836f4aa80c5d3739ca357364ad5c9200cf6`
>
> Authorized source tree: `0cfccbf6e8a500365837b4cb9551f6ff70af4bbf`

## Authorization

The user explicitly authorized one fresh privileged Task 39 ii-c replacement
machine campaign based on the pushed evidence-closure checkpoint above. This
one-shot authorization is named v16. Campaigns v8 through v13 are consumed and
non-retryable; v14 and v15 were superseded before launch and remain
unconsumed, but neither authorization can be reused or transferred.

The authorized invocation subsequently ran exactly once. It durably recorded
`armedConsumed` and then the closed failure
`postArmFailure/receiptInvalid/exited-82/receipt-eof/terminal-eof/cleanup-02`.
The checked [v16 failure disposition](phase-d-task-39b2c-iic-v16-failure-disposition.md)
is authoritative: v16 is consumed, rejected and non-retryable.

The authorization permits the sealed zero-argument campaign executable to
generate one fresh nonzero campaign UUID, one fresh nonzero attempt UUID and
one fresh owner-private evidence root at the unique launch. No such identity or
root exists at authorization time.

The authorization-only descendant may change only this authorization record,
status documentation, structural status assertions and exact digest pins. It
must not change production Swift, campaign/App/helper/driver/Gate/coordinator
binaries, lifecycle scripts, fixed prompts, the 120-second authorization bound,
the 1,400-second campaign horizon, exact-v13 preservation or any containment
boundary. Its exact HEAD/tree must be clean, reviewed and pushed before launch.

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
- Once v16 durably records `armedConsumed`, the attempt is consumed. Any failure,
  uncertainty, cancellation, timeout or verifier rejection stops and forbids
  automatic retry or another campaign.
- No v8-v15 artifact, receipt, evidence root or historical Gate state may be
  modified, deleted, reconstructed, appended to or reinterpreted. The exact v13
  attempt/capsule must remain byte- and identity-stable.
- A green independently verified v16 cohort may unblock L3c3d. It does not by
  itself complete Task 39 or enable product Deep Dive.
- L3c3d remains the sole authenticated real-model step. L3c4 remains the sole
  readiness/full-verifier admission step. Task 40 remains blocked until Task 39
  produces and pushes its Ready baseline.

## Preflight order

Before root/install/sudo action, the authorization-only descendant must be clean
and pushed; historical v8-v15 evidence stays read-only; the fixed runtime is
absent; the Application Support Gate contains exactly the permanent owner lock
and retained exact-v13 attempt/capsule; the historical Caches Gate is absent;
and the narrow structural, aggregate, component and review gates remain green.
The campaign is then launched exactly once from an interactive controlling
Terminal.
