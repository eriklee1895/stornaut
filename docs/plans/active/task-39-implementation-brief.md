# Task 39 Implementation Brief — Signed-App Production Runtime Admission

> **Status:** In progress; 39A contract/facade foundation, 39B1a exact
> Store/async-lifecycle prerequisite closure and 39B1b-i package-closed
> transport/composition are complete and independently verified. 39B1b-ii
> strict DEBUG App leaf is next; 39B2 signed-App machine admission remains
> pending. Evidence:
> [Task 39A Review](../../reports/phase-d-task-39a-review.md) and
> [Task 39B1a Review](../../reports/phase-d-task-39b1a-review.md) and
> [Task 39B1b-i Review](../../reports/phase-d-task-39b1b-i-review.md).
>
> **Parent plan:**
> [Phase D Conditional Deep Dive](phase-d-conditional-deep-dive.md)
>
> **Runtime foundation:** accepted R5/R6 local-only topology and the exact
> current-source receipt contracts. This Task must not modify
> `~/.codex/config.toml`.

## 1. Objective

Task 39 proves that the Task 38 closed Investigation facade can be composed by
the current locally signed Debug App with the already admitted R5/R6 runtime:

```text
current-source signed Stornaut.app/helper
→ exact fresh capability/integrity receipt
→ closed production Investigation facade
→ one bounded disposable read-only Investigation
→ real authenticated Codex
→ strict Envelope v2
→ non-authoritative persisted report
→ complete interrupt/drain/artifact cleanup
→ zero runtime residue
```

This is a signed-App production-runtime admission gate, not product
availability. Normal UI Deep Dive remains unavailable; no first-use disclosure
is accepted; no Agent proposal enters Review; no cleanup path is reachable.

Completion requires separate evidence for capability observation, enforced
controls and adversarial denial. A successful model call or absence of an
observed violation is never containment proof.

## 2. Preconditions

Task 39 begins only after Tasks 36–38 are independently committed and pushed.
It requires:

- Task 38 fake-runtime coordinator and terminal barrier green;
- current R5/R6 local-only root-owned helper/App topology;
- current exact signed App/helper identity binding;
- current receipt schema and nine-capability/twelve-integrity contracts;
- current managed-proxy exception and all other local/private/link-local/Unix
  destinations OS-blocked;
- current audit-session lifecycle supervisor and zero-residue verifier;
- user-authenticated Codex state projected without editing Codex config;
- current model preference `gpt-5.6-luna` when available.

Any runtime/topology/receipt drift requires a focused diagnostic and review,
not optimistic compatibility.

## 2.1 Scope and Cost Preflight

Task 39 reuses the accepted R5/R6 capability worker, machine-report
assembler, fixed lifecycle installation and signed-App binding as
authoritative low-level evidence owners. It must not copy or rename those
implementations.

The existing R5/R6 worker is a multi-session synthetic capability diagnostic.
It is not the Task 38 production coordinator and its aggregated report cannot
be replayed, translated or concatenated into a purported production
Investigation run. In particular:

- a successful R5/R6 capability report cannot fabricate Task 38 root, turn,
  lineage, budget, terminal-barrier or normalized-report evidence;
- synthetic capability Envelopes from separate sessions cannot be combined
  into the one Task 39 production diagnostic Envelope;
- Task 39 must add one distinct bounded production-session driver whose live
  identity-bound events are consumed by the existing Task 38 coordinator;
- R5/R6 capability, containment and lifecycle evidence remains a separate
  plane and is joined only by exact nonce/source/build/receipt bindings in
  the final machine report.

Implementation is divided into three internal gates and two independently
reviewed/pushed checkpoints:

1. **Contract gate** — strict configuration/report/binding/verdict types and
   tamper/freshness tests; no App launch or model call.
2. **Composition gate** — one reusable production App Server session adapter,
   one narrow `StornautInvestigation` diagnostic facade and DEBUG-only App
   composition; fake transport tests first, no product availability change.
3. **Machine gate** — signed-App helper invocation, real bounded model run,
   three-plane report assembly, failure matrix, teardown and zero residue.

Checkpoint **39A** closes the contract and reusable coordinator facade
foundation without linking the App, launching Codex or claiming signed runtime
readiness. The 39B preflight found that DEBUG App composition plus the complete
signed machine gate still exceeded one reviewable checkpoint, so it is split
before implementation:

