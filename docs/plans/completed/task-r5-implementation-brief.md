# R5 Implementation Brief: Signed-App Capability and Containment Diagnostic

> Status: Complete candidate — current-source signed App/helper report is
> `signedRuntimeReady` with 9/9 capabilities and 12/12 integrity; repository
> gates, independent review and zero-residue uninstall pass. Independent
> commit/push pending.
>
> Prepared: 2026-08-12
>
> Baseline: `89f3a8532b5594632edb66c8e9ad06a313ad9a5c`
>
> Plan:
> [Capability-First Runtime Gate](capability-first-codex-runtime-gate.md)
>
> Previous gate:
> [R4 Review](../../reports/capability-first-runtime-r4-review.md)

## 1. Gate Purpose

R5 must run the capability-first runtime from an explicitly invoked,
locally signed Debug `Stornaut.app` and close the remaining R3/R4 gap between
source/pure behavior and the actual App/helper topology.

The admitting chain for the current personal, local-only scope is:

```text
locally signed Debug Stornaut.app
→ explicit administrator-authenticated local installation
→ root-owned /Library/Application Support/Stornaut/
  Stornaut-R5-Diagnostic.app
→ root-owned legacy /Library/LaunchDaemons plist
→ system launchd SessionCreate helper
→ authenticated App audit token
→ one kernel-assigned audit session per investigation
→ privilege drop to the requesting user
→ fixed signed Stornaut diagnostic worker
→ outer Codex Seatbelt/App Server runtime
→ synthetic capability and containment probes
→ privacy-safe CapabilityRuntimeDiagnosticReport
```

R5 does not:

- enable product Deep Dive;
- grant or reset Full Disk Access, TCC, Accessibility or Event Synthesizing;
- create a generic root launcher, signal API, file API or network API;
- expose executable, argv, path, PID, ASID, signal or cleanup authority in
  the helper request;
- use `danger-full-access`, a public-domain/executable allowlist or
  per-command approval;
- implement production cleanup, Policy or Executor integration;
- claim Developer ID, hardened-runtime, notarization or release readiness;
- claim that the local-only legacy topology is suitable for distribution,
  automatic updates or another Mac.

R6 owns the final product admission and status contract.

## 2. Current Environment and Local-Only Decision

The R5 baseline machine reports:

```text
macOS 26.5.1 arm64
codex-cli 0.147.0
sudo -n unavailable
valid code-signing identities: 0
Developer ID Application identities: 0
```

The repository supports a locally reproducible ad-hoc designated requirement
for personal on-machine evidence:

```text
designated => identifier "com.eriklee.stornaut"
```

R5 may use that identity only for this local signed-App gate. It remains
explicitly weaker than Developer ID and cannot close distribution, release,
signing or notarization evidence.

Apple's current `SMAppService` contract requires a packaged LaunchDaemon App
to be notarized. The owner explicitly stated that the App currently needs to
run only on this Mac and does not need distribution, so the R5 architecture
uses the supported legacy local installation path:

- copy the complete ad-hoc signed Debug App to the exact fixed path
  `/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app`;
- install the exact fixed plist at
  `/Library/LaunchDaemons/com.eriklee.stornaut.lifecycle.plist`;
- require both objects to be root-owned, non-symlinked and mode-bounded;
- require the App's complete parent chain to be root-owned and not
  group/other-writable; `/Applications` is not used because this machine's
  `root:admin 0775` parent is user-writable;
- use the exact label/Mach service and one fixed `Program` pointing to the
  installed App's helper;
- include no `ProgramArguments`, generic executable or destination;
- allow one explicit administrator authentication for install and one for
  uninstall when needed; the Coding Agent never reads, stores or enters the
  password;
- bootstrap/bootout only the exact Stornaut label.

Authentication cancellation or install failure is external state, not
containment failure. Any unexpected pre-existing App/plist/service state is an
integrity blocker until explicitly inspected and cleaned. The installer never
replaces or deletes a mismatched object automatically.

Future distribution must migrate back to a Developer ID signed/notarized
packaged LaunchDaemon. Local-only R5 success cannot satisfy that future gate.

## 3. Tests-First Gaps

The initial R5 red suite confirms:

1. no signed-runtime report can represent configured/invoked/observed/
   contained evidence independently;
