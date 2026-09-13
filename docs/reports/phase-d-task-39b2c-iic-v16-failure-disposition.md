# Phase D Task 39B2c ii-c-c v16 failure disposition

> Status: consumed / non-admitting / non-retryable
>
> Date: 2026-09-13
>
> Frozen source: `9bc6d8d879bcae500137879b8ad5080d72f136ca`
>
> Campaign: `469fd1d1-f9fd-4a3c-a0e6-f72f586f5e72`
>
> Attempt: `fa83c861-a7e2-4903-bf64-9eb08c757f74`

## Result

The one authorized v16 invocation durably recorded exactly `prepared →
armedConsumed → spawnUncertain → terminal`. It produced nine bounded artifacts
and no driver epoch, coordinator receipt, diagnostic output, manifest, external
seal, uninstall record or global post-teardown record. The exact closed reason is
`postArmFailure/receiptInvalid/exited-82/receipt-eof/terminal-eof/cleanup-02`.
Admission is rejected and this attempt must not be retried.
The checked classification is `consumedClosedPostArmFailure`.

The checked schema-v9 disposition binds the exact source commit/tree, all nine
raw artifact hashes, the event hash chain and timestamps, zero auth/model/network
invocations, zero retained credential bytes, the owner-private one-shot launch
claim, empty launcher result, launcher status `70`, and the current absence of
the fixed App/plist/service/runtime and matching processes. Live absence is not
promoted to durable campaign teardown evidence because no uninstall or global
post-teardown artifact was emitted.

The persistent Application Support Gate now contains exactly the owner lock, the
previously retained v13 attempt/capsule and the new consumed v16
attempt/capsule. The verifier binds both attempts by physical identity and binds
both capsules by physical identity, size and SHA-256. Neither historical attempt
is deleted, rewritten, reconstructed or attributed to the other campaign.

## Root-cause evidence

The durable arm event was recorded at UTC microsecond `1789307597119697`; the
closed failure was recorded at `1789307628243435`, an elapsed `31,123,738`
microseconds. This rules out the old v13 shared-deadline exhaustion pattern: v16
used the dedicated 120-second authorization window and failed well before that
window expired. The driver returned exact status `82`, which maps to
`containmentUncertain`; both parent channels reached EOF and no driver epoch
artifact exists.

A separate macOS unified-log observation records `amfid` at
`2026-09-13T13:53:48.143000Z` describing the exact installed MachineDriver as
ad-hoc signed or signed by an unknown certificate chain, AMFI error `-423`. The
installed-artifact hash in that observation is bound to the campaign's
`installed.json`. The same diagnostic class can also be emitted for otherwise
executable local Homebrew binaries, so this supplemental log does not by itself
prove that AMFI denied `exec`, and it is not campaign-bound evidence. It is used
only to constrain the next root-cause investigation. It does not prove credential
validity and is not used for admission.

`cleanup-02` maps exactly to the outer harness's `.terminateFailed` bit. The
outer then obtained exact `exited-82`, both channels reached EOF, and the later
live observation found zero fixed process/service/runtime residue. Therefore the
bit is a secondary cleanup diagnostic, not proof of live residue. The current
evidence preserves no termination errno or mechanism and therefore does not
distinguish the underlying termination-operation failure. That distinction must
be closed by tests and a narrow repair before any later campaign.

## Next gate

The next checkpoint is tests-first root-cause repair. The machine currently has
no valid code-signing identities (`security find-identity -v -p codesigning`
reports `0 valid identities found`), so merely selecting an Apple Development
identity is not a locally available fix. The repair must first explain the exact
status-82 entry failure and make the launch path fail before arm when its required
execution trust cannot be proved; it must also make already-gone owned process
groups a successful cleanup result without hiding permission or identity errors.

Only a new pushed repair checkpoint and fresh explicit authorization could allow
a later privileged replacement campaign. L3c3d, L3c4, Task 39 readiness, Task 40
and production Deep Dive remain blocked.
