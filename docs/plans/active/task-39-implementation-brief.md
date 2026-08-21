# Task 39 Implementation Brief — Signed-App Production Runtime Admission

> **Status:** In progress; 39A contract/facade foundation, 39B1a exact
> Store/async-lifecycle prerequisite closure and 39B1b-i package-closed
> transport/composition plus 39B1b-ii strict DEBUG App leaf are complete and
> independently verified. The 39B2 preflight found that the accepted R5 helper
> still exposes only its one-shot capability-worker protocol; it cannot yet
> carry the Task 38 interactive App Server session that ADR 0016 requires the
> App to drive. To stay below the hard review budget, 39B2 is split into
> 39B2a strict supervised interactive transport, 39B2b signed-App/helper
> production composition and 39B2c machine admission/failure matrix. 39B2b
> is further split into 39B2b-i helper-owned contained worker and 39B2b-ii
> signed diagnostic-App/Task 38 composition. 39B2a
> implementation, focused/serialized regression and independent post-fix
> review are complete; its authoritative full verifier passed all 23 stages in
> one uninterrupted run. 39B2b-i implementation/focused post-fix review are
> complete, its 889-test serialized regression passed, and its authoritative
> full verifier passed 23/23 stages in one uninterrupted run. 39B2b-ii
> prerequisite E1 and E2a are complete: E1 moved Registered Action process
> authority into `StornautExecution`; E2a established the package-only cleanup
> injection seam and validated the corrected verification funnel with 47/47
> focused tests, an 893-test headless regression and a targeted Debug App
> build. E2b-i then moved concrete Trash/Executor authority into
> `StornautExecution`, kept Core authority-free, linked only the ordinary App,
> and passed its focused/product/App/serialized funnel plus isolated review.
> E2b-ii strict final-Mach-O admission is complete. The resumed 39B2b-ii
> signed diagnostic composition implementation, focused acceptance and
> independent post-fix review are also complete. Its single authoritative full
> verifier passed all 23 stages in one uninterrupted run, including the
> 898-test serialized regression. 39B2b-ii is complete and independently
> pushed. Before machine admission, a narrow 39B2c prerequisite closed the
> cross-attempt replay window between raw R5 capability evidence and the exact
> Task 39 nonce/source/build/runtime receipt. Its tests-first repair,
> 903-test headless regression and post-fix independent review passed.
> A separate tests-first strict-decoding prerequisite then made the reused
> capability report and derived outcome reject unknown fields; its 255-test
> serialized Codex suite and independent post-fix review passed.
> The 39B2c-L1 prerequisite then made the root helper seal exact per-run
> audit-session/lease/runtime-root residue after cleanup and before active state
> release. Its 949-test staged-only regression, targeted Debug helper build and
> independent post-fix review passed. L2 then added package-closed, non-Codable
> installed/post-teardown observation for fixed App/helper/plist/service/process/
> runtime/lease topology. Its root-helper signing P1 was fixed tests-first;
> 117-test focused, exact source-boundaries, targeted Debug diagnostic build,
> 981-test clean staged-only serial and post-fix review passed. The later
> deterministic machine driver/failure matrix is complete. L3c3c-i is complete
> as a transport/root-launch audit: B3/B4 algorithm evidence is retained, every
> UID-staged external root-launch path is NO-GO, and i-b2b-0b/i-b2b-1 were
> superseded before execution. L3c3c-ii-a authority-closed installed-driver and
> manifest observation is complete after exact source/final-Mach-O admission and
> independent post-fix review. The ii-b preflight identified helper-response
> handle echo, per-epoch/final-uninstall ambiguity and a closed-input gap, then
> froze ii-b as ii-b0–ii-b5 and inserted ii-c0 before privilege. A subsequent
> byte-completeness audit split ii-b0 into ii-b0a/ii-b0b. ii-b0a exact
> frame/capsule implementation and ii-b0b claim/release wire implementation,
> their staged-only serials and independent reviews are complete. ii-b1 preflight
> exposed a first-frame epoch-origin contradiction; ii-b0c bootstrap is complete.
> ii-b1 is also complete after its post-RED topology correction, authority-free
> leaf/fixed-FD implementation, exact artifact gates, one 1,138-test staged-only
> serial and independent post-fix review. The ii-b2 ASID cohort prerequisite
> then corrected the false App/helper same-ASID join while binding L1 residue to
> the helper. Its 1,142-test implementation serial, structural mutation controls,
> separate 1,143-test decoder-negative supplement and independent final review
> passed. ii-b2a typed escrow/deadline state then passed its 19-test focused,
> 167-test Lifecycle affected, coverage/structural/mutation gates, sole 1,162-
> test combined staged serial and final independent review. ii-b2b-i sealed
> non-connected server integration then passed 59 focused tests, one 1,194-test
> staged-only serial, exact source/package/mutation gates and independent post-fix
> reviews. ii-b2b-ii legacy-client quarantine / Machine production block is
> also complete after its helper-private legacy server correction, 34 focused,
> 175 Lifecycle affected, 308 Investigation affected, complete App/main-Mach-O
> gate, sole 1,196-test staged-only serial and grouped/cross-group review.
> ii-b2b-iii is split by fresh preflight into iii-a handle-v3/single-quantized
> transfer and iii-b public live façade/helper integration; iii-a and iii-b-i
> semantic/live integration, iii-b-ii executable physical-adapter closure and
> ii-b3a fixed handoff adapter and ii-b3b start-to-retire seam are complete and
> non-admitting; iii-b/ii-b2b/ii-b3 are closed; ii-b3c and ii-b4 are
> complete/non-admitting; ii-b5a0, ii-b5a, ii-b5b-i-a and i-b1 semantic target
> are also complete/non-admitting. The remaining cost/authority split is i-b2a
> artifact/static readers, i-b2b process/service + narrow C identity and i-b3
> observer composition; i-b2a is current.
> Evidence:
> [Task 39A Review](../../reports/phase-d-task-39a-review.md) and
> [Task 39B1a Review](../../reports/phase-d-task-39b1a-review.md) and
> [Task 39B1b-i Review](../../reports/phase-d-task-39b1b-i-review.md) and
> [Task 39B1b-ii Review](../../reports/phase-d-task-39b1b-ii-review.md) and
> [Task 39B2a Review](../../reports/phase-d-task-39b2a-review.md) and
> [Task 39B2b-i Review](../../reports/phase-d-task-39b2b-i-review.md) and
> [Task 39B2b-ii-E1 Review](../../reports/phase-d-task-39b2b-ii-e1-review.md)
> and
> [Task 39B2b-ii-E2a Review](../../reports/phase-d-task-39b2b-ii-e2a-review.md)
> and
> [Task 39B2b-ii-E2b-i Review](../../reports/phase-d-task-39b2b-ii-e2b-i-review.md)
> and
> [Task 39B2b-ii-E2b-ii Review](../../reports/phase-d-task-39b2b-ii-e2b-ii-review.md)
> and
> [Task 39B2b-ii Review](../../reports/phase-d-task-39b2b-ii-review.md) and
> [39B2c Attempt-Binding Prerequisite Review](../../reports/phase-d-task-39b2c-attempt-binding-prerequisite-review.md)
> and
> [39B2c Strict-Decoding Prerequisite Review](../../reports/phase-d-task-39b2c-strict-capability-decoding-prerequisite-review.md)
> and
> [39B2c-L1 Residue Observation Review](../../reports/phase-d-task-39b2c-l1-residue-observation-review.md)
> and
> [39B2c-L2 Root Topology Observation Review](../../reports/phase-d-task-39b2c-l2-root-topology-observation-review.md).
> L3 preflight then split the remaining work into L3a trusted target extraction,
> L3b root driver/L1+L2 collection and L3c failure matrix/final admission. L3a
> moved the machine-only contract and assembler into the non-product
> `StornautInvestigationMachine` target. Its 58 machine-focused tests, 151-test
> Investigation suite, exact boundaries, targeted Debug diagnostic build,
> 982-test clean staged-only serial and independent review passed. Evidence:
> [39B2c-L3a Trusted Machine Target Review](../../reports/phase-d-task-39b2c-l3a-trusted-machine-target-review.md).
> L3b has now been split before collector coding. L3b1 completed the exact
> connected-helper peer attestation and opaque one-shot L1 retirement handoff;
> its 987-test clean staged-only regression, targeted helper/diagnostic builds
> and independent post-fix review passed. Evidence:
> [39B2c-L3b1 Peer/Retirement Handoff Review](../../reports/phase-d-task-39b2c-l3b1-peer-retirement-handoff-review.md).
> L3b2 then completed the root-only one-shot L1/L2 topology collector,
> non-activating exact service/PID observation and synthetic transition
> contract. Its 1001-test clean staged-only regression, targeted builds and
> independent post-fix review passed. Evidence:
> [39B2c-L3b2 Lifecycle Topology Collector Review](../../reports/phase-d-task-39b2c-l3b2-lifecycle-topology-collector-review.md).
> The mandatory L3c scope/cost preflight found two additional trust boundaries:
> the current App-local retirement handoff cannot survive App exit, and the
> diagnostic lifecycle owner still infers managed-proxy/probe retirement rather
> than observing it. L3c is therefore split before coding into L3c1 opaque
> retirement escrow, L3c2 closed deterministic machine driver, L3c3 current-source
> real-success three-plane composition and L3c4 sealed final admission. Only L3c4
> may claim readiness or consume the remaining authoritative full verifier. L3c1
> is complete; the L3c2 scope/trust/cost preflight split the driver into
> L3c2a-i/L3c2a-ii/L3c2b, all now complete. The mandatory L3c3 preflight then
> split real-success composition into L3c3a driver-bound attempt schema, L3c3b
> native packaging, L3c3c-i/ii handoff design/implementation and L3c3d one real
> pending candidate. L3c3a is complete after its exact 14-path implementation,
> 199-test Investigation and 11-test App gates, 1,057-test clean staged-only
> serial and independent post-fix review. The fresh L3c3b preflight split native
> packaging from installer/L2 admission. A later final-Mach-O spike inserted
> L3c3b-0 authority closure before packaging. Its zero-dependency DriverSupport,
> Debug/Release final-Mach-O gates, 1,059-test clean staged-only serial and
> independent post-fix review passed. L3c3b-i diagnostic-only native packaging,
> final-artifact gates, 1,060-test clean staged-only serial and independent
> post-fix/cross-group review also passed. L3c3b-ii exact installer/L2 admission,
> ACL fail-closed, whole-installer source seal, six-case disposable matrix,
> 1,067-test clean staged-only serial and grouped/post-fix/cross-group review also
> passed. L3c3c-i-a transport/identity/protocol/lifecycle, i-b1 root-to-UID
> implementation/non-root/cleanup/static review and i-b2a historical
> reproducibility are complete. i-b2b-0a closed the external root-launch audit
> with NO-GO; i-b2b-0b/i-b2b-1 were superseded before execution. ADR 0018
> remains Proposed. L3c3c-ii-a is complete while L3c3c-ii-b is authorized by
> the revised preflight.
> Evidence:
> [39B2c-L3c1a Typed Owner Retirement Review](../../reports/phase-d-task-39b2c-l3c1a-typed-owner-retirement-review.md)
> and
> [39B2c-L3c1b-i Configuration-Bound Helper Escrow Review](../../reports/phase-d-task-39b2c-l3c1b-i-configuration-bound-helper-escrow-review.md)
> and
> [39B2c-L3c1b-ii Synthetic Machine Claim Review](../../reports/phase-d-task-39b2c-l3c1b-ii-synthetic-machine-claim-review.md)
> and
> [39B2c-L3c2a-i Machine-Claim Transport Review](../../reports/phase-d-task-39b2c-l3c2a-i-machine-claim-transport-review.md)
> and
> [39B2c-L3c2a-ii Machine Driver Host Review](../../reports/phase-d-task-39b2c-l3c2a-ii-machine-driver-host-review.md)
> and
> [39B2c-L3c2b Eight-Scenario Driver Review](../../reports/phase-d-task-39b2c-l3c2b-eight-scenario-driver-review.md)
> and
> [39B2c-L3c3a Driver-Bound Attempt Review](../../reports/phase-d-task-39b2c-l3c3a-driver-binding-review.md)
> and
> [39B2c-L3c3b-0 Driver Runtime Authority Review](../../reports/phase-d-task-39b2c-l3c3b-driver-runtime-authority-review.md).
> and
> [39B2c-L3c3b-i Native Driver Packaging Review](../../reports/phase-d-task-39b2c-l3c3b-i-native-driver-packaging-review.md).
> and
> [39B2c-L3c3b-ii Installer/L2 Admission Review](../../reports/phase-d-task-39b2c-l3c3b-ii-installer-l2-admission-review.md).
> and
> [39B2c-L3c3c Parent-Owned Handoff Study](../../upstream-studies/phase-d-task-39b2c-l3c3c-parent-owned-handoff.md),
> [Proposed ADR 0018](../../adr/0018-parent-owned-investigation-handoff.md) and
> [L3c3c-i Final Review](../../reports/phase-d-task-39b2c-l3c3c-i-handoff-launcher-spike-review.md),
> plus the
> [L3c3c-i-b2a Reproducibility Review](../../reports/phase-d-task-39b2c-l3c3c-i-b2a-reproducibility-contract-review.md)
> and
> [L3c3c-i-b2b-0a Root Provenance Review](../../reports/phase-d-task-39b2c-l3c3c-i-b2b-0a-root-provenance-review.md).
> and
> [L3c3c-ii Installed-Driver Path/Cost Preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-installed-driver-path-cost-preflight.md).
> and
> [L3c3c-ii-a Installed-Driver Observation Review](../../reports/phase-d-task-39b2c-l3c3c-ii-a-installed-driver-observation-review.md).
> and
> [L3c3c-ii-b1 Authority-Free App Leaf Review](../../reports/phase-d-task-39b2c-l3c3c-ii-b1-review.md).
> and
> [L3c3c-ii-b2 ASID Cohort Prerequisite Review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2-asid-prerequisite-review.md).
> and
> [L3c3c-ii-b2a Typed Escrow/Deadline Review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2a-review.md).
> and
> [L3c3c-ii-b2b-i Machine-Claim Server Review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2b-i-review.md).
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
2. **39B2 signed machine gate**:
   - **39B2a supervised interactive transport** — strict identity-bound
     lifecycle wire contract, exact signed-peer XPC client and package-closed
     Codex interactive transport. It does not change the helper, invoke a
     model or claim admission;
   - **39B2b signed production composition** — split before implementation:
     - **39B2b-i helper-owned contained worker** — root helper owns XPC,
       lease/audit-session lifecycle and cleanup; a same-helper child drops to
       the caller UID before constructing the fixed contained Codex session;
     - **39B2b-ii signed diagnostic composition** — DEBUG diagnostic App and
       Task 38 production-session driver under the fixed topology.
     These checkpoints may exercise deterministic/synthetic protocol fixtures
     but do not assemble a Ready machine report;
   - **39B2c machine admission** — current-source signed App/helper invocation,
     bounded real model run, three-plane machine report, failure matrix,
     teardown and zero-residue proof.

