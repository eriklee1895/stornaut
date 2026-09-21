# Task 39B2c ii-c-c Suspended sudo observation repair

## Status

Implemented and validated as a non-admitting repair. The consumed v8 machine
campaign remains a failed `spawnUncertain` attempt and was not retried. Task 39
and machine readiness remain incomplete.

## Observed failure

The v8 evidence reached `prepared -> armedConsumed -> spawnUncertain`. The
fixed Gate and its suspended child were launched, but no Gate prepared receipt,
sudo prompt, or Machine driver was observed.

A non-root physical probe reproduced the exact pre-continuation boundary using
the production `/usr/bin/sudo -N -p ... -- <fixed-driver>` argument vector and
spawn flags. It never sent `SIGCONT`, never requested credentials and killed and
reaped the exact child before returning. The observations were:

- `posix_spawn`: success;
- `waitpid(WUNTRACED | WNOHANG)`: raw status `0x7f`;
- Gate `setpgid(0, coordinatorPGID)`: success;
- child PGID/session: stable and equal to the expected recovery group/session;
- stdout and controlling-PTY output: zero bytes;
- exact child reap and recovery-group empty proof: successful;
- `proc_pidinfo(PROC_PIDTBSDINFO)`: `EPERM` for the suspended setuid sudo child;
- `sysctl(KERN_PROC_PID)`: stable PID, parent, PGID, start-time and stopped-state
  evidence before and after the Gate PGID transition.

This identifies the v8 Gate failure as use of a Darwin observation API that is
not available for this setuid suspended child, rather than a failure of raw
initial-stop status or Gate process-group migration.

## Repair

The Gate now reads the initial sudo-child lifecycle tuple through
`sysctl(KERN_PROC_PID)` and independently joins it to `getsid`. Existing checks
remain intact: exact direct child PID, parent PID, recovery PGID, coordinator
session, start seconds/microseconds, raw initial stop `0x7f`, stopped state, and
exact PID/group cleanup.

The physical fixture observes both sudo stdout and the controlling PTY, has
bounded result reads, and proves session cleanup on failure. It cannot continue
the sudo child and therefore cannot show a credential prompt or execute the
driver.

## Validation

- Gate physical suite: 7 tests / 11 expanded cases passed.
- Gate launcher and Task 39 target-boundary suites: combined focused run passed.
- Serialized SwiftPM regression: 1,924 tests / 99 suites passed in 196.396 s.
- `--iic-c-suspended-sudo-contract-only`: passed.
- `--iic-c-contract-only` with component rebuild skipped: passed, including
  current negative mutations and historical replay.
- `--iic-c-suspended-sudo-component-boundary-only`: Debug and Release passed.
- Historical Gate final-Mach-O boundary: passed after rebinding the exact current
  projections; intentionally embedded Gate and GateCoordinator tools remain
  positive controls, while closed product images remain negative controls.
- Independent post-fix reviews: no unresolved P0-P2.

The authoritative `scripts/verify --full` remains unconsumed and reserved for
L3c4. No privileged campaign, install, authentication, App/helper/XPC, model or
network operation was run for this repair.

## Remaining order

The consumed v8 attempt cannot be retried or retroactively sealed. Continue with
failure-evidence/recovery disposition for that attempt, then `L3c3d -> L3c4`.
