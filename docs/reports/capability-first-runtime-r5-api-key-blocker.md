# Capability-First Runtime R5 Historical App Server Blocker

> Status: Resolved by later tests-first provider/schema/raw-event diagnostics;
> historical evidence retained
>
> Date: 2026-08-12
>
> Gate: synthetic `gpt-5.6-luna` App Server capability diagnostic

## 1. Stop Reason

The owner clarified that Stornaut currently needs to run only for personal use
on this Mac. R5 therefore replaced the notarization-blocked packaged
LaunchDaemon candidate with the approved local-only topology documented in ADR
0016.

Before installing the privileged topology, the same fixed worker façade was
run directly against synthetic fixtures to validate the App Server/model
protocol. During the first two attempts, the installed Codex authentication
source used the closed API-key shape:

```text
top-level key: OPENAI_API_KEY
no ChatGPT token object
```

The installed Codex `0.147.0` generated protocol schema confirms:

```json
{
  "type": "apiKey",
  "apiKey": "<redacted>"
}
```

Stornaut added tests-first API-key projection and App Server login support. The
key remains memory-only, is never written to Runtime Home or reports, and is
erased with the existing App Server credential lifecycle.

Two effective, bounded, synthetic `gpt-5.6-luna` diagnostic attempts were then
allowed. Both reached the App Server turn and were rejected by an upstream
`error` notification. The stable pre-revision Stornaut reason was:

```text
runtime.worker.protocol.appServer.notification.error
```

The raw upstream error body was intentionally not retained or printed because
the R5 report contract forbids raw App Server messages and arbitrary output.

The owner subsequently approved one narrow diagnostic-protocol revision and
one additional bounded attempt. Tests-first implementation now retains only:

- a closed upstream category;
- an optional unsigned 16-bit HTTP status code;
- `willRetry`.

Raw error message, additional details, response body, credentials, private
paths, prompts and model output remain discarded. Unknown categories degrade
to `unclassified`; malformed metadata fails closed.

Before the additional attempt, the external Codex auth source had changed to a
mixed file containing both ChatGPT metadata and `OPENAI_API_KEY`. The existing
closed projector selected the `auth_mode=chatgpt` token shape and did not
project the extra API key. No credential value was printed or retained.

The one newly approved attempt reached the App Server turn and failed with:

```text
runtime.worker.protocol-upstream.other.code-none.retry-false
```

This is a non-retryable upstream `other` category with no HTTP status code.
It provides no evidence that any required capability was invoked or observed.
The approved additional-attempt allowance is exhausted.

## 2. Unresolved Provider Ambiguity

The post-stop read-only review found a configuration ambiguity that was not
measured by the approved attempt:

- Codex `0.147.0` `ThreadStartParams` exposes `modelProvider` separately from
  `model`;
- upstream Codex configuration documentation requires a custom provider to be
  selected explicitly with `model_provider`;
- the closed Stornaut Runtime Home fixes `gpt-5.6-luna` but does not fix a
  provider in either generated config or `thread/start`;
- the machine's normal Codex config currently selects the built-in `openai`
  provider and also defines other custom provider sections, but the isolated
  Runtime Home intentionally does not inherit that config.

This is not a root-cause claim. The sanitized `other` category does not reveal
whether the failure came from model availability, provider selection,
authentication, request semantics or another upstream condition. Selecting a
provider would change the closed runtime profile and credential/data-plane
assumptions, and another real-model call would exceed the approved attempt.
Both therefore require a new explicit owner decision and tests-first evidence.

## 3. Completed Candidate Work

The uncommitted R5 candidate now contains:

- fixed local-only App/plist/helper topology contracts;
- an administrator-authenticated install/uninstall harness with no caller-
  controlled destination, label, Mach service, executable or argv;
- exact App/helper code-signing peer requirements;
- root lease and audit-session fixed-point drain/recovery implementation;
- privacy-safe worker/lifecycle/repository evidence separation;
- closed API-key and ChatGPT-token auth projection;
- closed sanitized upstream error category/code/retry projection;
- explicit browser/image/shell/unified-exec/subagent/runtime-skill profile;
- synthetic text, PNG, skill, public-network and negative containment probes;
- Debug-only diagnostic entrypoints and Release negative boundaries.