1. **39B1 App composition** — package-closed interactive Codex transport,
   composition target, strict DEBUG App diagnostic leaf, fake-transport tests
   and Release/no-Executor structural boundaries. It does not launch Codex or
   claim machine readiness. Its scope preflight is itself split into:
   - **39B1a prerequisite closure** — exact Evidence v4 Store-path binding and
     a directly async lifecycle drain protocol with no semaphore/blocking XPC
     bridge;
   - **39B1b-i transport/composition** — package-closed transport, dedicated
     non-product composition target, server-owned identity mapping and
     structural no-Executor boundaries;
   - **39B1b-ii DEBUG App leaf** — strict DEBUG activation, App composition
     tests and structural Release boundaries.
2. **39B2 machine admission** — current-source signed App/helper invocation,
   bounded real model run, three-plane machine report, failure matrix,
   teardown and zero-residue proof.

Task 39 completes only after 39B2. Checkpoints 39A, 39B1a, 39B1b-i, 39B1b-ii
and 39B2 each receive focused tests, boundary checks, serialized SwiftPM,
independent review, one uninterrupted authoritative full verifier and an
independent commit/push. The additional verifier cost keeps every pushed
checkpoint authoritative rather than recreating the oversized Task 36–38
review surfaces.

Before either checkpoint expands beyond 14 non-document source/test/script
files or approximately 4,000 added non-document lines, stop and split again
before adding code. A split must preserve the same Task 39 product gate and
cannot weaken any final completion criterion.

The 39B1 preflight initially fixed its implementation write set to one package
composition target, one package-closed Codex interactive transport seam, one
DEBUG App leaf, focused SwiftPM/App tests and structural verifier updates. A
second preflight found that the Store-path correction and async lifecycle
composition would push that set beyond the 14-path absolute maximum, so 39B1a
was split before transport implementation. The completed 39B1a diff changed
eight non-document source/test/script paths and added 246 non-document lines;
it remained well below the hard split gate.

Implementation then showed that combining the stateful transport/composition
with its DEBUG App leaf would again create an avoidably broad review surface,
so 39B1b was split before any App source changed:

- **39B1b-i** owns only the package-closed App Server client, dedicated
  non-product composition target, production session adapter, async identity
  integration and structural boundaries;
- **39B1b-ii** owns only the strict DEBUG App diagnostic activation,
  App-level fake composition tests and Release activation boundaries.

39B1b-i changed 13 non-document source/test/script paths, adding 2,760 lines
and deleting 122. Its 92-test Investigation suite, 240-test Codex suite,
846-test serialized SwiftPM regression, independent post-fix review and one
uninterrupted 23-stage authoritative full verifier passed. See
[Task 39B1b-i Review](../../reports/phase-d-task-39b1b-i-review.md).

39B1b-ii must remain independently below the same 14-path/approximately
4,000-added-line hard split gate. Real model execution, fixed-topology
installation, machine-report assembly and failure-matrix diagnostics are
prohibited in every 39B1 checkpoint and remain exclusively 39B2.

39B1a bound the diagnostic configuration to the real Evidence Store v4 path,
made lifecycle drain directly asynchronous, reloaded actor-owned run state
after suspension, rechecked the 135-second terminal deadline before artifact
retirement or Store commit, and added a structural no-blocking-bridge gate.
Its 83-test Investigation suite, 833-test serialized SwiftPM regression,
independent post-fix review and uninterrupted 23/23-stage authoritative full
verifier passed. See
[Task 39B1a Review](../../reports/phase-d-task-39b1a-review.md).

39B1b-i added the package-scoped stateful JSON-RPC App Server client and a
dedicated `StornautInvestigationRuntime` target that is not a public package
product. It preopens the ephemeral root asynchronously, claims that root
exactly once inside Store admission, injects canonical prompt/context only on
the first admitted turn, maps only server-owned thread/turn identities,
supports bounded metadata/interrupt/retirement operations and fails closed on
transport loss. Pending turn reservation is distinct from an active turn so
an async response cannot cause premature settlement. The target graph and
source verifier reject cleanup/Executor authority, direct process spawning,
filesystem mutation and direct networking. No App source, real model, fixed
topology or machine report changed.

## 3. Composition Boundary

### 3.1 Current-source binding

The diagnostic must bind:

- repository HEAD and tracked/untracked source fingerprint;
- Debug App executable SHA-256;
- App bundle ID and local signature identity;
- helper executable SHA-256, fixed installation path and signature;
- fixed launchd plist/service identity;
- runtime receipt schema/version/fingerprint;
- Codex executable/version/provider/auth projection;
- current canonical prompt/schema resource hashes;
- Task 38 facade/module hash inputs;
- unique diagnostic nonce and timestamps.

A report from another source tree, build, receipt, helper, provider projection
or nonce cannot admit the current Task.

### 3.2 Diagnostic-only App factory

Add one DEBUG diagnostic-only App composition factory that supplies Task 38:

- exact current runtime receipt;
- closed `StornautCodex` App Server runner;
- current lifecycle owner;
- current managed proxy owner;
- exact Store v4 diagnostic database;
- isolated owner-only runtime workspace;
- one bounded read-only disposable source fixture;
- no cleanup, Policy or Executor dependency.

Ordinary App composition remains `.implementationUnavailable` for production
Deep Dive. The factory is unreachable from normal navigation/preferences and
absent from Release activation surfaces.

The diagnostic factory is a terminal leaf under
`StornautApp/Diagnostics/...`; its type and constructor are not imported by
normal App dependency composition. It may share only reviewed low-level
runtime/lifecycle/Store protocols and implementations. Its disposable source,
nonce, diagnostic config, canaries, hard-coded evidence and result transport
cannot conform to or be passed into the normal-product factory that Task 44
will add. Structural tests reject any reference from normal App composition,
Release sources or Task 44 production start code to the diagnostic factory or
diagnostic-only source/config types.

### 3.3 Isolated diagnostic source

The signed diagnostic uses a fresh script-owned temporary source containing
only disposable, non-secret evidence sufficient to exercise:

- direct read;
- shell;
- unified exec;
- live search;
- public command network;
- browser or direct fetch;
- image inspection;
- skills;
- subagents.

It must not inspect the user's repository, Home data, real caches, credentials
or private services. Any image/skill fixture is generated/checked in or
created beneath the diagnostic root with provenance; no credential is stored.

## 4. Diagnostic Protocol

### 4.1 Invocation

Use one DEBUG-only strict config argument, separate from the Task 35 Trash
argument, containing:

- schema version and fresh nonce;
- exact opt-in statement;
- absolute isolated source/support/runtime/report paths;
- expected App/helper/service/executable hashes;
- expected runtime receipt fingerprint;
- allowed public test origins;
- exact finite wall-clock/turn/Probe/context bounds;
- expected model preference;
- report deadline.

Unknown/missing/stale/relative/symlinked/reused paths fail before runtime
launch. Environment-only activation and normal UI activation are forbidden.

### 4.2 Bounded real run

The run:

- creates one new ephemeral root thread;
- uses the Task 38 closed Plan and coordinator;
- prefers `gpt-5.6-luna`, recording exact observed model/provider;
- performs no more work than the focused Task 36 preset or a stricter
  diagnostic bound;
- exercises all nine capabilities through identity-bound events;
- produces one strict valid Envelope v2 when successful;
- normalizes it only as a non-authoritative report;
- drains and removes ephemeral artifacts on success, cancellation, timeout,
  invalid envelope and process/runtime failure.

Repeated diagnostic runs are allowed only as fresh independent nonces and
bounded investigations. No uncertain write exists, but reports cannot be
combined across attempts to fabricate a pass.

## 5. Three Independent Evidence Planes

### 5.1 Capability observation

Record each required capability separately:

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

For each capability record:

- advertised by exact current runtime;
- configured in the admitted profile;
- observed through identity-bound current-run events/artifacts;
- any typed degradation/error;
- public internet success separately where relevant.

Nine-of-nine observation is required for `signedInvestigationRuntimeReady`.
An advertised/configured capability is not observed evidence.

### 5.2 Enforced-control verification

Independently prove:

- current signed App/helper/service identity;
- root-owned fixed topology and lease ownership;
- identity drop before worker execution;
- outer write-denial ordering inherited by the audit-session tree;
- only same-investigation parent-owned random-loopback managed proxy transport;
- every other localhost/private/link-local and Unix target OS-blocked;
- strict runtime receipt admission;
- complete descendant lineage and lifecycle drain;
- structural no-Executor/no-Trash/no-authorization boundary;
- runtime workspace/auth projection cleanup;
- zero App/helper/service/lease/proxy/worker residue after uninstall/drain when
  the diagnostic protocol requires teardown.

