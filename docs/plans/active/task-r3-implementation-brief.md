# R3 Implementation Brief: OS Containment, Runtime Home and Auth Projection

> Status: Stopped — behaviorBlocked/no-go at the R3 lifecycle hard gate
>
> Prepared: 2026-08-12
>
> Baseline: `1af81872b745cc819dda1e5cac1de88e9c954f49`
>
> Plan:
> [Capability-First Runtime Gate](capability-first-codex-runtime-gate.md)
>
> Previous gate:
> [R2 Review](../../reports/capability-first-runtime-r2-review.md)

## 1. Gate Purpose

R3 is the hard security gate. It turns the R2 configuration candidate into a
behaviorally proved runtime boundary:

```text
trusted Swift parent
→ owner-only ephemeral Runtime Workspace
→ Codex-managed single HTTP proxy on a random loopback port
→ one outer macOS Seatbelt sandbox for the complete Codex process tree
→ closed App Server driver with programmatic externalSandbox turns
```

The outer sandbox, not model instructions or the inner tool wrapper, enforces:

- the ADR 0004 investigation surface remains full-disk read-only;
- only the private Runtime Home is writable;
- projected auth is unreadable to Codex tools and descendants;
- public traffic can leave only through the same-process managed proxy;
- direct public, localhost, private, link-local and Unix-socket traffic fails;
- every shell, skill, browser worker and subagent-shaped descendant inherits
  the same boundary.

R3 does not:

- implement Investigation Envelope v2 or Policy/Executor seams;
- enable product Deep Dive;
- claim signed-App FDA/TCC inheritance;
- enable browser/image/subagent product behavior;
- create cleanup, Trash or Registered Action paths.

The candidate did not pass this gate. The checked-in lifecycle probe proved
that a sandboxed descendant can leave the investigation process group with
both direct `setsid()` and `POSIX_SPAWN_SETSID`. A temporary launchd user job
also failed to reclaim the new-session descendant after its leader exited.
R3 therefore stops as `behaviorBlocked`; the implementation candidate was
removed rather than admitted with an unproved crash/cancellation boundary.

## 2. Measured Upstream Facts

Source snapshot:

```text
OpenAI Codex tag rust-v0.147.0
commit be6e8eac029b183056b7e4402879f15d2c85f61b
Apache-2.0
```

Inspected files include:

```text
codex-rs/cli/src/debug_sandbox.rs
codex-rs/config/src/permissions_toml.rs
codex-rs/core/src/config/permissions.rs
codex-rs/login/src/auth/manager.rs
codex-rs/login/src/auth/storage.rs
codex-rs/network-proxy/src/policy.rs
codex-rs/network-proxy/src/proxy.rs
codex-rs/protocol/src/permissions.rs
codex-rs/app-server/src/external_auth.rs
codex-rs/app-server/src/request_processors/account_processor.rs
codex-rs/app-server-protocol/src/protocol/v2/account.rs
codex-rs/app-server-protocol/src/protocol/v2/permissions.rs
codex-rs/app-server-protocol/src/protocol/v2/thread.rs
codex-rs/app-server-protocol/src/protocol/v2/turn.rs
```

Measured conclusions:

1. `codex sandbox` starts the Codex-managed proxy outside Seatbelt, reserves
   loopback port `0`, injects its proxy environment, then executes the supplied
   child under the generated Seatbelt profile.
2. macOS rejects nested `sandbox-exec` with `Operation not permitted`.
3. `external-sandbox` is intentionally unavailable in `config.toml`/CLI, but
   is supported by App Server `turn/start` and `command/exec`.
4. App Server `chatgptAuthTokens` stores external access tokens only in the
   process-local ephemeral auth store and requests refresh from the host.
5. normal ChatGPT auth may proactively refresh and persist `auth.json`; R3
   therefore cannot copy the complete auth payload or give Codex direct access
   to the normal user home.
6. `enable_socks5` defaults on. The approved transport exception permits one
   random loopback listener, so R3 explicitly sets it to `false`.
