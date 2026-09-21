# Phase D Task 39B2c-L3c3c-ii-b3c Concrete Leaf/Entry Preflight

> Status: Complete; implementation and completion evidence recorded in the
> [ii-b3c review](phase-d-task-39b2c-l3c3c-ii-b3c-review.md); non-admitting
>
> Date: 2026-08-20
>
> Baseline: `61a24738c2c0b004e42986ed89126bb41d2cee5a`
>
> Scope: documentation and current-source inspection only; no source/test/script
> implementation, App/helper/XPC launch, install, sudo, model/auth use, serial
> regression or authoritative full verifier

## 1. Decision

L3c3c-ii-b3c can remain one bounded implementation checkpoint. ii-b3a now owns
the fixed FD 7/root-peer/bootstrap/credential-drop effects, ii-b3b owns the
package-closed exact `[start, retire]` Lifecycle operation, and the completed
pure leaf owns the wire/state sequence. The diagnostic SwiftPM target already
depends on every required package, and the native diagnostic Debug App already
links that target. No `Package.swift`, Xcode project/scheme, wire contract,
Runtime transport or helper/Lifecycle-server change is required.

This checkpoint joins those three completed surfaces without widening authority:

1. the sole public no-argument entry becomes directly async;
2. one package-internal concrete operations object owns the b3a adapter and one
   no-auth retirement factory;
3. strict configuration decoding reuses
   `SignedInvestigationRuntimeDiagnosticConfiguration.decodeValidated`;
   received bytes must equal `canonicalJSONData()` so the pure-leaf raw SHA and
   Lifecycle/Machine `machineConfigurationSHA256()` are one exact digest;
4. configuration machine-driver binding is compared to b3a's stable peer
   observation for same-epoch consistency only;
5. a narrow composition creates only the Lifecycle XPC session and b3b transport,
   calls `startAndRetireWithEvidence()`, consumes one exact retirement result and
   exposes no business/auth/model client; and
6. the existing pure leaf drives every handoff frame to terminal EXIT.

The existing config-path diagnostic and auth-capable product composition remain
unchanged. ii-b3c does not independently authenticate the driver: ii-c still
owns trusted current-source installer/static binding before root launch.

## 2. Frozen Call Graph

```text
Diagnostic App @main Task
  -> InvestigationRuntimeDiagnosticHarness.run(...)
     -> activation == inheritedHandoff
     -> admit fixed FD 7 duplex AF_UNIX/SOCK_STREAM shape
     -> await InvestigationHandoffAppLeafEntryPoint.run()

EntryPoint.run()
  -> create InvestigationHandoffAppLeafAdapter(system: .system)
  -> adapter.admitPeerAndBootstrap()
     -> LOCAL_PEERTOKEN / root-driver admission / stable signing evidence / STNP
  -> create one-shot concrete operations with that observation
  -> create InvestigationHandoffAppLeaf
  -> await leaf.run()
     -> PRE_DROP_READY / DROP_RELEASE
     -> fixed identity drop and DROP_EVIDENCE
     -> receive strict v3 configuration
     -> decode required v2 complete binding
     -> compare machine-driver executable/signing/DR/CDHash to peer evidence
     -> require canonical configuration bytes and compute one exact config SHA
     -> CONFIGURATION_ACK / HELLO
     -> no-auth Lifecycle session + transport
     -> startAndRetireWithEvidence()
        -> start / started / retire / retirement evidence
        -> zero write/read line bytes
     -> exact Lifecycle handle -> handoff retirement handle
     -> HANDLE / ACK / RELEASE / ALIVE / write EOF / EXIT
  -> .completed => 0; every failure => one fixed nonzero status
```

The root-native machine driver remains outside this checkpoint and retains its
current unavailable entry. b4/b5 later own the parent-side claim and complete
single-epoch composition.

## 3. Frozen Scope and Cost

At most eleven non-document paths and 2,800 added-or-changed lines:

1. `Sources/StornautInvestigationDiagnostic/InvestigationHandoffAppLeaf.swift`;
2. `Sources/StornautInvestigationDiagnostic/InvestigationHandoffAppLeafAdapter.swift`;
3. `Sources/StornautInvestigationDiagnostic/InvestigationRuntimeDiagnosticComposition.swift`;
4. `StornautApp/Diagnostics/InvestigationRuntimeDiagnosticHarness.swift`;
5. `StornautAppTests/InvestigationRuntimeDiagnosticTests.swift`;
6. `Tests/StornautInvestigationTests/InvestigationHandoffAppLeafTests.swift`;
7. one new focused concrete-composition test file if required;
8. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
9. `scripts/verify-investigation-boundaries`;
10. `scripts/verify-app-release-boundaries`; and
11. `scripts/verify-contract`.

Working estimate: 1,750–2,350 changed lines over 9–11 paths. If the implementation
requires a wire/Runtime/helper/Lifecycle-server/Package/Xcode change, more than
one new test file, a root-native driver entry, a caller-provided authorization
fact, or approaches 2,800 lines, stop and split before continuing. Verifier and
mutation growth above roughly 800 lines triggers an immediate cost re-audit.

