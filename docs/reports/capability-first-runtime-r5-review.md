# Capability-First Runtime R5 Review

> Status: `signedRuntimeReady`; current-source signed App/helper gate,
> repository gates, independent review and zero-residue uninstall complete
>
> Date: 2026-08-13
>
> Baseline: `89f3a8532b5594632edb66c8e9ad06a313ad9a5c`

## 1. Scope

R5 implements the personal-local signed runtime evidence gate:

- a fixed root-owned Debug App and LaunchDaemon topology;
- exact App/helper code-signing admission;
- one launchd-created audit session per investigation;
- privilege drop before the worker;
- official `openai` + ChatGPT subscription auth projection from the
  owner-only source `auth.json`;
- outer Codex containment, staged native package and synthetic capability
  fixtures;
- privacy-safe capability, integrity and machine reports;
- Debug-only diagnostic entry points with Release exclusion;
- exact uninstall and zero-residue checks.

R5 does not enable production Deep Dive, Executor, cleanup actions,
Developer ID distribution, notarization, TCC mutation or arbitrary local
network access.

## 2. Current Runtime Evidence

The current official subscription path is:

```text
provider=openai
model=gpt-5.6-luna
auth=ChatGPT subscription projection
```

A fresh real worker and the current-source installed signed App completed:

- 9/9 required capabilities observed;
- 6/6 worker integrity properties contained;
- 12/12 assembled integrity properties contained, including signed App
  identity, helper caller authentication, per-investigation audit session,
  timeout/cancellation cleanup, helper crash recovery and no-Executor;
- IPv4/IPv6 loopback, private, link-local, ULA and Unix-socket denial;
- direct-public bypass denial with managed-proxy public access;
- exact image token, selected skill marker and sender-bound subagent result;
- canonical/raw live-search completion;
- Runtime Home cleanup and no persisted auth file.

The historical TeamoRouter and `usageLimitExceeded` episode is retained only
as superseded debugging evidence. It is not an admitted product provider and
is not the current blocker.

## 3. Independent Review

`bits-code-guard` reviewed the complete workspace diff:

- 58 changed files;
- 45 code/config/script files reviewed;
- about 20k changed lines;
- seven general dimensions across auth/App Server, containment/worker,
  root lifecycle/XPC and installer/verifier/Release boundaries;
- no repository custom workflow was configured.

Report artifacts:

```text
/tmp/stornaut_r5_review/report.html
/tmp/stornaut_r5_review/report.md
```

The review found four P1 issues, all fixed:

| Finding | Fix | Regression evidence |
| --- | --- | --- |
| Machine diagnostic accepted any valid fixed installed App, not necessarily the current Xcode build | Require byte-for-byte bundle parity between built and installed Apps before model execution | Release boundary static gate plus final machine script |
| XPC error and reply callbacks could race and resume one checked continuation twice | Add a lock-protected one-shot reply resolver | connection-first/reply-first focused tests |
| External-state reasons masked missing capability or unverified integrity rows | Make all missing/unverified evidence produce `signedRuntimeBlocked` before external state | combined-outcome contract test |
| Subagent result evidence did not bind `senderThreadId` to the parent thread | Require exact parent sender identity | wrong-sender negative test |

Additional tests-first repairs during the live signed-path setup:

- explicit null encoding for absent XPC worker evidence;
- closed worker failure receipts without paths, errno, prompts or auth;
- exact root-owned installed-helper exception for the network-denial probe;
- separate image, skill and subagent model sessions;
- `agentsStates` result binding for completed subagents;
- cleanup digest calculation before workspace deletion;
- exited-but-unreaped processes now map to `ESRCH` only when a second public
  `proc_pidinfo` check confirms that no live process remains; a live but
  unreadable identity still fails closed;
- capability-group schemas remove `$ref` before adding closed `enum`
  identities, matching the provider-accepted strict-schema shape;
- direct-read command evidence accepts only four fixed `cat` path spellings
  and keeps the generic anti-forgery matcher unchanged.

Current unresolved review findings: **0 P0, 0 P1, 0 P2**.

## 4. Verification

Passed on the admitted current source:

```text
focused StornautCodexTests: 235 passed
focused StornautLifecycleTests: 60 passed
real provider/catalog preflight: openai, gpt-5.6-luna advertised
real base and capability-group v2 schema diagnostics: passed
real official worker: 9/9 capabilities, 6/6 worker integrity
serial swift test --no-parallel: 537 passed
scripts/verify --headless:
  selected SwiftPM 534 passed
  source/localization/verifier/docs/rules/App contracts passed
scripts/verify-codex-no-executor-boundary: passed
scripts/verify-app-release-boundaries: passed
scripts/check-doc-links: passed
git diff --check: passed
scripts/verify-codex-runtime-diagnostic: passed
scripts/verify-codex-runtime-gate: passed
post-machine uninstall and zero-residue proof: passed
```

Post-review targeted `bits-code-guard` evidence:

```text
/tmp/stornaut_r5_postfix_review/report.html
/tmp/stornaut_r5_postfix_review/report.md
```

It found no additional P0–P2 across the lifecycle identity, group-schema and
fixed direct-read command repairs.

## 5. Signed Machine Result

The installed App was byte-for-byte equal to the current Xcode Debug build.
The signed App/helper produced the privacy-safe machine report:

```text
/tmp/stornaut-r5-machine-report.json
SHA-256 08ba7c30373d4736124f0e507fcc9aa972880235251b8bbf636a7b2fabb1d193
schemaVersion=2
provider=openai
model=gpt-5.6-luna
signatureKind=adHoc
capabilities=9/9 observed
integrity=12/12 contained
outcome=signedRuntimeReady
```

`scripts/verify-codex-runtime-gate` first exposed that the shell-side metadata
check expected a string although Swift's synthesized Codable representation is
`{"signedRuntimeReady":{}}`. The Swift verifier had already reconstructed the
report and rejected every non-ready outcome. The shell check was corrected to
the canonical Codable shape and a Release/static regression gate now pins it.

After the gate passed, the fixed App, plist, launchd service, lease root,
runtime root and matching processes were removed. The final local status is
`administratorInstallRequired`, meaning no R5 installation remains.

## 6. Gate Result

- R5 outcome: `signedRuntimeReady`;
- unresolved P0/P1/P2: 0/0/0;
- current-source App binding: passed;
- signed capabilities: 9/9 observed;
- signed integrity: 12/12 contained;
- uninstall and zero residue: passed;
- production Deep Dive: still unavailable;
- R6: may begin only after this R5 commit is pushed;
- Task 29: remains paused until R6 completes.