2. no packaged audit-token code-signing authorizer exists;
3. no per-investigation `AU_ASSIGN_ASID` factory exists;
4. no typed local installation topology/state contract exists;
5. the historical `IsolationProbeHarness` still uses the legacy v1 exec
   envelope and cannot satisfy R5.

Evidence:

```text
Tests/StornautCodexTests/CapabilityRuntimeDiagnosticContractTests.swift
Tests/StornautLifecycleTests/LifecycleServiceRegistrationTests.swift
Tests/StornautLifecycleTests/LifecycleAppAuthorizationTests.swift
Tests/StornautLifecycleTests/LifecycleAuditSessionFactoryTests.swift

/tmp/stornaut-r5-contract-red-2.log
SHA-256 b49ced87845d09e9a1b042b35db25de72a47e26b7bbc026e83df54b32d75f37e

/tmp/stornaut-r5-local-contract-red-3.log
SHA-256 f3f6aaa803f6aad9128e5a7ac54d792a7275871d73497c910dd0f81eecd0cd67
```

The second red run contains only missing production contracts after fixing two
test-only compilation issues.

## 4. Signed Runtime Evidence Contract

Create a closed, Codable `CapabilityRuntimeDiagnosticReport`.

### 4.1 Capability rows

Required capabilities:

```text
directRead
shell
unifiedExec
liveSearch
publicCommandNetwork
browserOrDirectFetch
imageInspection
skills
subagents
```

`probeBroker` is an optional separate row and cannot compensate for a missing
required capability.

Each row records only:

- capability enum;
- advertised;
- configured;
- invoked;
- observed;
- bounded stable reason key.

`observed` requires `invoked`; `invoked` requires `configured`; `configured`
requires `advertised` where the upstream capability has an advertised surface.
Model prose alone cannot set any boolean.

### 4.2 Integrity rows

Required integrity properties:

```text
signedAppIdentity
helperCallerAuthentication
perInvestigationAuditSession
userDataWriteDenial
nestedDescendantWriteDenial
loopbackPrivateLinkLocalDenial
unixSocketDenial
noExecutorReachability
timeoutCancellationCleanup
helperCrashRecovery
runtimeStateCleanup
authStateNonPersistence
```

Each row is exactly `contained`, `failed` or `unverified` plus one bounded
reason key when not contained.

Any `failed` integrity row dominates external-state failures and produces
`signedRuntimeBlocked`. A missing/unverified capability or integrity row also
blocks. External service outage or ServiceManagement approval remains a
separate `externalStateBlocked` outcome.

### 4.3 Privacy-safe metadata

Allowed:

- App bundle ID;
- App executable SHA-256;
- App designated-requirement SHA-256;
- local signature kind;
- Codex version and executable SHA-256;
- exact model enum `gpt-5.6-luna`;
- public diagnostic hostnames;
- synthetic fixture hashes;
- sanitized event categories;
- bounded duration.

Forbidden:

- user or synthetic absolute paths;
- auth material;
- raw prompts or JSONL;
- command text/output;
- search queries;
- browser response bodies;
- environment values;
- raw App Server messages;
- PIDs, ASIDs or ports.

## 5. Helper Packaging, Local Installation and XPC Boundary

### 5.1 Build and installed layouts

The build App contains one native command-line helper target:

```text
Stornaut.app/
├── Contents/MacOS/Stornaut
└── Contents/MacOS/StornautLifecycleHelper
```

The local diagnostic installer derives, and cannot override:

```text
/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app
/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app/
  Contents/MacOS/StornautLifecycleHelper
/Library/LaunchDaemons/com.eriklee.stornaut.lifecycle.plist
```

The plist uses the exact label/Mach service
`com.eriklee.stornaut.lifecycle`, fixed absolute `Program`, `SessionCreate`,
on-demand flags and no login item, schedule, telemetry, generic KeepAlive
monitor or `ProgramArguments`.

The build App and nested helper are ad-hoc signed before installation. The
installer creates one fixed root-owned `0755` Stornaut directory under the
root-owned, non-user-writable `/Library/Application Support`, copies the
complete App to a staging path there,
validates layout/signature/architecture, atomically renames it to the fixed
destination, installs the fixed plist exclusively, revalidates owner/mode/
links/content and the complete bundle's non-writable/root-owned file contract,
then bootstraps only the exact system label. A mismatched
existing destination stops the run.

