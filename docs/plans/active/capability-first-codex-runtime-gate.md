# Capability-First Codex Runtime Evidence Gate

> Status: Paused for user review — R1–R3 complete; R3 behaviorReady candidate;
> R4–R6 not started
>
> Planned: 2026-08-11
>
> Capability ownership: Epic 5 runtime foundation, before production Epic 6
> Deep Dive
>
> Ordering: Task 28 complete → **R1–R6 runtime gate** → Task 29–35 resume
>
> Governing decision:
> [ADR 0004](../../adr/0004-codex-file-read-isolation.md)

## 1. Purpose

The amended ADR 0004 deliberately prioritizes Codex investigation quality for
this personal-use product:

- direct read-only filesystem investigation;
- normal shell and unified exec;
- live high-context web search;
- public-internet command, browser and direct-fetch workflows;
- image inspection;
- supported skills and subagents;
- optional structured Probe Broker evidence.

The existing Task 4–5 runtime candidate does the opposite: it disables most of
that surface in pursuit of the historical Broker-only boundary. This plan
replaces that candidate with a capability-first runtime while retaining the
non-negotiable integrity boundary:

- Codex and every descendant cannot write user data;
- public internet is available without a public-domain or executable allowlist;
- localhost, link-local/private networks and unrelated Unix sockets remain
  unavailable;
- Codex has no callable route to Trash, Registered Actions, Policy bypass or
  Executor;
- all output remains untrusted advisory evidence until Swift canonicalization,
  revalidation, Policy Gate and explicit user selection.

This is an evidence gate, not the production Deep Dive workflow. It does not
implement Candidate Planner, investigation orchestration, Deep Dive UI or
cleanup execution.

## 2. Why This Interlocks Phase C

Tasks 27–28 established the deterministic Plan/Policy/Journal/Manifest
contracts that a future Deep Dive must reuse. Task 29 begins promoting exact
deterministic rule evidence into Review plans. Before that product surface
expands, the project will close the amended ADR 0004 runtime uncertainty so
that later Codex work is designed against the real capability boundary rather
than the obsolete Broker-only profile.

This interlock does not change the responsibilities or numbering of the
approved Epic 8 Tasks 29–35. Once R1–R6 pass:

1. Phase C resumes at Task 29 and completes the deterministic execution slice;
2. production Deep Dive still remains unavailable;
3. Phase D may reuse the verified runtime foundation only after Task 35 closes
   the deterministic execution gate.

If the runtime gate is `no-go`, deterministic Tasks 29–35 may resume only after
the result is documented and the roadmap is explicitly revised. A no-go never
authorizes disabling required investigation capabilities, using
`danger-full-access`, or weakening the write/Executor boundary.

## 3. Approved Boundary

### 3.1 Required investigation capabilities

The production candidate must make all of the following available:

| Capability | Required behavior |
| --- | --- |
| Direct read | Read evidence in the user-selected investigation scope without a per-path approval loop |
| Shell | Normal local read/investigation commands; no Bash or executable allowlist |
| Unified exec | Stable Codex unified execution path with bounded process lifecycle |
| Live search | Explicit live mode, high context, no silent cached/indexed substitution |
| Public command network | Commands and descendants may reach public internet destinations |
| Browser/direct fetch | Public web investigation beyond search snippets |
| Image inspection | Inspect local synthetic images as evidence; generation is not required |
| Skills | Supported investigation skills are available without loading target-project instructions |
| Subagents | Supported subagent delegation inherits the same containment |
| Probe Broker | Optional preferred source for typed, bounded and auditable evidence |

No per-file, per-command, per-tool, per-executable or per-public-domain approval
is added after the aggregate first-use disclosure.

Desktop computer-use and arbitrary user-installed plugins, apps, hooks or
external MCP servers are not automatically part of the required product
profile. They may control unrelated local applications/services or introduce
independent credentials and side effects. R1 catalogs their interaction with
the required browser/skill/subagent surface; enabling one later requires proof
that it is necessary for an approved capability and does not expand local
write, private-network, Unix-socket or cleanup authority.

### 3.2 Required containment

- No create, modify, move, rename, unlink, truncate, metadata mutation or
  deletion of user data.
- A private, mode-`0700`, Stornaut-owned ephemeral runtime directory may be
  writable only when a required Codex/browser runtime cannot operate without
  private cache, profile or IPC state. It must never overlap the investigation
  scope, user-selected target, normal Codex home or application documents.
- The same file boundary applies to shells, scripts, skills, subagents,
  browsers and every descendant.
- IPv4/IPv6 loopback, link-local, RFC1918, carrier-grade NAT, IPv6 unique-local
  and other private destinations are blocked at connection time.