7. `:minimal` is rejected for this candidate because Codex `0.147.0` also
   grants write access to `/tmp`, `/private/tmp`, `/var/tmp` and
   `/private/var/tmp` in that platform-default block. R3 keeps the approved
   full-disk read-only base and narrows writes to the Runtime Home; it does not
   add an Agent read-path denylist beyond the projected auth source.

## 3. Fixed Architecture

### 3.1 Trusted parent

Swift performs all pre-sandbox work:

- locate and revalidate the installed Codex executable;
- create a private Runtime Workspace;
- read the existing user auth through a closed projection interface;
- retain only the access token, account ID and optional plan type in memory;
- never copy the ID token, refresh token, API key, auth file or keyring item;
- launch `codex sandbox` as the process-group leader;
- drive only the closed App Server sequence;
- answer an auth refresh request only through the same closed projection
  interface;
- destroy projected auth bytes and the Runtime Workspace after exit.

### 3.2 Runtime Workspace

One owner-only root contains:

```text
home/       empty synthetic HOME
runtime/    CODEX_HOME and the only writable root
work/       empty non-project App Server cwd
schema/     copied immutable output schema
fixtures/   selected synthetic/investigation read roots
```

Requirements:

- all directories use mode `0700`;
- generated config/schema/skill files use mode `0600`;
- no component is a symlink;
- all paths are canonical, pairwise disjoint where required and outside the
  normal user home, user Codex home and selected investigation roots;
- creation is exclusive and UUID-named;
- stale workspaces are deleted only when owner/mode/marker/age checks pass;
- cleanup never follows symlinks and never accepts an arbitrary caller path;
- raw JSONL, auth values and private content are not persisted.

### 3.3 Outer containment profile

The generated config selects one closed profile:

```toml
default_permissions = "stornaut-outer-v1"
cli_auth_credentials_store = "ephemeral"

[permissions.stornaut-outer-v1.filesystem]
"<projected auth source>" = "deny"
"<runtime home>" = "write"

[permissions.stornaut-outer-v1.network]
enabled = true
mode = "full"
enable_socks5 = false
allow_local_binding = false
dangerously_allow_non_loopback_proxy = false
dangerously_allow_all_unix_sockets = false

[permissions.stornaut-outer-v1.network.domains]
"*" = "allow"
```

The exact profile also retains R2 capability settings and all plugin/App/MCP
disables. It contains no:

- `danger-full-access`;
- fixed proxy URL or port;
- upstream proxy credential;
- MITM hook/header injection;
- Unix-socket allow entry;
- public destination or executable allowlist;
- per-command approval.

### 3.4 App Server driver

Production execution changes from direct `codex exec` to one fixed stdio App
Server session inside the outer sandbox:

```text
initialize(experimentalApi=true)
initialized
account/login/start(chatgptAuthTokens)
thread/start(ephemeral=true, model=gpt-5.6-luna)
turn/start(
  approvalPolicy=never,
  sandboxPolicy=externalSandbox(networkAccess=enabled),
  outputSchema=<closed schema>
)
observe bounded notifications
EOF / interrupt / process-group cleanup
```

No generic JSON-RPC method/parameter API is exposed. Unexpected server
requests, notifications, IDs, tool items, auth refresh frequency or protocol
ordering fail closed.

The driver never calls:

```text
process/spawn
fs/writeFile
fs/createDirectory
fs/remove
skills/config/write
plugin/install
plugin/uninstall
account/logout
command/exec with caller-supplied argv
```

R4 will version the output protocol and no-Executor seam. R3 uses the existing
closed synthetic schema only for containment diagnostics.

## 4. Environment Contract

The trusted parent constructs a typed environment:

- `CODEX_HOME`, `HOME`, `TMPDIR`: generated private paths;
- `PATH`: absolute, canonical directory entries only, ordered, deduplicated,
  bounded by count and bytes; this is not an executable allowlist;
