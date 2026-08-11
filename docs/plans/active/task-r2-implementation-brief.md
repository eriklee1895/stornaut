# R2 Implementation Brief: Capability Model and Runtime Profile

> Status: Complete — configurationReady; R3 behavioral gate remains pending
>
> Prepared: 2026-08-11
>
> Baseline: `3aa2defd3416c842b2292fd088c232db910ec18b`
>
> Plan:
> [Capability-First Runtime Gate](capability-first-codex-runtime-gate.md)
>
> R1 evidence:
> [study](../../upstream-studies/epic-5-capability-first-runtime.md),
> [ADR 0013](../../adr/0013-capability-first-runtime-containment.md)

## 1. Approved Transport Boundary

The user approved R2 implementation with this exact transport:

```text
Codex descendants may connect only to a same-investigation,
parent-owned managed proxy on a random loopback port.

All other localhost/private/link-local destinations and every Unix socket
remain OS-blocked.
```

R2 models this exception only as a closed configuration candidate. R3 must
prove it behaviorally before it can contribute containment evidence.

## 2. Purpose

Replace the historical Broker-only process profile with two closed,
version-aware contracts:

1. `CodexRuntimeProfile` — deterministic configuration and argv for the
   approved capability-first candidate;
2. `CodexRuntimeCapabilityReport` — separates advertised/configured evidence
   from behavioral/containment evidence.

R2 proves configuration expression and parser/report correctness without:

- creating production Runtime Home/auth lifecycle;
- claiming shell/browser/network behavior was observed in the signed App;
- enabling Deep Dive;
- changing the Investigation Envelope;
- creating a Probe Broker transport;
- touching Policy, Trash, Registered Actions or Executor.

The user separately authorized real-model diagnostics in R2/R5. R2 prefers
`gpt-5.6-luna`, uses only synthetic content/public endpoints and may record
actual successful tool events as `observed`. A successful model call cannot set
`contained`, prove signed-App inheritance or establish no-Executor reachability.

## 3. Exact File Scope

Create:

```text
Sources/StornautCodex/Runtime/CodexRuntimeProfile.swift
Sources/StornautCodex/Runtime/CodexRuntimeCapability.swift
Sources/StornautCodex/Runtime/CodexRuntimeDiagnostic.swift
Tests/StornautCodexTests/CodexRuntimeProfileTests.swift
Tests/StornautCodexTests/CodexRuntimeDiagnosticTests.swift
Tests/Fixtures/Codex/codex-root-help-0.147.0.txt
Tests/Fixtures/Codex/codex-features-0.147.0.txt
docs/reports/capability-first-runtime-r2-review.md
```

Modify:

```text
Sources/StornautCodex/Runtime/CodexCapability.swift
Sources/StornautCodex/Runtime/CodexProcess.swift
Tests/StornautCodexTests/CodexCapabilityTests.swift
Tests/StornautCodexTests/CodexProcessTests.swift
Tests/StornautCodexTests/InstalledCodexDiagnosticTests.swift
Tests/Fixtures/Codex/codex-exec-help-0.147.0.txt
StornautApp/AppState/AppDependencies.swift
```

Update routing/status documentation and create the R2 review report after
implementation.

Do not modify in R2:

```text
Sources/StornautCodex/Protocol/InvestigationEnvelope.swift
Sources/StornautCodex/Schemas/investigation-envelope.schema.json
Sources/StornautCore/Actions/*
Sources/StornautCore/Policy/*
Sources/StornautCore/Domain/Cleanup*
StornautApp/Diagnostics/*
StornautApp UI copy/views
```

R3 owns Runtime Home/environment/auth/OS containment. R4 owns Investigation
Envelope v2 and no-Executor verification. R5 owns signed-App behavior. R6 owns
product status copy/UI.

## 4. Runtime Profile Contract

### 4.1 Type shape

`CodexRuntimeProfile` is a closed value, not a dictionary supplied by Settings
or the model. It owns:

```text
profile schema/version
Codex version compatibility
root CLI arguments
exec CLI arguments
ordered config overrides
required advertised capabilities
explicitly disabled out-of-scope surfaces
instruction/config-isolation policy
diagnostic-safe summary
```

Only one production candidate exists in R2:

```text
capabilityFirstV1Codex0147
```

No public initializer accepts arbitrary flags, TOML paths, feature names,
domain patterns, executable names or approval policy.

### 4.2 Argument ordering

Codex root options must precede the `exec` subcommand:

```text
--strict-config
--ask-for-approval
never
--search
<ordered root -c overrides>
exec
--ephemeral
--json
--output-schema
<absolute schema path>
--ignore-user-config
--ignore-rules
--skip-git-repo-check
-C
<absolute isolated working directory>
<ordered exec -c overrides if any>
-
```

Tests compare the entire array. They do not use contains-only assertions that
would miss ordering or duplicate flags.

`--ask-for-approval never` is the only approval-policy expression and
`--search` is the only live-search selection. The generated `-c` list does not
also emit `approval_policy` or `web_search`, so root flags and config overrides
cannot drift into contradictory duplicate policy sources.

`--sandbox read-only` is not emitted because the named permission profile is
the canonical filesystem/network contract. Emitting both is rejected as a
contradictory policy source.

### 4.3 Named permission profile

Preferred R2 expression uses CLI config overrides so
`--ignore-user-config` remains effective:

```toml
default_permissions = "stornaut-capability-first-v1"

[permissions.stornaut-capability-first-v1]
extends = ":read-only"

[permissions.stornaut-capability-first-v1.network]
enabled = true
mode = "full"
allow_local_binding = false
dangerously_allow_non_loopback_proxy = false
dangerously_allow_all_unix_sockets = false

[features.network_proxy]
enabled = true
mode = "full"
allow_local_binding = false
dangerously_allow_non_loopback_proxy = false
dangerously_allow_all_unix_sockets = false
domains = { "*" = "allow" }
```

The equivalent CLI override paths use the hyphenated profile identifier as an
ordinary dotted-path segment, without embedding TOML quotes in the key:

```text
-c
default_permissions="stornaut-capability-first-v1"
-c
permissions.stornaut-capability-first-v1.extends=":read-only"
-c
permissions.stornaut-capability-first-v1.network.enabled=true
-c
features.network_proxy.domains={ "*" = "allow" }
```

These are process argument values, not shell fragments. R2 passes each `-c`
value directly to `Process`; it does not add shell quoting or attempt a
`permissions."stornaut-capability-first-v1"` key, because Codex `0.147.0`
splits override keys on `.` and does not implement quoted dotted-key segments.

The public wildcard is intentional here: it removes a public destination
allowlist. It does not bypass the proxy's resolved-address rejection of
non-public targets.

There are no Unix-socket entries, proxy URL overrides, fixed ports, credential
broker, MITM hooks, injected headers or upstream proxy credentials.

R2 must prove that `--ignore-user-config` plus ordered CLI overrides:

- selects the custom profile;
- passes strict config parsing;
- preserves isolated Runtime skills;
- does not load the normal user's config/project trust/plugins/hooks;
- does not load target-project config.

If isolated skills cannot remain discoverable under this strategy, R2 fails
closed and evaluates one fallback only:

```text
load a complete Stornaut-generated config.toml from the isolated Runtime Home,
with no --ignore-user-config
```

That fallback requires:

- exact byte-for-byte generated content;
- mode/owner/path checks delegated to R3;
- no merge with an existing file;
- strict config parsing;
- a digest-safe summary that contains no secret;
- proof that the working directory cannot contribute project config.

R2 may not silently switch strategies.

### 4.4 Required capability settings

Explicit configuration:

```text
--ask-for-approval never
--search
tools.web_search.context_size = high
project_doc_max_bytes = 0
skills.include_instructions = true
skills.bundled.enabled = false
features.shell_tool = true
features.unified_exec = true
features.multi_agent = true
features.image_generation = false
features.apps = false
features.plugins = false
features.remote_plugin = false
features.plugin_sharing = false
features.computer_use = false
orchestrator.skills.enabled = false
orchestrator.mcp.enabled = false
analytics.enabled = false
otel.metrics_exporter = none
```