This work is a candidate only. It is not R5 evidence because the real capability
matrix did not complete.

## 4. Attempt Evidence

```text
/tmp/stornaut-r5-worker-api-key-model-attempt-1.log
SHA-256 ae327b9873628c1dd7989fbe94a141dcb64cd4707709677807506446859dc73b

/tmp/stornaut-r5-worker-api-key-model-attempt-2.log
SHA-256 f328e8df5326ba9a583de128f47e5ec5398d6c0f7fb6f0954f38a1d876ed76c5

/tmp/stornaut-r5-worker-bounded-attempt-3.log
SHA-256 a755c59de891c4e9be0f410de3aa2b417097f7215050f5b66f51dc0f68ae6f16
```

Attempt 1 was recorded before precise nested protocol reason mapping. Attempt 2
recorded the stable pre-revision reason shown above. Attempt 3 ran after the
approved protocol revision and recorded only the closed
`other/code-none/retry-false` tuple. None of the reports contains auth material,
prompts, paths, raw JSONL, command output, search results, upstream error text
or model reasoning.

Focused verification after the revision:

```text
CodexAppServerRuntimeTests                  14/14 passed
CapabilityRuntimeDiagnosticContractTests   11/11 passed
CodexAppServerSessionRunnerTests            10/10 passed
```

One concurrent `StornautCodexTests` run hit the known load-sensitive
`diagnosticProcessTimeoutKillsDescendantsAndReturnsBoundedly` fixture with
`missingChildPID`; the exact test passed on two immediate serial reruns. The
subsequent full serial suite passed `168/168`. Repository regression is
therefore green, but it does not override the failed real-model gate.

## 5. Safety and Residue

After the stop:

- no local diagnostic App is installed in `/Applications`;
- no Stornaut plist is installed in `/Library/LaunchDaemons`;
- no `system/com.eriklee.stornaut.lifecycle` service exists;
- no helper or diagnostic Codex process remains;
- no lease root, Runtime Home or synthetic diagnostic root remains;
- no canary Unix socket remains;
- no TCC, FDA, Accessibility or Event Synthesizing state changed;
- no administrator password was read, stored or entered by the Coding Agent.

The attempted Terminal install command never created the fixed App/plist/service
and is not counted as an installed topology. The post-attempt residue check
again found zero Stornaut service, App, plist, lease root, diagnostic root,
canary socket, helper process or test process.

## 6. Gate Consequence

R5 is not complete:

- no required capability is admitted from the real worker run;
- signed-App/helper behavioral composition was not run;
- no final machine report exists;
- no independent R5 review/commit/push is allowed;
- R6 and Task 29 remain blocked.

The worktree intentionally remains dirty at the accepted R4 baseline:

```text
89f3a8532b5594632edb66c8e9ad06a313ad9a5c
```

## 7. Resolution

The owner later confirmed that the local Codex is authenticated through
ChatGPT and authorized real local Codex calls without a count limit, with
`gpt-5.6-luna` preferred. The subsequent tests-first investigation found three
separate compatibility defects rather than an intrinsic model blocker:

1. the closed App Server thread did not explicitly select the `openai`
   provider even though provider selection is independent from model;
2. the strict Investigation Envelope v2 schema included JSON Schema keywords
   unsupported by OpenAI Structured Outputs; Stornaut now sends a shape-only
   compatible projection while retaining every strict bound/pattern/identity
   check in the local decoder;
3. App Server `0.147.0` may expose typed `webSearch` as started-only; completion
   is now correlated with the same-turn raw Responses completion without
   retaining query, URL, result, response ID or usage payload.

The fixed worker then observed:

```text
directRead, shell, unifiedExec, liveSearch, publicCommandNetwork,
browserOrDirectFetch, imageInspection, skills, subagents = 9/9 observed
worker integrity = 6/6 contained
```

The final worker probe accepts only `EPERM`/`EACCES` as network denial and
observed direct-public, IPv4/IPv6 loopback, link-local, RFC1918/CGNAT, IPv6
ULA and Unix-socket denial. A no-sandbox negative control exits nonzero.

R5 is no longer blocked on App Server/model compatibility. It remains
incomplete only until the user completes the explicit administrator
authentication required for the root-only local App/plist installation and
the signed App/helper machine report passes. R6 and Task 29 remain paused
until that gate.