Task 39 completes only after 39B2. Product/security checkpoints 39A, 39B1a,
39B1b-i, 39B1b-ii, 39B2a, 39B2b-i, 39B2b-ii and 39B2c each receive focused
tests, boundary checks, serialized SwiftPM, independent review, one
uninterrupted authoritative full verifier and an independent commit/push.
Narrow prerequisite-only seam checkpoints may use the explicitly documented
risk-equivalent substitution in this brief when they do not move authority,
change App/UI behavior, alter the final binary or make a readiness claim. The
enclosing product/security checkpoint still receives exactly one final full
verifier after every prerequisite is integrated.

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

39B1b-ii changed nine non-document source, test, project and script paths,
adding 2,131 lines and deleting three. Its dedicated App test target passed
11/11 tests; the pure-product Debug/Release bundle boundary, Investigation and
no-Executor structural gates, 846-test serialized SwiftPM regression and
independent post-fix review passed. Its one uninterrupted 23-stage
authoritative full verifier exited `0` in 972 seconds. See
[Task 39B1b-ii Review](../../reports/phase-d-task-39b1b-ii-review.md).

The 39B2 preflight traced the live implementation rather than assuming that
the earlier R5 diagnostic was already interactive:

- `LifecycleSupervisorRequest` and `LifecycleSupervisorXPCWire` expose only
  one-shot `start`/`cancel`;
- `StornautLifecycleHelper` launches
  `CapabilityRuntimeWorker.runLocalDiagnostic`, waits for one final evidence
  receipt and then drains the audit session;
- `CodexInteractiveAppServerClient`, added in 39B1b-i, requires an ongoing
  bidirectional line transport for Task 38 identities and events;
- ADR 0016 explicitly requires the helper to retain lifecycle authority while
  the App drives stdio/App Server.

Adding the strict wire contract and XPC client, helper state machine and
contained child transport, diagnostic App composition, production driver,
three-plane assembler, scripts and failure matrix in one diff would exceed
both the 14-path and approximately 4,000-line hard limits. The split above was
therefore required before helper or App behavior changed. 39B2a is fixed to
at most nine non-document paths and approximately 2,500 added lines:

```text
Package.swift
Sources/StornautLifecycle/LifecycleInteractiveSessionContract.swift
Sources/StornautLifecycle/LifecycleSupervisorXPC.swift
Sources/StornautInvestigationRuntime/InvestigationLifecycleAppServerTransport.swift
Tests/StornautLifecycleTests/LifecycleInteractiveSessionContractTests.swift
Tests/StornautInvestigationTests/InvestigationLifecycleAppServerTransportTests.swift
scripts/verify-investigation-boundaries
```

The source/test names may be merged when that reduces surface area, but 39B2a
may not edit `StornautLifecycleHelper`, the Xcode App target, runtime report
assembly or any real-model script. A green 39B2a proves only a closed,
testable transport foundation; it cannot produce
`signedInvestigationRuntimeReady`.

39B2a changed seven non-document source, test and script paths and added 2,572
non-document lines with two deletions. It added the strict versioned
interactive contract, exact signed-peer XPC client, cancellation/dispatch
linearization, privacy-safe reason allowlist and package-closed serialized
transport. The final affected suites passed 73 Lifecycle and 103 Investigation
tests; the serialized SwiftPM regression passed 865 tests. Independent
post-fix review closed all P0–P2 findings, and its one uninterrupted
authoritative full verifier passed 23/23 stages in 932 seconds. 39B2a is
complete; helper implementation, signed production composition and every
readiness claim remain outside this checkpoint.

The 39B2b preflight then found that combining the helper state machine,
contained Codex process, signed diagnostic App and Task 38 production driver
would approach the 4,000-line hard limit and create two distinct privilege
review surfaces. It was split before implementation:

- **39B2b-i** is fixed to the root-helper/UID-worker boundary, contained
  session, process/pipe cleanup and structural gates;
- **39B2b-ii** owns only signed diagnostic-App composition and Task 38
  production driving.

39B2b-i changes nine non-document source, test and script paths and adds 3,497
non-document lines with 30 deletions. Its helper-owned worker, fixed contained
session and post-fix review are complete; 37 focused tests and the structural
boundary gate pass, as does the 889-test serialized SwiftPM regression. Its
one uninterrupted authoritative full verifier passed 23/23 stages with exit
`0` in 933.21 seconds. 39B2b-i is complete. See
[Task 39B2b-i Review](../../reports/phase-d-task-39b2b-i-review.md).

39B2b-ii preflight exposed a pre-existing link-boundary defect before any
model run: the dedicated diagnostic App linked the complete `StornautCore`
static target, so its final Mach-O contained concrete cleanup and Registered
Action authority even though the diagnostic source never referenced it.
`DEAD_CODE_STRIPPING=YES`, disabling the Xcode Debug dylib, whole-module
optimization and `-Osize` all retained the authority symbols. The binary gate
therefore remains valid and must not be weakened to a source-reference check.

To remain below the 14-path review maximum, the prerequisite repair is split
before resuming signed composition:

1. **39B2b-ii-E1 Registered Action authority extraction** — move the concrete
   `posix_spawn`/process-tree runner into a one-way `StornautExecution →
   StornautCore + StornautProcessSupport` target while Core retains only the
   typed protocol, result and error contract.
2. **39B2b-ii-E2 Trash/Executor authority extraction** — split before coding:
   - **E2a package-only seam** exposes only the minimum package-scoped injected
     policy/coordinator/accounting contracts needed by a sibling package
     target. It does not move concrete authority, change an App target, change
     a final binary or claim that the Investigation diagnostic is clean.
   - **E2b concrete authority migration** moves FileManager Trash,
     `ActionExecutor` and concrete cleanup runtime composition out of Core,
     explicitly links them only into ordinary App/authorized diagnostic paths,
     and proves the Investigation diagnostic Mach-O has no write authority.

E1 and final E2b receive tests-first structural coverage, focused tests,
serialized SwiftPM regression, independent review, one authoritative full
verifier and an independent commit/push. E2a is a deliberately narrow
prerequisite seam and uses this documented substitution instead:

```text
red structural/package boundary gate
→ focused affected tests
→ scripts/verify --headless
  (owns the checkpoint's one serialized SwiftPM regression)
→ targeted Debug App build
→ independent review
→ commit/push
```

E2a does not run XCUITest or `scripts/verify --full`; neither layer can add
evidence for a package-visibility-only change, while they accounted for most
of the last full verifier's 954.459 seconds. E2b owns the strict final Mach-O,
Debug/Release bundle and Xcode linkage gates and receives exactly one
authoritative full verifier after all focused failures are resolved. No E2
checkpoint launches Codex, invokes a model, creates an Investigation readiness
report or changes normal product availability. After E2b passes, the stashed
39B2b-ii signed composition diff resumes under its original scope and machine
execution remains exclusive to 39B2c.

E2a also corrects the sealed Task 35 receipt verifier before changing
safety-critical cleanup source. The immutable receipt remains unchanged; its
last rolled-forward source-hash set binds to the exact pre-extraction E1
ancestor recorded by a checked sidecar, while current source is independently
covered by live Phase C structural/product gates. Do not roll the receipt
hashes forward through this authority extraction or claim that a later build
performed the already-consumed Trash attempt.

The full verifier is an acceptance run, never a debugging loop. Record each
stage duration. If focused, headless, binary or full validation fails, diagnose
and rerun only the exact failed stage/suite/case until it is green; restart the
single clean authoritative full only after the defect is fixed. Do not rerun
unrelated XCUITest, golden or Release stages to obtain debugging signal.

39B2b-ii-E1 changed six non-document source, test and script paths. It adds
the one-way `StornautExecution → StornautCore + StornautProcessSupport`
target, moves the existing concrete Registered Action runner without changing
its behavior, and leaves only typed contracts in Core. Its 11-test focused
suite, structural gate, 895-test serialized regression and independent
read-only review passed with no unresolved P0–P2. Its one uninterrupted
authoritative full verifier passed 23/23 stages with exit `0`; timed stages
totaled 954.459 seconds. E1 is complete. See
[Task 39B2b-ii-E1 Review](../../reports/phase-d-task-39b2b-ii-e1-review.md).
E2a is also complete. It exposes only package-scoped injected cleanup
contracts, moves no concrete authority, and passed 47/47 focused cleanup tests,
all 8 headless stages including the 893-test serialized regression, a targeted
Debug App build and isolated review with no unresolved P0–P2. Its 170.717
seconds of headless timed stages were approximately 82 percent shorter than
E1's full-verifier timed stages without weakening E2b's final acceptance gate.
See
[Task 39B2b-ii-E2a Review](../../reports/phase-d-task-39b2b-ii-e2a-review.md).
E2b concrete authority migration is now active; signed composition remains
stashed and 39B2c still exclusively owns machine execution.

E2b preflight traced every current construction and test owner before moving
code. It initially fixed a 14-path write set, but the red gate exposed a
fifteenth mandatory verifier owner:
`scripts/verify-phase-c-trash-diagnostic-contract`. The checkpoint is
therefore split before exceeding the hard maximum:

- **E2b-i authority relocation and green App linkage** — at most 14
  non-document paths; moves concrete authority, updates behavioral tests,
  imports/links `StornautExecution` only into the ordinary App/Task 35
  diagnostic host, and updates every source/Phase C contract so the repository
  remains buildable;
- **E2b-ii strict final-Mach-O admission** — strengthens the built-artifact
  authority markers and exact Xcode dependency allowlist, runs the strict
  Debug/Release/Investigation diagnostic bundle gate, independent review and
  exactly one final full verifier.

The E2b-i fixed non-document write set is:

```text
Sources/StornautCore/Actions/ActionExecutor.swift
Sources/StornautCore/Actions/TrashMoving.swift
Sources/StornautCore/Actions/CleanupExecutionCoordinator.swift
Sources/StornautCore/Actions/CleanupExecutionRuntime.swift
Sources/StornautExecution/Actions/CleanupExecutionAuthority.swift
Tests/StornautCoreTests/TrashMovingTests.swift
Tests/StornautCoreTests/PlatformTrashDiagnosticTests.swift
Tests/StornautCoreTests/CleanupExecutionCoordinatorTests.swift
StornautApp/Diagnostics/PhaseCTrashDiagnosticHarness.swift
StornautAppTests/PhaseCTrashDiagnosticTests.swift
Stornaut.xcodeproj/project.pbxproj
scripts/verify-cleanup-execution-boundaries
scripts/verify-phase-c-gate
scripts/verify-phase-c-trash-diagnostic-contract
```

