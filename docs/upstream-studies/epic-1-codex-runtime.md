# Epic 1 Codex Runtime Upstream Study

> 状态：Accepted as the study gate for Epic 1 Tasks 3–5
>
> 日期：2026-08-09
>
> Coding Agent：TRAE CLI
>
> 目标模块：Codex discovery、capability report、structured process、cancellation、instruction/tool isolation、Probe Broker transport

> **2026-08-11 product-policy note:** This study preserves the measured
> Broker-only failure and strict-profile evidence. It no longer defines the
> product restriction. The amended
> [ADR 0004](../adr/0004-codex-file-read-isolation.md) deliberately allows
> direct read, Agent tools and live public internet, with OS write denial and
> Swift-only execution as the hard boundary.

## 1. Executive Conclusion

The installed Codex CLI `0.147.0` exposes the process and output primitives
needed for the next spikes:

- non-interactive `exec`;
- JSONL output through `--json`;
- final-response schema through `--output-schema`;
- ephemeral session storage through `--ephemeral`;
- read-only sandbox selection;
- user config and exec-policy rule isolation flags;
- strict config parsing;
- local MCP configuration with per-server tool allowlists;
- interrupt handling and process-group-aware termination in lower process layers.

These capabilities do **not** establish Stornaut's Deep Dive boundary.

In particular:

1. `--sandbox read-only` prevents writes but explicitly retains read access.
2. `--ignore-user-config` empties the user `config.toml` layer; it does not
   disable managed/system/project layers, built-in tools, or all instruction
   providers.
3. `--ignore-rules` skips user/project execpolicy `.rules`; it does not disable
   Shell.
4. Codex separately loads global instructions from `$CODEX_HOME/AGENTS.md` or
   `AGENTS.override.md`.
5. Project `AGENTS.md` loading can be disabled with
   `project_doc_max_bytes=0`, but that does not suppress global instructions.
6. Shell can be disabled with `features.shell_tool=false`, and Skills prompt
   injection with `skills.include_instructions=false`, but no single CLI flag
   proves that Probe Broker is the only remaining callable tool.
7. `apply_patch` and other core tools are assembled from model metadata,
   environment availability and feature state independently of MCP allowlists.
8. The installed user environment currently contains MCP servers, plugins,
   hooks, global instructions and many stable built-in capabilities. It is not
   a safe Deep Dive runtime configuration.

Therefore:

- Task 3 may implement discovery and an evidence-bearing capability report.
- Flag presence may mark only syntactic flag support.
- Instruction isolation, local Probe transport and Broker-only enforcement
  remain `unverified` until Tasks 4–5 execute behavioral tests.
- Deep Dive remains paused. Discovery of Codex `0.147.0` is not a safety pass.

## 2. Execution-Time Environment

| Item | Observed value |
| --- | --- |
| Date | 2026-08-09 |
| macOS | 26.5.1, Build 25F80 |
| Architecture | arm64 |
| Xcode | 26.6, Build 17F113 |
| Swift | 6.3.3 |
| PATH entry | `/Users/eriklee/.npm-global/bin/codex` |
| PATH entry type | symlink to the npm launcher `@openai/codex/bin/codex.js` |
| Installed package | `@openai/codex@0.147.0` |
| Runtime binary | signed arm64 Mach-O inside `@openai/codex-darwin-arm64` |
| Runtime binary SHA-256 | `19c4f144c5226a9f17c58e6f0fa854843b0f77a6eb420f40e2745a12f10f5d37` |
| Signing identity | `Developer ID Application: OpenAI OpCo, LLC (2DC432GLL2)` |
| Runtime Team ID | `2DC432GLL2` |
| Authentication state | configured ChatGPT auth; no Agent session was started |

The PATH and package locations are execution evidence, not permanent search
constants. The locator must not hard-code this user's home path.

### Execution-time command evidence

