# ADR 0003: Structured Codex Process Protocol and Lifecycle

> Status: Accepted for Task 4 process/protocol only
> Date: 2026-08-09
> Decision owners: Stornaut maintainers
> Related study: [`../upstream-studies/epic-1-codex-runtime.md`](../upstream-studies/epic-1-codex-runtime.md)
> Prerequisite: [`0002-codex-discovery-and-capabilities.md`](0002-codex-discovery-and-capabilities.md)

## Context

Task 3 established shell-free Codex discovery and syntax-level capability
reporting. Task 4 must establish a bounded process and protocol seam before any
Probe Broker or disk-read isolation experiment can run.

The seam must:

- launch the user-installed executable without `sh -c`;
- send the prompt through stdin;
- incrementally parse stdout as bounded JSONL;
- keep stderr separate and bounded;
- validate the final response again in Swift;
- create an isolated process group before any signal can be sent;
- terminate descendants on timeout, cancellation, decoder failure or normal
  leader exit;
- never expose raw model output, raw stderr, thread IDs or process IDs as App
  stream state.

This Task does not prove that Codex has a Broker-only tool surface or cannot
read files directly.

## Decision

### Fixed launch profile

`CodexRunRequest.fixedArguments` constructs an argument array containing:

```text
exec
--strict-config
--ephemeral
--json
--output-schema <schema>
--sandbox read-only
--ignore-user-config
--ignore-rules
--skip-git-repo-check
-C <isolated-directory>
-c <candidate isolation overrides>
-
```

The candidate overrides disable project docs, optional instruction catalogs,
analytics/OTel export, Shell/unified exec, Hooks, Plugins, Apps, computer/browser
features, image generation and orchestrator Skills/MCP.

These keys are a measured Task 4 launch profile, not a claim that all runtime
tools or instructions are absent. Task 5 must inspect the effective tool and
read surfaces.

The environment is allowlisted to:

- `CODEX_HOME`;
- `HOME`;
- locale keys;
- `PATH`;
- `TERM`;
- `TMPDIR`.

API keys, GitHub tokens and developer MCP configuration are not inherited.

`CODEX_HOME` must be absolute and must exist. Before launch, Stornaut uses
`lstat` to require both global instruction candidates,
`AGENTS.override.md` and `AGENTS.md`, to be absent or zero-byte regular files.
Symlinks, directories, non-empty files and inspection errors fail closed.
This mirrors the two filenames read by Codex `0.147.0`'s
`CodexHomeUserInstructionsProvider`.

### Process topology

Use `posix_spawn`, not `Process` followed by `setpgid`:

- `POSIX_SPAWN_SETPGROUP` creates a new process group atomically;
- `POSIX_SPAWN_CLOEXEC_DEFAULT` closes every descriptor not explicitly mapped
  by spawn file actions, including descriptors from concurrently starting
  Registered Actions;
- `posix_spawn_file_actions_addchdir` selects the isolated cwd;
- stdin/stdout/stderr are explicit pipes;
- all pipe descriptors use `FD_CLOEXEC`;
- the prompt pipe uses `F_SETNOSIGPIPE`;
- `waitid(P_PID, WNOWAIT)` observes leader exit without reaping it, so the PGID
  cannot be reused before descendant cleanup completes;
- the returned PGID must equal the child PID and must differ from Stornaut's
  process group.

This removes the race in which a failed `setpgid` could cause signalling of the
App or test runner group.

### JSONL and final envelope

`JSONLDecoder`:

- buffers only the unfinished line;
- handles arbitrary chunk and UTF-8 scalar boundaries;
- enforces per-line and whole-session byte limits;
- fails on malformed JSON or a truncated final line;
- decodes known event types;
- retains unknown events only as an event type and a small allowlist of bounded
  scalar metadata;
- never forwards unknown nested payloads.

The bounded event channel accepts at most 64 queued events. A caller that does
not drain the stream receives a typed overflow failure and triggers process
cleanup; the producer never grows memory or blocks cleanup indefinitely.

Agent-message text is retained only inside the process worker long enough to
decode the final envelope. The public stream receives a redacted
`item.completed` event and then a typed `InvestigationEnvelope`. Stderr is
represented only by its byte count.

The checked-in JSON Schema and Swift validator require exactly:

```text
summary
findings[{targetID, summary}]
unresolvedTargetIDs
```

Both top-level and nested additional fields fail. No executable command or
cleanup action field exists.

### Cancellation and cleanup

Timeout, consumer cancellation and asynchronous pipe/decoder failures trigger
the same group cleanup:

1. interrupt the group;
2. wait half the configured grace period;
3. terminate the group if it remains;
4. wait the remaining half;
5. kill the group if it remains;
6. reap the leader and close/drain pipes.

The terminator refuses PGID `<= 1` and the current process group. A normally
exiting leader is not sufficient: any surviving descendant in its group is
also terminated before pipe results are awaited.

## Evidence

### Tests first

The first focused test command failed at compile time because the planned
`JSONLDecoder`, `CodexEvent`, `InvestigationEnvelope`, `CodexProcess` and
`ProcessTreeTerminator` types did not exist. Existing test infrastructure and
fixture paths were not the cause.

The final focused suite discovered 58 tests:

- 56 passed;
- the installed capability diagnostic was skipped by default;
- the real process diagnostic was skipped by default.

The full SwiftPM suite added the Core smoke test and discovered 59 tests:
57 passed and the same two diagnostics were skipped.

Task 4 coverage includes:

- fragmented lines and multiple events per chunk;
- UTF-8 scalar boundaries;
- malformed and truncated JSONL;
- line/session/output/stderr byte limits;
- bounded unknown event metadata;
- strict top-level and nested envelope fields;
- fixed argv, stdin, cwd and environment allowlist;
- raw agent-message and stderr redaction;
- nonzero and early-exit behavior, including `SIGPIPE` protection;
- malformed protocol errors before overall timeout;
- event-buffer overflow when a consumer does not drain;
- independent PGID creation;
- timeout and consumer cancellation;
- ignored signals and forced group kill;
- leader exit with a surviving child;
- no live child PID after the bounded observation window;
- rejection of non-empty global Codex instructions.

One early parallel run exposed cross-test pipe descriptor inheritance. Parent
descriptors use `FD_CLOEXEC`; after Task 7 introduced another process runtime,
both runtimes also adopted `POSIX_SPAWN_CLOEXEC_DEFAULT`. The eight-way spawn
regression now mixes seven fake Codex processes and one fake Registered Action
without increasing the original process load.

A later stress run exposed a process-group lifecycle race: reaping the leader
before checking descendants allowed the PGID to become reusable. The wrapper
now observes exit with `WNOWAIT`, distinguishes a waitable leader from live
descendants, cleans the group, and reaps last. Five consecutive process-suite
runs (70 process cases) then passed. On macOS, signalling a group containing
an unreaped waitable leader can return `EPERM`. The fallback is allowed only
after `waitid(WNOWAIT)` proves leader exit and
`proc_listpids(PROC_PGRP_ONLY)` enumerates the group: an empty remainder is a
zombie-only group, while every remaining PID is signalled individually. Any
unprovable state or member signal failure still fails closed.

### Fake process evidence

The generated `fake-codex.sh` fixture is a test-only direct executable. It
supports success, stderr noise, malformed output, invalid envelope, output
limits, nonzero/early exit, timeout, ignored signals, a child process and a
normally exiting leader that leaves a child.

The fake tests prove Stornaut's wrapper behavior. They do not prove Codex's
internal implementation.

### Real Codex startup evidence

Installed runtime: `codex-cli 0.147.0`.

An empty temporary `CODEX_HOME` was used first:

- every candidate config key passed `--strict-config`;
- stdout reached `thread.started` and `turn.started`;
- the turn failed authentication with HTTP 401;
- the temporary workspace remained empty;
- the empty Codex home gained runtime state entries.

This proves strict startup compatibility and also proves that `--ephemeral`
does not mean "no local state initialization."

### One authenticated static-envelope probe

Exactly one authenticated model turn was then run using the existing
`CODEX_HOME` after checking both global instruction candidates. The current
`AGENTS.md` was a zero-byte regular file and `AGENTS.override.md` was absent,
which Codex's official provider treats as no global user instructions.

The prompt requested one constant envelope and prohibited file inspection or
tool use. Observed typed sequence:

```text
started
process-group-created
thread.started
turn.started
item.completed
turn.completed
completed
```

Results:

- all strict candidate config keys were accepted;
- JSONL decoded through the production parser;
- the final envelope passed Swift exact-key validation;
- no raw agent message was exposed by the typed stream;
- the isolated workspace had zero entries after the run;
- the session/history path set had no newly observed path.

The diagnostic's original metadata assertion compared size and modification
time of all existing session files. Another active Codex process changed one
pre-existing session file concurrently, so that assertion failed despite no
new path. The audit was corrected to compare path sets only. The model turn was
not repeated.

No raw JSONL, thread ID, prompt response, credential or private path inventory
is checked into the repository.

## Consequences

Positive:

- later Spikes have a typed, bounded, shell-free process seam;
- malformed output and invalid envelopes fail closed;
- process-group creation precedes signalling;
- cancellation and timeout include descendants;
- raw model/stderr payloads do not become UI state;
- actual Codex `0.147.0` accepted the strict launch profile and produced a
  schema-valid final envelope.

Costs:

- the POSIX wrapper is macOS-specific and more complex than `Process`;
- `CODEX_HOME` instruction preflight is version-specific evidence and must be
  revalidated when Codex changes;
- ephemeral sessions may still initialize or update non-session runtime state;
- an authenticated diagnostic can be affected by other Codex processes writing
  the same user home, so residue checks must avoid mutable metadata.

## Residual Risks and Gates

Task 4 does **not** establish:

- Broker-only tool-surface enforcement;
- absence of Shell/apply-patch or other built-in tools in the effective turn;
- direct filesystem-read isolation;
- App-context FDA/TCC inheritance;
- local Probe Broker transport;
- complete suppression of every future instruction/config provider;
- production-safe credential isolation.

The real static-envelope response is protocol evidence only. A constant prompt
and an empty workspace cannot prove that direct reads or tools are unavailable.

Deep Dive therefore remains paused. Task 5 must run synthetic canaries from an
actual signed App context, inspect effective tool/instruction surfaces and
prove the local Broker-only boundary. Failure remains an acceptable no-go
result; it must not be bypassed by dropping strict config or weakening the
product boundary.

## Validation

Task 4 requires:

```text
swift test --filter StornautCodexTests
scripts/verify
```

One final `scripts/verify` attempt passed SwiftPM but failed before any UI test
case started because macOS AutomationMode timed out during runner
initialization; a fresh UI-only retry reproduced the same infrastructure
failure. The GUI session was unlocked with two active displays. A current-user
`AutomationModeUI` restart restored the XCTest handshake; no root daemon, TCC,
Accessibility, Event Synthesizing or system permission was modified. The
subsequent full verification passed both UI tests and all remaining
build/signing/docs checks.

The real process diagnostic remains opt-in and must not be repeated casually:

```text
STORNAUT_RUN_REAL_CODEX_PROCESS_PROBE=1 \
  swift test --filter realCodexStaticEnvelopeProcessProbe
```

It may run only when the authenticated `CODEX_HOME` has no non-empty global
AGENTS instruction file. It is not part of ordinary CI.
