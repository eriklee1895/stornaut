# ADR 0002: Codex Discovery and Evidence-Bearing Capabilities

> Status: Accepted for Task 3 discovery only
> Date: 2026-08-09
> Decision owners: Stornaut maintainers
> Related study: [`../upstream-studies/epic-1-codex-runtime.md`](../upstream-studies/epic-1-codex-runtime.md)

## Context

Stornaut must discover a user-installed Codex from a GUI App environment
without:

- launching a login shell;
- sourcing dotfiles;
- depending on a real Codex login in unit tests;
- starting a model/Agent session;
- treating a CLI version number or help flag as proof of runtime isolation.

Task 3 also needs a typed compatibility report for later process and isolation
Spikes. That report must distinguish syntax advertised by `codex exec --help`
from behavior that still requires Tasks 4–5.

## Decision

### Discovery

`CodexLocator` uses direct Foundation filesystem APIs in this order:

1. an explicit configured URL;
2. absolute directories from the supplied GUI `PATH`, capped at 64 entries;
3. a bounded list under the supplied absolute `HOME`:
   - `~/.npm-global/bin/codex`
   - `~/.local/bin/codex`
   - `~/.bun/bin/codex`
   - `~/.volta/bin/codex`

An invalid explicit configuration fails closed instead of silently falling
back. Empty or relative `PATH` entries are ignored. Finder aliases are resolved
with UI and volume mounting disabled; symlinks are resolved; the final URL must
be an executable regular file.

The result records only the winning canonical URL and source. Stornaut does not
persist a private inventory of searched paths.

### Process abstraction

`ProcessRunning` accepts an executable URL and argument array directly.
`FoundationProcessRunner`:

- never invokes a shell;
- uses an explicit environment;
- rejects non-empty standard input in Task 3;
- drains stdout and stderr concurrently;
- independently caps both output streams;
- returns nonzero exit status to the caller;
- terminates and, if necessary, kills the direct process on timeout.

Task 4 still owns process-group/descendant cancellation. Task 3's direct-process
timeout is not evidence that an Agent subprocess tree is fully contained. Task
4 also owns structured stdin and interactive process I/O.

### Capability report

`CodexCapabilityDetector` runs only:

```text
<codex> --version
<codex> exec --help
```

It passes only `HOME`, locale keys, `TERM`, `TMPDIR`, and at most 64 absolute,
deduplicated `PATH` directories from the supplied environment. Tokens, API keys
and developer MCP configuration are not copied into the probe environment.

Probe output is capped at 64 KiB per stream with a five-second timeout.
Nonzero exit, truncation, invalid UTF-8, invalid executable identity, and an
executable replacement during probing fail closed.

The parser:

- derives option support from help text, never version equality;
- parses each required option independently;
- requires the documented `read-only` sandbox selector;
- rejects malformed or duplicate/contradictory option declarations;
- marks missing syntactic prerequisites as `unsupported(reason:)`;
- keeps unmeasured runtime behavior as `unverified(reason:)`.

The report is cached only in the detector actor for the current App session.
Every lookup re-runs `--version`; a changed canonical file identity or version
causes a new help probe. No compatibility result is persisted.

## Evidence

### Tests first

The first focused command was:

```text
swift test --filter StornautCodexTests
```

It failed at compile time because the planned `CodexLocator`,
`ProcessRunning`, `CodexCapabilityParser`, and `CodexCapabilityDetector` APIs
did not exist. Fixture loading and the existing Swift Testing setup were not
the cause.

After implementation and boundary fixes, the focused `StornautCodexTests`
suite discovered 34 tests: 33 passed and the installed diagnostic was skipped
by default. The full SwiftPM suite added the Core smoke test. The installed
diagnostic passed in the separate opt-in run.
The suite covers:

- configured/PATH/known-candidate precedence;
- symlink and Finder alias canonicalization;
- invalid explicit configuration, directories, non-executable files and
  broken symlinks;
- empty, relative and capped PATH entries;
- historical `0.146.0` and execution-time `0.147.0` generated fixtures;
- independent flag parsing, required sandbox value, malformed/duplicate help,
  and missing prerequisites;
- fixed probe commands and environment allowlisting;
- nonzero/truncated output and session-only cache invalidation;
- stdout/stderr bounds, rejected non-empty input, timeout and nonzero process
  exit.

### Generated fixtures

