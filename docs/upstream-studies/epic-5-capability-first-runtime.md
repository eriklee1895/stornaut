# Epic 5 Capability-First Codex Runtime Upstream Study

> Status: Accepted for R1 evidence — conditional runtime candidate only
>
> Date: 2026-08-11
>
> Baseline: `549ece3282a7909f085c62a1c036f6172397a9e5`
>
> Decision: [ADR 0013](../adr/0013-capability-first-runtime-containment.md)

## 1. Question

The amended ADR 0004 requires one combination:

```text
direct read + shell/unified exec + live public investigation
+ image + skills + subagents
+ public command/browser network
+ no user-data writes
+ no local/private network or arbitrary Unix socket
+ no Executor route
```

This study asks whether installed Codex `0.147.0` and current macOS can provide
that combination without:

- `danger-full-access`;
- an executable or public-domain allowlist;
- per-command approvals;
- disabling required Agent capabilities;
- relying only on prompts or shell wrappers for containment.

R1 is an architecture/evidence task. It does not modify the production
`CodexProcess`, call a real model, copy credentials or enable Deep Dive.

## 2. Environment

| Item | Observed |
| --- | --- |
| Date | 2026-08-11 |
| macOS | 26.5.1, build 25F80 |
| Architecture | arm64 |
| Xcode | 26.6, build 17F113 |
| Swift | 6.3.3 |
| Installed launcher | `/Users/eriklee/.npm-global/bin/codex` |
| Codex | `codex-cli 0.147.0` |
| npm package | `@openai/codex@0.147.0` |
| Vendor binary | Mach-O arm64 |
| Vendor binary signature | Developer ID Application: OpenAI OpCo, LLC (`2DC432GLL2`) |
| App Sandbox | Stornaut currently disabled |
| Hardened Runtime | Stornaut currently disabled |
| Git baseline | `HEAD == origin/main == 549ece3...` before R1 changes |

Installed hashes:

```text
launcher codex.js:
134063e133f0b4244fa3b251acf973d4fe4b4aeeacbdc135211bf480f59f1477

vendor arm64 codex:
19c4f144c5226a9f17c58e6f0fa854843b0f77a6eb420f40e2745a12f10f5d37
```

The Node launcher selects `@openai/codex-darwin-arm64` on this host and spawns
the vendor binary with inherited stdio and environment. Stornaut may continue
to locate the user-facing launcher, but containment claims must be tested
against the actual vendor process tree.

## 3. Upstream Snapshot

| Source | Version/commit | License | Inspected material |
| --- | --- | --- | --- |
| OpenAI Codex | tag `rust-v0.147.0`, commit `be6e8eac029b183056b7e4402879f15d2c85f61b` | Apache-2.0 | CLI help, feature registry, config schema, permission profiles, Seatbelt generator, network proxy, exec loader, skills, subagents, auth |
| npm `@openai/codex` | `0.147.0` | Apache-2.0 | launcher and Darwin arm64 package layout |
| Apple Security docs | current 2026 documentation | Apple documentation terms | App Sandbox overview and file-access model |
| macOS SDK/manpages | macOS 26.5 SDK | Apple SDK terms | `sandbox.h`, `sandbox-exec(1)`, `sandbox_init(3)` |

Primary Codex files:

```text
codex-rs/protocol/src/permissions.rs
codex-rs/protocol/src/models.rs
codex-rs/protocol/src/protocol.rs
codex-rs/config/src/permissions_toml.rs
codex-rs/core/src/config/permissions.rs
codex-rs/core/src/config/mod.rs
codex-rs/core/config.schema.json
codex-rs/sandboxing/src/manager.rs
codex-rs/sandboxing/src/seatbelt.rs
codex-rs/sandboxing/src/seatbelt_base_policy.sbpl
codex-rs/sandboxing/src/seatbelt_network_policy.sbpl
codex-rs/network-proxy/README.md
codex-rs/network-proxy/src/config.rs
codex-rs/network-proxy/src/policy.rs
codex-rs/network-proxy/src/connect_policy.rs
codex-rs/core/src/tools/handlers/multi_agents.rs
codex-rs/core/src/tools/handlers/multi_agents_tests.rs
codex-rs/core/src/agents_md.rs
codex-rs/core/src/agents_md_tests.rs
codex-rs/exec/src/lib.rs
```