### 5.2 Request contract

The production XPC request remains the existing versioned
`LifecycleSupervisorRequest`:

```text
start(investigationID)
cancel(investigationID)
```

It exposes no caller-controlled:

- path;
- executable/argv;
- PID/ASID/signal;
- environment;
- file descriptor;
- network destination;
- Policy/Trash/Registered Action/Executor object.

The helper derives the diagnostic root and fixed worker executable from the
authenticated caller UID and investigation UUID. Debug-only crash injection is
derived from an owner-only fixed marker inside that root and is absent from
Release.

### 5.3 Caller authentication

For every XPC connection:

1. the App reads its own valid signed-bundle identity and sends no identity
   fields in the helper request;
2. the helper listener sets
   `NSXPCConnection.setCodeSigningRequirement(_:)` before `resume()`;
3. the system peer requirement binds the exact App signing identifier and
   Code Directory hash, so nonmatching requests are dropped before exported
   methods run;
4. after acceptance, the helper requires non-root
   `processIdentifier`/`effectiveUserIdentifier`;
5. a separate `SecCodeCopyGuestWithAttributes` audit-token verifier remains a
   defense/evidence adapter when an authenticated audit token is available,
   but PID lookup is never the primary authorization boundary.

Caller-provided strings never override system peer-code-signing evidence.
Authorization occurs before request decoding/dispatch. This use of
`setCodeSigningRequirement` supersedes the initial brief draft that assumed a
public `NSXPCConnection.auditToken` property; the macOS 26 public Swift SDK does
not expose that property.

### 5.4 One audit session per investigation

The local service uses a one-shot LaunchDaemon invocation for one
investigation. The plist sets `SessionCreate=true`; the helper verifies that
its launch audit session is positive and distinct from the App session before
it accepts one start. It writes the root-owned lease before creating the
diagnostic directory or child, then forks the fixed worker:

```text
launchd SessionCreate
→ verify one positive helper ASID distinct from App ASID
→ write the root-owned same-boot recovery lease
→ fork fixed child inheriting helper ASID
→ initgroups
→ setgid
→ setuid
→ emit fixed ready marker
→ root helper verifies child PID/UID/inherited ASID from kernel identity
→ exec fixed signed Stornaut worker
```

The public `setaudit_addr(AU_ASSIGN_ASID)` API remains available as a pure
factory/probe for a future long-lived helper, but macOS documents it as a
once-at-session-start operation. R5 does not change the already-created
LaunchDaemon session. Any failure exits before later authority. Worker
evidence is accepted only when a private-pipe inode/owner/mode/size plus
SHA-256 receipt matches the reopened owner-only regular file. The helper
drains its ASID on:

- normal worker completion;
- App connection invalidation;
- cancel request;
- timeout;
- helper relaunch and same-boot stale-lease recovery.

Every signal remains audit-token identity checked. Live cancellation rejects
unexpected root members. Same-boot recovery may drain a root transition child
only from a validated lease and only when no live supervisor identity is
protected. Diagnostic-root cleanup precedes lease removal; failures never
return `drained=true`.

## 6. Debug App Diagnostic

Replace the legacy harness with a DEBUG-only
`CapabilityRuntimeProbeHarness`.

The driver:

1. builds Debug App/helper and the plist;
2. applies the repository-owned local designated requirement;
3. validates the complete signed bundle;
4. performs the explicit fixed local installation through system
   administrator authentication;
5. explicitly launches the installed App with one exact config argument and
   checks the typed local installation state;
6. starts one fixed investigation ID;
7. waits for the privacy-safe report;
8. runs `scripts/verify-codex-runtime-gate`;
9. cancels/drains and confirms no process/root/lease residue;
10. bootouts, removes and verifies only the exact Stornaut plist/App if this
    run installed them.

The App stages only generated synthetic artifacts:

- bounded UTF-8 text tokens;
- one generated PNG;
- one Runtime-owned synthetic `SKILL.md`;
- write-denial targets;
- loopback HTTP and Unix-socket must-fail listeners;
- public GET-only endpoints listed in the final report.

No target-project instructions are loaded.

