# Phase D Task 39B2c ii-c-c v10 replacement campaign authorization

> Status: authorized / unconsumed / preflight pending
>
> Date: 2026-09-07
>
> Frozen parent repair baseline: `05fd0cded87714170105744c5c42945a0017c6c1`

## Authorization

The user explicitly authorized one new privileged Task 39 machine campaign.
This campaign is named v10 for operator communication and is independent of the
consumed, non-admitting and non-retryable v8 and v9 campaigns. It must generate
a fresh nonzero campaign UUID, a fresh nonzero attempt UUID and a fresh
owner-private evidence root. It must not retry, append to, rewrite, remove or
reinterpret any v8 or v9 artifact, receipt or evidence root.

The campaign is bound to the pushed reviewed AMFI-repair implementation above.
Its executable source must not change after that baseline; the authorization
commit may add only authorization/status documentation and the existing
structural digest pins/tests that seal it, with no production-source change.
Before the one executable launch, the resulting exact HEAD/tree must be clean
and pushed, captured by the existing source-binding contract, and all frozen
non-privileged preflight gates must pass.

## Exact authority boundary

This authorization permits only the existing fixed Task 39 ii-c campaign:

- build the current-source Debug diagnostic App and package-only campaign binary;
- install only the fixed Stornaut App/helper/driver/Gate/coordinator and fixed
  `com.eriklee.stornaut.lifecycle` plist through the sealed lifecycle script;
- run the non-executing `/usr/bin/sudo -knv` policy probe;
- after durable arm, launch the fixed installed driver at most once through the
  existing `/usr/bin/sudo -N -p` path;
- let the trusted operator personally enter the administrator credential only
  after observing one of the three exact fixed prompts: install authorization,
  driver authorization or uninstall authorization;
- run the existing eight-scenario no-model machine cohort, independent evidence
  verifier, fixed uninstall and zero-residue observation.

The Coding Agent must not read, record, request in chat, paste or synthesize the
administrator credential. Install and uninstall credentials are read directly
by fixed `/usr/bin/sudo` from the controlling TTY. Only the post-arm driver
credential is relayed through the campaign's bounded `CChar` buffer and cleared
with `memset_s` on every path.

No Codex write authority, localhost/private/link-local/Unix access, Executor,
Trash, Policy, Registered Action, release/notarization, Task 40 start or
production Deep Dive availability is authorized by this amendment.

## One-shot and stop rules

- Before `armedConsumed`, a preflight failure may be repaired only after exact
  uninstall and zero-residue proof.
- Once v10 durably records `armedConsumed`, the attempt is consumed. Any failure,
  uncertainty, cancellation, timeout or verifier rejection stops the campaign
  and forbids automatic retry or a v11 attempt.
- A green independently verified v10 cohort may unblock L3c3d. It does not itself
  complete Task 39 or enable production Deep Dive.
- L3c3d remains the sole authenticated real-model step. L3c4 remains the sole
  readiness/full-verifier admission step. Task 40 remains blocked until Task 39
  produces and pushes its Ready baseline.

## Preflight order

Before any root/install/sudo action, the source tree must be clean and pushed as
the reviewed repair plus authorization-only descendant, both v8 and v9 current
dispositions must still verify read-only, the frozen v9-v2 receipt must remain
byte-identical, the fixed runtime must be absent, the Gate base must contain
only `.owner-lock-v1`, and the existing
structural, focused, component/final-Mach-O and independent-review gates required
by the frozen ii-c plan must be green. The campaign is then launched exactly once
from an interactive Terminal.
