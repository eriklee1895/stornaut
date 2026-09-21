# Capability-First Runtime R5 Provider/Usage-Limit Blocker

> Status: Historical, superseded — official `openai` + ChatGPT subscription
> access recovered on 2026-08-13 and a fresh worker passed 9/9 capabilities
> plus 6/6 worker integrity
>
> Date: 2026-08-13
>
> Scope: product provider availability and admission for the final
> signed-App/helper machine report

## Summary

This report preserves a bounded historical provider outage and must not be
used as the current R5 status. The product remained pinned to `openai`; no
custom provider was admitted. Later on 2026-08-13 the user switched back to
official Codex subscription login, a minimal health probe passed, and the
current closed worker completed all required capability and containment rows.
The remaining R5 gate is the current-source signed App/helper machine report
and post-run zero-residue proof.

R5 implementation, post-review repair and repository verification are ready
up to the signed machine gate. The model itself is now reachable through the
user's configured `custom` provider, TeamoRouter. The product candidate does
not inherit that configuration: its generated config and App Server thread
explicitly pin provider `openai`, and its closed auth projection currently
uses ChatGPT auth.

That product path still returns the sanitized upstream category
`usageLimitExceeded` before capability execution. TeamoRouter success is
independent review/model-availability evidence; it is not evidence that the
signed product runtime used the approved provider/auth/data plane.

The local Codex client reports the next retry time as:

```text
2026-08-18 08:08 local time
```

This is an external/provider-admission failure. It is not evidence of a
containment, helper, signing or no-Executor failure.

## Bounded Attempts

Post-fix real-worker retries now pass:

- staged native-package discovery;
- synthetic private-read denial;
- the installed-wrapper outer launcher plus staged-native inner executable;
- bundled `codex-code-mode-host` availability required by
  `gpt-5.6-luna`'s `code_mode_only` catalog entry;
- closed login/thread setup.

They then stop before capability execution with:

```text
runtime.worker.protocol-upstream.usageLimitExceeded.code-none.retry-false
```

A minimal no-tool probe with explicit `model_provider="openai"` independently
returned the same ChatGPT account usage-limit condition and retry time.

Separate user-level probes with `model_provider="custom"` reached TeamoRouter
and completed `gpt-5.6-luna` turns. A model-catalog compatibility warning was
observed on some attempts, and two bounded post-fix review attempts later
failed at the TeamoRouter stream before a final review result. These facts do
not change the product provider contract.

The local authentication/provider inventory is:

- `codex login status` reports ChatGPT login;
- the owner-only `~/.codex/auth.json` selects `auth_mode=chatgpt`;
- its optional `OPENAI_API_KEY` field is `null`;
- user config selects `model_provider="custom"`, provider name `TeamoRouter`,
  a Responses API base URL and a configured bearer-token reference.

Only field presence/type and the selected auth mode were inspected. No token,
key or credential value is printed or retained. Admitting `custom` would
change the R2/R5 provider, auth and data-plane contract, so the implementation
does not silently switch.

No raw upstream response, account identifier, token, credential, prompt
content or model body is retained in repository documentation.

## Last Successful Real Evidence

Before the usage limit was reached, an earlier post-review real worker completed
against synthetic fixtures and observed:

- 9/9 required capabilities;
- 6/6 worker integrity properties;
- the fixed synthetic image token;
- canonical plus raw live-search evidence;
- child streaming isolated from primary capability promotion;
- errno-only direct-public, IPv4/IPv6 local/private/link-local/ULA and Unix
  socket denial.

That evidence is useful regression evidence, but it cannot substitute for the
still-missing signed-App/helper machine report.

## Current Local Verification

The 2026-08-13 source review found and fixed:

- fixed marker/model-prose false-positive evidence for command, image and
  subagent observations;
- random denial tokens that no longer matched the helper's fixed output;
- shell metacharacters accepted by the random-token translation helper;
- a staged-native privacy preflight that timed out instead of using the
  installed outer launcher;
- omission of the bundled `codex-code-mode-host`, which makes
  `gpt-5.6-luna` fail closed because its Codex `0.147.0` catalog entry is
  `code_mode_only`;
- PATH-sensitive verifier commands.

After those repairs:

- focused App Server/runtime diagnostic tests passed;
- `StornautCodexTests` passed 218/218;
- `StornautLifecycleTests` passed 55/55;
- serial SwiftPM passed 515/515;
- `scripts/verify --headless` passed; its serialized SwiftPM selection passed
  512/512 and App contract tests passed;
- installed-provider/catalog privacy preflight passed;
- the negative control proves the network-denial helper cannot pass without
  outer containment;
- XcodeBuildMCP Debug build passed with no warnings;
- Release diagnostic-marker isolation passed;
- no-Executor, documentation links and diff hygiene passed;
- fixed App, plist, service, lease root, diagnostic root and machine report are
  all absent.

The independent review used `gpt-5.6-luna` through TeamoRouter for a bounded
read-only pass and local `bits-code-guard` fallback for the remaining groups.
Its concrete P1 findings were fixed and covered by focused/full tests. Two
fresh post-fix model-review retries ended at the TeamoRouter stream before a
result, so they do not count as a clean final independent model pass. The
deterministic gates do not substitute for missing signed-machine evidence.

## Decision and Resume Procedure

Do not install the local helper while the product provider is known to fail.
Choose one:

1. Keep the approved `openai` provider and wait until its ChatGPT usage limit
   clears; or
2. explicitly approve a tests-first custom-provider admission revision that
   validates provider ID, auth projection, generated config, App Server
   identity, catalog semantics, report metadata and privacy boundaries for
   TeamoRouter.

After the selected provider passes one minimal health probe:

1. rerun the real synthetic worker diagnostic;
2. complete a fresh independent post-fix review;
3. rebuild the Debug App/helper;
4. request explicit administrator authentication for the fixed install;
5. run `scripts/verify-codex-runtime-diagnostic` and
   `scripts/verify-codex-runtime-gate`;
6. explicitly uninstall and prove zero residue;
7. rerun the required R5 repository gates;
8. create the final R5 review report and independent commit/push only if the
   outcome is `signedRuntimeReady`.

R6 remains blocked. This report does not admit Deep Dive or resume Task 29.