No `tools.web_search.allowed_domains` value is emitted.

Profile-owned stable feature settings are explicit so a change in upstream
defaults cannot silently remove shell/unified-exec/subagent configuration.
Connector/requirements-backed declarations are not falsely promoted by
re-emitting their current defaults. In particular:

- `browser_use`, external browser and full CDP must be advertised enabled but
  remain unverified; R2 does not claim their desktop/App connector is
  configured;
- `view_image` must be advertised enabled but remains unverified until the R5
  signed-App synthetic-image diagnostic;
- image generation is explicitly disabled because it is not required;
- computer use is out of scope;
- arbitrary plugins, remote-plugin flows, apps and external MCP are explicitly
  disabled;
- Codex `0.147.0` keeps the stable `hooks` feature enabled through its managed
  feature layer even when a user `-c features.hooks=false` override is
  supplied, so R2 does not emit that ineffective override; instead, the
  isolated config stack and plugin exclusions must produce an empty
  `hooks/list` inventory;
- Stornaut-owned Runtime skills remain enabled;
- bundled/system skills are disabled so only the staged Stornaut Runtime skill
  source is eligible;
- orchestrator-owned skills and MCP remain disabled because they are opaque
  external capability sources, not the explicit Stornaut Runtime skill source;
- subagents remain enabled;
- Probe Broker is not represented as an exclusive surface.

Remove the old suppressions that disable:

```text
shell_tool
unified_exec
browser_use
browser_use_external
browser_use_full_cdp_access
multi-agent/collaboration context
```

Retain the explicit image-generation suppression. R2 enables the required
image-inspection surface and leaves generation outside the disk-investigation
contract. Retain the orchestrator skills/MCP suppressions while exposing the
Stornaut-staged Runtime skill through the isolated `CODEX_HOME`.

### 4.5 Instruction isolation

Retain:

- isolated absolute `CODEX_HOME`;
- an empty anonymous `HOME` distinct from the user's real home;
- absent/zero-byte global instruction preflight;
- `project_doc_max_bytes=0`;
- `--ignore-rules`;
- isolated non-project working directory;
- `--skip-git-repo-check`.

R2 test fixtures place canaries in:

```text
normal user config
normal user AGENTS.md
target AGENTS.md
target .codex/config.toml
isolated Runtime skill
```

No-model prompt-input/config canaries must show only the isolated Runtime skill
metadata is available. The actual target files remain directly readable as
evidence in later runtime behavior; they are simply not instruction providers.

`--ignore-user-config` replaces the config layer, but Codex `0.147.0` still
derives skill roots from `$CODEX_HOME/skills`, `$HOME/.agents/skills` and
`.agents/skills` between the selected working directory and its detected
project root. Therefore R2 must not claim that flag alone isolates skills:

- `CODEX_HOME` contains only the staged Stornaut Runtime skill;
- bundled/system skills are disabled;
- `HOME` points to an empty anonymous directory, not the user's real home;
- the selected working directory is an empty, Stornaut-owned non-project
  directory with no `.agents/skills`;
- the user-selected target is never the Codex working directory.

R2 diagnostics emulate these environment/path preconditions. R3 owns their
production creation, owner/mode checks and cleanup. If a future installed Codex
still discovers any normal-user or target skill under those preconditions, the
candidate fails closed.

The checks are deliberately split: the strict parser canary validates the
generated override list, while the prompt-input canary validates model-visible
instruction and skill composition. Codex `0.147.0` rejects root
`--strict-config` for `features` and `debug`, so neither command may be
misrepresented as the strict parser gate.

## 5. Capability Evidence Model

### 5.1 Required capability IDs

`CodexRuntimeCapability` is a closed `CaseIterable` enum:

```text
structuredJSONL
outputSchema
ephemeralSession
strictConfiguration
isolatedUserConfiguration
ignoredExecRules
isolatedHookInventory
directRead
shell
unifiedExec
liveSearch
highContextSearch
publicCommandNetwork
managedNetworkProxy
browserOrDirectFetch
imageInspection
runtimeSkills
subagents
optionalProbeBroker
userDataWriteDenial
privateNetworkDenial
unixSocketDenial
noExecutorReachability
```

Broker-only is not a current capability. Historical evidence remains in docs
and historical fixtures, not the current enum.

### 5.2 Evidence dimensions

Avoid one ordinal status that treats all capabilities identically. A capability
entry contains independent evidence flags:

```text
advertised
configured
observed
contained
```

and one outcome:

```text
supported
unsupported(reasonKey)
degraded(reasonKey)
failed(reasonKey)
unverified(reasonKey)
```

Rules:

- help/features output can set `advertised` only;
- generated-profile validation can set `configured`;
- R2 may set `observed` only from a successful synthetic real-model JSONL tool
  event explicitly authorized by the user; model self-report is insufficient;
- R2 cannot set `contained` for Agent behavior;
- existing Task 4 protocol tests may contribute observed structured
  JSONL/schema/process lifecycle evidence only when explicitly mapped;
- R1 probe evidence is not silently loaded from a prose report into production
  status;
- R5 signed-App report is the future source for observed/contained behavior;
- missing the capability-specific minimum R2 evidence below blocks the
  candidate;
- browser feature declarations remain advertised/unverified;
- `unsupported` differs from `unverified`;
- containment violation is `failed`, never degraded.

Reason keys are bounded enum/string constants suitable for localization later;
raw help output, command output and private paths are not stored in the report.

### 5.3 Minimum R2 evidence by capability class

`configurationReady` does not require every product capability to be
`configured`; that would falsely treat connector-backed and behavioral
capabilities as CLI profile settings.

| Capability class | Examples | Minimum R2 evidence | R2 outcome |
| --- | --- | --- | --- |
| Process/protocol syntax | structured JSONL, output schema, ephemeral, ignore flags | exact help parsing plus deterministic argv | supported or blocked |
| Profile-owned configuration | permission profile, shell, unified exec, live/high-context search, multi-agent, network proxy | advertised where applicable plus strict profile parse and expected effective state | supported or blocked |
| Isolation configuration | user/project instructions, Runtime skills, hooks, plugins/apps/orchestrator sources | strict profile parse plus prompt-input/hook inventory canaries | supported or blocked |
| Connector/default-backed declaration | Browser Use, external/full CDP, view-image | exact advertised enabled declaration with no suppressing override | unverified, not blocked |
| Behavioral capability | direct read, public command network, browser/direct fetch, image inspection, subagent execution | configuration/declaration provenance only | unverified until R5 |
| Containment property | write denial, private-network denial, Unix-socket denial, no Executor | intended profile provenance only | unverified until R5 |
| Optional source | Probe Broker | absence does not block R2 | unverified/optional |

An advertised connector declaration that disappears or becomes disabled blocks
R2 as unsupported. Its presence permits `configurationReady` but never
`supported` behavior. Likewise, strict parsing of a containment profile permits
configuration readiness but cannot set `contained`.

### 5.4 Report layers

`CodexRuntimeCapabilityReport` includes:

```text
executable identity
version
profile schema/version
advertised capability entries
configuration validation result
required missing capabilities
degraded capability IDs
gate readiness
```

R2 gate readiness has only:

```text
configurationReady
configurationBlocked
```

It never says Deep Dive safe/ready. Runtime behavior admission remains R5/R6.

The existing Settings `syntaxStatus` becomes a compatibility projection from
R2's required advertised/configured entries. It does not inspect
`brokerOnlyToolSurface` and does not claim runtime safety.

## 6. Detector Inputs

The no-model detector executes fixed commands only:

```text
codex --version
codex --help
codex exec --help
codex <ordered profile overrides> features list
```

The existing `ProcessRunning` abstraction remains the one-shot runner for
version/help/features/prompt-input. It is not expanded into a generic
interactive process API.

