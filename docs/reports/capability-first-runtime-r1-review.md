# Capability-First Runtime R1 Review

> Status: Passed as conditional-go evidence; R2 remains blocked
>
> Date: 2026-08-11
>
> Scope: upstream study, ADR 0013, anonymous sandbox probe and routing docs

## 1. Review Scope

Reviewed:

```text
scripts/probe-codex-sandbox-containment
docs/upstream-studies/epic-5-capability-first-runtime.md
docs/adr/0013-capability-first-runtime-containment.md
docs/plans/active/task-r1-implementation-brief.md
all R1 routing/status updates
```

Cross-checked against:

- installed Codex CLI/help/features/vendor binary;
- upstream `rust-v0.147.0` commit
  `be6e8eac029b183056b7e4402879f15d2c85f61b`;
- current macOS SDK `sandbox.h`;
- `sandbox-exec(1)` and `sandbox_init(3)`;
- Apple App Sandbox Markdown documentation;
- actual anonymous Seatbelt command results.

## 2. Confirmed Findings and Corrections

### 2.1 Bare network-enabled read-only profile reaches local services

**Severity:** P1 boundary violation
**Disposition:** Rejected candidate

Public, loopback, private and Unix-socket canaries were all reachable. R1 now
requires managed proxy containment; `network.enabled=true` alone can never pass.

### 2.2 Managed proxy needs one loopback connection

**Severity:** P1 product-boundary ambiguity
**Disposition:** R2 blocked pending explicit decision

The proxy is the only observed route that gives unrestricted public domains
while blocking arbitrary local/private targets. The exception is stated
precisely and is not silently approved by R1.

### 2.3 `--ephemeral` still writes substantial runtime state

**Severity:** P1 containment architecture
**Disposition:** Plan corrected

The design now requires a Stornaut-owned ephemeral writable Runtime Home and
does not claim a zero-write Codex process. User/investigation data stays
read-only.

### 2.4 Browser feature flags were being overinterpreted

**Severity:** P1 capability evidence
**Disposition:** Corrected

Browser Use is desktop/connector-backed. It remains advertised/unverified until
R5 signed-App evidence.

### 2.5 Existing user config cannot be inherited

**Severity:** P1 configuration integrity
**Disposition:** Confirmed

The current user config contains full-access, plugins/hooks, project trust and
local provider state. Isolated config remains mandatory.

### 2.6 Isolated auth cannot be assumed

**Severity:** P1 credential boundary
**Disposition:** Assigned to R3

`--ignore-user-config` still resolves auth from selected `CODEX_HOME`. R1
rejects symlink/direct access to the original auth store; a bounded ephemeral
projection needs threat analysis and tests.

### 2.7 Initial probe harness used zsh `status`

**Severity:** P2 experiment correctness
**Disposition:** Fixed before checked-in script

`status` is a zsh read-only special parameter. The ad-hoc harness was corrected
to use a normal exit variable and rerun. The checked-in probe does not use it.

### 2.8 Initial network harness passed literal `\n`

**Severity:** P2 experiment correctness
**Disposition:** Fixed before checked-in script

The ad-hoc command string did not contain actual line breaks. The final probe
writes a synthetic script file and verifies it under Seatbelt.

### 2.9 Probe needed direct network bypass cases

**Severity:** P1 containment completeness
**Disposition:** Added

The final probe includes `curl --noproxy '*'`. Managed mode blocks direct
public, loopback and private connections while normal proxied public access
succeeds.

### 2.10 App Sandbox could not be claimed as a drop-in fix

**Severity:** P2 architecture supportability
**Disposition:** Corrected

Apple documents entitlement/container/security-scope behavior and user-granted
FDA. Current Stornaut disables App Sandbox. XPC/App Sandbox remains a separate
future spike, not an R1 assumption.

### 2.11 Signal cleanup relied on multi-signal trap fallthrough

**Severity:** P2 diagnostic cleanup robustness
**Disposition:** Fixed

The final script keeps `cleanup` on `EXIT` and maps `INT`/`TERM` to explicit
exit codes. Listener processes and the synthetic root are therefore cleaned by
one deterministic path.

### 2.12 TCP canary initially bound all interfaces

**Severity:** P2 diagnostic exposure
**Disposition:** Fixed

The final probe uses separate listeners bound only to `127.0.0.1` and the
current private interface. It no longer opens one `0.0.0.0` listener while
testing both address classes.

## 3. Probe Review

The checked-in probe:

- has `set -euo pipefail`;
- verifies Codex is executable;
- uses `mktemp` under `/tmp`;
- installs cleanup traps;
- never reads the normal user Codex home;
- creates no credential;
- uses only synthetic text plus disposable TCP/private-address and Unix-socket
  listeners;
- checks post-state hashes/modes/timestamps;
- covers nested descendant writes;
- distinguishes proxy versus no-proxy network;
- validates restricted/open/managed expected matrices;
- fails on any unexpected allow/deny;
- leaves no persistent fixture.

No shell string is sourced from user/model input.

## 4. Final Result

- P0: 0;
- P1 unresolved implementation bugs: 0;
- P2 unresolved plan/evidence bugs: 0;
- product decision pending: one exact dedicated loopback proxy exception.

R1 is complete and ready for an independent commit/push. R2 remains blocked.

## 5. Verification

Final no-model containment probe:

```text
scripts/probe-codex-sandbox-containment
/tmp/stornaut-r1-containment-probe-final-2.log
SHA-256 2c5625b6f94164cc4c238fcd24a3b53d9104b84a340a0e2a9c0a161fb1c3c857
```

Final observed evidence:

- read allowed;
- 13 mutation/escape/descendant classes blocked;
- restricted network blocks all;
- bare enabled network reaches public and local/private/Unix targets;
- managed network reaches public only through proxy;
- direct public/local/private bypass fails;
- managed Unix socket fails.

Existing Codex focused suite:

```text
64 test entries completed successfully; two opt-in installed/real diagnostics skipped
/tmp/stornaut-r1-codex-tests-isolated.log
SHA-256 bf32eb059ddccf8c29be858f0d5bf62f8d140d0829c6956a9cfcc3d9dbabedeb
```

The first focused suite ran concurrently with the live network probe and the
existing eight-way spawn test reached its five-second timeout. The same test
passed alone in 1.36 seconds, passed inside the independently rerun complete
Codex suite in 3.17 seconds, and then passed ten serial stress iterations:

```text
10/10 passed
/tmp/stornaut-r1-concurrent-spawn-stress.log
SHA-256 a891a55bb12d16d93ecebe9c3a598ff484a836e23c4b702d13b09fc9ee608c45
```

No fake child, containment root or listener remained. Because R1 changes no
Swift source and the isolated/stress reruns passed, the concurrent failure is
recorded as external load sensitivity rather than a product regression.

Documentation gate:

```text
scripts/check-doc-links
git diff --check
zsh -n scripts/probe-codex-sandbox-containment
```

No full product build is required because R1 changes no Swift/App/runtime code.
The final repository validation still runs the focused probe and existing
offline Swift tests applicable to the unchanged product baseline.

The supporting `bits-code-guard` workflow filtered Markdown incorrectly and
does not include untracked files by default. All 16 tracked/untracked R1 files
were therefore manually reviewed under the same seven dimensions. No
repository-specific custom workflow was configured. The generated local report
is:

```text
/tmp/stornaut_r1_review_1786439708/report.html
```