- Public egress is for unauthenticated investigation and retrieval. Stornaut
  does not supply user service credentials or expose a remote-mutation product
  capability; the absence of a destination allowlist does not authorize
  modifying external services.
- Unix-socket connection is denied by the approved baseline, including sockets
  inside the private runtime directory. If R1 proves a browser/worker cannot
  operate without one private internal IPC socket, that is an unresolved
  permission-boundary expansion: stop, document the exact path/peer/lifetime
  restriction in ADR 0013 and obtain separate user approval before R3
  implements it.
- `danger-full-access` is not used.
- Codex output, events and child processes cannot call parent-process cleanup
  capabilities.

### 3.3 Instruction and configuration isolation

- Product Codex uses an isolated runtime configuration and does not load this
  repository's, the target tree's or the user's global `AGENTS.md` as
  instructions.
- Target `AGENTS.md`, README files and other instruction-like content may be
  read as untrusted investigation evidence.
- User configuration cannot silently disable required capabilities or loosen
  containment.
- Supported skills may be exposed through an explicit runtime skill source,
  but project instruction discovery remains disabled.
- Credentials and tokens are not inherited wholesale. Authentication material
  required by the user's installed Codex is handled through a narrowly scoped,
  ephemeral mechanism and is never written to reports, logs, fixtures or Git.
- The plan does not assume authentication can safely be copied. R1 first
  determines whether installed Codex can authenticate through a read-only
  isolated home or another documented mechanism; any fallback requires an
  explicit threat analysis before implementation.

## 4. Baseline and Confirmed Drift

Baseline commit when this plan was written:

```text
87fb6b0a22d698fcde80964c36094ef18b90bccf
```

Installed runtime:

```text
/Users/eriklee/.npm-global/bin/codex
codex-cli 0.147.0
```

Current CLI evidence confirms:

- `--sandbox read-only`;
- `--ask-for-approval never`;
- `--search` live search without per-call approval;
- `--ignore-user-config`;
- `--ignore-rules`;
- `--strict-config`;
- stable shell, unified exec, browser, computer-use, image-generation,
  multi-agent, plugin, hook and app feature declarations.

Feature declaration is syntax evidence only. It does not prove that the
required tool works in the signed App, that public network and write denial can
coexist, or that descendants inherit containment.

Known implementation drift:

- `CodexRunRequest.fixedArguments` disables shell, unified exec, browser,
  image, skills and orchestrator MCP;
- `CodexCapabilityReport` still treats `brokerOnlyToolSurface` as a current
  behavior;
- Settings treats historical strict/ignore flags as the complete required
  syntax set;
- the process environment allowlist is too narrow to claim support for all
  useful toolchain/browser/network paths, but broad inheritance would leak
  credentials;
- `InvestigationEnvelope` has no versioned provenance, source, coverage,
  degradation or advisory-candidate contract;
- current App copy still says Broker-only isolation is required.

## 5. Non-Goals

R1–R6 must not:

- enable the user-facing Deep Dive CTA;
- implement Candidate Planner or the scientific investigation state machine;
- implement production Evidence Report persistence;
- place Codex findings directly into a current Cleanup Plan;
- add a real Adapter or Registered Action;
- add permanent delete;
- change the cleanup protected-path policy;
- grant Codex a callback, IPC endpoint or capability object for Policy Gate,
  Trash or Executor;
- load Coding Agent XcodeBuildMCP or Peekaboo tools into product Codex;
- add telemetry, remote rules, background monitoring, a login item or a remote
  Stornaut service;
- request, grant or reset TCC, Accessibility or Event Synthesizing;
- add third-party dependencies without an upstream/license record and explicit
  justification;
- use real private user files, credentials or paths as diagnostic fixtures.

No new visual asset is required by this plan. If a later UI state genuinely
needs one, web material must retain source/license provenance and
`$erik-gpt-image-2` output must retain its prompt/metadata; generated concepts
remain non-pixel specifications.

## 6. Meaning of Detailed-Plan Approval

Approval of this detailed plan authorizes the Coding Agent to execute R1–R6 in
order, including:

- public documentation/source lookup;
- bounded calls to the user's installed Codex that may consume the user's model
  quota;
- public-internet requests containing only generated synthetic diagnostic
  material;
- disposable local listeners used solely as must-fail loopback/Unix-socket
  canaries;
- local signing and launch of the Debug Stornaut App;
- creation and removal of anonymous disposable fixture/runtime roots;
- independent commits and pushes to `origin/main` after each passed R-task.

It does not authorize:

- reading or transmitting real private user content for diagnostics;
- granting/resetting TCC, Full Disk Access, Accessibility or Event Synthesizing;
- opening Codex access to localhost/private networks or Unix sockets;
- changing the cleanup protected-path policy or Executor capability;
- real Trash, Registered Action, release, notarization or force-push.

If R1 finds that satisfying a required capability needs one of those excluded
permissions, stop and request a new explicit decision with measured evidence.

## 7. Execution Order

```text
R1 Current Runtime and macOS Containment Study
→ R2 Capability Model and Runtime Profile
→ R3 OS-Enforced Containment and Environment/Auth Boundary
→ R4 Investigation Protocol v2 and No-Executor Seam
→ R5 Signed-App Capability/Containment Diagnostic
→ R6 Product Status Copy, Final Gate and Admission Decision
```

R1–R3 are the critical path. R4–R6 do not start if R3 cannot prove a viable
containment design.

R3 has now proved a viable candidate. Per the user's 2026-08-12 instruction,
the plan pauses after the independent R3 commit/push and remote-state check.
R4 does not start until the user reviews the R3 output and gives a new
instruction.

Every R-task follows:

```text
Upstream evidence
→ task implementation brief
→ tests/fixtures first
→ implementation
→ adversarial review
→ focused verification
→ full applicable verification
→ docs/provenance
→ independent commit
→ push origin/main
```

## 8. Cross-Task Contracts

### 8.1 Capability verdicts

The new report separates:

1. **advertised** — help/config/features syntax exists;
2. **configured** — Stornaut generated the intended closed profile;
3. **observed** — a signed-App synthetic diagnostic exercised the behavior;
4. **contained** — adversarial attempts proved the integrity restriction;
5. **degraded** — the capability is unavailable or silently fell back;
6. **failed** — a required integrity boundary was violated.

Help text or feature-list presence can never promote a behavior to
`observed`/`contained`.

### 8.2 Runtime report privacy

Checked-in and persisted reports may contain only:

- Codex executable identity and version;
- OS/Xcode/Swift/App signature identity;
- capability and containment verdict keys;
- bounded reason codes;
- counts, durations and hashes of synthetic fixtures;
- external public test endpoint hostnames used by diagnostics;
- sanitized event categories.

They must not contain:

- auth material or environment secrets;
- raw prompts or raw JSONL;
- model reasoning;
- private file content;
- real private paths;
- full environment dumps;
- browser profile/cookie content;
- arbitrary stdout/stderr.

### 8.3 Required test classes

- deterministic unit tests run offline and without a model;
- fake-process integration tests run on every `swift test`;
- OS containment fixtures use only anonymous disposable roots;
- real Codex/model/public-network diagnostics are explicit opt-in signed-App
  evidence and never run as an incidental unit test;
- UI changes use build/test → real `.app` launch → Peekaboo read-only
  capture/inspection → XCUITest/`scripts/verify`.

### 8.4 Failure semantics

- Missing investigation capability: `degraded` and gate blocked.
- Failed write/private-network/no-Executor containment: `failed` and gate
  blocked.
- Ambiguous or unmeasured behavior: `unverified` and gate blocked.
- Model declines to use a required tool: retry only within the documented
  bounded diagnostic protocol; never reinterpret absence as success.
- External network outage: report environment-level unmeasurable evidence and
  rerun later; do not silently switch to cached search.
- Any target mutation: preserve synthetic evidence, terminate the process tree,
  mark no-go and stop later R-tasks.

## 9. R1 — Current Runtime and macOS Containment Study

### Files

- Create:
  `docs/upstream-studies/epic-5-capability-first-runtime.md`
- Create:
  `docs/adr/0013-capability-first-runtime-containment.md`
- Create:
  `docs/plans/active/task-r1-implementation-brief.md`
- Update if factual evidence changes:
  `docs/research/upstream-reference-matrix.md`
- Create:
  `docs/reports/capability-first-runtime-r1-review.md`

### Purpose

Select an evidence-backed runtime/containment architecture before changing the
production process launcher.

### Study requirements

Record exact URL, version/commit, license and inspected source/docs for:

- installed Codex `0.147.0` CLI help, feature output and config schema;
- OpenAI Codex sandbox, approval, live-search, browser, skills and subagent
  behavior;
- the implementation that maps sandbox modes to filesystem and command-network
  permissions;
- macOS App Sandbox, child-process inheritance and network entitlements;
- viable outer process containment mechanisms on the target macOS;
- DNS and connect-time private-address blocking, including IPv6;
- proxy, PAC, VPN, DNS/CNAME and redirect behavior that could bypass destination
  classification;
- browser/worker subprocess and private-runtime requirements.

Do not assume an undocumented private macOS mechanism is shippable merely
because a local spike can invoke it. Record API stability, signing/distribution
impact and license/redistribution implications.