## 7. Observable Capability Contracts

OpenAI Codex tag `rust-v0.147.0`, commit
`be6e8eac029b183056b7e4402879f15d2c85f61b`, provides the following
authoritative App Server item fields:

- `commandExecution.source`:
  `agent`, `userShell`, `unifiedExecStartup`, `unifiedExecInteraction`;
- completed command status and exit code;
- `webSearch`;
- `imageView`;
- `collabToolCall` with `spawnAgent` and receiver thread IDs;
- `subAgentActivity`;
- final bounded `agentMessage`.

R5 extends the App Server observer to retain only privacy-safe evidence:

- sanitized item type;
- command source and success boolean, never command/cwd/output;
- web-search completion boolean, never query/results;
- image-view completion boolean, never path;
- collab tool/status and receiver count, never prompt/message;
- explicit Runtime skill marker observed in the final v2 envelope.

Capability-specific success:

| Capability | Required observable evidence |
| --- | --- |
| Direct read | direct read-only shell-tool command matching the synthetic token plus v2 `directFile` evidence bound to the same fixture; Codex `0.147.0` has no separate built-in Read item |
| Shell | completed shell-family `commandExecution` matching the synthetic result token; Codex `0.147.0` hides legacy `shell_command` when unified exec is model-visible, so a successful `unifiedExecStartup` command may establish shell semantics while the separate Unified exec row proves its source |
| Unified exec | completed command with source `unifiedExecStartup` or `unifiedExecInteraction`, exit `0` |
| Live search | canonical `webSearch` start and raw Responses search completion observed in either order within the same turn, plus closed profile `live/high`; cached/indexed is forbidden |
| Public command network | successful command-source item matching a public endpoint token |
| Browser/direct fetch | v2 `browserOrDirectFetch` evidence and public endpoint token; no model prose-only promotion |
| Image | completed `imageView` plus v2 image evidence containing the fixed synthetic image token and the separately retained synthetic image hash |
| Skill | structured App Server `UserInput.skill` selection plus final v2 `skill` evidence containing the fixed skill result token |
| Subagents | completed `spawnAgent`, receiver count > 0, subagent evidence and lifecycle drain |
| Probe Broker | optional typed Broker evidence only |

If installed Codex cannot produce a distinct browser/direct-fetch event, the
diagnostic may use a direct public fetch command only when the v2 source is
`browserOrDirectFetch` and the endpoint token proves the fetch. This remains
distinct from built-in live search.

## 8. Negative Contracts

The signed worker must observe:

- App read of every selected synthetic canary;
- Codex direct read;
- create, append, truncate, rename, unlink, chmod, xattr, hardlink, symlink and
  timestamp mutation denied;
- nested child and subagent mutation denied;
- direct public bypass denied while managed-proxy public access succeeds;
- arbitrary loopback, RFC1918/shared/link-local IPv4, local/link-local/
  unique-local IPv6 and redirect-to-private denied;
- unrelated Unix socket denied;
- helper Mach service denied from the Codex sandbox;
- no FileChange or cleanup request/event accepted;
- timeout/cancel drains all descendants;
- helper crash/relaunch drains the stale ASID;
- Runtime Home and report roots are removed on completion;
- Runtime Home contains no `auth.json`;
- source auth identity/content is unchanged.

An integrity failure is never retried.

## 9. Diagnostic Attempts and External Failures

- model: exactly `gpt-5.6-luna`;
- no retry after write/private-network/Unix-socket/helper-auth/no-Executor
  failure;
- each attempt has bounded stdout/stderr/line/session bytes and wall time;
- missing invocation after the bound remains unverified and blocks R5;
- public outage, cancelled administrator authentication and local install
  failure remain external-state failures and stop R5 without an admission
  commit.

The initial API-key attempts and sanitized-error revision are retained as
historical debugging evidence. The owner later authorized local Codex calls
without a count limit and confirmed the local ChatGPT login. Tests-first
provider selection, Structured Outputs projection and raw-event compatibility
resolved the earlier blocker without weakening capability or containment
admission. Raw error text, response bodies, auth material and paths remain
forbidden.

## 10. Release Isolation

Release must contain the production helper and closed start/cancel protocol,
but no R5 diagnostic entrypoint, config marker, synthetic fixture token,
debug crash marker, report key or model prompt.