`CodexRuntimeDiagnostic` owns one closed interactive operation:

```text
validateConfigurationAndHookInventory(profile, executable, isolated paths)
```

Its production implementation may drive only the fixed app-server
initialize/initialized/hooks-list/EOF sequence below. It has no public method
for arbitrary JSON-RPC method names, params, stdin bytes, ports or transports,
and it is not used by production `CodexProcess.run`. Every diagnostic process
also sets its OS current directory to the same empty isolated non-project
workdir; passing that path only as a CLI/RPC parameter is insufficient because
startup config discovery may occur before the request is handled.

The feature probe provides advertised stage plus effective enabled state for
the exact closed profile. It does not validate strict parsing by itself,
because Codex `0.147.0` rejects:

```text
Error: `--strict-config` is not supported for `codex features`
```

An effective feature state contributes `configured` evidence only when the
strict probe succeeds for the same profile digest. The detector requires the
expected true/false state for every explicit feature override except `hooks`;
that upstream-managed feature remains true and is admitted only when the
effective hook inventory is empty. Browser and view-image declarations must
remain advertised enabled, but their feature-list state does not satisfy
behavioral or connector configuration evidence.

The installed no-model diagnostic uses four fixed, separate probes against an
anonymous disposable `CODEX_HOME`:

```text
codex --strict-config <ordered profile overrides> app-server --stdio
  stdin: initialize → initialized → hooks/list(<isolated workdir>) → EOF

codex <ordered profile overrides> features list

codex -C <isolated non-project workdir> <ordered profile overrides>
  debug prompt-input

codex --strict-config <root flags + ordered profile overrides> exec
  --ignore-user-config --output-schema <intentionally invalid synthetic schema>
  -C <isolated non-project workdir> -
```

`app-server` is diagnostic-only here. The production Stornaut launch path
remains `codex exec`; R2 does not start or depend on app-server at runtime. A
future Probe Broker may expose a Stornaut-owned read-only transport to
`codex exec`, which is a separate role.

The first process loads the complete config through
`ConfigBuilder.strict_config(true)` before serving stdio. The detector performs
only the fixed initialization handshake and read-only `hooks/list` request,
requires one entry for the isolated workdir with empty `hooks`, `warnings` and
`errors`, then closes stdin and requires a clean exit. It does not start a
thread or call a model. Companion negative canaries append one unknown root key
and one unknown feature key and must both fail with the bounded strict-config
error before protocol initialization.

The third process must not use `--strict-config`; Codex rejects that
combination. It renders model-visible input only and must prove:

- the normal user config/global instructions are absent;
- target `AGENTS.md` and target project config canaries are absent;
- the isolated Stornaut Runtime skill name/description is present;
- bundled, normal-user, working-directory and target skill canaries are absent;
- no normal user-home path is rendered.

The fourth process proves the production `exec --ignore-user-config` loader
path directly without calling a model. The disposable `CODEX_HOME/config.toml`
contains invalid TOML and stdin contains only a synthetic prompt. With
`--ignore-user-config`, startup must pass config loading and stop at the
intentionally invalid output schema. The negative control omits
`--ignore-user-config` and must fail on the invalid user config before reaching
the schema failpoint.

All four probes consume the exact ordered override array from the same closed
`CodexRuntimeProfile` value. The detector records and compares one
secret-free profile digest; it must not reconstruct a second, similar-looking
configuration for prompt-input.

`codex --strict-config ... doctor --json` is not a substitute. The `0.147.0`
dispatcher accepts the flag, and `checks["config.load"]` is useful redacted
observability, but `doctor` does not pass root `strict_config` into its
`ConfigBuilder`. A measured unknown-key canary therefore reports
`config.load.status = ok`; R2 must not treat its overall exit code or that row
as strict validation.

The strict canary must:

- parse the generated named profile and every override;
- avoid auth/model calls;
- avoid writing outside the disposable home;
- permit only Codex-internal state/bootstrap writes inside that home;
- launch with the isolated workdir as the process current directory;
- return an empty hook inventory for the isolated workdir;
- have bounded stdout/stderr/time;
- reject unknown keys;
- report nonzero/truncation/invalid UTF-8 separately;
- use no shell.

