# Phase D Task 39B2c ii-c v16 Status-82 Identity Repair

> Status: complete / non-privileged / non-admitting
>
> Date: 2026-09-14
>
> Baseline: `4d71ae29474425b8fedecf6f9ac97517d68fd506`

## Result

The v16 GateCoordinator `exit 82` path is reproduced and repaired without
reusing the consumed v16 attempt. The UID-501 Gate no longer calls either
`PROC_PIDTBSDINFO` or per-PID BSM for the stopped UID-0 driver. The physical
suspended-sudo fixture directly confirms `PROC_PIDTBSDINFO == EPERM`; this
checkpoint does not claim an independently retained errno for the per-PID BSM
call, and instead removes that unavailable observation from the cross-UID path.

The replacement observation has two independent parts:

1. a double `KERN_PROC_PID` sample around `getsid(2)` binds PID, start time,
   parent, process group, Unix session, real/effective/saved IDs and bounded
   supplementary groups; and
2. two stable Gate-self `getaudit_addr(2)` samples bind the driver's
   self-sealed AUID/ASID claim to the audit session inherited through the fixed
   sudo cohort.

The fixed 1,006-byte driver claim does not change. Its audit token must remain
internally consistent with PID, pidversion, AUID, ASID, EUID and EGID. The pure
validator additionally requires independently observed root user/group IDs and
membership of group zero. Live signing remains PID-bound and the fixed
path/node/SHA/static-signing checks are unchanged.

## Physical Evidence

`kernelProcessIdentityReadsSuspendedSetuidChildWhenProcPidinfoCannot` passed on
the real `/usr/bin/sudo` setuid boundary: `PROC_PIDTBSDINFO` remained `EPERM`,
the new cross-UID helper returned zero twice with equal observations, Gate audit
anchors were stable, the child remained stopped, and exact SIGKILL/reap left no
reused original lifetime. No credential prompt or privileged campaign ran.

## Validation and Review

- Exact checkpoint scope: 11 non-document paths / 922 changed lines, within the
  11-path / 1,700-line gate.
- Combined focused regression: 110 tests across the validator, sudo-shaped
  launcher, physical Gate and target-boundary suites; all passed.
- Dedicated suspended-sudo source/component gates: passed.
- v16 repair source gate, seven semantic mutations, direct staged-scope call and
  nine scope negatives: passed.
- Final staged-only serialized SwiftPM regression: 1,976 tests / 100 suites,
  zero failures, 210.473 seconds.
- Independent runtime/document and verifier reviews: no unresolved P0-P2 after
  closing two documentation P2s and one staged-scope aggregate P1.

## Boundary

This checkpoint repairs only the status-82 identity observation. The v16
evidence and persistent Gate remain immutable. The independent `cleanup-02`
attribution repair follows as a separate checkpoint. Task 39 remains incomplete,
production Deep Dive remains unavailable, and a new privileged campaign still
requires a new pushed commit plus explicit user authorization.