## 4. Tests-First RED Contract

Before implementation, focused tests must fail for the missing concrete surface:

1. public `run()` is `async`, no-argument and the only public handoff entry;
2. native harness accepts `@Sendable () async -> Int32`, rejects non-inherited or
   invalid FD shape without calling it, and awaits exactly once when admitted;
3. a concrete fake factory drives the complete pure-leaf sequence and emits only
   PRE_DROP_READY, DROP_EVIDENCE, CONFIGURATION_ACK, HELLO, HANDLE and ALIVE;
4. Lifecycle transcript is exactly `[start, retire]` with zero line bytes;
5. strict configuration rejects unknown top-level/binding/machine-driver fields;
6. executable SHA, signing identifier, designated-requirement SHA and CDHash
   mismatch/length drift each fail before CONFIGURATION_ACK;
7. peer evidence drift between observation and acknowledgement fails terminally;
8. non-canonical but otherwise valid JSON is rejected; canonical wire-byte SHA
   equals `machineConfigurationSHA256()`, and every one-field binding mutation
   changes that complete configuration commitment;
9. retirement investigation UUID, configuration SHA, retire-operation UUID,
   ownership, L1, helper freshness/identity and Store one-shot joins fail closed;
10. adapter, factory and every pure-state operation failure are terminal;
11. concurrent/repeated entry/factory use has one winner; cancellation at
    configuration/start/retire/handle suspension never publishes success;
12. existing config-path behavior remains unchanged; and
13. Debug diagnostic final images retain the concrete entry/adapter/b3b seam while
    ordinary Debug/Release, preview and dependency-free release shell remain
    negative.

No new binding-digest field or copied private hashing algorithm is added. The
existing ACK/capsule `signedRuntimeBindingSHA256` field is filled with the
existing `capabilityEvidenceBindingSHA256()` algorithm, while configuration and
handle use the canonical configuration SHA and peer consistency is the direct
four-field machine-driver comparison. The
adapter's half-close completes the local EOF action; the following exact EXIT
frame is the remote causal proof. Requiring either a new digest wire field or a
standalone remote-EOF proof inside `halfCloseAndProveEOF()` is scope drift and
forces a contract split.

The narrow source/body gate must reject `prepareRoot`, `writeLine`, `readLine`,
`CodexInteractiveAppServerClient`, auth projection/source,
initialize/login/thread/turn, capability/model evidence, `EvidenceStore`,
`ProbeBroker`, Executor/Cleanup/Trash, semaphore/blocking bridges and public
caller-selected descriptor/path/authorization/binding inputs.

## 5. Validation Funnel

```text
RED focused package/native tests
-> focused concrete leaf/composition tests
-> full App leaf/adapter/transport/config focused group
-> affected Investigation suite and dedicated App tests
-> structural/source and mutation gates
-> targeted SwiftPM compile/test
-> targeted diagnostic Debug build/test (no launch)
-> dependency-free Release-shell build
-> ordinary Debug/Release + diagnostic Debug + release-shell final-Mach-O matrix
-> one staged-only serial with five maximum benchmarks skipped
-> independent review
-> implementation commit/push
-> completion audit/docs commit/push
```

An invocation that starts SwiftPM consumes the checkpoint's serial and is never
rerun merely to obtain a green headline. Exact failed cases/stages are used for
debugging. `scripts/verify --full` remains forbidden before L3c4. This checkpoint
does not launch the built App/helper, invoke real XPC, install, use privilege,
call Codex/model/auth/public network, touch Trash/Executor or claim readiness.

## 6. Prompt-to-Artifact Checklist

| Obligation | Direct evidence required | Status |
| --- | --- | --- |
| public direct-async no-argument entry | source/API structural gate and App harness tests | satisfied |
| b3a peer/bootstrap/drop join | concrete operations tests and Debug artifact positive | satisfied |
| strict configuration reuse | existing decoder plus unknown-field and mismatch tests | satisfied |
| epoch driver consistency | complete four-field comparison before acknowledgement | satisfied |
| canonical configuration and attempt commitments | canonical wire bytes equal machine config digest; ACK uses existing capability binding digest | satisfied |
| no-auth/no-business-line retirement | exact `[start, retire]`, zero line bytes, API/body negatives | satisfied |
| exact retirement/handle join | behavior negatives and one-shot evidence consumption | satisfied |
| complete pure-leaf sequence | focused concrete factory transcript | satisfied |
| native FD activation only | dedicated App tests | satisfied |
| product/release boundaries closed | source recursion and final-Mach-O matrix | satisfied |
| scope/cost | real staged index plus extra/over/deletion mutations | satisfied |
| no premature admission | no report/receipt/readiness/full; ADR 0018 Proposed | required |

ADR 0018 remains Proposed. Task 39 remains incomplete. Production Deep Dive and
real Trash remain closed; L3c4 alone owns machine readiness and Task 39's
remaining authoritative full.