### Required experiments

Use only disposable synthetic roots to measure:

1. native Codex `read-only` plus built-in live search;
2. native Codex shell public network behavior in read-only mode;
3. any Codex mode that permits public command network without
   `danger-full-access`;
4. file-write attempts by the direct child and nested descendants;
5. loopback/private network and Unix-socket attempts;
6. browser and subagent process-tree shape;
7. authentication/config isolation without loading global/project
   instructions;
8. whether browser/worker operation requires local IPC that conflicts with the
   approved Unix-socket denial.

### ADR decision

ADR 0013 must choose one of:

- **go** — one production-candidate containment design satisfies all required
  capability/integrity properties;
- **conditional go** — a bounded implementation spike is justified, with
  explicit unresolved proof assigned to R3;
- **no-go** — no acceptable design exists under the approved boundary.

It must explicitly reject alternatives that:

- use `danger-full-access`;
- require a public destination-domain or executable allowlist;
- rely only on prompts, environment variables or shell wrappers for write
  denial;
- allow private/local service access;
- require Unix-socket access without a separately approved ADR amendment;
- require per-command approval;
- silently disable required capabilities.

### Tests and verification

R1 is documentation/evidence work, but every experiment uses checked-in
anonymous setup scripts or exact reproducible commands. Validate:

```text
scripts/check-doc-links
git diff --check
```

Review all claims against command output and primary sources. The review report
must list every confirmed correction before R1 is committed and pushed.

### Stop condition

If R1 is `no-go`, stop this plan after updating the roadmap and report. Do not
start R2 or Task 29 without a new user-reviewed order.

## 10. R2 — Capability Model and Runtime Profile

### Candidate files

- Create:
  `Sources/StornautCodex/Runtime/CodexRuntimeProfile.swift`
- Create:
  `Sources/StornautCodex/Runtime/CodexRuntimeCapability.swift`
- Modify:
  `Sources/StornautCodex/Runtime/CodexCapability.swift`
- Modify:
  `Sources/StornautCodex/Runtime/CodexProcess.swift`
- Add/update generated, sanitized fixtures under:
  `Tests/Fixtures/Codex/`
- Create:
  `Tests/StornautCodexTests/CodexRuntimeProfileTests.swift`
- Modify:
  `Tests/StornautCodexTests/CodexCapabilityTests.swift`
- Modify:
  `Tests/StornautCodexTests/CodexProcessTests.swift`
- Modify:
  `Tests/StornautCodexTests/InstalledCodexDiagnosticTests.swift`
- Create:
  `docs/plans/active/task-r2-implementation-brief.md`
- Create:
  `docs/reports/capability-first-runtime-r2-review.md`

Exact file names may change in the implementation brief if R1 selects a
different responsibility split.

### Tests first

Write failing tests proving the generated candidate:

- uses ephemeral structured execution and the output schema;
- sets approval policy to `never`;
- explicitly selects live search/high context;
- does not use cached/indexed search as a hidden fallback;
- enables shell and unified exec;
- exposes required browser/direct-fetch, image-inspection, skill and subagent
  capabilities supported by the installed runtime;
- does not carry the historical `brokerOnlyToolSurface` requirement;
- keeps project/global instruction discovery isolated;
- does not disable required capabilities through legacy overrides;
- never emits `danger-full-access`;
- rejects unknown/contradictory config fields under strict configuration;
- keeps stable arguments deterministic and NUL-safe;
- classifies syntax/config evidence separately from behavioral evidence.

Feature names are versioned evidence, not permanent assumptions. A future
Codex version that renames or removes a required feature must become
unsupported/degraded until a new study updates the profile.

### Implementation

Replace the static disable-list with a typed `CodexRuntimeProfile` that owns:

- protocol options;
- approval policy;
- sandbox/outer-containment selector from ADR 0013;
- live-search mode and context;
- explicit required feature settings;
- instruction/config isolation;
- private runtime paths;
- bounded diagnostics metadata.

Do not expose arbitrary user config merging. Profile construction fails closed
when required capability settings cannot be expressed.

`CodexCapabilityReport` must report the cross-task verdict dimensions from
§8.1 and remove Broker-only from the current product gate. Historical Task 3–5
fixtures remain available as historical parser evidence, clearly named as such.

### Review

Review for:

- default capability accidentally disabled;
- capability claimed from help text only;
- config injection/quoting;
- profile drift across installed versions;
- accidental user/project instruction loading;
- secret-bearing config in errors or snapshots;
- approval/sandbox mismatch;
- unbounded argument/environment data.

### Verification