```text
codex --version
codex exec --help
codex features list
codex doctor --json
codex mcp list
codex plugin list
codex debug prompt-input
```

Observed version:

```text
codex-cli 0.147.0
```

Observed `exec --help` SHA-256:

```text
444f5b0c9ccbf961a3ba12ad3099074106b5ff757df854dd718f93b4dcd3a174
```

Observed supported flags include:

```text
--strict-config
--sandbox
--skip-git-repo-check
--ephemeral
--ignore-user-config
--ignore-rules
--output-schema
--json
```

Task 3 will check in the execution-time help output as a parser fixture. The
existing plan's `0.146.0` fixture remains historical evidence and must not be
treated as the installed version.

## 3. Official Upstream Snapshot

| Source | Version / commit | License | Evidence read |
| --- | --- | --- | --- |
| [OpenAI Codex](https://github.com/openai/codex) | tag `rust-v0.147.0`; commit `be6e8eac029b183056b7e4402879f15d2c85f61b` | Apache-2.0 | release notes, `README.md`, files below |
| npm package | `@openai/codex@0.147.0`; integrity `sha512-EQLEXecAG2ptxI7UpBMo2TR/ga5596/c/OsYF/0LoUDh5JANZ7IoGqlzBEWbuEVQ76JePIbtTW/ihCkp1a7Z3w==` | Apache-2.0 | package metadata and platform package layout |
| [Non-interactive mode](https://developers.openai.com/codex/noninteractive) | execution-time official docs | OpenAI documentation terms | `exec`, JSONL, schema, automation |
| [Configuration basics](https://developers.openai.com/codex/config-basic) | execution-time official docs | OpenAI documentation terms | base config and CLI overrides |
| [Advanced configuration](https://developers.openai.com/codex/config-advanced) | execution-time official docs | OpenAI documentation terms | profiles, layers, metrics |
| [Configuration reference](https://developers.openai.com/codex/config-reference) | execution-time official docs | OpenAI documentation terms | settings and MCP shape |
| [Security](https://developers.openai.com/codex/security) | execution-time official docs | OpenAI documentation terms | sandbox and approvals |
| [AGENTS.md guide](https://developers.openai.com/codex/guides/agents-md) | execution-time official docs | OpenAI documentation terms | project instructions |
| [Exec policy](https://developers.openai.com/codex/exec-policy) | execution-time official docs | OpenAI documentation terms | `.rules` behavior |

### Source files read

- `codex-rs/exec/src/cli.rs`
- `codex-rs/exec/src/lib.rs`
- `codex-rs/exec/src/event_processor_with_jsonl_output.rs`
- `codex-rs/exec/src/exec_events.rs`
- `codex-rs/config/src/loader/mod.rs`
- `codex-rs/config/src/state.rs`
- `codex-rs/config/src/config_toml.rs`
- `codex-rs/config/src/mcp_types.rs`
- `codex-rs/config/src/strict_config.rs`
- `codex-rs/core/src/agents_md.rs`
- `codex-rs/codex-home/src/instructions/mod.rs`
- `codex-rs/core/src/config/mod.rs`
- `codex-rs/core/src/tools/spec_plan.rs`
- `codex-rs/tools/src/tool_config.rs`
- `codex-rs/core/src/prompt_debug.rs`
- `codex-rs/core/src/session/session.rs`
- `codex-rs/app-server/src/message_processor.rs`
- `codex-rs/app-server-client/src/lib.rs`
- `codex-rs/utils/pty/src/pipe.rs`
- `codex-rs/utils/pty/src/pty.rs`
- relevant tests for config loading, exec policy, tool planning, project docs
  and process-group termination.

Selected source fingerprints:

| File | SHA-256 |
| --- | --- |
| `exec/src/cli.rs` | `c928cbe54c3ad12b09852b53048b5c7cdf66ca089963e029a503893cd880f1b4` |
| `exec/src/lib.rs` | `52d801c747c18524b42552e9da9080aa43e8eeb04b368570bb0bbfc601f613ae` |
| `config/src/loader/mod.rs` | `ef4e31d094943c18a995bbb9c3fd390a145a35fc561a3f74d8cd595d733e7005` |
| `config/src/state.rs` | `d1f9ce744e462898d8d697e096d24d070763ba16dc22a396f39b8c8c6d5caac6` |
| `core/src/agents_md.rs` | `61c0374190f323dd0bb1cfdd1b17b033a1263133921a1021c392d922dbe397bd` |
| `core/src/tools/spec_plan.rs` | `6321bbdb398cdfd6bdec1bbc48bb179a663bf4a6f7d6bff2d418bb08a8944202` |
| `config/src/config_toml.rs` | `52f71bf2e16f5868fbbdf66f73e3a78179149c45f8ac054588619116d57f335a` |

No upstream code is copied into Stornaut.

## 4. Process and Output Contract

### 4.1 JSONL

`codex exec --json` selects `EventProcessorWithJsonOutput`. Upstream documents
and enforces that stdout is JSONL and non-protocol output goes to stderr.

Task 3 may report parsed support for the flag. Task 4 must still test:

- representative event decoding;
- malformed/truncated lines;
- stdout/stderr separation;
- output byte limits;
- unknown event forward compatibility.

### 4.2 Output Schema

`--output-schema <FILE>` reads and parses a JSON file before starting the turn.
The schema is passed in `TurnStartParams.output_schema`.

This proves that Codex accepts a schema input. It does not prove that every
provider/model returns a compliant final object. Task 4 must validate the final
payload again in Swift and fail closed.

### 4.3 Ephemeral mode

`--ephemeral` sets the session's ephemeral state and avoids normal session-file
persistence. Upstream still initializes runtime state, auth and telemetry
subsystems. Stornaut must not equate ephemeral mode with "no local processing"
or "no telemetry."

The candidate launch configuration must include:

```text
-c analytics.enabled=false
-c 'otel.metrics_exporter="none"'
```

and Task 4 must verify supported config keys under `--strict-config`.

### 4.4 Cancellation

The `exec` frontend handles Ctrl-C by sending `turn/interrupt`, later
unsubscribes from the thread and shuts down the in-process app server. Lower
pipe/PTY implementations use process groups and have tests for terminating
background children.

This is useful upstream behavior, not App-context proof. Task 4 must launch a
fake child tree from Stornaut's own process wrapper and verify:

- cooperative interrupt;
- timeout escalation;
- process-group termination;
- no surviving descendants.

## 5. Configuration Layers and Isolation

The effective configuration stack includes:

1. admin / managed requirements;
2. system config;
3. cloud-managed config;
4. user config and optional profile;
5. project/tree/repository `.codex/config.toml`;
6. runtime `-c` overrides.

### `--strict-config`

`--strict-config` makes config files reject unknown fields. It is a parser
safety mechanism, not an isolation mechanism.

Version/help commands can exit before loading effective config, so
`codex exec --strict-config --version` cannot validate isolation overrides.
Task 4 must verify strict config on the actual process startup path.

### `--ignore-user-config`

Source behavior:

- replaces the user `config.toml` layer with an empty layer;
- skips Codex-home configured environments;
- continues to load managed/system/cloud layers;
- continues to consider project config layers;
- still uses `CODEX_HOME` for authentication.

It does not mean "ignore everything in CODEX_HOME."

### `--ignore-rules`

Source behavior:

- marks user and project execpolicy rule files as ignored.

It does not disable Shell. In fact, `--ignore-user-config` without
`--ignore-rules` intentionally keeps user policy files, so the two flags must
be treated as separate capabilities.

### Project instructions

Project `AGENTS.md` / `AGENTS.override.md` discovery is independent of
`--ignore-user-config`. `project_doc_max_bytes=0` disables project-doc loading
in source and tests.

### Global instructions

Codex creates a `CodexHomeUserInstructionsProvider` rooted at `CODEX_HOME`,
which loads `AGENTS.override.md` or `AGENTS.md`. There is no corresponding
`codex exec --ignore-user-instructions` flag in `0.147.0`.

This creates an unresolved product constraint:

- using the user's real `CODEX_HOME` preserves ChatGPT auth but can load global
  instructions;
- using a fresh isolated `CODEX_HOME` removes those instructions but also
  changes where Codex looks for auth.

Task 5 must establish a credential-safe isolated-home strategy. Stornaut must
not copy, persist, mutate or symlink user credentials without a separate
security decision and tests.

## 6. Tool Surface

### Shell

Shell is a stable feature enabled by default. Tool assembly calls
`add_shell_tools`; setting `features.shell_tool=false` resolves the shell type
to `Disabled`.

This is a promising candidate control. It still requires behavioral proof under
the installed model catalog and strict startup path.

### MCP and Probe Broker

Codex MCP configuration supports:

- an explicit server list;
- server enabled/required state;
- `enabled_tools` / `disabled_tools`;
- per-tool policy;
- timeouts and approval modes.

Stornaut can therefore inject one local Probe Broker server with an exact
allowlist. This constrains that MCP server, not the complete Codex tool registry.

### Plugins, Apps, Skills and Hooks

Relevant candidate overrides include:

```text
features.plugins=false
features.apps=false
features.hooks=false
features.computer_use=false
features.browser_use=false
features.browser_use_external=false
features.browser_use_full_cdp_access=false
features.image_generation=false
skills.include_instructions=false
skills.bundled.enabled=false
orchestrator.skills.enabled=false
orchestrator.mcp.enabled=false
```

An execution-time `codex debug prompt-input` diagnostic, which does not invoke a
model, showed:

- default configuration included a Skills instruction catalog;
- partial overrides still included Skills;
- adding `skills.include_instructions=false`, disabling bundled Skills and
  suppressing environment/permission/app/collaboration instruction blocks
  reduced the model-visible input to the explicit user prompt in that
  diagnostic.

`debug prompt-input` does not accept the `exec --ignore-user-config` flag and
does not prove the callable runtime tool registry. It is evidence for candidate
prompt isolation only.

### Core-tool residual risk

`apply_patch` is registered when the selected model metadata advertises it and a
local environment exists. It is not controlled by an MCP allowlist. A read-only
sandbox should reject its writes, but the tool may still be model-visible.

There is no public `codex exec --only-tools <ProbeBroker>` flag in `0.147.0`.
Broker-only enforcement therefore remains unverified even if Shell, external
MCP, Plugins, Apps, Skills and Hooks are disabled.

## 7. Read-Only Sandbox

Upstream tests describe the read-only profile as:

- reads allowed;
- writes denied;
- network restricted according to the effective profile.

This matches Stornaut's existing architecture warning: read-only is a write
boundary, not a confidentiality boundary. It does not prevent direct reads of
paths available to the child process or inherited App permissions.

Task 5 must use synthetic canaries to determine:

- working-directory direct read;
- Broker-root direct read;
- non-sensitive sibling direct read;
- App-context FDA/TCC inheritance;
- behavior with Shell disabled;
- whether any non-Broker file-read mechanism remains.

No real private file may be used as a canary.

## 8. Candidate Fail-Closed Launch Profile

This is a hypothesis for Tasks 4–5, not an approved production command:

```text
codex exec
  --strict-config
  --ignore-user-config
  --ignore-rules
  --ephemeral
  --json
  --output-schema <schema>
  --sandbox read-only
  --skip-git-repo-check
  -C <isolated-workdir>
  -c project_doc_max_bytes=0
  -c skills.include_instructions=false
  -c skills.bundled.enabled=false
  -c include_environment_context=false
  -c include_permissions_instructions=false
  -c include_apps_instructions=false
  -c include_collaboration_mode_instructions=false
  -c analytics.enabled=false
  -c 'otel.metrics_exporter="none"'
  -c features.shell_tool=false
  -c features.unified_exec=false
  -c features.hooks=false
  -c features.plugins=false
  -c features.apps=false
  -c features.computer_use=false
  -c features.browser_use=false
  -c features.browser_use_external=false
  -c features.browser_use_full_cdp_access=false
  -c features.image_generation=false
  -c orchestrator.skills.enabled=false
  -c orchestrator.mcp.enabled=false
  -c <exact local Probe Broker MCP config>
```

Before use, Task 4 must prove that every config key is accepted on the actual
`exec --strict-config` startup path. Task 5 must prove the resulting tool and
instruction surfaces. Unknown or rejected controls are a no-go, not a reason to
drop `--strict-config`.

## 9. Task 3 Implementation Brief

### Locator

Use direct Swift filesystem APIs only:

1. explicit configured executable;
2. sanitized GUI `PATH` entries;
3. a bounded list of user-local conventional candidates.

Requirements:

- never launch a login shell;
- never source dotfiles;
- require an executable regular file;
- resolve symlinks and standardize the URL;
- reject directories and broken aliases;
- preserve evidence about which source won without persisting private path
  inventories.

The installed npm launcher demonstrates why symlink canonicalization is
required.

### Capability probing

Run only:

```text
<codex> --version
<codex> exec --help
```

Use an injectable `ProcessRunning` abstraction with:

- fixed arguments;
- sanitized environment;
- stdout/stderr byte limits;
- timeout;
- no shell;
- no login requirement;
- no Agent session.

Parse capability support from help text, not from version equality.

### Verdict model

Syntactic flag evidence may mark:

- JSONL flag support;
- output Schema flag support;
- ephemeral flag support;
- read-only sandbox selector support;
- ignore-user-config, ignore-rules and strict-config flag support.

The following stay `unverified(reason:)` in Task 3:

- effective structured JSONL behavior;
- provider/model schema compliance;
- no session persistence beyond the documented flag;
- effective read-only write denial;
- all instruction-source isolation;
- local Probe transport;
- Broker-only tool-surface enforcement.

Malformed or contradictory help output is `unsupported(reason:)`, never an
optimistic default.

Cache the report only for the current App session and invalidate it if the
canonical executable identity or version output changes.

## 10. Tests and Fixtures

Task 3:

- locator precedence and canonicalization;
- missing, directory, non-executable and broken-symlink candidates;
- bounded PATH parsing;
- process output truncation and failures;
- historical `0.146.0` help fixture;
- execution-time `0.147.0` version/help fixtures;
- malformed help;
- flags parsed independently;
- all behavioral isolation verdicts remain unverified.

Tasks 4–5:

- JSONL success/malformed/truncation;
- schema mismatch;
- ephemeral residue audit;
- strict config rejection;
- Ctrl-C/timeout/descendant termination;
- prompt-input and actual tool-catalog canaries;
- global/project instruction canaries;
- Shell/apply-patch/external-tool absence;
- Broker-only requests;
- direct-read canaries and App-context FDA inheritance.

## 11. License and Reuse Boundary

- Codex is Apache-2.0.
- Stornaut invokes the user's installation and does not bundle Codex.
- This study uses public behavior, interfaces, source facts and test ideas.
- No Codex source is copied into Stornaut.
- Any future copied fixture must be generated command output or independently
  authored test data, not copied implementation code.

## 12. Gate Decision

**Task 3 discovery/capability implementation: GO.**

**Task 4 structured process/cancellation spike: GO, with strict fail-closed
configuration validation.**

**Deep Dive / Task 5 security boundary: still PAUSED / NO-GO until behavioral
proof.**

No observed fact authorizes:

- direct Codex filesystem investigation;
- arbitrary Shell;
- inherited repository or target-disk instructions;
- user credential copying;
- App FDA claims;
- Broker-only safety claims.