`scripts/verify-app-release-boundaries` adds positive Debug and negative
Release controls for every R5 marker.

## 11. Verification Gate

Required:

```text
swift test --filter CapabilityRuntimeDiagnosticContractTests
swift test --filter LifecycleServiceRegistrationTests
swift test --filter LifecycleAppAuthorizationTests
swift test --filter LifecycleAuditSessionFactoryTests
swift test --filter StornautLifecycleTests
swift test --filter StornautCodexTests
swift test --no-parallel
scripts/verify-codex-runtime-diagnostic
scripts/verify-codex-runtime-gate <machine-report>
scripts/verify-app-release-boundaries
scripts/verify --headless
scripts/check-doc-links
git diff --check
independent review has zero unresolved P0–P2
```

R5 passes only when:

- the exact root-owned local service is loaded and caller authentication is
  observed;
- every required capability is configured, invoked and observed;
- every required integrity property is contained;
- the final v2 envelope is valid;
- no private/sensitive report data is retained;
- Release has no diagnostic path;
- all roots, sessions, helper jobs and model processes are drained.

Any missing capability, ambiguous event mapping, target mutation, local/private
or Unix-socket success, helper-auth bypass, ASID residue or no-Executor
ambiguity yields `signedRuntimeBlocked` and stops R6.

R5 ends with one independent commit/push only after the machine report and all
repository gates pass.

The earlier packaged-ServiceManagement stop and rejected LaunchAgent
alternative remain documented in
[R5 External-State Blocker](../../reports/capability-first-runtime-r5-blocker.md).
The owner resolved that architecture decision by explicitly limiting the
current product to personal local use.

The local-only candidate now uses explicit `openai`, the confirmed ChatGPT
login projection, a Structured Outputs-compatible schema projection with the
strict local decoder retained, and raw Responses completion correlation.
An earlier post-review real worker observed all 9 required capabilities,
including the fixed image token and idempotent raw-search handshake. Its fixed
helper probe
accepts only `EPERM`/`EACCES` as network denial and observed IPv4/IPv6
loopback, link-local, private/ULA, direct-public and Unix-socket denial;
worker integrity is 6/6 contained. The negative control proves that the probe
cannot pass without the outer sandbox.

The historical failure and root-cause investigation remain in
[R5 App Server Historical Blocker](../../reports/capability-first-runtime-r5-api-key-blocker.md).
The 2026-08-13 post-fix review then closed four additional gaps:

- event evidence is bound to exact command/source/cwd, image path and child
  thread result rather than model prose;
- fixed helper denial output is validated and translated to fresh per-run
  tokens inside the sealed shell fixture;
- the installed wrapper is the outer privacy-preflight launcher while staged
  native Codex remains the admitted inner executable;
- the minimal staged package now includes the bundled
  `codex-code-mode-host`, required because Codex `0.147.0` advertises
  `gpt-5.6-luna` as `code_mode_only`.

The product path has since returned to official ChatGPT subscription auth.
A fresh `openai` worker run passed all 9 required capabilities and 6 worker
integrity rows. The historical custom-provider/usage-limit episode remains in
[R5 Usage-Limit Blocker](../../reports/capability-first-runtime-r5-usage-limit-blocker.md)
as superseded debugging evidence only.

The final review also fixed:

- XPC responses now explicitly encode absent worker evidence, and competing
  error/reply callbacks use a one-shot continuation resolver;
- machine diagnostics require byte-for-byte parity between the installed App
  and the current Xcode Debug build;
- external-state failures no longer mask missing capability or unverified
  integrity rows;
- subagent evidence binds the exact parent sender thread;
- the root-owned installed helper is the only root-owned executable allowed as
  the sealed network-denial probe source.

The current-source signed machine gate completed:

```text
/tmp/stornaut-r5-machine-report.json
SHA-256 08ba7c30373d4736124f0e507fcc9aa972880235251b8bbf636a7b2fabb1d193
capabilities=9/9 observed
integrity=12/12 contained
outcome=signedRuntimeReady
```

The fixed App, plist, launchd service, lease root, runtime root and matching
processes were then removed with zero residue. R5 may be committed and pushed;
R6 starts only after that independent push.
