# Phase D Task 39B2b-ii Code Review and Completion Audit

> Status: Complete; authoritative `scripts/verify --full` passed 23/23 stages
> in one uninterrupted run
>
> Date: 2026-08-16
>
> Baseline:
> `47e17379a4dc063589eb0f7ff50b41f15b37c722`
>
> Scope: signed diagnostic-App/Task 38 composition without model execution or
> machine admission

## 1. Current Decision

Task 39B2b-ii is complete. Its implementation, focused validation, independent
post-fix review and single authoritative `scripts/verify --full` all passed.
The full verifier completed 23/23 stages in one uninterrupted run with no
restart or stage retry.

This checkpoint composes the Task 38 closed Investigation facade through the
dedicated signed diagnostic App, the supervised interactive transport and the
helper-owned contained worker. Construction is deliberately non-executing:
it does not open an XPC connection, start the helper-owned Investigation
session, launch Codex, invoke a model or emit a machine-readiness verdict.

Construction does initialize the exact diagnostic Evidence Store v4 database.
That expected diagnostic-local write is distinct from the helper-owned
`R5Runtime/<uid>/<investigation>` root, which is not created until the
interactive transport starts. The preflight receipt is therefore evidence of
a prepared composition, not evidence that a contained worker ran.

Task 39 remains incomplete. Task 39B2c alone owns the current-source signed
machine run, real model, capability/control/denial evidence planes, failure
matrix, zero-residue proof and `signedInvestigationRuntimeReady` verdict.
Production Deep Dive remains `.implementationUnavailable`; Task 44 remains
its sole normal-product admission gate.

## 2. Delivered Boundary

Task 39B2b-ii adds:

- one DEBUG-only opaque
  `InvestigationRuntimeDiagnosticComposition` public wrapper;
- strict signed configuration and installed App/helper/service identity
  binding before composition;
- one nonce-derived `investigation-<uuid>` identity shared with the Task 38
  facade and exposed as bounded diagnostic evidence;
- the exact Evidence Store v4 path, bounded Probe Broker adapter,
  Investigation Envelope v2 schema, Task 38 facade and lifecycle drain owner;
- a closed App Server client that validates the helper-reported random runtime
  workspace beneath the exact fixed Investigation root;
- delayed auth projection: construction derives only the current UID's fixed
  `~/.codex/auth.json` path, while credential bytes are not read until
  `prepareRoot`;
- a diagnostic App helper target dependency, exact helper copy phase and
  scheme build entry;
- lifecycle installer binding to
  `StornautInvestigationDiagnostic.app` rather than the ordinary App;
- a prepared/blocked preflight receipt that always retires the unstarted
  composition before reporting prepared;
- strict source and final-Mach-O gates proving no cleanup/Executor authority
  is exposed by the wrapper or linked into the complete diagnostic bundle.

The App derives the fixed auth source from the current non-root UID. The
helper-owned UID worker still owns fixed workspace creation, containment and
Codex process launch. No config field accepts an auth path, provider, model,
URL, executable, command, socket, network policy or cleanup dependency.

## 3. Scope and Cost Audit

The checkpoint changes fourteen non-document source, test, project and script
paths, adding 1,296 non-document lines and deleting 96. It is exactly at the
fourteen-path hard ceiling and remains well below the approximately 4,000-line
addition ceiling.

The one documentation path in the implementation diff is the approved Task 39
brief. This completion report and status-router updates are documentation-only
freshness changes and do not expand the implementation surface.

No new dependency, license, product permission or release distribution claim
is introduced.

## 4. Tests-First and Layered Validation

The checkpoint used the corrected cost-ordered funnel. Static contract changes
failed first in approximately `0.40` seconds, before any build. After the
implementation and review repairs:

| Gate | Result |
| --- | ---: |
| `scripts/verify-investigation-boundaries` | passed in approximately `0.80` seconds |
| `scripts/verify-contract` | passed in approximately `3.45` seconds |
| `CodexInteractiveAppServerClientTests` | 6/6 passed |
| `SignedRuntimeContractTests` | 15/15 passed |
| complete `StornautInvestigationTests` | 106/106 passed |
| dedicated diagnostic App tests | passed in `37.09` seconds |
| strict App/Release/final-Mach-O boundary | passed in `182.08` seconds |
| documentation links | passed |
| diff hygiene | passed |
| authoritative `scripts/verify --full` | 23/23 stages passed; 898-test serialized SwiftPM regression; `981` wall-clock seconds |

The first focused Swift test after cache invalidation spent `43.63` seconds
rebuilding while the selected test itself took `0.042` seconds. Incremental
focused suites then completed in approximately `0.75` to `0.92` seconds. This
is the expected evidence that static/focused checks now catch ordinary defects
without repeatedly paying the App or full-verifier cost.

XcodeBuildMCP returned `Transport closed` during this checkpoint. The
repository-documented equivalent targeted `xcodebuild` command ran the
dedicated App tests successfully. This is a development-harness transport
failure, not a product-code failure.

The strict final-binary gate:

- proves the current build's `StornautExecution.o` contains concrete authority
  symbols as a positive control;
- scans every Mach-O in the diagnostic App bundle after Swift demangling;
- rejects any symbol with the `StornautExecution.` prefix;
- fails closed when `nm` or `swift-demangle` cannot scan a Mach-O;
- admits the helper copy phase and target dependency by exact allowlist.