Selected source hashes:

```text
seatbelt.rs
b8d4b0b8b375516784b5b51797d7c5db69810f223430e1756e63889dce9f4df5

seatbelt_base_policy.sbpl
9a7a181ac5fab3e8fcecfeeec280f8b0d4fd60c852cf71cdf3b5c65d02401e0c

connect_policy.rs
4fe5ca899c38b425ed6a78a51b372da92e75a69dc7f2c939c19b0cee4622b83b

network policy.rs
2f8183c75e455821a86d3cd20995e6a8a22120b59f9e860594835989fb100a45

permissions.rs
f80bc0ca59d2a5847c67a21ad0780fe82ed94d2bd8d1685dd4bec7dfdc022ea3

config.schema.json
b9105f17442d5c41ba5d4d82603259d3cc0ceb38aeb3badf9e5ca20da328ae6e
```

No upstream source is copied into Stornaut. The R1 probe independently invokes
the installed CLI as a black-box diagnostic.

## 4. Codex Permission Model

### 4.1 Filesystem and network are separate

`0.147.0` has a canonical `PermissionProfile` with independent:

- `FileSystemSandboxPolicy`;
- `NetworkSandboxPolicy`.

A named permission profile may extend `:read-only` and set:

```toml
[permissions.stornaut.network]
enabled = true
```

Upstream test
`default_permissions_profile_can_extend_builtin_read_only` verifies that this
keeps full read access, no filesystem writes and enabled network.

This is materially better than the old Stornaut assumption that only
`sandbox_mode` could select the boundary.

### 4.2 macOS enforcement is Codex-generated Seatbelt

On macOS, the sandbox manager constructs a policy and executes:

```text
/usr/bin/sandbox-exec -p <generated policy> ...
```

The base policy:

- starts with `(deny default)`;
- allows `process-exec` and `process-fork`;
- states that descendants inherit the parent policy;
- grants only selected system facilities;
- emits filesystem read/write and network rules from the compiled permission
  profile.

Read-only grants `file-read*` and no user-data `file-write*` root. The base
policy still permits narrow device/PTY/shared-memory/platform operations. The
product claim must therefore be “no user-data writes”, not “no syscall that
macOS categorizes as any write”.

### 4.3 Seatbelt is real but deprecated API surface

The macOS 26 SDK header says `sandbox_init` is deprecated and only documents
named profiles. Both `sandbox-exec(1)` and `sandbox_init(3)` are marked
deprecated; Apple tells app developers to adopt App Sandbox.

Codex itself nevertheless ships and signs a Developer ID arm64 binary that
uses `/usr/bin/sandbox-exec` and generated Seatbelt profile syntax. This is
strong execution evidence for the installed runtime, but it is not an Apple
guarantee that arbitrary profile syntax is a stable public API.

R3 must therefore:

- fail closed if `/usr/bin/sandbox-exec` or expected policy behavior is absent;
- run signed-App synthetic diagnostics on every supported Codex/macOS
  combination;
- treat a Codex/macOS upgrade as capability evidence invalidation;
- not claim Mac App Store compatibility from this mechanism.

## 5. Network Findings

### 5.1 Restricted network

Read-only with network restricted denied:

- public DNS/HTTPS;
- loopback TCP;
- private-address TCP;
- Unix-domain socket;
- direct `--noproxy '*'` attempts.

It satisfies containment but not investigation capability.

### 5.2 Bare enabled network

Read-only with `network.enabled = true` and no managed proxy allowed:

- public HTTPS;
- loopback TCP;
- private-address TCP;
- Unix-domain socket;
- direct/no-proxy requests.

The Seatbelt generator emits broad network inbound/outbound access in this
mode. This candidate is rejected.