- locale/terminal: bounded `LANG`, `LC_ALL`, `LC_CTYPE`, `TERM`;
- trust-store variables: only closed certificate path variables whose values
  are absolute regular files and not beneath the user home;
- no loader injection: `DYLD_*`, `LD_*`, `RUSTC_WRAPPER`, `NODE_OPTIONS`,
  `PYTHONPATH`, `RUBYOPT`, `BASH_ENV`, `ENV`, `ZDOTDIR`;
- no API/cloud/GitHub tokens, SSH agent socket, arbitrary proxy variables,
  unrelated app/session variables or inherited `CODEX_*`.

Codex's managed proxy overwrites proxy variables for sandboxed descendants.
The trusted parent does not pass a localhost proxy itself.

## 5. Authentication Contract

The closed projection accepts only the currently measured ChatGPT file-auth
shape:

```text
auth_mode == chatgpt
tokens.access_token: nonempty JWT
tokens.account_id: nonempty UUID/string
tokens.id_token: ignored
tokens.refresh_token: ignored
optional plan type: derived from bounded non-secret metadata only
```

The projection:

- opens `auth.json` with `O_NOFOLLOW`;
- checks owner, mode, regular-file type, size and descriptor identity;
- parses with a byte bound;
- never logs or hashes auth bytes;
- stores projected values in a non-Codable value whose description is
  redacted;
- zeroizes mutable token buffers on release where Swift permits;
- injects the access token only into the App Server request pipe;
- never writes an auth file into the Runtime Home;
- treats 401 refresh as an external-state gate: the parent may re-read a fresh
  access token once from the same identity-bound source, otherwise the
  investigation fails closed.

API-key, keyring, Agent Identity, PAT, Bedrock and missing/malformed auth are
`authenticationBlocked` in R3, not silent fallback.

## 6. Tests First

Create:

```text
Tests/StornautCodexTests/CodexContainmentPolicyTests.swift
Tests/StornautCodexTests/CodexRuntimeEnvironmentTests.swift
Tests/StornautCodexTests/CodexRuntimeWorkspaceTests.swift
Tests/StornautCodexTests/CodexRuntimeAuthProjectionTests.swift
Tests/StornautCodexTests/CodexAppServerRuntimeTests.swift
Tests/Fixtures/CodexContainment/
```

### 6.1 Pure contract tests

Prove:

- exact deterministic config bytes and digest;
- one `enable_socks5=false` listener expression;
- no forbidden profile/config surface;
- exact environment allow/reject behavior and bounds;
- workspace modes, topology, marker and cleanup;
- stale cleanup rejects symlink, wrong owner/mode/marker and fresh roots;
- auth parser accepts only the closed shape;
- auth errors/log descriptions contain no secret;
- fixed App Server request ordering and `externalSandbox`;
- no generic RPC, command, filesystem-write or Executor surface.

### 6.2 Anonymous behavioral diagnostic

Use `codex sandbox` and only disposable `/tmp` fixtures. Verify direct child,
nested shell, skill-shaped script and subagent-shaped descendant attempts:

Filesystem:

- selected fixture read succeeds;
- Runtime Home write succeeds;
- create/overwrite/append/truncate/rename/exchange/unlink/rmdir/chmod/chown/
  xattr/flags/timestamp/hardlink/symlink/symlink escape outside Runtime Home
  fail;
- normal home, normal Codex home, App documents and auth projection are
  unreadable/unwritable;
- inherited/open descriptors do not add authority;
- relative, case/Unicode, replacement and mount-boundary variants fail;
- post-state identities and bytes remain unchanged.

Network:

- exactly one nonzero random HTTP proxy listener is exposed;
- public DNS/TLS through the proxy succeeds;
- direct public bypass fails;
- `127.0.0.0/8`, `::1`, IPv4/IPv6 link-local, RFC1918, CGNAT, IPv6 ULA,
  mapped IPv6, multicast/broadcast and arbitrary local bind fail;
- hostname/CNAME/redirect/rebinding to blocked addresses fail;
- filesystem and abstract/path-aliased Unix sockets fail;
- proxy crash/fallback fails closed.