The diagnostic always removes the disposable home. Its expected internal
writes include SQLite state files, an installation identifier and system-skill
bootstrap metadata; their presence is not evidence of permission to write the
investigation scope. R3 still owns the production Runtime Home write boundary.

Cache keys include executable device/inode/size/mtime, version, and the profile
schema/version. A changed feature output or profile version invalidates cache.

## 7. Tests First

### 7.1 Runtime profile tests

Write failing tests before production types:

1. exact root/exec argument ordering;
2. exactly one `never` approval selection;
3. exactly one live-search selection;
4. no duplicate `approval_policy`/`web_search` config override;
5. high context with no search-domain list;
6. custom profile extends `:read-only`;
7. profile override key uses the plain hyphenated segment;
8. network enabled only with managed proxy enabled;
9. public wildcard inline table present exactly once;
10. local binding false in both profile and proxy config;
11. no Unix-socket entry and both dangerous proxy/socket switches explicitly
    false;
12. no fixed proxy port/URL;
13. no `danger-full-access`;
14. no `--add-dir`;
15. shell/unified exec/multi-agent enabled;
16. Browser Use/external/full-CDP and view-image advertised enabled, with no
    profile override that falsely claims connector configuration;
17. Runtime skills enabled;
18. bundled skills and image generation disabled;
19. plugins/remote plugins/plugin sharing/apps/computer-use/external MCP
    disabled;
20. orchestrator skills/MCP disabled while the staged Runtime skill remains
    visible;
21. no ineffective `features.hooks=false` override;
22. project docs/rules isolated;
23. stable deterministic output;
24. NUL/newline/path injection rejected;
25. non-file/relative schema or working directory rejected by existing request
    validation;
26. future/unsupported profile version fails closed.

### 7.2 Capability parser tests

Add generated fixtures for root help and feature list, then test:

- option declaration must be in an option block, not prose;
- root `--search` and `--ask-for-approval` parsed independently;
- exec structured flags parsed independently;
- duplicate contradictory declarations fail closed;
- feature line parser requires exact name/stage/boolean columns;
- stable enabled shell/unified exec/multi-agent/view-image recognized;
- browser stable enabled is advertised, not observed;
- experimental network proxy is advertised with an explicit experimental
  reason;
- removed feature is not supported;
- malformed/duplicate feature lines fail closed;
- unknown future feature lines are ignored within output bounds;
- current report contains no Broker-only capability;
- all behavior remains unverified unless mapped to existing protocol evidence.

### 7.3 Configuration canary tests

Use a fake process runner first:

- fixed probe command ordering;
- fixed app-server initialize/initialized/hooks-list/EOF sequence;
- every one-shot and interactive diagnostic process uses the isolated workdir
  as its process current directory;
- fixed production-exec ignore-user-config positive/negative failpoints stop
  before model initialization;
- the closed diagnostic session rejects unexpected response IDs, methods,
  duplicate initialize responses, malformed JSONL and out-of-order messages;
- no generic JSON-RPC request API is exposed;
- bounded environment;
- API/GitHub/cloud credentials absent;
- output/time/error bounds;
- executable identity rechecked between commands;
- cache invalidation on version/profile/feature-output change;
- strict positive canary requires zero;
- unknown root and feature keys require nonzero;
- nonempty hook inventory, warnings or errors block configuration;
- production `exec --ignore-user-config` must bypass invalid user config while
  the negative control fails on it;
- `doctor` output cannot satisfy strict validation;
- prompt-input and strict-parser evidence cannot be conflated;
- all four probes receive the same profile version, ordered overrides and
  secret-free digest.

Then add one opt-in installed no-model diagnostic that:

- creates an anonymous isolated home;
- validates the generated profile with the strict app-server canary;
- verifies both strict negative canaries fail closed;
- verifies `hooks/list` returns an empty inventory without warnings/errors;
- verifies the production `exec --ignore-user-config` path with the synthetic
  output-schema failpoint and its no-ignore negative control;