### 5.3 Managed network proxy

Codex `0.147.0` has an experimental managed network proxy. With:

- `network.enabled = true`;
- `features.network_proxy.enabled = true`;
- full mode;
- public wildcard domain allow in the proxy;
- `allow_local_binding = false`;
- no Unix-socket allow entry;

the CLI:

1. starts a parent-owned HTTP/SOCKS proxy on random loopback ports;
2. injects proxy variables into the sandboxed command;
3. changes Seatbelt so the command may reach only those loopback proxy ports
   and DNS required for proxy routing;
4. denies direct network bypass;
5. enforces non-public-address checks in the proxy connector;
6. keeps Unix socket access absent.

Observed:

| Probe | Restricted | Bare enabled | Managed proxy |
| --- | --- | --- | --- |
| Public HTTPS through normal client path | blocked | reachable | reachable |
| Public HTTPS with `--noproxy '*'` | blocked | reachable | blocked |
| Loopback through normal client path | blocked | reachable | blocked |
| Loopback with `--noproxy '*'` | blocked | reachable | blocked |
| Current private interface | blocked | reachable | blocked |
| Current private interface, no proxy | blocked | reachable | blocked |
| Filesystem Unix socket | blocked | reachable | blocked |

The managed proxy source classifies IPv4 loopback/private/link-local,
unspecified, multicast, broadcast, CGNAT and other non-public ranges. IPv6
loopback, unique-local, link-local, unspecified, multicast and IPv4-mapped
forms are also non-public. Its connector checks the actual resolved socket
address before connection.

The upstream README is honest that DNS rebinding is hard to prove completely
without lower-layer pinning. R3 must retain explicit rebinding/redirect/CNAME
fixtures and may not promote source review alone to containment proof.

### 5.4 Required minimal exception

The only observed candidate that combines public egress and local-target
denial requires the sandboxed descendant to connect to a dedicated loopback
proxy owned by its parent Codex runtime.

That connection:

- is not a general localhost investigation capability;
- uses a random port reserved by the current process;
- is not exposed as an arbitrary destination to the model;
- is the enforcement path that prevents all other local/private destinations;
- disappears with the session.

However, the approved baseline currently says no localhost access. R1 therefore
cannot approve this exception by itself. ADR 0013 records a conditional-go and
requires explicit user approval before R2.

## 6. Filesystem Probe

Checked-in probe:

```text
scripts/probe-codex-sandbox-containment
```

It creates anonymous disposable roots and runs only `codex sandbox`; it does
not call a model or use `auth.json`.

Observed under the read-only profile:

- read: allowed;
- create: blocked;
- append: blocked;
- truncate: blocked;
- rename: blocked;
- unlink: blocked;
- directory creation: blocked;
- chmod: blocked;
- xattr: blocked;
- timestamp mutation: blocked;
- hardlink creation: blocked;
- symlink creation: blocked;
- write through an in-scope symlink: blocked;
- nested descendant write: blocked.

The probe verifies post-state, not only command exit codes.

Final R1 probe log:

```text
/tmp/stornaut-r1-containment-probe-final-2.log
SHA-256 2c5625b6f94164cc4c238fcd24a3b53d9104b84a340a0e2a9c0a161fb1c3c857
```

The log is machine-local and contains only synthetic verdicts.

## 7. Runtime-Private Writes

`--ephemeral` means no persisted session, not no runtime writes. Starting
`codex exec` against an empty synthetic `CODEX_HOME` created:

- SQLite state/log/queue/goal/memory files;
- installation ID;
- arg0 wrappers;
- system skills;
- plugin/marketplace cache;
- shell snapshot/runtime directories.

The parent Codex process must therefore have a private writable runtime home.
The user-data boundary remains valid only if that home:

- is Stornaut-created and owner-only;
- is outside every scan/investigation root;
- is never the user's normal `~/.codex`;
- contains no raw report or cleanup authorization;
- is cleaned on completion and bounded after crash;
- is the only writable filesystem root granted to Codex/descendants.