Lifecycle:

- eight-way concurrent launch;
- grandchild descriptor holder;
- browser/worker-shaped descendant;
- network timeout;
- cancellation during fan-out;
- output/event overflow;
- no surviving process/listener/workspace.

### 6.3 External auth/App Server diagnostic

Opt in separately. It may use the user's existing login only through the
closed auth projection and must use synthetic files/endpoints. It proves:

- external auth login succeeds without creating `runtime/auth.json`;
- projected refresh token and ID token never enter Runtime Home, environment,
  JSONL, logs or report;
- App Server `command/exec` with `externalSandbox` inherits the outer boundary;
- a synthetic real-model turn can be initialized for later R5 without
  expanding filesystem/network authority.

R3 does not set product capability `observed` from this diagnostic; R5 owns
signed-App capability observation.

## 7. Review and Verification Gate

Review dimensions:

- filesystem race/symlink/mount escape;
- network address, DNS and redirect coverage;
- proxy identity and single-listener lifecycle;
- auth leakage, refresh and zeroization;
- App Server request-surface closure;
- process group, cancellation, descriptor and cleanup behavior.

Required:

```text
focused R3 pure tests pass
anonymous containment diagnostic passes
external-auth App Server diagnostic passes or R3 stops as no-go
complete StornautCodexTests pass
full serial swift test passes
Xcode App tests/build/bundle pass
scripts/verify --headless passes
scripts/check-doc-links passes
git diff --check passes
review has zero unresolved P0–P2
```

R3 succeeds only as `behaviorReady`. Any missing required evidence,
unsupported external auth, extra loopback listener, write/network escape,
secret leak or cleanup ambiguity yields `behaviorBlocked`, records a no-go
review and stops R4–R6.

Success ends with one independent commit/push. It does not start R4 until that
push and remote-state check complete.

## 8. Measured No-Go Outcome

Final anonymous probe:

```text
scripts/probe-codex-r3-lifecycle-escape
/tmp/stornaut-r3-lifecycle-escape-probe-final.log
SHA-256 f25700e0e35178910cda4809468ea1aa37a9936abaec4100fb6b74e49fde3557
```

Observed on Apple Silicon macOS with installed `codex-cli 0.147.0`:

```text
lifecycle.direct_setsid_escape=observed
lifecycle.posix_spawn_setsid_escape=observed
lifecycle.launchd_job_escape=observed
lifecycle.cleanup=complete
probe.verdict=behaviorBlocked
```

Interpretation:

1. the current process-group terminator cannot reach a descendant after that
   descendant creates a new POSIX session;
2. adding Seatbelt denies for `SYS_setsid` and `SYS_setpgid` is insufficient
   because `posix_spawn(..., POSIX_SPAWN_SETSID)` still creates the new
   session;
3. launchd's default process-group cleanup does not reclaim that new-session
   descendant;
4. modern macOS marks recursive kqueue `NOTE_TRACK` process tracking
   unsupported, and no supported parent-death signal or public per-
   investigation process-container API was found;
5. private coalition APIs, Endpoint Security monitoring, a privileged daemon
   or permission expansion are outside this approved candidate and were not
   introduced.

The probe itself owns only anonymous `/private/tmp` fixtures, gives every
helper a bounded lifetime and force-cleans every recorded PID and temporary
launchd label before reporting `lifecycle.cleanup=complete`.

Positive pre-blocker evidence remains useful but cannot override the hard
failure:

- the outer Seatbelt candidate denied target writes;
- the managed proxy allowed public HTTPS while direct public, arbitrary
  loopback and Unix-socket attempts failed;
- external App Server authentication worked with `gpt-5.6-luna` without a
  Runtime Home `auth.json`.

Those observations prove neither cancellation nor crash cleanup. The
unresolved descendant escape is a P1 containment defect, so no R3 production
runtime code, R4 protocol work, R5 signed-App admission or R6 final admission
is retained or started.
