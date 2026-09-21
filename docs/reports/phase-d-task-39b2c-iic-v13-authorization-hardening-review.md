# Phase D Task 39B2c ii-c-c v13 authorization hardening review

> Status: implementation complete / non-admitting
>
> Date: 2026-09-10
>
> Baseline: `88851614b090d6d6b9da6a6d7208743b85689cda`

## Result

The consumed v13 failure is now independently classified and the authorization
path is bounded separately from the 1,400-second campaign horizon. The campaign
reader and Gate's first driver-claim wait both use a fixed 120-second
authorization sub-deadline, leaving the remaining campaign and cleanup budget
available after a stalled PAM/OpenDirectory call. The existing 1,400-second
cohort horizon and five-second Gate cleanup reserve remain unchanged.

The credential relay still accepts exactly one human-entered value from the
dedicated controlling-TTY reader. It now validates canonical/no-echo mode,
rejects `INLCR` newline translation, and
writes one credential line followed by the terminal's enabled `VEOF` character.
If sudo rejects the first authentication attempt, a second prompt receives EOF
instead of waiting for an unowned second credential. Embedded NUL/newline/CR/
VEOF bytes are rejected; relay writes are nonblocking, use the same absolute
authorization deadline and wipe the temporary frame on every return.

## Evidence closure

The checked schema-v8 disposition binds v13's nine immutable artifacts, source
and install identity, exact event chain, schema-v2 failure reason, persistent
Gate base/lock/attempt/capsule identities and the current zero fixed-runtime
state. A separate unified-log observation is explicitly non-campaign-bound and
not used for classification or admission. The independent verifier is read-only and
rejects admission or retry. v13 remains consumed/non-admitting/non-retryable.

The real `forkpty` regression proves one canonical credential line, immediate
EOF on a second read, fail-closed `INLCR`, restored echo, zero child residue and
no credential echo.
Focused deadline-policy coverage proves the local 120-second cap and the
existing cleanup-reserve clamp. Structural and mutation gates pin the VEOF
relay, local authorization bound and Gate-side live-clock call.

This checkpoint does not run sudo, install the fixed runtime, invoke a model or
authorize v14. It does not enable L3c3d, L3c4, Task 40 or production Deep Dive.

## Validation

- credential PTY focused suite: 1/1 test passed;
- campaign Harness + credential + sudo-shaped Gate focused selection: 42/42
  tests across 3 suites passed;
- Evidence + target-boundary affected selection: 162/162 tests across 2 suites
  passed;
- ii-c aggregate contract, credential source/mutation contract, 1,400-second
  deadline-budget contract, failure-disposition contract and frozen v13 external
  evidence gate passed;
- Debug/Release campaign final-artifact component gate passed;
- Debug/Release suspended-sudo Gate component gate passed;
- the first whole serial attempt became invalid after the Data volume returned
  `ENOSPC`; its first SQLite and runtime failures each passed immediately after
  space recovery. Three old, unowned verifier scratch directories created by
  earlier local runs were removed without touching any campaign evidence or the
  persistent Gate, increasing free space from roughly 14 GiB to 19 GiB;
- the final post-review serialized SwiftPM regression passed 1,967 tests in 100
  suites in 236.300 seconds;
- final independent runtime/security and verifier/evidence reviews both report
  no unresolved P0-P2 findings.