R3 must determine the minimum required subpaths. Granting all of a broad App
container is not assumed safe.

## 8. Authentication and Instruction Isolation

### 8.1 Config isolation

`--ignore-user-config` replaces the user config layer with an empty layer. It
does not mean “ignore all of `CODEX_HOME`”, and it does not remove auth.

The current real user config includes:

- `danger-full-access`;
- local provider endpoints;
- plugins/hooks;
- project trust records;
- user shell environment additions.

This confirms that production Deep Dive must not inherit it.

### 8.2 Project/global instructions

- `project_doc_max_bytes=0` disables project `AGENTS.md` discovery.
- Global instructions are read independently from
  `$CODEX_HOME/AGENTS.override.md` or `AGENTS.md`.
- An isolated home with both absent avoids global instructions.
- Current user global `AGENTS.md` is zero bytes, but Stornaut must not rely on
  that mutable fact.

The synthetic prompt-input probe observed:

```text
global user home path count: 0
project instruction canary count: 0
isolated skill name count: 2
```

The isolated skill's body is not injected eagerly; its name/description is
advertised and the body is read when invoked. This is the desired capability
shape.

### 8.3 Authentication remains unresolved

`codex exec --ignore-user-config` still authenticates using the selected
`CODEX_HOME`. A new empty home cannot run an authenticated turn.

R1 rejects:

- symlinking the real user `auth.json`;
- giving the sandbox direct read access to the real user Codex home;
- long-lived copying into an uncontrolled directory;
- environment-wide inheritance of API keys.

The R3 candidate is an owner-only, ephemeral auth projection inside the private
runtime home, created by the trusted Swift parent and deleted deterministically.
Before implementation, R3 must inspect exact `auth.json` refresh/write behavior
and prove the projection cannot mutate or expose the original. If a safe
projection cannot be proved, authenticated Deep Dive remains no-go.

## 9. Skills, Subagents, Browser and Image

### Skills

User/runtime skills are discovered under `CODEX_HOME/skills`. This supports a
Stornaut-owned synthetic/production skill root in the isolated runtime home
without loading target repository skills. The R1 prompt-input probe proves the
skill metadata is visible while the target `AGENTS.md` is not.

### Subagents

Upstream source and tests state that subagents inherit the effective provider,
approval policy, sandbox and cwd. A regression test reapplies the runtime
permission profile after role config. This is promising source evidence, not
signed-App behavioral proof; R5 must attempt descendant writes and network
bypasses from actual subagents.

### Browser

`browser_use`, external browser and full-CDP feature declarations are stable
and enabled in the feature registry, but the CLI repository contains
requirements/connector glue rather than a standalone Browser Use
implementation for `codex exec`. The actual surface is supplied through a
desktop/App connector/plugin.

Therefore:

- feature declaration is only advertised capability;
- R2 must not claim browser observed;
- R5 must prove the signed Stornaut App can expose a contained browser/direct
  fetch surface;
- if the browser requires arbitrary localhost/CDP/Unix-socket access, the
  runtime gate is blocked pending a separate exact decision.

### Image

`view_image` and image-generation feature declarations are stable. Local image
attachment exists on `codex exec`. R5 must prove synthetic image inspection;
image generation is not required for disk investigation.

## 10. Apple App Sandbox Assessment

Apple's current documentation says App Sandbox:

- limits resources through entitlements;
- gives the app read/write access to its own container;
- extends access through user selection and security-scoped bookmarks;
- can pass a bookmark to a launch agent or XPC service;
- does not grant Full Disk Access automatically; the user must enable FDA.

Stornaut currently disables App Sandbox because it performs developer disk
survey and awaits a separate distribution/FDA decision. Enabling App Sandbox
on the whole App during R1 would change product filesystem access and is not a
drop-in solution.

An XPC/App Sandbox design remains a future supported-API alternative, but it
requires a separate spike for:

- passing read-only security scopes/FDA behavior to the helper;
- executing the user-installed Codex binary;
- private runtime writes;
- public proxy network;
- signing/notarization;
- child process inheritance.

