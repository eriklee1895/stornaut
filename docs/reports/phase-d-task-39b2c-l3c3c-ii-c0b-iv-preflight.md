# Phase D Task 39B2c L3c3c-ii-c0b-iv Final Composition Preflight

> Status: scope/authority split frozen; implementation not started; non-admitting
>
> Date: 2026-08-29
>
> Frozen preflight baseline: `ced4da22d9aa5d1b13632794cb1922348626b9ae`
> (tree `f1955e0d813ea1f55382a8f5ef9b6caf6284cf3d`)
>
> Scope: current-source documentation, target/source inspection and commit
> history only. No root/sudo, App/helper/driver/gate launch, XPC, model/auth,
> network, staged serial or `scripts/verify --full` was run.

## 1. Decision

The c0b-iv configuration-owner/final-composition checkpoint cannot be one
reviewable change. HEAD already contains the complete non-admitting chain
through the c0b-iii fixed gate and its verifier seal: retained-base ownership,
canonical capsule publication/settlement, and the narrow fixed gate. The old
active-plan text naming `ii-c0b-ii-a3` as current is therefore superseded.

The remaining c0b-iv work joins three different trust responsibilities: sealed
source/build provenance plus Task 38 semantic configuration, same-UID process/
descriptor ownership plus post-reap settlement, and final executable/artifact
admission. It is frozen, with no recursive prerequisite split permitted, as:

```text
ii-c0b-iv-a   authoritative binding/configuration/source inputs
-> ii-c0b-iv-b1  contained fixed-gate handoff, exact reap and settlement
-> ii-c0b-iv-b2  zero-argument executable and aggregate verifier closure
-> ii-c          unique real no-model privileged machine attempt
-> L3c3d         authenticated real Codex attempt
-> L3c4          final admission and remaining authoritative full verifier
```

Each child is below fourteen non-document paths and 4,000 changed lines. If a
child cannot fit its frozen envelope, implementation stops and reports the
blocker; it does not create iv-a1/iv-a2, iv-b1a/iv-b1b or another prerequisite.
No child accepts ADR 0018 or makes a readiness claim.

## 2. Resolved Semantic Ambiguities

### 2.1 `sourceFingerprintSHA256` is Investigation data

`SignedInvestigationRuntimeBinding.sourceFingerprintSHA256` means the exact
shared `InvestigationSourceProjection.summary.sourceFingerprint` used by the
Task 38 cohort. It is not a Git tree hash, working-copy hash, package-source
hash, build hash or synonym for `repositoryHEAD`. All eight configurations and
plans must use one byte-identical source projection fingerprint, and the
existing Machine checks must continue to join each plan to that field.

Repository/build provenance is a separate package-only typed
`InvestigationMachineBuildProvenanceReceiptV1`. It carries:

- schema version and domain `stornaut.task39.machine.build-provenance.v1`;
- the validation-snapshot commit and its Git tree object ID;
- SHA-256 of a canonical ordered manifest of every tracked path, Git mode,
  blob object ID and byte count in that tree;
- build configuration and coordinator target/product identifiers; and
- prompt, Envelope-v2 schema and Task 38 facade artifact SHA-256 values.

The manifest excludes generated plugin output and build products, so the
receipt has no self-reference. The controlled build obtains the commit from the
already sealed validation-snapshot environment, proves the snapshot is clean,
derives the tree/manifest, and generates Swift source only in SwiftPM's declared
plugin work directory. The coordinator validates the generated typed receipt
before binding construction. Runtime `git`, an install/runtime mutable sidecar,
config-file fields, arbitrary environment input and caller-supplied repository/
source/build strings are forbidden. This receipt does not change the
Investigation source schema and is never substituted for
`sourceFingerprintSHA256`.
`SignedInvestigationRuntimeBinding` advances to schema v3 with a distinct
`repositorySourceSHA256` field equal to the validated build-provenance manifest
SHA-256. The nested binding therefore carries both trust domains: repository
source/build provenance and Investigation input projection. Existing v2 bytes
are rejected by the current diagnostic path rather than silently reinterpreted.

### 2.2 One Task 38 runtime receipt binds the cohort

The configuration owner constructs exactly one typed
`InvestigationRuntimeReceiptV1` for the whole eight-scenario cohort. Its
canonical hash commits, with an explicit domain/version, to the receipt ID, the
collaboration schema and the complete sorted, unique required capability-token
set. That hash is `SignedInvestigationRuntimeBinding.runtimeReceiptSHA256`.
The production schema is frozen as `collab-tool-call-v1`, matching the current
validated App Server event path. `collab-agent-tool-call-v1` remains supported
by the Task 38 generic contract and tests but is not a c0b-iv runtime choice.