Run focused capability/profile/process tests, the complete
`StornautCodexTests`, full `swift test`, docs links and diff hygiene. No real
model call is required for R2.

R2 ends with one independent commit/push.

## 11. R3 — OS-Enforced Containment and Environment/Auth Boundary

### Candidate files

- Create:
  `Sources/StornautCodex/Runtime/CodexContainmentPolicy.swift`
- Create:
  `Sources/StornautCodex/Runtime/CodexRuntimeEnvironment.swift`
- Create:
  `Sources/StornautCodex/Runtime/CodexRuntimeWorkspace.swift`
- Create only if ADR 0013 requires a dedicated launcher/helper:
  an explicitly named target and source directory approved by the R3 brief
- Modify:
  `Sources/StornautCodex/Runtime/CodexProcess.swift`
- Add anonymous helpers under:
  `Tests/Fixtures/CodexContainment/`
- Create:
  `Tests/StornautCodexTests/CodexContainmentTests.swift`
- Create:
  `Tests/StornautCodexTests/CodexRuntimeEnvironmentTests.swift`
- Create:
  `docs/plans/active/task-r3-implementation-brief.md`
- Create:
  `docs/reports/capability-first-runtime-r3-review.md`

### Tests first: filesystem

From direct child, shell script, nested shell, skill helper and subagent-like
descendant attempts, verify denial of:

- create and overwrite;
- append and truncate;
- rename and exchange;
- unlink and recursive removal;
- hard-link and symlink-assisted escape;
- chmod/chown/xattr/flags/timestamp mutation;
- directory creation/removal;
- writes through already-open descriptors not explicitly inherited;
- writes through relative paths, Unicode/case variants and mount boundaries;
- writes after target replacement;
- writes into the normal user Codex home, App documents and investigation
  scope.

If a private runtime directory is required, prove:

- canonical non-overlap with all user/scan roots;
- owner-only permissions;
- bounded lifetime and crash cleanup;
- no symlink escape;
- no report/log persistence of auth or raw content;
- only required runtime classes are writable.

### Tests first: network and IPC

Verify denial for:

- `127.0.0.0/8` and `::1`;
- IPv4 link-local and IPv6 link-local;
- RFC1918, carrier-grade NAT and IPv6 unique-local ranges;
- IPv4-mapped IPv6 equivalents;
- multicast/broadcast where applicable;
- a hostname that resolves or rebinds to a blocked address;
- CNAME chains and HTTP redirects that end at a blocked address;
- a pre-existing filesystem Unix socket outside the private runtime;
- a socket path reached through symlink/path aliasing.

Verify public DNS, TLS and command/browser egress without maintaining a public
destination allowlist. Enforcement must occur below model instructions and
shell environment manipulation.

### Environment and authentication

Define a typed environment policy rather than either a tiny accidental
allowlist or broad inheritance:

- preserve the full useful absolute executable search path within a documented
  byte bound; do not make it an executable allowlist;
- preserve locale/terminal and required certificate/runtime variables;
- preserve system trust-store behavior without copying user keychain material;
- reject relative path entries and loader injection variables;
- do not inherit API keys, GitHub tokens, cloud credentials, SSH agent sockets,
  arbitrary proxy credentials or unrelated app/session variables;
- do not route public network through a localhost proxy because localhost is a
  denied boundary;
- make missing enterprise/system proxy support an explicit degraded result;
- stage only the minimum installed-Codex authentication material into private
  ephemeral state, with restrictive permissions and deterministic cleanup;
- never print auth file contents, hashes that facilitate secret comparison or
  secret-bearing errors.

### Process lifecycle

The existing atomic process-group, bounded stdout/stderr/JSONL, timeout,
cancellation and descendant termination guarantees remain mandatory. Add
stress tests that combine containment with:

- eight-way concurrent launch;
- a grandchild holding descriptors;
- browser/worker-shaped descendants;
- timeout during public network I/O;
- cancellation during subagent-like fan-out;
- output and event-buffer overflow.

### Review and gate

R3 receives a dedicated adversarial review for filesystem race/escape,
network-address coverage, descriptor inheritance, auth leakage and process
cleanup.

Required focused evidence:

- all synthetic filesystem mutations denied;
- public egress succeeds;
- all specified private/local/Unix-socket attempts fail;
- descendants inherit both boundaries;
- no leaked fixture process;
- no secret material in output/report fixtures.

Then run complete `StornautCodexTests`, full `swift test`, App build/bundle
checks, docs links and diff hygiene.

R3 is the hard gate. Any integrity failure blocks R4–R6 and yields a no-go
report. Success ends with one independent commit/push.

