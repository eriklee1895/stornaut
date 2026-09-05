# Phase D Task 39B2c ii-c-c v9 replacement campaign authorization

> Status: authorized / first launch cancelled before credential and arm /
> zero residue verified / replacement attempt remains unconsumed
>
> Date: 2026-09-05
>
> Frozen parent baseline: `4147e455d326a87cda1a3b048ce5ce85e08b5309`

## Authorization

The user explicitly authorized one new replacement privileged machine campaign
to continue Task 39. This is a plan amendment after the conclusive v8 no-go; it
does not retry, rewrite, append to, delete or reinterpret v8. The v8 evidence and
its consumed/non-admitting/non-retryable disposition remain immutable.

The replacement campaign is named v9 for operator communication. The executable
must generate a fresh nonzero campaign UUID, a fresh nonzero attempt UUID and a
fresh owner-private evidence parent. Its exact pushed source commit/tree and all
runtime identities must be captured by the existing pre-arm evidence contract.

The first v9 executable launch reached the lifecycle install authorization
prompt while that path still used generic `Password:` text. The operator entered
no credential. The exact campaign process group was interrupted before install,
before evidence-writer creation and before `armedConsumed`; the fixed App, plist,
service, runtime and lease paths remained absent, and the Gate base still
contained only `.owner-lock-v1`. This pre-arm cancellation did not consume v9.
The prompt defect is now repaired: install and uninstall use closed fixed prompts,
and non-privileged contract, mutation, component, build and regression gates are
green. A second launcher invocation awaits this repair's reviewed pushed baseline.

## Exact authority boundary

The authorization permits only the existing fixed Task 39 ii-c campaign:

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

The install and uninstall prompts are distinct from the driver prompt and are
selected only by the closed lifecycle action enum; generic `Password:` output is
not accepted as an authorized product prompt. The Coding Agent must not read,
record, request in chat, paste or synthesize the administrator credential. For
install and uninstall, fixed `/usr/bin/sudo` reads the credential directly from
the controlling TTY; the campaign never reads or retains those bytes. Only the
post-arm driver credential is relayed through the campaign's bounded `CChar`
buffer and cleared with `memset_s` on every path.

No Codex write authority, localhost/private/link-local/Unix access, Executor,
Trash, Policy, Registered Action, release/notarization, Task 40 start or
production Deep Dive availability is authorized by this amendment.

## One-shot and stop rules

- Before `armedConsumed`, a preflight failure may be repaired only after exact
  uninstall and zero-residue proof.
- Once v9 durably records `armedConsumed`, the attempt is consumed. Any failure,
  uncertainty, cancellation, timeout or verifier rejection stops the campaign
  and forbids automatic retry or a v10 attempt.
- A green independently verified v9 cohort may unblock L3c3d. It does not itself
  complete Task 39 or enable production Deep Dive.
- L3c3d remains the sole authenticated real-model step. L3c4 remains the sole
  readiness/full-verifier admission step. Task 40 remains blocked until Task 39
  produces and pushes its Ready baseline.

## Preflight order

Before any root/install/sudo action, the source tree must be clean and pushed,
the v8 disposition must still verify read-only, the fixed runtime must be absent,
the Gate base must contain only `.owner-lock-v1`, and the existing structural,
focused, component/final-Mach-O and independent-review gates required by the
frozen ii-c plan must be green. The campaign is then launched once from an
interactive Terminal.