This plane must use enforced-control evidence, not model self-report.

### 5.3 Adversarial denial

Attempt and attribute denial for:

- write/create/rename/remove beneath disposable and representative user-data
  denied paths;
- IPv4 and IPv6 loopback other than the exact managed proxy;
- private, link-local and reserved IPv4/IPv6;
- local/private DNS resolution and rebinding-shaped candidates;
- arbitrary Unix socket;
- access to cleanup/Policy/Executor/XPC authority;
- direct bypass of the managed proxy;
- descendant/subagent variants of the same attempts.

Each expected denial records the OS/runtime control responsible. A request
that simply was not attempted or did not return is not denial evidence.

## 6. Report Contract

Add a strict signed diagnostic report with:

- schema version and current-source/build/receipt hashes;
- exact App/helper/service/signature metadata;
- diagnostic nonce/timestamps/model/provider;
- Plan/run/source fingerprints;
- nine capability records;
- twelve integrity/control records;
- adversarial denial records;
- strict Envelope result and normalized report ID;
- cancellation/timeout/invalid-envelope outcomes;
- Task 38 terminal barrier evidence;
- lifecycle/proxy/Probe/artifact residue counts;
- sanitized upstream error category/code/`willRetry` only;
- explicit non-claims.

Required verdicts:

- `signedInvestigationRuntimeReady`;
- `signedInvestigationRuntimeBlocked`;
- `signedInvestigationRuntimeFailed`.

Ready requires all expected observations/controls/denials and zero residue.
Partial evidence never yields Ready.

The report explicitly does not prove:

- release distribution/notarization;
- arbitrary user FDA/TCC behavior;
- product first-use disclosure;
- ordinary App availability;
- report quality over real user data;
- cleanup safety beyond the unchanged structural no-Executor boundary.

## 7. Cancellation, Timeout and Invalid Output

Run independent diagnostics for:

- successful bounded final Envelope;
- user cancellation during an admitted turn;
- wall-clock timeout;
- malformed/unknown-field Envelope;
- valid schema with foreign/forged IDs;
- runtime transport interruption;
- lifecycle drain recovery.

Every case must:

- use the Task 38 T0/15/45/135/140 terminal settlement envelope;
- admit no later scientific work after closure;
- classify missing terminal/drain truth correctly;
- preserve only verified evidence;
- delete/recover raw artifacts;
- prove zero descendant/proxy/lease residue;
- avoid enabling product UI.

## 8. Tests First

### 8.1 Config/report contracts

- strict valid round trip;
- unknown/missing/stale/reused/symlink/relative path rejection;
- App/helper/source/receipt hash mismatch;
- stale/synthetic/cross-nonce report rejection;
- incomplete capability/integrity/denial matrix cannot be Ready;
- observed/configured/advertised/contained remain distinct;
- sanitized upstream error fields only;
- Release activation marker absence.

### 8.2 Composition

- normal App remains implementation unavailable;
- only DEBUG strict diagnostic can construct production facade;
- no runtime factory retained when diagnostic admission fails;
- isolated source/support/runtime paths only;
- no repository/target `AGENTS.md` loading;
- no arbitrary provider/model/CLI flags;
- no cleanup dependency reachable.

### 8.3 Machine verifier

- current build/receipt binding;
- 9/9 capability event evidence;
- public internet separately observed;
- 12/12 enforced integrity evidence;
- adversarial write/network/Unix/authority denials;
- descendant/subagent attempts included;
- terminal and residue assertions;
- report fingerprint reproducibility and tamper rejection.

### 8.4 Failure matrix

- cancellation;
- timeout;
- invalid envelope;
- identity mismatch;
- transport loss;
- lifecycle recovery;
- artifact cleanup failure;
- no success/non-observation promoted to containment.

## 9. Scripts and Installation Safety

Add a focused diagnostic verifier that:

1. validates Task 38 focused/fake gates;
2. builds the exact current Debug App/helper;
3. installs only the accepted fixed local-only topology;
4. creates a fresh isolated diagnostic config/source;
5. invokes the signed App;
6. verifies the three evidence planes and report fingerprint;
7. exercises failure cases with fresh nonces;
8. drains/uninstalls fixed topology;
9. proves zero residue.

The script must:

- fail closed on ownership/mode/hash drift;
- never edit `~/.codex/config.toml`;
- never reset or request TCC/Accessibility/Event Synthesizing;
- never stop unrelated processes;
- never persist credentials/raw JSONL in the repository;
- use no shell xtrace;
- create every diagnostic beneath a fresh script-owned `mktemp -d` root
  with directory mode `0700` and file mode `0600`;
- bind any sanitized failure artifact to the exact nonce, source
  fingerprint, runtime receipt, App/helper hashes and report hash in an
  owner-only manifest; a path alone is never evidence;
- delete artifacts on success and before a later run; bounded failure
  artifacts expire within 24 hours, and cleanup failure quarantines the
  diagnostic result instead of admitting it.

## 10. Expected Files

```text
Package.swift
Stornaut.xcodeproj/project.pbxproj
StornautApp/AppState/AppDependencies.swift
StornautApp/StornautApp.swift
StornautApp/Diagnostics/InvestigationRuntimeDiagnosticHarness.swift
StornautAppTests/InvestigationRuntimeDiagnosticTests.swift
Sources/StornautCodex/Diagnostics/...
Sources/StornautInvestigation/...
Tests/StornautInvestigationTests/SignedRuntimeContractTests.swift
scripts/verify-investigation-runtime-diagnostic
scripts/verify-investigation-runtime-machine-report
scripts/verify-investigation-boundaries
scripts/verify-app-release-boundaries
scripts/verify
docs/plans/active/task-39-implementation-brief.md
docs/reports/phase-d-task-39a-review.md
docs/reports/phase-d-task-39-review.md
docs/agent/coding-agent-handoff.md
docs/plans/active/README.md
docs/plans/roadmap.md
AGENTS.md
```

Exact names may reuse current R5/R6 scripts and report types where they remain
the authoritative owner. Do not fork a second capability or containment
verifier merely for naming convenience.

## 11. Focused Validation

Run heavy work serially:

```text
swift test --filter SignedRuntimeContract
swift test --filter InvestigationCoordinator
swift test --filter CapabilityRuntime
swift test --filter Lifecycle
scripts/verify-investigation-boundaries
xcodebuild ... -only-testing:StornautAppTests/InvestigationRuntimeDiagnosticTests
scripts/verify-investigation-runtime-diagnostic
scripts/check-doc-links
git diff --check
```

Then:

```text
swift test --no-parallel
scripts/verify --full
```

The focused real-model diagnostic may be repeated with fresh nonces when a
provider/transient failure is honestly classified. It may not reinterpret a
failed containment/control assertion as a provider issue.

## 12. Independent Review

Review for:

- model success treated as containment;
- advertised/configured treated as observed;
- missing denial treated as blocked;
- stale build/receipt/report reuse;
- diagnostic fixture leaking into production prompt;
- real user path/credential/repository access;
- normal UI availability change;
- arbitrary provider/CLI/config mutation;
- incomplete descendant capability/denial accounting;
- lifecycle/proxy/artifact residue;
- no-Executor verifier gaps;
- synthetic report acceptance;
- error detail leaking secrets;
- R5/R6 topology drift;
- release marker leakage;
- stale docs/broken links.

Fix all P0–P2 findings and rerun affected gates before final full verification.

## 13. Explicit Non-Goals

- first-use disclosure or Settings UI;
- normal Deep Dive start;
- App workflow reducers/navigation;
- real user-disk investigation;
- report-to-Review projection;
- Cleanup Plan, Policy, selection, authorization or execution;
- release distribution, Developer ID or notarization;
- arbitrary provider/model selection;
- system permission changes;
- telemetry/background runtime.

## 14. Completion and Git

Task 39 completes only when:

- one current-source signed-App report is
  `signedInvestigationRuntimeReady`;
- capability, control and denial planes independently pass;
- cancellation/timeout/invalid-envelope paths drain with zero residue;
- structural no-Executor and Release boundaries pass;
- independent review has zero unresolved P0–P2;
- one uninterrupted authoritative `scripts/verify --full` exits `0`;
- docs keep product Deep Dive unavailable;
- a docs-freshness audit verifies every referenced normative document, task
  dependency/status router, ownership/non-goal claim and product-availability
  claim matches the committed diff and canonical contract;
- docs links, credential/artifact hygiene and `git diff --check` pass;
- one independent commit has no Coding Agent co-author trailer;
- `GITHUB_TOKEN` and `GH_TOKEN` are unset before push;
- `HEAD == origin/main` after push.