`ActionExecutor.swift` in Core retains only the package-scoped injected
execution protocol and typed failure contract. `TrashMoving.swift` in Core
retains only the public immutable Trash receipt. The concrete Executor,
Trash adapter/mover and DEBUG diagnostic composition move together into
`StornautExecution`; the Core runtime remains a no-authority state machine
with package-scoped injection. Existing behavioral tests import the execution
module rather than duplicating fixtures. The ordinary App explicitly links
`StornautExecution` only because its sealed DEBUG Task 35 diagnostic source
constructs that authority; production composition remains `writeDisabled`.
The separate Investigation diagnostic target must not link the execution
product.

E2b-i starts with the red source/package authority assertion already observed,
then runs the affected Execution/Core tests, Phase C product gate, one
serialized SwiftPM regression, targeted ordinary/diagnostic App builds and
independent review. It cannot be pushed with a broken App. E2b-ii then owns the
strict Debug/Release/Investigation diagnostic bundle gate and exactly one final
full verifier. The Release/bundle gate must inspect built artifacts for
concrete Trash, Executor, Registered Action and process-runner markers and
verify the diagnostic target does not link `StornautExecution`;
source-reference checks alone are not accepted as final Mach-O evidence.

E2b-i is complete. The initial authority assertion failed with the expected
missing-Execution-source reason. The final 14-path checkpoint passed 3/3
package seam tests, 32/32 affected cleanup tests, the 73/73 Phase C product
gate, ordinary and Investigation diagnostic Debug App builds, and one
898-test / 37-suite serialized SwiftPM regression. Static review found no
public concrete authority, no concrete authority remaining in Core, and no
Investigation diagnostic dependency on `StornautExecution`; no unresolved
P0–P2 remain. See
[Task 39B2b-ii-E2b-i Review](../../reports/phase-d-task-39b2b-ii-e2b-i-review.md).
E2b-ii strict final-Mach-O admission is now active and exclusively owns the
single clean authoritative full verifier for the E2 checkpoint.

E2b-ii is complete. Its verifier contract
first failed on the missing authority-object requirement, then the final gate
bound seven concrete authority markers to the built `StornautExecution.o`
positive control, scanned every Mach-O in the Investigation diagnostic bundle
for the same forbidden markers, and enforced that only the ordinary
`StornautApp` target/Frameworks phase links `StornautExecution`. The strict
built-artifact gate passed after review strengthening; no unresolved P0–P2
remain. Its one clean authoritative full passed 23/23 stages without restart
or stage rerun; timed stages totaled 1,046.300 seconds. See
[Task 39B2b-ii-E2b-ii Review](../../reports/phase-d-task-39b2b-ii-e2b-ii-review.md).

With the E1/E2 prerequisites complete, the original signed-composition scope
resumes under the following frozen preflight.

### 2.4 39B2b-ii scope/cost preflight

39B2b-ii is a construction and signed-installation checkpoint, not a model or
machine-admission checkpoint. Its exact production call chain is:

```text
StornautInvestigationDiagnosticApp
→ StornautInvestigationDiagnostic static wrapper
→ InvestigationRuntimeDiagnosticFacade
→ InvestigationCodexSessionAdapter
→ CodexInteractiveAppServerClient
→ InvestigationLifecycleAppServerTransport
→ LifecycleInteractiveSessionXPCClient
→ installed StornautLifecycleHelper
→ same-helper user-UID worker
```

The package wrapper is the only new public composition surface. The dedicated
App continues to link one static package product and does not import the
package-closed `StornautInvestigationRuntime` target directly. The wrapper
internally owns the exact Evidence Store v4 path, bounded Probe Broker adapter,
nonce-derived report identity provider, lifecycle drain adapter, App Server
client and supervised interactive transport. It returns only an opaque
prepared composition whose public surface can prove identities and perform
explicit retirement. It does not expose arbitrary executable, provider,
model, auth, socket, command, network or cleanup inputs.

Construction validates the strict diagnostic configuration, exact fixed
installed-App/helper topology, current helper path and the checked-in
Investigation Envelope v2 schema. The App wrapper derives only the fixed
current non-root UID's `~/.codex/auth.json` path; it does not accept an auth
path from configuration, and the App Server client delays reading credential
bytes until `prepareRoot`. The helper-owned user-UID worker remains responsible
for fixed workspace creation, containment and Codex process launch. This
checkpoint never reads or edits `~/.codex/config.toml`.

The dedicated DEBUG diagnostic App becomes the exact fixed installed App for
the Investigation diagnostic and embeds the existing lifecycle helper through
an explicit helper target dependency and copy phase. The local lifecycle
installer therefore binds to:

```text
.derivedData/xcodebuildmcp/Build/Products/Debug/
    StornautInvestigationDiagnostic.app
```

and validates the diagnostic executable
`Contents/MacOS/StornautInvestigationDiagnostic` plus
`Contents/MacOS/StornautLifecycleHelper`. Ordinary `Stornaut.app` Debug and
Release builds remain negative controls and retain no Investigation diagnostic
activation marker or wrapper dependency.

The planned non-document write set was initially limited to:

```text
Package.swift
Sources/StornautInvestigationDiagnostic/
    InvestigationRuntimeDiagnosticAppLeaf.swift
Sources/StornautInvestigationDiagnostic/
    InvestigationRuntimeDiagnosticComposition.swift
StornautApp/Diagnostics/InvestigationRuntimeDiagnosticHarness.swift
StornautAppTests/InvestigationRuntimeDiagnosticTests.swift
Stornaut.xcodeproj/project.pbxproj
Stornaut.xcodeproj/xcshareddata/xcschemes/
    StornautInvestigationDiagnosticApp.xcscheme
scripts/stornaut-r5-local-lifecycle
scripts/verify-app-release-boundaries
scripts/verify-investigation-boundaries
```

That is ten non-document paths, below the fourteen-path checkpoint limit. New
non-document code is budgeted below approximately 3,000 lines. If
implementation requires another privilege surface, more than fourteen paths
or approximately 4,000 new non-document lines, it must split again before
those changes are written.

The pre-implementation call-chain audit then found one protocol-identity gap:
the App-side App Server client currently validates one exact `codexHome`, while
the helper-owned contained worker creates its workspace only after the
interactive `start` request and uses a random workspace component. A wrapper
cannot truthfully precompute that path. 39B2b-ii therefore also owns the narrow
fix that makes the client validate the server-reported `codexHome` against the
exact fixed Investigation run root and closed workspace shape rather than an
invented exact child path. This adds at most these four existing
non-document paths:

```text
Sources/StornautCodex/Runtime/CodexAppServerAdvisoryResult.swift
Sources/StornautCodex/Runtime/CodexInteractiveAppServerClient.swift
Sources/StornautInvestigationRuntime/
    InvestigationLifecycleAppServerTransport.swift
Tests/StornautInvestigationTests/
    InvestigationLifecycleAppServerTransportTests.swift
```

The resulting ceiling is fourteen non-document paths, still within the
approved checkpoint limit. The change may only expose the checked-in
Investigation Envelope v2 structured-output schema to sibling package targets,
validate `codexHome` under the nonce/user-bound fixed runtime root, and expose
the transport's already-confirmed retirement state to the lifecycle adapter.
It must not add a new request kind, arbitrary runtime/auth path input, broader
network authority or another lifecycle service.

The final implementation uses exactly fourteen non-document paths and adds
1,296 non-document lines with 96 deletions. It uses the two Codex runtime paths
above, a focused Codex client test and `scripts/verify-contract`; it does not
modify the existing Investigation lifecycle transport or its tests. The
checkpoint therefore reaches but does not exceed the frozen path ceiling.

Tests-first gates must initially fail because the current repository still has
a zero-dependency diagnostic leaf, no approved production-wrapper dependency
graph, no helper in the dedicated App, no helper scheme build entry, an
installer bound to ordinary `Stornaut.app`, and no opaque Task 38 composition
handle. The implementation turns only those exact failures green.

39B2b-ii may construct the full chain and prove that construction itself does
not start XPC, launch Codex, create an Investigation root, invoke a model or
write a readiness report. It may perform a signed deterministic composition
smoke against the installed helper only when the smoke terminates before
`prepareRoot`, `start` or `startTurn`. It must emit a
`compositionPrepared`/`compositionBlocked` receipt, never
`signedInvestigationRuntimeReady`.

The completed implementation follows that boundary. Construction initializes
the exact diagnostic Evidence Store v4 database but does not create the
helper-owned `R5Runtime/<uid>/<investigation>` root, open XPC, launch Codex or
read auth credential bytes. Focused validation and independent review are
recorded in
[Task 39B2b-ii Review](../../reports/phase-d-task-39b2b-ii-review.md); the
checkpoint's one frozen authoritative full verifier passed 23/23 stages in
981 wall-clock seconds with no restart or stage retry. 39B2b-ii is complete.

39B2c remains the sole owner of:

- any real model invocation;
- Task 38 start/turn/event/settlement driving;
- capability/control/denial three-plane evidence;
- failure-matrix execution;
- zero-residue machine admission; and
- every `signedInvestigationRuntimeReady` claim.

Before implementing those machine-only surfaces, the independently reviewed
attempt-binding prerequisite made raw capability worker evidence carry the
exact Task 39 Investigation UUID and complete configuration-binding SHA-256
through App → XPC → helper → worker. The final verifier reconstructs the
receipt from authoritative raw metadata/worker/lifecycle/repository evidence,
and receipt decoding reconstructs all four canonical component projections.
See the
[39B2c Attempt-Binding Prerequisite Review](../../reports/phase-d-task-39b2c-attempt-binding-prerequisite-review.md).
This prerequisite made no machine-readiness claim.

The independently reviewed deterministic machine-contract preflight also found
that the reused capability report and serialized derived outcome accepted
unknown fields. The tests-first strict-decoding prerequisite closed every
relevant report layer and requires reconstructed outcome equality. See the
[39B2c Strict-Decoding Prerequisite Review](../../reports/phase-d-task-39b2c-strict-capability-decoding-prerequisite-review.md).
It likewise made no machine-readiness claim and did not consume the frozen
39B2c checkpoint's final full-verifier run.

The independently reviewed L1 residue prerequisite now requires the signed
root helper to generate a strict nonce/UID/same-retire observation after
audit-session drain, worker reap, diagnostic-root removal and lease removal,
before releasing the active slot. Investigation transport rejects missing,
foreign, stale, future, replayed or non-zero observations. See the
[39B2c-L1 Review](../../reports/phase-d-task-39b2c-l1-residue-observation-review.md).
It proves only per-run helper-owned residue. The machine driver must still
provide an independent root topology observation for App/helper/service
teardown before any readiness verdict.

The independently reviewed L2 prerequisite now provides that read-only
topology observation contract without performing teardown itself. It binds the
fixed App/helper executables, signatures, plist, service identity, complete
PID-version/audit-token identities and whole runtime/lease roots across
installed and post-teardown phases. Only initial `ENOENT`/`ESRCH` observations
prove absence; later disappearance or observer failure stays unresolved. The
observation is package-closed, non-`Codable` and file-private to construct. See
the [39B2c-L2 Review](../../reports/phase-d-task-39b2c-l2-root-topology-observation-review.md).
It makes no readiness claim and leaves build/install/run/bootout/uninstall,
failure-matrix execution and sealed machine-report assembly to the driver.

The remaining L3 work is split before driver coding:

1. **L3a trusted target extraction** — move the existing machine-only Codable
   contract, filesystem revalidation, sealed cohort, assembler and verifier into
   the non-product `StornautInvestigationMachine` target. Keep trusted
   declarations module-internal; do not add an executable, CLI, collector,
   model call or readiness result. This checkpoint is complete; see the
   [L3a Review](../../reports/phase-d-task-39b2c-l3a-trusted-machine-target-review.md).
2. **L3b root collection** — add the fixed-service observer and root-owned
   machine driver composition inside the trusted target, combine L1/L2 evidence
   in one sealed window and exercise synthetic lifecycle transitions. It must not
   emit final readiness or consume the final full gate.