R1 does not select it over the installed Codex Seatbelt candidate because no
current evidence shows it satisfies the product's full-disk investigation
shape with less risk or complexity.

## 11. Rejected Candidates

| Candidate | Result |
| --- | --- |
| Historical Broker-only disable profile | Reject: defeats approved capability-first product |
| `danger-full-access` | Reject: violates ADR 0004 |
| Read-only + restricted network | Reject: no public command/browser network |
| Read-only + bare network enabled | Reject: localhost/private/Unix socket all reachable |
| Prompt/shell wrapper write policy | Reject: not OS enforced |
| Public-domain allowlist | Reject: product explicitly disallows it |
| Per-command approval | Reject: product explicitly disallows it |
| Whole user `CODEX_HOME` | Reject: inherits config/instructions/credentials/state |
| Entire App Sandbox migration in R1 | Reject: unproved FDA/full-disk and distribution impact |

## 12. Candidate Architecture

Pending the exact loopback exception decision:

```text
Stornaut App
  creates owner-only ephemeral Runtime Home
  stages closed config + runtime skills + bounded auth projection
  launches installed Codex in one process group

Codex parent
  may write only Runtime Home
  owns managed proxy on random loopback port
  owns structured JSONL/stdin/stdout pipes

Codex shell/skills/subagents
  read authorized investigation scope
  cannot write user data
  cannot direct-connect to network
  may connect only to the session-bound managed proxy

Managed proxy
  unrestricted public destination domains
  blocks non-public resolved addresses
  no Unix sockets
  no credential broker / MITM hooks

Swift
  receives advisory typed output only
  owns all canonicalization, Policy and Executor paths
```

Browser remains an R5 conditional surface; it must fit this boundary or fail
the gate.

## 13. Outcome

**Conditional go for R2 planning only, blocked before implementation.**

The filesystem side is viable. The network side is viable only with a narrowly
scoped loopback proxy transport. That transport technically contradicts the
literal current “no localhost” baseline even though it exists to enforce the
denial of all arbitrary localhost/private destinations.

Required explicit decision:

> May Codex descendants connect only to a Stornaut/Codex-owned managed proxy
> listener on a random loopback port created for the same investigation
> session, while all other loopback/private/link-local destinations and all
> Unix sockets remain OS-blocked?

If approved, R2 may model this as a closed internal transport, and R3 must prove
port identity, lifecycle, bypass denial and descendant inheritance. If denied,
the current `0.147.0` candidate is no-go and R2 does not start.

## 14. R3 Lifecycle Correction

R2 reached `configurationReady`, but R3 did not behaviorally admit this
candidate. macOS measurements added on 2026-08-12 found:

1. a descendant under the Codex outer Seatbelt can call `setsid()`, leave the
   investigation process group and remain live after the sandbox leader exits;
2. a stricter Stornaut-owned Seatbelt profile can deny direct `SYS_setsid` and
   `SYS_setpgid`, but `posix_spawn(..., POSIX_SPAWN_SETSID)` still creates a
   new session and survives the wrapper;
3. a temporary launchd user job with `AbandonProcessGroup=false` does not
   reclaim the new-session descendant after its leader exits;
4. modern macOS does not support recursive kqueue `NOTE_TRACK`, and no public
   parent-death signal or supported per-investigation process-container API was
   found;
5. PPID or environment polling is not crash-safe after reparenting and PID
   reuse; private coalition APIs, Endpoint Security and a privileged daemon
   would require a different supported architecture and explicit product/
   permission review.

Reproducible anonymous evidence:

```text
scripts/probe-codex-r3-lifecycle-escape
/tmp/stornaut-r3-lifecycle-escape-probe-final.log
SHA-256 f25700e0e35178910cda4809468ea1aa37a9936abaec4100fb6b74e49fde3557
```

This corrects the R1 conditional candidate: managed-proxy transport remains a
viable network shape, but the current macOS process lifecycle shape is not
viable. R3 is `behaviorBlocked/no-go`, no production runtime is retained and
R4–R6 do not start.
