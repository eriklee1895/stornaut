# ADR 0004: Probe Broker Policy and Codex File-Read Isolation

> Status: Accepted as a Task 5 no-go decision
> Date: 2026-08-09
> Decision owners: Stornaut maintainers
> Related study: [`../upstream-studies/epic-1-codex-runtime.md`](../upstream-studies/epic-1-codex-runtime.md)
> Prerequisites: [`0001-package-first-native-shell.md`](0001-package-first-native-shell.md), [`0003-codex-process-protocol.md`](0003-codex-process-protocol.md)

## Context

Task 5 must answer two different questions:

1. Can Stornaut enforce path, content, budget and audit policy inside its own
   Probe Broker?
2. Can installed Codex `0.147.0` be technically restricted so that this Broker
   is its only disk-evidence surface?

The first is necessary but does not imply the second. A typed Swift bridge or
an MCP server allowlist constrains that transport only. It does not remove
Codex core tools or direct file reads.

## Decision

### Probe Broker spike

Keep the Task 5 Broker as a narrow in-process spike with four capabilities:

- `diskSnapshot`;
- `directorySummary`;
- `largestChildren`;
- `safeTextSnippet`.

All requests are bounded and Codable. `CanonicalPathPolicy`:

- accepts absolute existing paths only;
- canonicalizes symlinks before scope comparison;
- compares path components rather than string prefixes;
- respects volume case sensitivity and canonical Unicode equivalence;
- binds each path to device/inode/type/size/mtime identity;
- rejects `/`, the home directory, mount roots and broad allowed roots;
- requires a target and its allowed root to remain on the same device;
- applies the immutable sensitive-path denylist.

`.ssh`, `.gnupg` and `.env`-style secret files are denied at every root. Mail,
Messages, Photos libraries, Safari and common browser profiles are denied
under the user's home. There is no settings override.

Directory probes open an identity-checked directory descriptor and enumerate
with `fdopendir`/`fstatat(AT_SYMLINK_NOFOLLOW)`. The text probe uses
`open(O_NOFOLLOW)`, verifies the descriptor identity with `fstat`, reads at
most `byteLimit + 1` bytes, restricts filenames, rejects binary/invalid UTF-8
content and redacts secret patterns. Every probe revalidates the path identity
after access. Symlink replacement between authorization and open fails closed.

Session call/read/output budgets are actor-isolated. Content-read budget is
reserved before file access. Audit records contain only capability, a
`redacted` target marker, outcome and byte counts; raw paths and snippets are
not retained.

### Typed bridge spike

`ProbeBridge` accepts one bounded JSON object with exactly `id`, `tool` and
`arguments`. `ProbeToolSchema` contains exactly four read-only names. Unknown
tools, extra fields, malformed arguments, arbitrary Shell/filesystem requests,
writes, Trash and registered cleanup actions are rejected before Broker
execution.

This is a protocol seam proved with a fake Codex client. It is not represented
as an MCP server running inside the real Codex experiment because the installed
runtime does not offer a complete Broker-only tool-surface control.

### Release outcome

**Outcome: `protocol-only but direct tools/read still possible`.**

Deep Dive remains **no-go/paused** under the approved v1 boundary.

Reasons:

1. Official `rust-v0.147.0` source and execution-time help still expose no
   public control equivalent to `--only-tools stornaut.*`.
2. Per-MCP `enabled_tools` constrains one server, not the complete Codex tool
   registry.
3. Shell, Skills, Hooks, Plugins, Apps and external MCP can be disabled by the
   strict candidate profile, but model/core tool assembly is independent.
4. The read-only sandbox is a write boundary, not a confidentiality boundary.
5. A single canary turn that does not use a direct-read tool cannot prove such
   a tool is technically absent.

Do not run a real Codex-to-Broker MCP against the user disk while this remains
unresolved. The fake bridge is the safe end-to-end evidence for this Task.

## Evidence

### Unit and integration tests

Contract-first tests initially failed because Task 5 types did not exist. The
final focused suite has 23 test entries, all passing; parameterized entries add
22 path/tool cases.

Coverage includes:

- traversal, sibling-prefix confusion and relative input;
- in-root and escaping symlinks;
- nonexistent paths, `/`, home and mount protection;
- case-sensitive volume behavior and Unicode normalization;
- immutable sensitive paths and secret filenames;
- capability/root/read-level enforcement;
- call/read/output budgets;
- timeout and cancellation;
- path replacement with an escaping symlink between authorization and open;
- four bounded read-only responses;
- approved text types, binary rejection and secret redaction;
- prompt-injection README treated as data;
- audit payload redaction;
- exact four-tool schema;
- malformed, oversized, extra-field and unregistered Bridge requests;
- explicit rejection of Shell, direct filesystem, write and cleanup names.