The receipt ID is deterministically derived from a domain-separated projection
of the binding's repository commit and shared Investigation source fingerprint;
its canonical receipt hash then covers that ID, the selected schema and the
complete capability set. The builder writes only the hash into binding schema
v3. Every configuration and c0a projection re-encodes that nested v3 binding,
and every current diagnostic consumer rejects v2 rather than reinterpreting it.
The consumer reconstructs the same typed receipt from the binding, recomputes
the hash and rejects a mismatch before creating a one-shot
`InvestigationStartAdmissionV1`; no separate runtime-receipt transport is
needed. A per-
scenario receipt, hash of only the ID, hash of only the schema, omitted or extra
capability token, caller-provided digest, or consumer-selected replacement is
rejected. This is the Task 38 semantic runtime receipt; it is not the c0b-iii
gate transport receipt or the final coordinator receipt.

### 2.3 Codex identity is a live installed-native observation

`codexExecutableSHA256` is obtained through one narrow package facade extracted
from the existing capability-runtime package-layout logic; resolver logic may
not be copied into the coordinator. The fixed closed runtime environment may
locate the installed package's `codex.js` entry, but the identity is never the
wrapper hash and never comes from a caller URL or report string. iv-a resolves
and opens the installed native
`bin/codex` read-only and binds canonical path, held/named device+inode, regular
file type, owner/mode/link/flags/ACL/xattrs, bounded size and complete SHA-256.
It retains the held identity through configuration sealing and revalidates held
and named identity after hashing and immediately before the first configuration
is sealed. The capability worker must use the same resolver and require its
staged native copy's SHA-256 to equal this installed-native observation before
producing evidence. Replacement, disappearance, metadata drift, a different
resolver result or staged digest mismatch fails closed. The observation grants
no execution or write authority.

### 2.4 One fixed disposable source projection

iv-a defines one fixed disposable source-fixture template and its canonical
Task 36 projection contract. iv-b2 materializes the template beneath a fresh
coordinator-owned attempt base, imports it once through the existing Store v4
source-projection and Candidate Planner path, and only then calls the iv-a
receipt/binding/configuration factory with the resulting fingerprint. All eight
plans reference
that one canonical source fingerprint but carry distinct Investigation/run
identities. The fixture bytes and expected target semantics are part of the
build provenance manifest. User repositories, Home data, caller-selected scans
and prior mutable sessions are forbidden. iv-b2 retains the attempt base, source
fixture and Store through all eight epochs. It may remove only those exact
coordinator-created objects after Gate reap, capsule settlement and runtime-
artifact retirement; identity mismatch or removal uncertainty dominates the
earlier outcome and enters the final receipt. This diagnostic-only exact cleanup
is not product Cleanup/Trash/Executor authority.

## 3. Frozen Target Graph

```text
StornautInvestigationDiagnostic
  -> StornautInvestigation + StornautInvestigationRuntime
  -> StornautCodex + StornautCore + StornautLifecycle
  -> StornautInvestigationHandoffContract
  -> iv-a binding/configuration owner and sealed build-provenance join

StornautInvestigationMachineLaunchSupport
  -> StornautInvestigationHandoffContract
  -> StornautInvestigationMachineGateSupport (added only by iv-b1)
  -> existing owner-only capsule plus one fixed high-level handoff facade

StornautInvestigationMachineGateSupport
  -> StornautInvestigationHandoffContract
  -> existing fixed gate and strict transport receipt

new StornautInvestigationMachineGateCoordinatorSupport
  -> StornautInvestigationDiagnostic
  -> StornautInvestigationMachineLaunchSupport
  -> StornautInvestigationMachineGateSupport
  -> StornautInvestigationHandoffContract
  -> iv-b2 final composition; no raw descriptor/proof authority

new StornautInvestigationMachineGateCoordinator executable
  -> StornautInvestigationMachineGateCoordinatorSupport

existing StornautInvestigationMachineGate executable
  -> StornautInvestigationMachineGateSupport
  -> StornautInvestigationHandoffContract
```

The coordinator is diagnostic-only, non-product and same-UID. Its complete
implementation is built in Debug and Release for binary-boundary evidence; the
Release entry is inert and returns a fixed unavailable status before any
filesystem or process operation. Only the Debug build can be selected by ii-c.
The gate remains the
distinct narrow executable and must not gain Diagnostic, Core, Codex, Lifecycle,
Execution, cleanup or networking dependencies. Neither executable gains Xcode/
App membership. LaunchSupport owns iv-b1's fixed gate spawn/drain/reap/proof/
settlement bridge so its internal descriptor and settlement-token capabilities
never escape. No generic launcher, raw descriptor/path API or dependency edge
from the gate back to LaunchSupport or the coordinator is allowed.