3. **L3c1 opaque retirement bridge** — close the live handoff gap before adding
   a driver. Its path-level preflight is split again because the strict worker/
   broker wire and the helper/root escrow have separate test surfaces and would
   otherwise require more than 14 non-document paths:
   - **L3c1a typed owner retirement** makes the contained owner mint a non-
     `Codable` success observation only after exact process-group reap, bounded
     stderr retirement and workspace removal; propagates only strict wire facts
     through the worker/broker/helper path; and makes Investigation transport
     distinguish owned-resource retirement from a never-started no-resource
     retirement. It changes no XPC listener role and creates no root claim. Its
     budget is at most 14 non-document paths and 2,200 added lines, including
     the exact structural boundary verifier. This checkpoint is complete; its
     86 focused tests, exact boundaries, targeted build, 11 App tests, 1012-test
     clean staged-only serial and post-fix review passed. See the
     [L3c1a Review](../../reports/phase-d-task-39b2c-l3c1a-typed-owner-retirement-review.md).
   - **L3c1b helper-owned opaque escrow** records a challenge-bound, one-shot
     capsule only after the L3c1a owner truth and same-retire L1 zero. A future
     exact signed root driver may claim it once and reconstruct only a module-
     internal, non-`Codable` authority. The claim must survive App exit, but
     helper restart, stale/foreign identity, connection-epoch drift, replay,
     cancellation or deadline failure must destroy admission. Production root
     claim stays closed until L3c2 supplies an exact signed driver identity.
     The original path preflight reached exactly 14 non-document paths after
     preserving the helper-minted opaque handle through Runtime and migrating
     the structural gate. Independent review then found that Investigation ID,
     operation, token and process identities alone did not prevent a capsule
     from one signed-runtime configuration being joined to another configuration
     with the same Investigation ID. Closing that P1 requires the production
     diagnostic composition to inject its canonical complete machine-configuration
     binding,
     which would be a fifteenth path. L3c1b is therefore split before that
     review fix is coded:
     - **L3c1b-i configuration-bound helper escrow** owns at most twelve
       non-document paths and 2,500 added lines:
       `Sources/StornautLifecycle/LifecycleMachineRetirementEscrow.swift` (new),
       `Sources/StornautLifecycle/LifecycleInteractiveSessionContract.swift`,
       `Sources/StornautLifecycle/LifecycleInteractiveSessionBroker.swift`,
       `StornautLifecycleHelper/main.swift`,
       `Sources/StornautInvestigationRuntime/InvestigationLifecycleAppServerTransport.swift`,
       `Sources/StornautInvestigationDiagnostic/InvestigationRuntimeDiagnosticComposition.swift`,
       `Tests/StornautLifecycleTests/LifecycleMachineRetirementEscrowTests.swift`
       (new),
       `Tests/StornautLifecycleTests/LifecycleInteractiveSessionContractTests.swift`,
       `Tests/StornautLifecycleTests/LifecycleInteractiveSessionBrokerTests.swift`,
       `Tests/StornautInvestigationTests/InvestigationLifecycleAppServerTransportTests.swift`
       `Tests/StornautInvestigationTests/SignedRuntimeContractTests.swift` and the
       minimal existing Runtime-constructor compatibility hunk in
       `Tests/StornautInvestigationTests/InvestigationLifecycleTopologyTestSupport.swift`.
       It reuses `machineConfigurationSHA256()` from the exact decoded signed
       configuration; no alternate hash, optional/empty value or legacy
       fallback is permitted. The strict interactive start/retire path, escrow
       entry, opaque handle and claim echo must all carry the same lowercase
       64-hex value. The helper stores only that digest and the token digest.
       This checkpoint is complete. Its 58-test clean staged focused gate,
       136-test Lifecycle suite, 168-test Investigation suite, targeted Debug
       App/helper build, 11/11 dedicated App tests, 1025-test clean staged-only
       serial and independent post-fix reviews passed. See the
       [L3c1b-i Review](../../reports/phase-d-task-39b2c-l3c1b-i-configuration-bound-helper-escrow-review.md).
     - **L3c1b-ii synthetic Machine claim and collector join** owns at most seven
       non-document paths and 1,900 added lines:
       `Sources/StornautInvestigationMachine/InvestigationMachineRetirementClaim.swift`
       (new),
       `Sources/StornautInvestigationMachine/InvestigationLifecycleTopologyCollector.swift`,
       `Tests/StornautInvestigationTests/InvestigationMachineRetirementClaimTests.swift`
       (new),
       `Tests/StornautInvestigationTests/InvestigationLifecycleTopologyCollectorTests.swift`,
       `Tests/StornautInvestigationTests/InvestigationLifecycleTopologyTestSupport.swift`,
       `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
       and `scripts/verify-investigation-boundaries`. It preserves the exact
       digest in the non-`Codable` claim and rejects any mismatch with the
       collection request's canonical signed-runtime configuration before L2 or
       transition work.
       This checkpoint is complete. Its 20-test focused gate, 139-test
       Lifecycle suite, 178-test Investigation suite, targeted Debug diagnostic
       App build, 1035-test clean staged-only serial and independent grouped/
       cross-group review passed. See the
       [L3c1b-ii Review](../../reports/phase-d-task-39b2c-l3c1b-ii-synthetic-machine-claim-review.md).
     It must not modify `LifecycleSupervisorXPC.swift`, add an Objective-C XPC
     selector, add a concrete claim client/sender or weaken the existing exact
     App-only/non-root one-connection listener. The helper owns one bounded
     in-memory `empty -> recorded -> consumed` escrow. It records before the
     retired reply, enters `awaitingClaim`, survives the expected App disconnect
     until the claim deadline, and exits on expiry. A disconnect before record,
     helper restart, invalid claim or expiry remains blocked; no escrow data is
     persisted. L3c1b-ii exposes only an injected synthetic Machine claim source.
     L3c2 must separately preflight the exact signed root-driver identity,
     endpoint and authorization-before-consume ordering.
   Together they replace inferred `managedProxyOwnerEmpty`/`probeWorkerEmpty`
   values with an independent typed owner-retirement observation joined to the
   same audit-session L1 zero. Both are synthetic-only: no install/uninstall,
   model, report, readiness or full verifier.
4. **L3c2 closed deterministic machine driver** — the mandatory post-L3c1
   scope/trust/cost preflight found three independent security surfaces: a
   role-separated root claim transport, a non-product root host/L1+L2 topology
   composition and the eight-scenario Task 38 state machine. Their combined
   write set exceeds fourteen non-document paths, so L3c2 is split before
   coding rather than recreating an oversized review surface. Local evidence
   supports the selected topology: the installed `launchd.plist` manual
   requires a daemon to check in for any advertised `MachServices`, and the
   current Foundation SDK exposes per-name privileged `NSXPCListener` and
   `NSXPCConnection` initializers. A repository-external SwiftPM spike also
   proved that a non-product executable target can depend on a non-product
   library target and call its `package` facade on the current toolchain. An
   independent sanity review found two preflight P2s—an omitted root-policy
   path and an unspecified second service identifier—which were corrected by
   the exact fourteen-path list and fixed identifiers below:
   - **L3c2a-i strict Machine-claim transport** adds a second fixed launchd Mach
     service, exactly
     `com.eriklee.stornaut.lifecycle.machine-claim`, owned by the existing root
     helper, with a separate claim-only XPC interface and listener delegate. The
     existing App endpoint remains exact
     App-signed, non-root and one-connection; its interface, peer policy and
     accepted-connection state are not shared with the root-driver role. The
     claim listener accepts only EUID 0 plus the complete PID-version/audit-
     session/audit-token identity, exact fixed executable path and exact code-
     signing identity of
     `/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautInvestigationMachineDriver`.
     The driver's fixed signing identifier is exactly
     `com.eriklee.stornaut.investigation.machine-driver`; no prefix, team-only,
     bundle-only or caller-supplied identity match is accepted.
     It revalidates that identity immediately before calling the escrow, and
     authorization must be established before `claim` can consume any entry.
     The escrow exposes one integrated fixed-driver authorization-and-claim
     operation; a public/package Boolean `authorized` parameter, raw caller-
     selected signing identity or separately mintable claim authority is
     prohibited. The operation re-reads the full caller identity, fixed process
     executable path and static/dynamic signing identity immediately before the
     terminal escrow state change.
     The root client independently pins the current helper executable and
     signing identity. Missing driver/helper files, helper restart, peer drift,
     selector drift, replay, malformed wire, deadline or connection failure all
     fail closed. The helper may start while the driver is not yet packaged; in
     that intermediate state the new role is unreachable rather than weakening
     the App route. This checkpoint owns exactly fourteen possible non-document
     paths and at most 3,000 added lines:
     `Sources/StornautLifecycle/LifecycleServiceRegistration.swift`,
     `Sources/StornautLifecycle/LifecycleAppAuthorization.swift`,
     `Sources/StornautLifecycle/LifecycleSupervisorXPC.swift`,
     `Sources/StornautLifecycle/LifecycleMachineRetirementEscrow.swift`,
     `StornautLifecycleHelper/main.swift`,
     `StornautLifecycleHelper/com.eriklee.stornaut.lifecycle.plist`,
     `Tests/StornautLifecycleTests/LifecycleServiceRegistrationTests.swift`,
     `Tests/StornautLifecycleTests/LifecycleAppAuthorizationTests.swift`,
     `Tests/StornautLifecycleTests/LifecycleMachineRetirementEscrowTests.swift`,
     `Tests/StornautLifecycleTests/LifecycleMachineClaimXPCContractTests.swift`
     (new),
     `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`,
     `scripts/verify-investigation-boundaries`,
     `scripts/stornaut-r5-local-lifecycle` and
     `scripts/verify-app-release-boundaries`. It adds no Machine host, App
     handoff, model, scenario driver, report or readiness result.
     `LifecycleMachineDriverAdmissionPolicy` lives only in
     `LifecycleAppAuthorization.swift`; it owns fixed path plus complete static/
     dynamic signing and full process-identity comparison. The XPC/helper files
     may consume its Boolean result but may not reimplement or weaken it. The
     fourteenth-path ceiling is hard: any additional source/test/script path
     requires another pre-coding split.
     This checkpoint is complete. Its 36-test focused gate, 144-test Lifecycle
     suite, 178-test Investigation suite, exact structural/release boundaries,
     targeted diagnostic App/helper build, 1041-test clean staged-only serial
     and independent post-fix review passed. See the
     [L3c2a-i Review](../../reports/phase-d-task-39b2c-l3c2a-i-machine-claim-transport-review.md).
   - **L3c2a-ii non-product root host and topology composition** adds an
     executable SwiftPM target that depends on the non-product
     `StornautInvestigationMachine` target but is itself omitted from the
     package `products` list. The host is
     root-only and exposes one narrow `package` facade; it composes the strict
     claim client/claimant with the existing collector, enforces
     `claim -> installed L2 -> transition -> post-teardown L2`, and returns only
     opaque non-`Codable` authority to the Machine module. It accepts no caller-
     selected executable, service, path, socket, PID, signal or cleanup action.
     Its deterministic checkpoint uses an injected one-shot handle handoff;
     packaging the driver into the installed App and the real App-to-driver
     handoff remain L3c3 scope. This checkpoint owns at most eight non-document
     paths and 2,400 added lines: `Package.swift`,
     `Tools/StornautInvestigationMachineDriver/main.swift` (new),
     `Sources/StornautInvestigationMachine/InvestigationMachineDriverHost.swift`
     (new), optional narrow edits to
     `Sources/StornautInvestigationMachine/InvestigationMachineRetirementClaim.swift`
     and
     `Sources/StornautInvestigationMachine/InvestigationLifecycleTopologyCollector.swift`,
     `Tests/StornautInvestigationTests/InvestigationMachineDriverHostTests.swift`
     (new),
     `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
     and `scripts/verify-investigation-boundaries`.
     This checkpoint is complete. Its root-only terminal host, strict XPC and
     independent helper-signing adapters, resolved package/source authority
     gate, 20-test affected regression, 187-test Investigation suite, targeted
     driver/diagnostic builds, three-bundle release boundary, mutation negative
     control, 1046-test clean staged-only serial and independent post-fix review
     passed. See the
     [L3c2a-ii Review](../../reports/phase-d-task-39b2c-l3c2a-ii-machine-driver-host-review.md).
   - **L3c2b fixed eight-scenario driving** adds the closed deterministic state
     machine using injected DEBUG faults and fake Task 38 transports. It creates
     a fresh nonce/root/config/Store per scenario and proves the exact success,
     cancellation, timeout, invalid-envelope, identity-mismatch, transport-loss,
     lifecycle-recovery and artifact-cleanup-recovery controls already pinned by
     `SignedInvestigationRuntimeMachineCaseEvidence`. Every path must settle or
     fail closed, retire artifacts, drain local runtime and preserve one-shot
     topology collection. It may emit a failure matrix or machine-admission-
     pending candidate only; it cannot call a real model, use authoritative R5
     capability evidence, create a Ready receipt or perform live install/
     uninstall. This checkpoint owns at most eight non-document paths and 3,000
     added lines: up to two new Machine scenario-driver/fault files, the existing
     host file, up to two focused test/support files, the Machine boundary test
     and structural verifier, plus at most one fixed runner contract.
     Its mandatory preflight found that fresh nonces/Investigation IDs make
     actual plan fingerprints unique while the old matrix incorrectly required
     one shared synthetic plan fingerprint. The independently reviewed
     [plan-freshness prerequisite](../../reports/phase-d-task-39b2c-l3c2b-plan-freshness-prerequisite-review.md)
     now requires eight unique actual plan fingerprints plus one shared exact
     target-set fingerprint, with strict schema migration. L3c2b is complete:
     its exact eight-path implementation, 8/8 focused scenarios, 197-test
     Investigation suite, structural and targeted driver/App/release gates,
     final independent review and one 1,055-test clean staged-only serial passed.
     See the
     [L3c2b Review](../../reports/phase-d-task-39b2c-l3c2b-eight-scenario-driver-review.md).

   The L3c2 preflight also closed two ordering ambiguities. The escrow surviving
   App disconnect is a failure-tolerance property, not permission to postpone
   installed-L2 proof until the App has vanished: the live order remains driver
   ready, App retirement/record, driver claim while the exact App/helper/service
   topology is still observable, installed L2, transition, then post-teardown
   L2. That sequence is historical synthetic L3c2 evidence: live multi-epoch
   composition replaces per-epoch global post-teardown with exact epoch process
   retirement and reserves global post-teardown L2 for final uninstall. The opaque App-to-driver handle handoff is not smuggled through JSON, a
   filesystem mailbox or the helper claim response; its current-source live
   implementation is explicitly deferred to L3c3. The untracked verifier/CLI
   sketches in the user's separate main worktree are stale, outside this
   worktree and excluded from every L3c2 budget.