| Fixture | SHA-256 |
| --- | --- |
| `codex-exec-help-0.146.0.txt` | `71e55de96e5126b214ad5abd775ca42b692b771bf332bd5f0b5d384964a212e0` |
| `codex-exec-help-0.147.0.txt` | `eabdc4bd7e21a621a1dbc91f006dbe984f807c5222e8716f77146685b0a315ef` |
| `codex-version-0.147.0.txt` | `47e8650c39eae3ea896e5873f03a97a65d183d81cd0d86616e8b83d7d87877ca` |

The fixtures are generated command output with trailing horizontal whitespace
removed for repository hygiene. No Codex implementation source is copied. The
upstream study retains the SHA-256 of the raw execution-time `0.147.0` help
capture.

### Installed Codex diagnostic

The opt-in test was run with:

```text
STORNAUT_RUN_INSTALLED_CODEX_DIAGNOSTIC=1 \
  swift test --filter installedCodexCapabilityDiagnostic
```

Observed on macOS 26.5.1 arm64, Xcode 26.6 and Swift 6.3.3:

- GUI/PATH entry: `$HOME/.npm-global/bin/codex`;
- selected canonical executable: the npm package launcher
  `$HOME/.npm-global/lib/node_modules/@openai/codex/bin/codex.js`;
- version: `codex-cli 0.147.0`;
- advertised syntax support: JSONL, output Schema, ephemeral mode, read-only
  sandbox selector, strict config, ignore-user-config, ignore-rules and
  skip-git-repository-check;
- all nine behavior/isolation verdicts remained `unverified`.

The test did not invoke a model, read Codex credentials, or start an Agent
session.

The selected canonical file is the npm JavaScript launcher. The upstream study
separately records the signed arm64 runtime binary that launcher dispatches.
Task 3 does not claim that canonicalizing the launcher authenticates the
downstream runtime supply chain.

## Behavioral Verdicts

The following remain unverified after Task 3:

- effective JSONL event behavior;
- provider/model output Schema compliance;
- absence of session residue;
- effective read-only write denial;
- strict isolation-key acceptance on real `exec` startup;
- complete user/project/global instruction isolation;
- local Probe Broker transport;
- Broker-only tool-surface enforcement.

`--sandbox read-only`, `--ignore-user-config`, `--ignore-rules`, and
`--strict-config` are individual syntax capabilities. They are not a combined
security proof.

## Consequences

Positive:

- the App can discover common user-local Codex installations without shell
  startup behavior;
- unit tests are independent of login/authentication;
- compatibility failures carry typed, fail-closed evidence;
- later Spikes receive a bounded process seam and do not need to parse version
  numbers as policy;
- a Codex update invalidates the session cache.

Costs:

- the known-candidate list is intentionally small and will not discover every
  version manager when GUI `PATH` omits it;
- every cached report lookup still runs the cheap `--version` probe;
- Finder alias resolution and filesystem identity are macOS/Foundation
  contracts that require continued platform tests;
- Task 4 must strengthen direct-process timeout into process-group/descendant
  cancellation.

## Residual Risks and Gates

- A user-controlled executable named `codex` can advertise compatible help.
  Task 3 reports compatibility; it does not establish publisher trust.
- The npm launcher can dispatch a changed downstream native binary without the
  launcher file identity changing. Version output is rechecked, but this is not
  a cryptographic runtime attestation.
- Help output can only establish syntax. Runtime semantics may differ by
  provider, model, config layer or release.
- App-context FDA/TCC inheritance and direct filesystem reads are unmeasured.
- Global instructions, built-in tools, Shell, apply-patch, Plugins, Hooks and
  MCP exposure remain unverified.

Therefore Deep Dive remains paused. Task 4 may proceed with structured process,
JSONL, Schema and cancellation tests. Task 5 must prove Broker-only isolation
or record a no-go; no prompt or help flag may substitute for that evidence.

## Validation

Task 3 is accepted only when all of the following pass:

```text
swift test --filter StornautCodexTests
STORNAUT_RUN_INSTALLED_CODEX_DIAGNOSTIC=1 \
  swift test --filter installedCodexCapabilityDiagnostic
scripts/verify
```

The installed diagnostic remains opt-in so ordinary tests never depend on a
user Codex installation. `scripts/verify` runs the fake/fixture suite and skips
that one diagnostic by default.
