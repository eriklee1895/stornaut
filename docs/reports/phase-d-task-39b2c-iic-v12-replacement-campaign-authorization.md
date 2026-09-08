# Phase D Task 39B2c ii-c-c v12 replacement campaign authorization

> Status: approved / suspended before launch / unconsumed / rebind required
>
> Authorized source baseline: `4fd9c539dbc2a7d9c659147c041712b945fa3b00`
>
> Authorized source tree: `0d8c4b56347f4f92a3f188a31bef7f2d3fc90843`

## Authorization

The user explicitly authorized one fresh privileged Task 39 ii-c replacement
machine campaign bound to the pushed v11 failure-closure baseline above. This
authorization permits the sealed zero-argument campaign executable to generate
one fresh nonzero campaign UUID, one fresh nonzero attempt UUID and one fresh
owner-private evidence root at launch. It must not retry, append to, rewrite,
remove or reinterpret any v8, v9, v10 or v11 artifact, receipt, Gate capsule or
evidence root.

The authorization-only descendant may change status documentation, structural
status assertions and their digest pins. It must not change production Swift,
the campaign/helper/driver/Gate/coordinator/plist/service binaries, the fixed
prompts, the 1,400-second campaign horizon or any security boundary. Before the
single executable launch, its exact HEAD/tree must be clean and pushed and the
existing non-privileged preflight gates must be green.

## Exact authority boundary

This authorization permits only the existing fixed Task 39 ii-c campaign:

- build the current-source Debug diagnostic App and package-only campaign
  binary;
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
- Once v12 durably records `armedConsumed`, the attempt is consumed. Any
  failure, uncertainty, cancellation, timeout or verifier rejection stops the
  campaign and forbids automatic retry or a v13 attempt.
- A green independently verified v12 cohort may unblock L3c3d. It does not
  itself complete Task 39 or enable production Deep Dive.
- L3c3d remains the sole authenticated real-model step. L3c4 remains the sole
  readiness/full-verifier admission step. Task 40 remains blocked until Task 39
  produces and pushes its Ready baseline.

## Preflight order

Before any root/install/sudo action, the source tree must be clean and pushed as
the exact authorization-only descendant of `4fd9c53`; v8-v11 dispositions must
still verify read-only; the fixed runtime must be absent; preserved historical
Gate residue must remain unchanged; structural, focused, component/final-Mach-O
and independent-review gates required by the frozen ii-c plan must be green.
The campaign is then launched exactly once from an interactive Terminal.

No campaign UUID, attempt UUID or evidence root exists at authorization time.
The sealed executable generates all three at the unique launch and the retained
evidence binds their exact values.

## Pre-launch suspension

Independent authorization review found that baseline `4fd9c53` would invoke
mandatory stale recovery and remove the preserved v11 Gate capsule before a new
publication, conflicting with this authorization's explicit historical-evidence
boundary. No v12 executable was launched, no identifier/evidence root was
created, and the authorization remains unconsumed. The campaign is suspended
until the preserved-capsule prerequisite is implemented, reviewed and pushed,
and the user explicitly rebinds this one-shot authorization to that new commit.