The first R3 process-group candidate reached that stop condition on
2026-08-12. Direct `setsid()` and `POSIX_SPAWN_SETSID` descendants escaped the
investigation process group, and a launchd user job did not reclaim the
new-session descendant. After explicit user approval, ADR 0016 introduced a
narrow audit-session lifecycle supervisor. The final privileged composition
proved identity reduction, outer Seatbelt ordering, audit-session inheritance
across direct/spawn/double-fork detach shapes, managed-proxy-owner cleanup and
stale-lease recovery with zero residue. The anonymous containment matrix and
external-auth `gpt-5.6-luna` diagnostic also passed. See the
[R3 review](../../reports/capability-first-runtime-r3-review.md).

R3 closes as `behaviorReady` candidate. It does not prove signed-App helper
packaging, FDA/TCC inheritance, no-Executor protocol integration or final
product admission. R4–R6 remain not started.

## 12. R4 — Investigation Protocol v2 and No-Executor Seam

### Candidate files

- Create or version:
  `Sources/StornautCodex/Protocol/InvestigationEnvelopeV2.swift`
- Modify:
  `Sources/StornautCodex/Protocol/InvestigationEnvelope.swift`
- Create:
  `Sources/StornautCodex/Protocol/InvestigationEvidenceSource.swift`
- Update:
  `Sources/StornautCodex/Schemas/investigation-envelope.schema.json`
- Modify:
  `Sources/StornautCodex/Protocol/CodexEvent.swift`
- Modify:
  `Sources/StornautCodex/Protocol/JSONLDecoder.swift`
- Add protocol fixtures under:
  `Tests/Fixtures/Codex/`
- Create:
  `Tests/StornautCodexTests/InvestigationEnvelopeV2Tests.swift`
- Modify:
  `Tests/StornautCodexTests/JSONLDecoderTests.swift`
- Add/update a source/package boundary verifier under:
  `scripts/`
- Create:
  `docs/plans/active/task-r4-implementation-brief.md`
- Create:
  `docs/reports/capability-first-runtime-r4-review.md`

### Contract design

The brief must define a bounded, versioned final result with at least:

- investigation/run identity supplied by Swift;
- summary;
- findings bound to candidate/target identities;
- evidence source/provenance references;
- coverage and unresolved targets;
- capability degradation reason keys;
- advisory candidate proposals;
- confidence and explicit uncertainty;
- source labels that distinguish Broker evidence from direct file, shell, live
  search, browser/direct fetch, image, skill and subagent evidence.

The persisted projection contains summaries and provenance, not raw read
content, browser bodies or raw model streams.

### Tests first

Test:

- strict keys at every nesting level;
- schema/version mismatch;
- UTF-8 byte limits rather than only character counts;
- bounded arrays, strings and aggregate payload;
- duplicate IDs and dangling evidence references;
- unknown source/capability/status values;
- prompt-injection text treated as data;
- forged path, identity, confidence and action-like fields;
- public URL provenance normalization without credential/query leakage;
- source labels cannot claim Broker guarantees for direct evidence;
- v1 historical envelope decode remains available where required;
- v2 cannot encode authorization, executable, arbitrary args, shell cleanup,
  permanent delete, Policy bypass or an executable `CleanupAction`.

### No-Executor seam

Add a verifier and tests proving:

- `Sources/StornautCodex` contains no Executor/Trash/Registered Action
  invocation;
- the child process receives no cleanup IPC endpoint, inherited descriptor,
  XPC service or callback;
- final envelope decoding produces advisory values only;
- conversion to future Core evidence is an explicit Swift normalization step;
- Codex-supplied paths/identities are always re-opened and canonicalized by
  Swift before any later plan can use them;
- no Deep Dive result can create a current PolicyDecision, authorization or
  journal record.

This task may introduce protocol types and normalizers but not a production
Deep Dive coordinator.

### Review and verification

Review schema confusion, injection, bounds, privacy, backward compatibility and
any accidental action reachability. Run focused protocol/boundary tests,
complete `StornautCodexTests`, full `swift test`, verifier scripts and docs.

R4 ends with one independent commit/push.

## 13. R5 — Signed-App Capability and Containment Diagnostic

### Candidate files

- Replace or supersede:
  `StornautApp/Diagnostics/IsolationProbeHarness.swift`
- Create:
  `StornautApp/Diagnostics/CapabilityRuntimeProbeHarness.swift`
- Add only DEBUG/synthetic fixtures required by the diagnostic
- Update:
  `scripts/verify-app-release-boundaries`
- Create:
  `scripts/verify-codex-runtime-diagnostic`
- Create:
  `scripts/verify-codex-runtime-gate`
- Create:
  `Tests/StornautCodexTests/CapabilityRuntimeDiagnosticContractTests.swift`
