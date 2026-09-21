# Phase D Task 39B2c ii-c-c v12 credential-deadline repair review

> Status: implementation complete / non-admitting
>
> Date: 2026-09-09
>
> Baseline: `212320fa9f05cad52a40fb9ce02ed7bf73543b04`

## Result

The post-arm administrator-credential relay no longer calls an unbounded
`readpassphrase` in the long-lived Swift process. A package-only C boundary
resolves the current Mach-O with `proc_pidpath`, starts one suspended internal
credential-reader child in a dedicated process group, transfers terminal
foreground ownership, and receives one bounded frame over fixed FD 6. The
child-owned system `readpassphrase` emits the fixed prompt and reads the
credential under the same bounded lifetime, so the Swift parent has no separate
blocking prompt write. The system call's signal contract restores terminal
state before exit. The parent monitors the pipe against
`CLOCK_UPTIME_RAW`; at the deadline it sends SIGTERM, allows a 250 ms restore
window, then uses SIGKILL only if necessary, exactly reaps the child and restores
the original foreground group and termios. Swift and C map the original
operation deadline into the same Darwin continuous-uptime clock domain without
minting a fresh relative budget, and Swift rechecks that original deadline
before relaying any credential bytes.

No process-level signal handler, `SIGALRM`, `alarm`, `setitimer` or shared reader
thread was added. The API admits at most 1,023 credential bytes, rejects empty
or overflowed input, and returns a dedicated deadline status. Swift maps that
status to the existing campaign deadline failure and still clears its buffer
after relay. The internal mode accepts no caller-selected executable path and
validates its parent/session/process-group/foreground-TTY/fixed-pipe topology.

## Evidence

The tests-first physical fixture uses `forkpty` to create a real controlling
terminal. It waits until the dedicated reader child is the foreground group and
echo is actually disabled before sending successful, empty, overflowing or
Ctrl-C input. Assertions cover deadline return, exact errno, echo restoration,
full failure-buffer zeroing, absence of credential echo and zero child/zombie
residue. Deterministic injection covers expiry before C entry plus terminate
signal, termination-clock and wait failures; all still force the final
SIGKILL/reap fallback. The earlier
reader-thread prototype passed 30/30 repeated PTY runs but was superseded after
review found a theoretical join-error lifetime gap. The final child-reader
focused case and C compiler warnings-as-errors gate pass.

The structural contract rejects removal or drift of deadline classification,
foreground handoff, exact wait, the internal child mode, the 1,023-byte cap and
the no-echo overflow assertion. Additional mutations reject relative-deadline
reminting, removal of the Swift pre-relay deadline check, premature child
ownership clearing and vacuous reap-failure tests. It requires exactly one `readpassphrase` call in
the child and forbids `SIGALRM`, `alarm`, `setitimer` and pthread reader creation.

## Validation

- warnings-as-errors C syntax checks passed for the production source and the
  test-only fault-injection build;
- the PTY suite passed one test covering ten physical paths: idle timeout,
  expiry before C entry, normal success, 1,023-byte success, empty input,
  Ctrl-C, 1,024-byte canonical-terminal overflow, and injected TERM/clock/wait
  cleanup failures;
- campaign Harness passed 12/12, Evidence passed 85/85 after external historical
  Gate admission was made an explicit opt-in, and the target-boundary suite
  passed 20/20;
- the sole pre-review serialized SwiftPM regression passed 1,947 tests in 100
  suites. The two independent-review fixes were then covered by exact PTY,
  source, mutation and Mach-O gates; the serial suite was not redundantly rerun;
- Debug and Release campaign builds and the existing final-Mach-O component
  boundary passed;
- the v12 external verifier was invoked directly against the frozen absolute
  evidence root, and both v12 integration tests passed with the same explicit
  evidence-root opt-in;
- independent runtime post-fix review found no remaining P0–P2. Independent
  verifier/evidence post-fix review is recorded separately before commit.

This repair is non-admitting. It does not execute sudo, install the fixed
runtime, run a model, authorize v13, establish a green cohort or unblock Task
40. The separate Gate persistence prerequisite remains open because the v11 and
v12 capsules disappeared from the purgeable cache location after v12.
