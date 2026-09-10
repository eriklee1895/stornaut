# Phase D Task 39B2c ii-c-c v13 failure disposition

> Status: consumed / non-admitting / non-retryable
>
> Date: 2026-09-10
>
> Frozen source: `88851614b090d6d6b9da6a6d7208743b85689cda`
>
> Campaign: `864065f6-8c9e-48e1-bedf-b0f6becd7b21`
>
> Attempt: `a77c4d21-9bba-46f6-b694-3d1d1e55209d`

## Result

The one authorized v13 invocation durably recorded exactly `prepared →
armedConsumed → spawnUncertain → terminal`. It produced nine bounded artifacts
and no driver epoch, coordinator receipt, diagnostic output, manifest, external
seal, uninstall record or global post-teardown record. Admission is rejected and
the attempt must not be retried.
The checked classification is `consumedClosedPostArmFailure`.

The exact closed reason is
`postArmFailure/receiptInvalid/exited-82/receipt-eof/terminal-eof/cleanup-02`.
`cleanup-02` means the outer campaign's post-failure owned-group termination
operation returned failure; the retained evidence does not identify whether its
deadline precheck or underlying signal operation failed. It does not mean wait,
descriptor close or residue observation failed. The coordinator was still exactly reaped with
exit 82, both channels reached EOF, and the current live machine has zero fixed
Stornaut process/service/runtime residue. The owner-private persistent Gate and
the exact consumed attempt capsule remain intact. Live absence is not promoted
to durable campaign teardown evidence because the run emitted no uninstall or
global post-teardown artifact.

## Root-cause evidence

The durable arm event was recorded at UTC microsecond `1789013747278745`; the
closed failure event was recorded at `1789015142377277`, an elapsed
`1,395,098,532` microseconds under a 1,400-second campaign deadline. The human
attestation confirms one operator action and zero retained credential bytes. A
separate macOS unified-log observation records `/usr/bin/sudo` PID 6508 at
`2026-09-10T04:39:02.324696Z` reporting exactly `1 incorrect password attempt`
for the fixed installed MachineDriver command. It is not one of the nine
campaign artifacts and is not used for disposition classification or admission.
No driver epoch artifact exists.

The campaign-bound evidence proves only a closed post-arm `receiptInvalid`
failure with exit 82, both channels at EOF and cleanup mask 02. The supplemental
log is compatible with a rejected credential but cannot make that interpretation
campaign-bound or prove what the operator intended to type. The current
implementation bounded the prompt reader by the entire campaign deadline and
relayed only one credential line, but it neither supplied a shorter authorization
sub-deadline nor terminated sudo's possible retry input. A long PAM/OpenDirectory
return is compatible with the observed timing but is not a campaign-bound
conclusion. Independently of the credential interpretation, the shared-window
design allowed authorization to consume almost the whole campaign budget before
coordinator containment and outer cleanup at the deadline edge.

## Narrow repair

The successor implementation keeps the real controlling-TTY and one-human-input
boundary. It gives authorization a dedicated 120-second sub-deadline in both the
campaign reader and Gate's first driver-claim wait, preserving the later cohort
and cleanup budget. It also relays the credential line followed by the PTY's
actual enabled `VEOF` character, so a rejected first sudo authentication attempt
cannot request a second unowned credential and wait until the campaign deadline.
The relay validates canonical/no-echo terminal mode, rejects embedded line or EOF
characters, uses bounded nonblocking writes, and wipes its temporary buffer. A
real `forkpty` test proves one line, immediate second-read EOF, restored echo,
zero child residue and no credential disclosure.

This repair is non-admitting and does not authorize v14. L3c3d, L3c4, Task 39
readiness, Task 40 and production Deep Dive remain blocked until a separately
authorized fresh campaign produces a green cohort.