- Add App contract tests as required
- Create:
  `docs/plans/active/task-r5-implementation-brief.md`
- Create:
  `docs/reports/capability-first-runtime-r5-review.md`

### Diagnostic shape

The diagnostic runs only when explicitly invoked against a locally signed
Debug `.app`. It uses:

- synthetic anonymous directories;
- generated non-secret text/image artifacts;
- a disposable local HTTP listener used only as a must-fail loopback canary;
- a disposable Unix-socket listener used only as a must-fail canary;
- public GET-only endpoints recorded in the brief;
- a runtime-owned synthetic diagnostic skill;
- bounded prompts that request observable use of each required capability.

It never reads a real private file, mutates the user's normal Codex config,
changes TCC or sends user data to a network service.

### Required positive evidence

Observe from the signed App:

- direct read of the selected synthetic scope;
- shell and unified exec;
- live web-search event with non-cached configuration;
- public command network;
- browser/direct-fetch public access;
- local synthetic image inspection;
- diagnostic skill use;
- subagent delegation and descendant cleanup;
- optional Probe Broker access as a separate structured source;
- valid bounded v2 envelope with source/coverage labels.

Tool declaration alone is insufficient. The report distinguishes a tool being
configured, invoked and successfully observed.

### Required negative evidence

Observe:

- all user/synthetic target mutation attempts denied;
- nested descendants denied;
- loopback/private/link-local destinations denied;
- unrelated Unix socket denied;
- no cleanup capability reachable;
- timeout/cancel kills every descendant;
- raw JSONL and private runtime/auth state are removed on normal completion;
- crash residue, if deliberately injected, follows the documented maximum
  lifetime and contains no raw credential.

### Flake policy

Model choice is not silently interpreted as platform support:

- each capability probe has one precise observable success contract;
- bounded retries and their reason are recorded;
- a tool not invoked after the allowed attempts remains unverified/degraded;
- external outage is reported separately from containment failure;
- integrity failure is never retried into a pass.

### Report and release isolation

The machine-local report contains only the privacy-safe fields from §8.2. The
repository report records its SHA-256 and summarized verdicts, not raw output.

`scripts/verify-app-release-boundaries` must prove all diagnostic entrypoints,
fixtures and markers are absent from Release.

After focused diagnostic contract tests, run the signed-App diagnostic, full
SwiftPM/App/build/bundle verification, review and docs. R5 ends with one
independent commit/push only if every integrity requirement passes.

## 14. R6 — Product Status Copy, Final Gate and Admission Decision

### Candidate files

- Modify:
  `StornautApp/AppState/AppDependencies.swift`
- Modify Settings state/model/views as required
- Modify:
  `StornautApp/Resources/en.lproj/Localizable.strings`
- Modify:
  `StornautApp/Resources/zh-Hans.lproj/Localizable.strings`
- Modify relevant App and UI tests
- Update:
  `scripts/verify-settings-boundaries`
- Update:
  `scripts/verify`
- Create:
  `docs/reports/capability-first-runtime-validation-report.md`
- Create:
  `docs/reports/capability-first-runtime-r6-review.md`
- Create:
  `docs/plans/active/task-r6-implementation-brief.md`
- Update current-state routing docs

### Product status contract

Settings must stop presenting Broker-only isolation as the current
requirement. It distinguishes:

- Codex installation;
- required syntax/config support;
- last signed-App capability/containment evidence;
- runtime gate outcome;
- production Deep Dive implementation availability.

A passed runtime gate does not enable Deep Dive by itself. Until Phase D
implements and validates the full product workflow, the UI states:

```text
Runtime boundary verified · Deep Dive implementation not yet available
```

If the gate is not current or failed, it shows the exact bounded reason and
keeps Quick Scan unaffected.

The aggregate first-use data-boundary disclosure receives a typed/localized
contract and tests, but R6 does not display an actionable first-use flow or
persist acceptance while Deep Dive remains unavailable.

### UI verification

Tests cover English and `zh-Hans`, installed/missing/unsupported/unverified/
passed/stale/failed runtime states, VoiceOver labels, keyboard traversal,
reduced motion and System/Light/Dark.

For every UI change:

```text
build/test
→ launch actual Debug .app
→ Peekaboo read-only screenshot and AX inspection
→ XCUITest canonical screenshot/state assertions
→ scripts/verify
```

External user interaction that changes window focus is recorded as
environmental interference and rerun undisturbed; it is not reclassified as a
product defect without reproducible evidence.

### Final validation report

The report maps every ADR 0004 residual-risk item to:

- implementation;
- deterministic test;
- signed-App observation;
- negative/adversarial evidence;
- unresolved limitation;
- final `go`, `conditional go` or `no-go`.