No standalone serial SwiftPM suite was run before final acceptance. The
authoritative full verifier owned this checkpoint's one broad serialized
regression, which passed 898 tests across 37 suites.

## 5. Independent Review and Repairs

The independent local `bits-code-guard` fallback reviewed fourteen changed
non-document paths across four call-chain groups:

1. Codex transport identity and delayed auth;
2. opaque signed composition and App harness;
3. Xcode/helper installation composition;
4. verifier soundness and cost ordering.

No subagent was used and no custom repository workflow was configured. The
review found two P1 defects:

1. the first opaque composition exposed the bare nonce as
   `investigationID`, while the Task 38 facade and Store used
   `investigation-<nonce>`;
2. the first demangled-symbol scanner continued after an `nm` or
   `swift-demangle` failure, so an unscannable Mach-O could be misclassified
   as containing no execution authority.

Both findings received tests-first/static-red witnesses. The repairs now:

- construct one `InvestigationID` and expose that same identity's `rawValue`;
- use a three-state symbol scan (`found`, `absent`, `scan error`) and make both
  positive and negative authority checks fail closed on scan error.

The post-fix review has zero unresolved P0–P2.

Review artifacts:

```text
/tmp/stornaut_task39b2bii_review_1786894207/final_comments.json
/tmp/stornaut_task39b2bii_review_1786894207/resolved_findings.json
/tmp/stornaut_task39b2bii_review_1786894207/report.html
/tmp/stornaut_task39b2bii_review_1786894207/report.md
```

Artifact SHA-256:

| Artifact | SHA-256 |
| --- | --- |
| final unresolved findings | `37517e5f3dc66819f61f5a7bb8ace1921282415f10551d2defa5c3eb0985b570` |
| resolved findings | `239026b171455baf89658ebfd3950003bf90e24e1715aecd383757750c6d0095` |
| HTML report | `f88432b7c33aa20663c85d242ec7c188643666e5fd1b534e2248649b5031b94a` |
| Markdown report | `f40825f16903163eba66627fb0117b37da1b1fa2d092e46340ad3246d939b0cb` |

## 6. Safety Audit

Task 39B2b-ii does not:

- call `prepareRoot`, `start`, `startTurn` or a real model;
- install, start or uninstall the fixed lifecycle topology;
- create the helper-owned Investigation runtime root;
- emit capability, containment, denial or machine-readiness evidence;
- claim that model success proves containment;
- expose or link `StornautExecution`, Trash, Policy, authorization, Executor
  or Registered Action authority into the diagnostic App;
- edit `~/.codex/config.toml`;
- accept an arbitrary auth path, provider, model, URL, executable, CLI flag,
  socket or network policy;
- inspect a real user investigation source;
- replay the sealed Task 35 Trash/recovery mutation;
- coordinate or terminate unrelated Node, Chrome, Cursor, Claude or MCP
  processes;
- enable normal-product Deep Dive;
- alter release, notarization, FDA/TCC or distribution claims.

The diagnostic App may read the current user's auth file only after 39B2c
explicitly starts the prepared root. That future read is bounded by the
existing owner/mode/link/size/identity checks and is not performed by this
checkpoint's preflight.

## 7. Final Acceptance

The checkpoint was frozen with fourteen non-document paths and pre-acceptance
staged-diff SHA-256
`514d4e479af73c37463fc1f4e5c3b160949d77b484133897f34837d9c2846076`.
Exactly one clean `scripts/verify --full` then ran:

| Evidence | Value |
| --- | --- |
| Result | `23/23` stages passed; exit `0` |
| Timed stages | `980.300` seconds |
| End-to-end wall time | `981` seconds |
| Serialized SwiftPM regression | `898` tests in `37` suites passed |
| Full log SHA-256 | `14a4c4f755320547244106b587477f8eca8629821a0be06a5380fb6f7c7a395e` |
| Timings TSV SHA-256 | `c2b310170ff6f5e8bb50316afafe5b0e5e2c498f31c21072e79ff41f04c5f260` |

The run included XCUITest, screenshot contracts, SwiftPM build/tests,
Investigation and matcher benchmarks, App tests, Debug/Release builds,
signing/bundle checks, strict source/final-Mach-O boundaries, localization,
rule compilation, verifier contracts, documentation/diff hygiene and the
sealed Phase C product/receipt gates. No real model, machine admission or
Trash mutation was invoked by this checkpoint.

After recording this evidence, only documentation links and diff hygiene are
rerun before the independent commit/push; the full verifier is not repeated.

## 8. Next Gate

After the independent 39B2b-ii commit/push, Task 39B2c starts tests-first. It
exclusively owns:

- current-source signed App/helper installation and invocation;
- one bounded authenticated `gpt-5.6-luna` Investigation;
- Task 38 start/turn/event/settlement driving;
- independent capability, control and denial evidence planes;
- cancellation, timeout, malformed-envelope, identity, transport and recovery
  failure cases;
- zero matching process/service/lease/runtime residue;
- the final Task 39 review and `signedInvestigationRuntimeReady` or truthful
  blocked/failed verdict.

Task 44, not Task 39, remains the only gate allowed to enable normal-product
Deep Dive.