- separately verifies target/project instruction canaries are absent through
  `debug prompt-input`;
- separately verifies isolated skill metadata is present;
- verifies bundled, normal-user, working-directory and target skill canaries
  are absent under the isolated `HOME`/`CODEX_HOME`/cwd preconditions;
- verifies no normal user home path/config appears;
- bounds and inventories Codex-internal writes inside the disposable home;
- deletes the home;
- never reads or copies auth.

### 7.4 Process regression tests

Migrate `CodexProcessTests` to require the typed profile and assert:

- fake process receives exact capability-first arguments;
- prompt remains stdin-only;
- stdout/stderr/JSONL bounds unchanged;
- process group creation/termination unchanged;
- concurrent pipe inheritance regression unchanged;
- environment secret stripping unchanged;
- no cleanup/Executor argument or descriptor appears.

Do not repeat live network behavior in R2; the checked-in R1 probe remains the
separate behavioral evidence.

## 8. Implementation Sequence

After ADR 0013 approval:

1. Create the failing `CodexRuntimeProfileTests`.
2. Create the failing capability fixture/parser tests.
3. Implement the closed capability/profile types.
4. Implement deterministic argument/config generation.
5. Implement the closed app-server diagnostic session and its protocol tests.
6. Expand the detector's fixed no-model probes.
7. Replace `CodexRunRequest.fixedArguments` with profile-owned arguments.
8. Remove legacy Broker-only current behavior.
9. Migrate App syntax compatibility projection.
10. Run focused tests and the installed no-model configuration diagnostic.
11. Review every tracked and new file.
12. Run complete `StornautCodexTests`, full serial `swift test`, docs links and
    diff hygiene.
13. Write R2 review evidence, commit independently and push `origin/main`.

## 9. Review Checklist

Review must inspect:

- root/subcommand argument placement;
- TOML override key segmentation and inline-table quoting, especially the
  hyphenated profile ID and `"*"`;
- duplicate/contradictory policy sources;
- accidental user config/project config loading;
- unsupported `--strict-config` command combinations;
- a `doctor` success row being mistaken for strict validation;
- an ineffective `features.hooks=false` override being treated as hook
  isolation instead of validating the effective inventory;
- capability promoted from help text only;
- experimental network proxy treated as stable;
- browser advertised as observed;
- secret-bearing environment/config/errors;
- public-domain allowlist accidentally introduced;
- local binding or Unix-socket entry accidentally enabled;
- `danger-full-access`/`--add-dir`;
- arbitrary Settings/model input into profile;
- nondeterministic dictionary serialization;
- version/cache drift;
- generic or externally parameterized app-server JSON-RPC exposure;
- process lifecycle regression;
- App syntax status claiming safety.

Confirmed P0–P2 findings are fixed and retested before the R2 commit.

## 10. Verification Gate

R2 completion requires:

```text
focused CodexRuntimeProfile tests pass
focused capability parser/detector tests pass
existing process/protocol tests pass
installed no-model strict-config diagnostic passes
complete StornautCodexTests pass
full serial swift test passes
scripts/check-doc-links passes
git diff --check passes
review has zero unresolved P0–P2
HEAD == origin/main after independent push
```

R2 may conclude only **configurationReady**. It does not enable Deep Dive,
close ADR 0013, or start R3 automatically.

Final evidence:
[Capability-First Runtime R2 Review](../../reports/capability-first-runtime-r2-review.md).

## 11. Decision Branch

### If dedicated loopback proxy is approved

- Amend ADR 0013 status to “Accepted for R2 configuration candidate; R3
  behavioral gate pending”.
- Start tests-first R2 in the sequence above.

### If dedicated loopback proxy is rejected

- Mark ADR 0013 `Rejected` for Codex `0.147.0`.
- Do not implement this profile.
- Update the roadmap to continue deterministic product work or authorize a
  separate XPC/App Sandbox study.