Required final gate:

- all required capabilities observed;
- public network observed without a public-domain/executable allowlist;
- no target/user-data writes from any descendant;
- all private/local/Unix-socket canaries denied;
- no Executor reachability;
- protocol v2 strict and bounded;
- process timeout/cancel/output limits intact;
- no secrets/raw JSONL in retained or checked-in evidence;
- Release has no debug diagnostic path;
- UI text accurately describes capability versus product availability;
- focused, full SwiftPM, App, UI, docs and boundary verifiers pass;
- final code review has zero unresolved P0–P2 findings.

R6 ends with one independent commit/push. Only then may Task 29 be marked
active again.

## 15. Review Requirements Per Task

Each R-task review covers all tracked and new files, including files a
working-tree review tool may omit. At minimum inspect:

- correctness and contract completeness;
- filesystem race/symlink/descriptor escape;
- network bypass and IPv6 coverage;
- process-tree and cancellation races;
- configuration/argument injection;
- prompt injection and schema confusion;
- credential/environment leakage;
- action/Executor reachability;
- persistence and retention;
- Release/debug isolation;
- localization/accessibility for UI tasks;
- third-party code/license provenance.

Confirmed findings are fixed and retested before the task commit. The task
report records:

- review scope;
- confirmed findings and severity;
- corrections;
- focused/full command results;
- log path and SHA-256 for final long-running gates;
- unresolved limitations;
- commit readiness.

## 16. Verification Ladder

Use the narrowest applicable rung first:

1. new focused unit/contract tests;
2. complete `StornautCodexTests`;
3. containment stress/adversarial fixtures;
4. full serial `swift test`;
5. App contract tests and builds;
6. signed-App synthetic diagnostic;
7. Release fixture/boundary audit;
8. actual-window Peekaboo/XCUITest for UI changes;
9. full `scripts/verify`;
10. docs links, `git diff --check`, status/diff audit.

Long-running commands use shell `pipefail`; a successful `tee` process is not a
test pass. A gate is accepted only from the actual command exit status.

`scripts/verify` remains offline/repeatable and must not unexpectedly spend
model tokens or require public network. The explicit signed-App runtime
diagnostic supplies the separate live evidence class.

## 17. Final Prompt-to-Evidence Matrix

| Approved requirement | Required evidence |
| --- | --- |
| Direct read | signed-App synthetic read + source-labeled v2 evidence |
| Shell/unified exec | configured profile + observed tool events + bounded lifecycle |
| Live high-context search | explicit config + observed live search + degradation test |
| Public command network | descendant public HTTPS success |
| Browser/direct fetch | observed public browser/fetch result |
| Image inspection | synthetic image observation |
| Skills/subagents | diagnostic skill and delegated subagent observation |
| No executable/domain allowlist | profile/source audit and multiple public endpoints |
| No per-command approvals | approval config and unattended diagnostic |
| Probe optional, not exclusive | direct and Broker source tests |
| No user-data writes | adversarial filesystem matrix across descendants |
| No localhost/private network | IPv4/IPv6/DNS-rebind negative matrix |
| No arbitrary Unix socket | pre-existing socket negative tests |
| No `danger-full-access` | config/source/runtime report audit |
| No cleanup authority | package/source/runtime no-Executor gate |
| Swift revalidation remains authoritative | advisory-only v2 schema/boundary tests |
| No raw secret/JSONL retention | environment/report/crash-lifecycle tests |
| Accurate disclosure/status | localized App model/UI/XCUITest evidence |
| Debug only diagnostic | Release binary/bundle marker audit |

No row may be closed by a proxy signal alone. Syntax support does not prove
behavior; behavior does not prove containment; containment does not prove
product integration.

## 18. Completion and Resume Criteria

This plan is complete only when:

- R1–R6 each have an implementation brief, review report, verification evidence
  and independent pushed commit;
- the final evidence matrix has no missing or unverified required row;
- the final report records a supported `go` outcome;
- `HEAD == origin/main` and the worktree is clean;
- no sensitive fixture, auth material, raw JSONL or private path is tracked;
- current routing docs point to the final report;
- Task 29 is explicitly reactivated without changing its deterministic scope;
- production Deep Dive remains disabled pending its own Phase D plan.

If any capability or integrity row remains uncertain, this gate is not
complete. Record the no-go/conditional result and continue the deterministic
product only through a separately reviewed roadmap update.

Current outcome: the plan is **not complete**. R3 is a `behaviorReady`
candidate and the workflow is paused for user review before R4. Task 29 and
production Deep Dive remain paused. R4–R6 still must prove protocol/no-Executor,
signed-App capability/helper packaging and final admission.