The measured Task 5 line coverage was `92.19%` and function coverage was
`93.26%` before final descriptor-relative hardening; coverage was informational,
not a release proxy. The complete SwiftPM suite after hardening discovered 83
test entries: 81 passed and the two opt-in installed/real diagnostics skipped.

Full verification initially exposed two existing concurrency assumptions that
became reproducible under the larger parallel suite:

- sibling `posix_spawn` calls could create pipes before another spawn had
  applied `FD_CLOEXEC`, leaving fake children waiting for stdin EOF;
- macOS could return transient `EPERM` while a group leader changed to a
  waitable exit during asynchronous output-limit cleanup.

The initial fix serialized pipe creation and spawn with a process-local mutex.
Task 7 later added a second process runtime, so the final implementation uses
macOS `POSIX_SPAWN_CLOEXEC_DEFAULT` plus explicit standard-descriptor mappings
in both runtimes. The existing eight-way spawn regression now mixes seven fake
Codex processes with one fake Registered Action, avoiding cross-runtime pipe
inheritance without serializing all spawns. The terminator retries only while
`EPERM` remains, then uses the existing fallback only after `waitid(WNOWAIT)`
proves leader exit and `proc_listpids(PROC_PGRP_ONLY)` enumerates remaining
members. Repeated full suites and focused stress passed with no surviving
fixture process.

### App-context canary experiment

Execution environment:

| Item | Observed value |
| --- | --- |
| macOS | 26.5.1, build 25F80 |
| Architecture | arm64 |
| Xcode | 26.6, build 17F113 |
| Swift | 6.3.3 |
| Codex | `codex-cli 0.147.0` |
| App bundle | `com.eriklee.stornaut` |
| Signature | ad-hoc, explicit designated requirement |
| App Sandbox | disabled |
| Launch context | `open -W -n -g -a <signed Stornaut.app> --args ...` |

A Debug-only harness was compiled into the real App target. It accepted one
ignored local JSON configuration, read only synthetic canaries, launched the
production `CodexProcess`, wrote a redacted report under `.derivedData/`, and
terminated the App. Release builds contain none of this harness.

Three non-sensitive files were created under one ignored temporary root:

1. inside the isolated Codex working directory;
2. inside the candidate Broker fixture root;
3. in a sibling outside both.

The signed App read all three expected synthetic tokens. This proves the App
host is not confined to the Codex workspace and can act as the Broker host.

The same App attempted `open(O_DIRECTORY)` on the user's Mail directory without
enumerating it. The call was denied. Terminal was also unable to create a
synthetic canary there, so no private file was selected, read or recorded.
Current App FDA/TCC state is therefore measured as **not granted for Mail**.
No TCC database was read, no permission was granted/reset, and no alternate
state was manufactured.

Exactly one authenticated Codex canary turn ran under the strict Task 4 profile.
The prompt named all three synthetic paths and required the tokens only if
directly readable. The typed result contained an empty summary and no finding;
the event categories contained only lifecycle, thread/turn and final
`agent_message` events. No tool event was observed and no token was returned.

This result means the selected turn did not directly read the canaries. It does
not prove the complete runtime tool registry is Broker-only, so it cannot
upgrade the release outcome.

No raw JSONL, prompt response, canary token, credential, TCC database content or
private path inventory is committed.

## Consequences

Positive:

- path, denylist, budget, redaction and audit behavior now have executable
  Swift contracts;
- the Bridge rejects write/cleanup/unregistered requests structurally;
- App-context launch and current Mail TCC denial are measured using the real
  signed bundle;
- failure of the Codex gate does not block Quick Scan, Surveyor, Policy or
  Action lifecycle work.

Costs:

- the current Bridge is an in-process protocol spike, not a production MCP/XPC
  deployment;
- content-read reservations are conservative and are not refunded on failure;
- directory probes report immediate-child metadata only;
- the sensitive-path catalog must be reviewed as macOS/browser layouts evolve.

## Residual Risks and Next Gate

Deep Dive may resume only after one of these receives separate approval and
evidence:

1. a future Codex version provides and behaviorally proves a complete tool
   allowlist with direct filesystem/core tools absent;
2. a stronger process boundary (for example a narrowly sandboxed helper/XPC
   design) proves Codex can access only an isolated workspace plus Broker IPC;
3. the user explicitly approves a changed product boundary and corresponding
   PRD/design wording.

Task 5 does **not** request that boundary change. Existing PRD and architecture
wording already require this exact no-go behavior, so no normative weakening is
needed.

Task 6 and Task 7 may proceed because they are deterministic and do not depend
on Deep Dive.

## Validation

Task 5 acceptance requires:

- focused path/Broker/Bridge tests;
- full SwiftPM tests;
- App target build and ad-hoc signature verification;
- LaunchServices App-context report;
- `scripts/verify`;
- clean diff checks and no committed sensitive evidence.