## 4. Exact Child Budgets

Documentation paths do not count. Budgets are measured as added plus deleted
non-document lines against each child's exact pushed predecessor. No deletion,
binary path or path outside the listed set is allowed.

### 4.1 iv-a — authoritative binding/configuration/source

Exactly fourteen non-document paths, at most 3,900 changed lines:

1. `Package.swift`;
2. `Plugins/StornautInvestigationBuildReceiptPlugin/plugin.swift` (new);
3. `tools/StornautInvestigationBuildReceiptGenerator/main.swift` (new);
4. `Sources/StornautCodex/Runtime/CodexNativeExecutableIdentity.swift` (new);
5. `Sources/StornautCodex/Diagnostics/CapabilityRuntimeWorker.swift`;
6. `Sources/StornautInvestigation/InvestigationRuntimeProtocols.swift`;
7. `Sources/StornautInvestigation/SignedInvestigationRuntimeContract.swift`;
8. `Sources/StornautInvestigationDiagnostic/InvestigationRuntimeDiagnosticAppLeaf.swift`;
9. `Sources/StornautInvestigationDiagnostic/InvestigationRuntimeDiagnosticComposition.swift`;
10. `Sources/StornautInvestigationMachineGateCoordinatorSupport/InvestigationMachineCoordinatorBindingSource.swift` (new);
11. `Sources/StornautInvestigationMachineGateCoordinatorSupport/InvestigationMachineCoordinatorConfigurationSet.swift` (new);
12. `Tests/StornautCodexTests/CodexNativeExecutableIdentityTests.swift` (new);
13. `Tests/StornautInvestigationTests/InvestigationMachineCoordinatorBindingSourceTests.swift` (new); and
14. `Tests/StornautInvestigationTests/SignedRuntimeContractTests.swift`.

A fifteenth path or line 3,901 blocks implementation. iv-a owns the generated
build-provenance contract, installed-native read-only identity shared with the
worker, one deterministic cohort runtime receipt plus strict binding/admission
join, one fixed disposable source fingerprint, one complete binding and eight
fresh scenario-specific configurations. c0b-i authoring remains owned by
iv-b2 after all three components exist. The plugin and
generator may read only the exact clean validation snapshot and write only the
declared plugin output directory; they add no runtime authority. Verifier
implementation is intentionally deferred to iv-b2. iv-a must not publish a
capsule or spawn a product/gate process.

### 4.2 iv-b1 — contained handoff and settlement

Exactly eight non-document paths, at most 3,600 changed lines:

1. `Package.swift`;
2. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationOwnerOnlyCapsule.swift`;
3. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationFixedGateHandoff.swift` (new);
4. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationMachineGateHandoffReceipt.swift` (new);
5. `Tests/StornautInvestigationTests/InvestigationMachineGateCoordinatorHandoffTests.swift` (new);
6. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
7. `scripts/verify-investigation-boundaries`; and
8. `scripts/verify-contract`.

A ninth path or line 3,601 blocks implementation. iv-b1 returns only a typed
handoff/transport/settlement receipt; it cannot construct the broad final
coordinator receipt. LaunchSupport may expose only
one package-closed fixed high-level handoff result; the borrower protocol, raw
FD, settlement token and proof factory remain target-internal. It must never
expose a path, generic callback or forgeable proof. iv-b1 owns behavior/focused
evidence only, not final image admission or serial.

### 4.3 iv-b2 — zero-argument executable and verifier closure

Exactly ten non-document paths, at most 3,800 changed lines:

1. `Package.swift`;
2. `Sources/StornautInvestigationMachineGateCoordinatorSupport/InvestigationMachineGateCoordinatorComposition.swift` (new);
3. `Sources/StornautInvestigationMachineGateCoordinatorSupport/InvestigationMachineGateCoordinatorReceipt.swift` (new);
4. `tools/StornautInvestigationMachineGateCoordinator/main.swift` (new);
5. `Tests/StornautInvestigationTests/InvestigationMachineGateCoordinatorCompositionTests.swift` (new);
6. `Tests/StornautInvestigationTests/InvestigationMachineGateCoordinatorReceiptTests.swift` (new);
7. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
8. `scripts/verify-contract`;
9. `scripts/verify-investigation-boundaries`; and
10. `scripts/verify-app-release-boundaries`.

An eleventh path or line 3,801 blocks implementation. iv-b2 owns the sole executable
entry, aggregate source/scope/mutation/component/final-Mach-O closure, immutable
replay of c0b-i/ii/iii and the one c0b staged-only serial. It may not modify the
already sealed gate sources.

## 5. Field Source and Time-Order Matrix

| Field/evidence | Authoritative source | Required observation/order | Rejected substitute |
| --- | --- | --- | --- |
| `sourceFingerprintSHA256` | one Task 36/38 `InvestigationSourceProjection` | before plan/config creation; identical across eight | Git/build/source receipt |
| `repositoryHEAD` + `repositorySourceSHA256` | generated `InvestigationMachineBuildProvenanceReceiptV1` over the clean validation commit/tree/manifest | plugin generates in its declared work directory; binding schema v3 carries both values | runtime Git, install/runtime sidecar, caller/env fields, self-hash |
| App/helper/driver identities | one current installed binding observation | after build receipt, before configs | constants or stale report |
| prompt/schema/facade hashes | exact current resources/source identities joined by the sealed build receipt | before binding construction | caller strings or independent mutable files |
| Task 38 runtime receipt | one typed cohort receipt plus strict configuration projection | created once before binding; hash covers ID/schema/capabilities; exact projection reaches every App admission | per-config receipt, digest-only input or App-side replacement |
| Codex native executable | shared installed-native resolver plus held read-only node | resolve/open/hash/revalidate before first config seal; later staged digest must match | wrapper hash/caller URL/old capability report |
| source fixture/fingerprint | one fixed disposable fixture plus its canonical Task 36 projection contract | materialize once in iv-b2 before plans; reuse one fingerprint across eight | user repository, prior mutable session or eight snapshots |
| complete signed binding | iv-a authoritative builder | only after all preceding joins agree | individual binding fields from caller |
| eight roots/plans/configs | iv-a fixed scenario-set builder | fresh after complete binding; fixed scenario order | input files or scenario selector |
| projected cohort | sealed c0b-i author | after all eight canonical configs validate | ad hoc encoder |
| capsule identity/digest | sealed c0b-ii owner | after projected cohort, before gate spawn | pathname or copied FD integer |
| gate transport receipt | sealed c0b-iii gate on FD 1 | concurrently drained, then strict-decoded after exact reap | stdout prose or semantic success |
| settlement result | retained c0b-ii owner | only after one exact-gate-reaped proof | gate prediction or Boolean |
| final coordinator receipt | iv-b2 CoordinatorSupport receipt | last; binds iv-a provenance/configuration, iv-b1 transport, exact wait/reap and settlement | root/readiness claim |

The runtime order is fixed: zero-argument/identity/TTY validation -> sealed
build receipt -> installed identity -> installed-native identity -> iv-b2 fresh
source projection -> one Task 38 receipt -> iv-a complete binding -> eight
plans/configurations -> c0b-i author -> c0b-ii publish -> fixed gate handoff ->
concurrent bounded
receipt drain -> exact gate wait/reap -> strict receipt join -> capsule settle ->
final coordinator receipt. Every earlier failure uses the typed never-handed-off
path when applicable and may not advance to launch.

The final coordinator receipt uses domain
`stornaut.task39.machine.gate-coordinator-receipt.v1`, schema version `1`, and a
maximum canonical size of 4 KiB. The ii-c harness creates and retains the read
end of a private pipe; the coordinator inherits only its write end at FD 3. The
harness closes its own write copy immediately after spawn, and the coordinator
closes FD 3 after writing exactly one length-prefixed frame, so EOF is evidence.
The gate inherits neither pipe end. Coordinator FD 1 and FD 2 remain ordinary
diagnostic output and the controlling terminal. The receipt's exact fields are build-
provenance receipt SHA-256, complete signed-binding SHA-256, outer-attempt UUID,
whole projected-input SHA-256, capsule node identity and size, gate executable
SHA-256, canonical gate-transport-receipt SHA-256, exact gate PID/PGID/session
and raw wait classification, receipt EOF/overflow/deadline state, post-reap
capsule settlement outcome, attempt-base/runtime-artifact retirement outcome,
monotonic start/completion and a receipt SHA-256 calculated with its own digest
field zeroed. The strict decoder rejects unknown/missing/duplicate fields,
noncanonical bytes, trailing bytes, identity/digest disagreement and any
readiness/root-semantic field. A successful process exit without this exact
frame followed by EOF is failure.

The sealed c0b-iii `C/G` topology is authoritative: the coordinator is session/
foreground-group leader `C`; it spawns the gate as distinct background recovery-
group leader `G`; the gate later rejoins `C` before its prepared/stop handshake.
The coordinator does not duplicate the gate's child-PGID or `tcsetpgrp` logic.
The ii-c harness, not an arbitrary invoking shell, creates the PTY, calls
`setsid`/`TIOCSCTTY`, makes the zero-argument coordinator session and foreground-
group leader, and then waits for its bounded final receipt. The coordinator
resolves only a sibling `StornautInvestigationMachineGate` beside its own
`proc_pidpath`-observed executable, opens and hashes that regular executable
with no-follow semantics, and revalidates the named node before spawn. PATH and
caller-selected executable locations are forbidden.

## 6. Tests-First and Gate Matrix

| Owner | Required RED/focused evidence | Structural/artifact evidence | Explicitly excluded |
| --- | --- | --- | --- |
| iv-a | every binding field source; source/build non-conflation; runtime receipt ID/schema/capability mutations and App reconstruction; eight shared receipt/source rows; native replacement before/during/after hash; caller/path/env rejection | focused Swift tests; generated receipt validation; no runtime Git/sidecar | capsule, product/gate spawn, root, serial/full |
| iv-b1 | pre-publication failure, publish failure, spawn/prepared failure, signal/death before and after prepared, empty/truncated/oversized/noncanonical/trailing/mismatched receipt, exact-reap mismatch, close uncertainty, settlement success/residue/failure, proof reuse and deadline precedence | no raw FD/path/generic callback; exact one-shot proof; gate source immutable; coordinator never claims root semantics | real gate/sudo chain, App/XPC, serial/full |
| iv-b2 | zero/nonzero argv, activation environment, fixed eight-config call count/order, bounded final receipt, all iv-a/b1 failure mappings | exact target graph; Debug/Release coordinator and gate objects; gate narrow positive/forbidden negative controls; ordinary App/Release absence; historical c0b-i/ii/iii replay; exact scope/mutation gates | real root/model/network/App run, full |

Named verifier modes, all implemented and owned by iv-b2, are reserved as:

- `--iic0b-iv-a-binding-contract-only`;
- `--iic0b-iv-b1-handoff-contract-only`;
- `--iic0b-iv-b2-composition-contract-only`,
  `--iic0b-iv-b2-staged-scope-contract-only`,
  `--iic0b-iv-source-contract-only` and
  `--iic0b-iv-component-boundary-only`.

iv-a and iv-b1 run RED focused tests, exact affected suites and targeted builds,
then receive independent implementation review. iv-b2 implements and runs all
reserved structural/scope/mutation/component modes and receives independent
verifier/cross-boundary review. iv-b2 additionally runs bare
`scripts/verify-contract`, `scripts/verify-investigation-boundaries`,
`scripts/verify-app-release-boundaries` and exactly one clean staged-only
serialized SwiftPM regression for aggregate c0b. Failed gates are rerun only at
the exact failing mode/case after repair.

No iv child runs root/sudo, installs or launches the real App/helper/driver/gate
chain, opens product XPC, invokes auth/model/network, or runs the authoritative
full verifier. ii-c owns the first real zero-argument coordinator -> gate -> sudo
-> root-driver attempt and real-sudo topology evidence. L3c4 retains the single
remaining `scripts/verify --full`.

## 7. Stop Conditions and Non-Claims

Implementation stops rather than weakening the contract if any field lacks an
authoritative source; the build receipt needs runtime Git or an install/runtime
mutable sidecar;
the native executable cannot be held/revalidated without a replacement window;
one Task 38 receipt cannot be reconstructed and bound by all eight admissions;
a raw descriptor/path must
escape; the coordinator must duplicate gate process-group authority; or the gate
artifact gains a forbidden dependency/symbol. The remedy is design review, not
a recursive implementation split.

This preflight does not claim iv-a, iv-b1 or iv-b2 is implemented. It does not
prove real sudo/root FD, TTY, descendant or containment behavior; installed
multi-epoch success; Codex capabilities; public networking; global zero residue;
machine readiness; or ADR 0018 acceptance. It creates no cleanup/Trash/Executor
authority, does not enable production Deep Dive and introduces no dependency or
license decision.

## 8. Frozen Outcome

At baseline `ced4da2`, c0b-i, c0b-ii and c0b-iii implementation/verifier slices
are complete and non-admitting. c0b-iv is now frozen as iv-a -> iv-b1 -> iv-b2;
iv-a is the current implementation frontier. The earlier active-plan wording
that named ii-c0b-ii-a3 as current is superseded by current HEAD evidence and
this preflight. ii-c remains blocked until all three children have been
implemented, reviewed and pushed.