5. **L3c3 current-source real-success three-plane composition** — bind one fresh
   success attempt to the exact current source/App/helper/runtime receipt and run
   the bounded real Task 38 flow with authenticated `openai` / `gpt-5.6-luna`.
   Reuse the existing R5 capability collector and strict report types rather than
   nesting the old R5 script or generating a second nonce. Join 9/9 observed
   capabilities, 12/12 enforced controls, attributed adversarial denials and the
   opaque L1/L2/owner-retirement cohort. Its preflight must also package the
   fixed Machine driver into the installed current-source App, add the driver
   executable/code-signing hash and fixed Machine-claim service identifier to
   the authoritative attempt/runtime binding, and implement a one-shot non-
   persistent App-to-parent handle handoff that is
   ready before App launch. It must prove the App stays alive through driver
   claim and installed-L2 observation; only the driver transition may allow App/
   helper/service teardown. The handle may not travel through config JSON, the
   filesystem, the claim response or a caller-selected endpoint. This checkpoint
   may produce only a
   machine-admission-pending candidate and does not consume the final full.
   The mandatory fresh scope/trust preflight found four independent surfaces
   and split this work before coding into **L3c3a driver-bound signed-attempt
   schema**, **L3c3b native driver packaging/installed-topology admission**,
   **L3c3c-i parent-owned handoff/launcher spike and root-launch audit**,
   **L3c3c-ii-a authority-closed live DriverSupport**, **L3c3c-ii-b fixed
   handoff composition**, **L3c3c-ii-c one no-model outer installed-driver gate**,
   and **L3c3d one real-success three-plane pending candidate**. The original
   SwiftPM driver had a
   toolchain-derived ad-hoc identifier rather than the fixed accepted signing
   identifier; the Xcode diagnostic target and installer currently reject a
   packaged driver; and the current App receives retirement handle material in
   the helper XPC response before immediately retiring and writing a filesystem
   receipt. The original parent-owned/anonymous-XPC idea was not an accepted
   transport design. L3c3c-i must prove and record the exact launcher/handoff
   topology before production code. See the
   [L3c3 Scope/Trust Preflight](../../reports/phase-d-task-39b2c-l3c3-scope-trust-preflight.md).
   L3c3a is complete. Its exact fourteen-path / 1,266-added-line implementation
   added the strict driver binding and enclosing schema migrations, independent
   App-leaf decoding, complete installed static-identity comparison and temporary
   blocked-until-L3c3b structural/release gates. Review found and tests-first
   fixed a 40-versus-64-hex CodeDirectory-hash incompatibility; 199 Investigation
   tests, 11 App tests, targeted gates, one 1,057-test clean staged-only serial and
   independent post-fix review passed. See the
   [L3c3a Review](../../reports/phase-d-task-39b2c-l3c3a-driver-binding-review.md).
   The fresh L3c3b preflight found that native Xcode packaging and root-owned
   installer/L2 admission are independent trust surfaces whose combined path set
   exceeds the hard review ceiling. L3c3b is therefore split before coding into
   **L3c3b-i native diagnostic-only packaging** and **L3c3b-ii installer and L2
   driver admission**. See the
   [L3c3b Scope/Trust Preflight](../../reports/phase-d-task-39b2c-l3c3b-scope-trust-preflight.md).
   The first b-i final-Mach-O spike then proved that linking the complete Machine
   target carries forbidden Core Cleanup/Policy/Registered Action surfaces even
   in Release. A mandatory **L3c3b-0 authority-closed driver runtime extraction**
   is inserted before b-i; see its
   [preflight](../../reports/phase-d-task-39b2c-l3c3b-driver-runtime-authority-preflight.md).
   L3c3b-0 is complete after the authority-closed target extraction, explicit
   Debug/Release final-Mach-O gates, one clean staged-only serial and independent
   post-fix review; see its
   [review](../../reports/phase-d-task-39b2c-l3c3b-driver-runtime-authority-review.md).
   L3c3b-i is complete after its diagnostic-only native target, exact copy/sign
   graph, ordinary absence and final-artifact gates; see its
   [review](../../reports/phase-d-task-39b2c-l3c3b-i-native-driver-packaging-review.md).
   L3c3b-ii is complete after exact built/staging/installed admission, L2 driver
   evidence, ACL fail-closed, whole-installer source sealing, a six-case
   disposable matrix, one clean staged-only serial and independent grouped/
   post-fix/cross-group review; see its
   [review](../../reports/phase-d-task-39b2c-l3c3b-ii-installer-l2-admission-review.md).
   L3c3c-i split its research into **i-a** transport/identity/protocol/lifecycle,
   **i-b1** root-to-UID implementation/non-root/cleanup/static review,
   **i-b2a** signed-projection reproducibility and **i-b2b-0a** root-launch
   trust-anchor audit. i-a, i-b1 and i-b2a are complete as external algorithm/
   reproducibility evidence; i-b2b-0a is complete with NO-GO for external root
   staging:
   two B3-v8 19/19 matrices and the forced-drain negative contained all
   scenarios, the public Security probe preserved live-vnode validity while
   rejecting replacement-path static identity, and B4 passed strict compile,
   pre-spawn non-root rejection, cleanup negative and independent static review.
   i-b2a freezes the historical B4 full SHA
   `d157241035e9bdda8bd5ed139509fcb23ae45528ae79b89e3d22b98d614e760d`;
   a fresh fixed-UID build matches both normalized
   unsigned complete-Mach-O projections; and fixed-identifier strict signing,
   CodeDirectory and the parsed signed prefix must match. Only the measured 193
   post-SuperBlob padding bytes may differ, and copying reviewed padding is
   forbidden. i-b2b-0a retains exact final7 B4/driver/stager/verifier hashes and
   synthetic rc75/25-negative evidence, but two independent reviews rejected
   both `sudo -v` and separate no-cache stock-command root-launch topologies.
   i-b2b-0b staging and i-b2b-1 execution are superseded before execution; B4
   root execution count is zero and no root artifact or receipt exists.
   Therefore
   [ADR 0018](../../adr/0018-parent-owned-investigation-handoff.md) remains
   Proposed, while L3c3c-i is complete as a NO-GO audit, L3c3c-ii-a is complete,
   and the nested exact-wire split is frozen; ii-b0a/ii-b0b/ii-b0c, ii-b1,
   the ii-b2 ASID prerequisite, ii-b2a, ii-b2b-i, ii-b2b-ii, iii-a, iii-b-i and
   iii-b-ii, ii-b3a, ii-b3b, ii-b3c and ii-b4 are complete; ii-b5 is split
   into b5a0/b5a/b5b-i/b5b-ii/b5b-iii; b5a0, b5a, b5b-i-a and i-b1 are
   complete/non-admitting. The b5b-i exact-path preflight leaves i-b2a/i-b2b/
   i-b3; i-b2a is current, while i-c retains the DriverSupport join and
   legacy-owner closure.
   See the
   [study](../../upstream-studies/phase-d-task-39b2c-l3c3c-parent-owned-handoff.md)
   and [final review](../../reports/phase-d-task-39b2c-l3c3c-i-handoff-launcher-spike-review.md),
   plus the [i-b2a review](../../reports/phase-d-task-39b2c-l3c3c-i-b2a-reproducibility-contract-review.md),
   [i-b2b-0a review](../../reports/phase-d-task-39b2c-l3c3c-i-b2b-0a-root-provenance-review.md)
   and [installed-driver preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-installed-driver-path-cost-preflight.md),
   plus the [ii-a review](../../reports/phase-d-task-39b2c-l3c3c-ii-a-installed-driver-observation-review.md),
   [ii-b split preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b-split-preflight.md),
   [ii-b0 wire preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b0-wire-contract-preflight.md),
   [ii-b0a review](../../reports/phase-d-task-39b2c-l3c3c-ii-b0a-review.md) and
   [ii-b0b review](../../reports/phase-d-task-39b2c-l3c3c-ii-b0b-review.md).
   The first-frame origin correction is frozen in the
   [ii-b0c preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b0c-epoch-bootstrap-preflight.md).
   Completion evidence is in the
   [ii-b0c review](../../reports/phase-d-task-39b2c-l3c3c-ii-b0c-review.md).
   The ii-b1 post-RED topology correction, exact implementation boundary and
   completion evidence are recorded in the
   [ii-b1 preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b1-app-leaf-preflight.md)
   and
   [ii-b1 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b1-review.md).
   The ASID correction and completion evidence are recorded in the
   [ii-b2 ASID preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b2-asid-prerequisite-preflight.md)
   and
   [ii-b2 ASID review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2-asid-prerequisite-review.md).
   The server split and completion evidence are recorded in the
   [ii-b2b server preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b2b-server-integration-preflight.md)
   and
   [ii-b2b-i review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2b-i-review.md).
   ii-b2b-ii evidence is in the
   [legacy-client quarantine review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2b-ii-review.md).
   The current split is frozen by the
   [iii-a/iii-b preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b2b-iii-split-preflight.md).
   iii-a completion evidence is in the
   [handle v3 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2b-iii-a-review.md).
   iii-b-i completion evidence is in the
   [live integration review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2b-iii-b-i-review.md).
   iii-b-ii completion evidence is in the
   [physical adapter review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2b-iii-b-ii-review.md).
   The ii-b3 trust/cost split is frozen by the
   [ii-b3 preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b3-split-preflight.md).
   ii-b3 completion evidence is in the
   [ii-b3a review](../../reports/phase-d-task-39b2c-l3c3c-ii-b3a-review.md),
   [ii-b3b fixture review](../../reports/phase-d-task-39b2c-l3c3c-ii-b3b-fixture-prerequisite-review.md),
   [ii-b3b seam review](../../reports/phase-d-task-39b2c-l3c3c-ii-b3b-review.md)
   and [ii-b3c review](../../reports/phase-d-task-39b2c-l3c3c-ii-b3c-review.md).
   The fixed helper-claim contract and completion evidence are in the
   [ii-b4 preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b4-preflight.md)
   and [ii-b4 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b4-review.md).
   The b5 split, claim-abort completion and typed composer completion evidence
   are in the
   [ii-b5 preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b5-split-preflight.md),
   [ii-b5a0 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5a0-review.md),
   [ii-b5a review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5a-review.md)
   and [ii-b5b-i-a review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-i-a-review.md)
   and [ii-b5b-i-b1 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-i-b1-review.md).
   The projection/observer/legacy-owner split is frozen in the
   [ii-b5b-i exact-path preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-i-exact-path-preflight.md).
   ii-a implements only authority-closed self-observation/runtime primitives.
   ii-b is frozen as **ii-b0a frame/capsule contract**, **ii-b0b claim/release
   wire contract**, **ii-b1 authority-
   free App leaf**, **ii-b2 handle-free helper response**, **ii-b3a fixed channel/
   root peer/drop adapter**, **ii-b3b start-to-retire-only Lifecycle seam**,
   **ii-b3c concrete leaf/native entry**, **ii-b4 fixed claim client** and **ii-b5
   single-epoch composition**; **ii-c0** requires its own fresh preflight and
   proves only gate-side launcher/FD hygiene, not real-sudo child behavior. The split preserves a
   zero-argument driver using only a pre-opened bounded stdin cohort capsule,
   removes the opaque handle/token from the helper reply and reserves global
   post-teardown L2 for final uninstall rather than every epoch. Per-epoch L2 is
   a timestamp barrier followed by exact helper release/exit; the next epoch
   attests a fresh helper. ii-c alone rebuilds/
   installs/re-admits and invokes the fixed installed driver once as an outer
   supervisor containing closed scenario epochs, with
   no model call. Only a green ii-c gate may accept ADR 0018.
