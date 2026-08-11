# ADR 0004: Codex Investigation and Swift Execution Boundary

> Status: Amended and accepted — integrity-first Agent boundary approved
> Date: 2026-08-09
> Amended: 2026-08-11
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

Task 5 therefore recorded a correct execution-time fact: installed Codex
`0.147.0` could not prove a Broker-only tool surface. The original product
boundary treated that missing proof as a Deep Dive no-go.

On 2026-08-11 the user explicitly changed the product priority for this
personal-use tool:

1. investigation quality and Codex's full Agent reasoning are the highest
   priority;
2. Codex must be able to inspect unfamiliar directory and project types with
   direct read-only shell tools;
3. Codex must be able to use live web search when local evidence is
   insufficient;
4. lower investigation-data confidentiality is accepted;
5. Codex still has no cleanup authority, and every write remains behind Swift
   validation, explicit user selection and the typed Executor.

This amendment changes the normative product boundary. It does not rewrite the
historical Task 5 measurements below.

## Decision

### 2026-08-11 amendment: integrity-first Agent investigation

The Broker-only requirement is no longer a prerequisite for Deep Dive. Replace
it with an integrity-first boundary:

- Codex may use direct filesystem reads and local shell commands for
  investigation.
- Codex runs under an OS-enforced read-only sandbox. It must not create,
  modify, move, rename or delete user data.
- Codex may use built-in live web search when it encounters an unfamiliar
  directory, artifact, toolchain or project type.
- Built-in web search is distinct from arbitrary command/subprocess network
  access. Command network remains disabled by default; enabling it would be a
  separate future decision with its own evidence.
- Probe Broker remains a preferred structured, bounded and auditable evidence
  source, but it is no longer Codex's exclusive investigation interface.
- Codex output is advisory evidence and candidate proposals only. It cannot
  invoke `MoveToTrash`, a Registered Action, Policy Gate or Executor.
- Swift canonicalizes every proposed path, applies protected-path and activity
  policy, revalidates current identity and state, and presents the result for
  explicit user selection.
- Only actions selected by the user and approved by Swift Policy Gate can reach
  the typed Executor. Trash failure still never falls back to permanent
  deletion.

The accepted confidentiality trade-off is explicit: files read by Codex may be
represented in model context, and live search queries/results are processed by
external services. Stornaut no longer claims that Deep Dive exposes only
Broker-filtered or Broker-redacted evidence to Codex. It still must not
intentionally collect credentials, bypass TCC, persist raw model streams, or
turn investigation content into cleanup authority.

The current OpenAI documentation supports separating these controls: local
Codex sandboxing governs filesystem writes and command network access, while
the built-in web-search mode can be configured independently. It also warns
that web content is untrusted and that arbitrary Agent internet access adds
prompt-injection, exfiltration, malware and licensing risks:

- [Agent approvals and security](https://developers.openai.com/codex/agent-approvals-security)
- [Agent internet access](https://developers.openai.com/codex/cloud/internet-access)

The product accepts those documented confidentiality risks for personal use in
exchange for higher investigation quality, while retaining the non-negotiable
write and execution separation above.

### Historical Task 5 Probe Broker spike

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

`.ssh`, `.gnupg`, cloud/CLI credential directories, Keychains/password-manager
data, `.env`, private-key and common credential files are denied at every root.
Mail, Messages, Photos libraries, Safari and common browser profiles are denied
under the user's home. There is no settings override.

Directory probes open an identity-checked directory descriptor and enumerate
with `fdopendir`/`fstatat(AT_SYMLINK_NOFOLLOW)`. The text probe uses
`open(O_NOFOLLOW)`, verifies the descriptor identity with `fstat`, reads at
most `byteLimit + 1` bytes, restricts filenames, rejects binary/invalid UTF-8
content and redacts quoted JSON/TOML/YAML values, common token prefixes,
Authorization values and complete/incomplete private-key blocks. Directory
metadata probes filter denied children, stop summaries after `limit + 1`, and
retain only a bounded top-N set. Every probe revalidates the path identity
after access. Symlink replacement between authorization and open fails closed.

Session call/read/output budgets are actor-isolated. Content-read budget is
reserved before file access. Audit records contain only capability, a
`redacted` target marker, outcome and byte counts; raw paths and snippets are
not retained.

### Historical Task 5 typed bridge spike

`ProbeBridge` accepts one bounded JSON object with exactly `id`, `tool` and
`arguments`. `ProbeToolSchema` contains exactly four read-only names. Unknown
tools, extra fields, malformed arguments, arbitrary Shell/filesystem requests,
writes, Trash and registered cleanup actions are rejected before Broker
execution.

This is a protocol seam proved with a fake Codex client. It is not represented
as an MCP server running inside the real Codex experiment because the installed
runtime does not offer a complete Broker-only tool-surface control.

### Historical Task 5 release outcome

**Outcome: `protocol-only but direct tools/read still possible`.**

Deep Dive was **no-go/paused** under the boundary approved at that time.

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

This historical outcome remains valid evidence that Broker-only isolation was
not available. The 2026-08-11 amendment removes Broker-only isolation as the
product prerequisite; it does not reinterpret the canary as proving isolation.

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
  Action lifecycle work;
- Deep Dive may now be planned around Codex's direct read-only Agent tools and
  live web search instead of waiting for a complete Broker-only allowlist;
- unfamiliar artifacts can be investigated adaptively instead of being limited
  to the four initial Probe schemas;
- cleanup integrity remains owned by Swift Policy Gate, user selection and the
  typed Executor.

Costs:

- the current Bridge is an in-process protocol spike, not a production MCP/XPC
  deployment;
- content-read reservations are conservative and are not refunded on failure;
- directory probes report bounded immediate-child metadata only;
- the sensitive-path catalog must be reviewed as macOS/browser layouts evolve;
- direct Codex reads are not covered by Probe Broker redaction, byte budgets or
  path audit records;
- model context and live web search create accepted confidentiality,
  prompt-injection, third-party processing and licensing exposure;
- human cleanup confirmation does not mitigate investigation-time disclosure,
  so UI and privacy documentation must describe this trade-off honestly.

## Residual Risks and Next Gate

The user approval required by the historical third option was granted on
2026-08-11. A complete Broker-only tool allowlist or confidentiality sandbox is
therefore no longer the gate.

Deep Dive is not automatically production-ready merely because the normative
blocker has been removed. A separately approved implementation plan must prove:

1. effective write denial for Codex and every descendant process;
2. no callable path from Codex events, shell commands or output fields to
   Trash, Registered Actions, Policy Gate bypass or Executor;
3. bounded timeout, cancellation, output and process-tree cleanup remain intact
   when shell and live search are enabled;
4. live search works without granting arbitrary command/subprocess network
   access;
5. all candidates are treated as untrusted advisory input and are
   canonicalized, classified, revalidated and displayed for explicit selection;
6. malformed, injected, stale, active, protected or out-of-scope candidates
   fail closed as `Unknown` or rejected;
7. the UI and privacy documentation disclose that direct reads and live search
   are not Broker-redacted confidentiality boundaries;
8. no raw Codex JSONL or uncontrolled content payload is retained beyond the
   approved evidence lifecycle.

Until that implementation and evidence gate passes, current production UI may
remain unavailable. Its reason is now **implementation not yet delivered**, not
**Broker-only isolation required**.

## Validation

The historical Task 5 acceptance evidence remains valid for Probe Broker and
the typed bridge. The amended boundary requires a new Deep Dive implementation
gate with:

- adversarial read-only sandbox tests covering the Codex process tree;
- direct-read and shell investigation fixtures for unfamiliar artifact types;
- live-search behavior and provenance tests with command network disabled;
- prompt-injection and candidate-forgery fixtures;
- proof that Codex output cannot encode or trigger an executable cleanup path;
- focused protocol, Policy Gate and revalidation suites;
- signed-App runtime evidence using synthetic, non-sensitive fixtures;
- full `scripts/verify`, actual-window UI inspection and clean diff checks.