6. **L3c4 sealed final admission** — execute the authoritative current-source
   cohort with eight independent fresh nonces, one real success model run and
   bounded closed failure injections; perform exact per-case teardown, fixed
   bootout/uninstall and zero-residue observation; revalidate all three planes in
   the sealed machine target; promote pending to
   `signedInvestigationRuntimeReady`; create the privacy-safe report/receipt and
   source seal; then, after independent review is green, run the one remaining
   uninterrupted authoritative full verifier. The final full is receipt/source/
   raw-evidence read-only and must not repeat model calls or root mutation.

The order is strict: `L3c1a -> L3c1b-i -> L3c1b-ii -> L3c2a-i -> L3c2a-ii ->
L3c2b -> L3c3a -> L3c3b-0 -> L3c3b-i -> L3c3b-ii -> L3c3c-i-a ->
L3c3c-i-b1 -> L3c3c-i-b2a -> L3c3c-i-b2b-0a -> L3c3c-ii-a ->
L3c3c-ii-b0a -> L3c3c-ii-b0b -> L3c3c-ii-b0c -> L3c3c-ii-b1 ->
L3c3c-ii-b2 ASID prerequisite -> L3c3c-ii-b2a -> L3c3c-ii-b2b-i ->
L3c3c-ii-b2b-ii -> L3c3c-ii-b2b-iii-a -> L3c3c-ii-b2b-iii-b-i ->
L3c3c-ii-b2b-iii-b-ii -> L3c3c-ii-b3a -> L3c3c-ii-b3b ->
L3c3c-ii-b3c ->
L3c3c-ii-b4 -> L3c3c-ii-b5a0 -> L3c3c-ii-b5a -> L3c3c-ii-b5b-i-a ->
L3c3c-ii-b5b-i-b1 -> L3c3c-ii-b5b-i-b2a -> L3c3c-ii-b5b-i-b2b ->
L3c3c-ii-b5b-i-b3 -> L3c3c-ii-b5b-i-c ->
L3c3c-ii-b5b-ii -> L3c3c-ii-b5b-iii -> L3c3c-ii-c0 -> L3c3c-ii-c -> L3c3d -> L3c4`.
L3c1, L3c2, L3c3a,
L3c3b-0, L3c3b-i, L3c3b-ii, L3c3c-i and L3c3c-ii-a are complete;
i-b2b-0b/i-b2b-1 were superseded before execution. The ii-b split is frozen and
ii-b0a/ii-b0b/ii-b0c/ii-b1, the ii-b2 ASID prerequisite, ii-b2a, ii-b2b-i and
ii-b2b-ii, ii-b2b-iii-a, iii-b-i, iii-b-ii, ii-b3a and ii-b3b are complete;
ii-b3c concrete leaf/native entry, ii-b4 fixed helper-claim client, ii-b5a0 and
ii-b5a, ii-b5b-i-a and i-b1 are complete and non-admitting; i-b2a is current,
followed by i-b2b/i-b3.
ADR 0018
remains Proposed until ii-c succeeds. L3c1 used focused
Codex/Lifecycle/Investigation tests, exact structural boundaries, one clean
staged serial regression, targeted helper/diagnostic builds and independent
review in place of full. Each L3c2 sub-checkpoint uses structural, focused, one
clean staged serial, applicable targeted build and independent review in place
of full. L3c3 must receive its own fresh scope/cost preflight and recorded non-
admitting validation funnel. L3c4 alone owns the
live readiness claim and Task 39's final full.

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

39B1b-ii adds a separate zero-dependency static diagnostic leaf and a
one-source DEBUG App target that performs only strict configuration preflight
and exclusive bounded receipt creation. Ordinary Debug/Release Apps reject the
diagnostic marker; the diagnostic product contains no normal App model/UI,
Codex transport, Lifecycle/helper, cleanup, Executor, network or process
surface. The test bundle alone links `StornautInvestigation` to compare the
preflight against the authoritative configuration, and product scanning occurs
before XCTest injection. It still does not invoke a model or compose the
production Investigation runtime.

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

Use a cost-ordered validation funnel. Run heavy work serially:

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

For a product/security checkpoint, then run:

```text
swift test --no-parallel
scripts/verify --full
```

Do not use the full verifier to discover ordinary compile, unit, structural or
bundle-boundary failures. Resolve and rerun the narrow failed stage first.
Start one clean final full only when the focused funnel and independent review
are green, and preserve per-stage timing in the checkpoint report.

The completed E2a seam used the explicit exception documented in §3: after its red
structural gate and focused tests, run `scripts/verify --headless`, which owns
the checkpoint's one serialized SwiftPM regression, then a targeted Debug App
build and independent review. Do not run a second standalone serialized suite
before or after headless. E2a omits full/XCUITest because it changes neither UI
nor final authority.
The completed E2b-ii checkpoint passed the strict final-binary/Release gates
and exactly one clean authoritative full after all cheaper layers and review
were green. E2b-i did not receive a redundant full run.

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
