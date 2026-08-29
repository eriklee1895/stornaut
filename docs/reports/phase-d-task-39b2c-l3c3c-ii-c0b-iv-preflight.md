# Phase D Task 39B2c L3c3c-ii-c0b-iv Final Composition Preflight

> Status: iv-a0, iv-a-r and iv-b1a complete; iv-b1b Steps 1-2 complete,
> Step 3 scope frozen, Step 4 RED tests next;
> non-admitting
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
admission. The original eight-path iv-b1 mixed a semantic ownership state
machine with independent Darwin process/descriptor authority. Scope/cost
preflight therefore supersedes that shape with two separately reviewable
children:

```text
ii-c0b-iv-a0  authoritative binding/configuration/source core
-> ii-c0b-iv-a-r  provenance acceptance + App receipt admission closure
-> ii-c0b-iv-b1a  typed handoff outcome and injected settlement semantics
-> ii-c0b-iv-b1b  Darwin fixed-gate authority and structural verifier closure
-> ii-c0b-iv-b2  zero-argument executable and aggregate verifier closure
-> ii-c          unique real no-model privileged machine attempt
-> L3c3d         authenticated real Codex attempt
-> L3c4          final admission and remaining authoritative full verifier
```

The iv-a0 implementation reached its 3,900-line ceiling margin before final
review exposed two cross-path acceptance gaps. Under the user's explicit
dynamic-planning authority, the remaining work is frozen as the narrow iv-a-r
closure below instead of weakening tests or exceeding the review budget. No
child accepts ADR 0018 or makes a readiness claim.
The same authority permits the iv-b1a/iv-b1b split without weakening the
original contract: iv-b1a closes only the injected semantic boundary, while
iv-b1b must independently close the Darwin authority and structural boundary.

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
receipt has no self-reference. The controlled build passes only the sealed
validation commit into a commit-keyed SwiftPM command. Inside the write-
protected validation snapshot, the generator independently derives and verifies
the tree, complete tracked-file manifest, modes and semantic artifact hashes
with fixed Git arguments and a closed environment, then writes only in the
plugin output directory. The coordinator validates the generated typed receipt
before binding construction. Runtime `git`, an install/runtime mutable sidecar,
config-file fields, arbitrary hash environment input and caller-supplied
repository/source/build strings are forbidden. This receipt does not change the
Investigation source schema and is never substituted for
`sourceFingerprintSHA256`.
The existing binding schema v2 remains wire-compatible. `repositoryHEAD` is the
exact clean validation-snapshot commit and therefore commits to its Git tree;
`promptSHA256`, `envelopeSchemaSHA256` and `facadeSHA256` retain their direct
artifact meanings and must equal the corresponding build-receipt entries. The
iv-a0 output carries the complete build-provenance receipt and its canonical
digest beside the binding, and iv-b2 includes that digest in the final
coordinator receipt. This preserves both trust domains without overloading a
legacy field or adding an unjoined sidecar: the binding identifies the source
commit and exact semantic artifacts, while `sourceFingerprintSHA256` remains
exclusively the Investigation input identity.

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
complete capability set. The builder writes that hash into the existing binding
schema v2; every configuration and c0a projection preserves the same nested v2
binding. The consumer reconstructs the same typed receipt from the binding, recomputes
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
wrapper hash and never comes from a caller URL or report string. iv-a0 resolves
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
Like the already accepted installed-L2 Security observations, these held/named
checks are a race-detecting sandwich rather than an atomic descriptor-bound
exec claim. A malicious concurrent same-UID actor could replace, execute and
restore a staged path between checks; that actor is outside ADR 0018's explicit
serialized trusted-local-operator development threat model. Once the contained
Codex worker starts, it and its descendants are denied writes to the staged
package. Distribution-grade resistance to a hostile local account requires a
root-owned installation or notarized update boundary and is not claimed here.

### 2.4 One fixed disposable source projection

iv-a0 defines one fixed disposable source-fixture template and its canonical
Task 36 projection contract. iv-b2 materializes the template beneath a fresh
coordinator-owned attempt base, imports it once through the existing Store v4
source-projection and Candidate Planner path, and only then calls the iv-a0
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
  -> iv-a0 binding/configuration owner and sealed build-provenance join
  -> iv-a-r inherited-handoff App receipt admission join

StornautInvestigationMachineLaunchSupport
  -> StornautInvestigationHandoffContract
  -> StornautInvestigationMachineGateSupport (added by iv-b1a)
  -> iv-b1a owner-only capsule plus injected fixed high-level handoff semantics
  -> iv-b1b Darwin sibling/descriptor/spawn/drain/wait/reap adapter

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
App membership. LaunchSupport owns iv-b1a's typed handoff/settlement state
machine and iv-b1b's fixed Darwin spawn/drain/reap bridge so its internal
descriptor and settlement-token capabilities never escape. No generic launcher,
raw descriptor/path API or dependency edge from the gate back to LaunchSupport
or the coordinator is allowed.

## 4. Exact Child Budgets

Documentation paths do not count. Budgets are measured as added plus deleted
non-document lines against each child's exact pushed predecessor. No deletion,
binary path or path outside the listed set is allowed.

### 4.1 iv-a0 — authoritative binding/configuration/source core

Exactly fourteen non-document paths, at most 3,900 changed lines:

1. `Package.swift`;
2. `Plugins/StornautInvestigationBuildReceiptPlugin/plugin.swift` (new);
3. `tools/StornautInvestigationBuildReceiptGenerator/main.swift` (new);
4. `scripts/with-clean-validation-snapshot`;
5. `Sources/StornautInvestigationMachineGateCoordinatorSupport/Resources/InvestigationMachineBuildInputs.json` (new);
6. `Sources/StornautCodex/Runtime/CodexNativeExecutableIdentity.swift` (new);
7. `Sources/StornautCodex/Diagnostics/CapabilityRuntimeWorker.swift`;
8. `Sources/StornautInvestigation/InvestigationRuntimeProtocols.swift`;
9. `Sources/StornautInvestigationDiagnostic/InvestigationRuntimeDiagnosticComposition.swift`;
10. `Sources/StornautInvestigationMachineGateCoordinatorSupport/InvestigationMachineCoordinatorBindingSource.swift` (new);
11. `Sources/StornautInvestigationMachineGateCoordinatorSupport/InvestigationMachineCoordinatorConfigurationSet.swift` (new);
12. `Tests/StornautCodexTests/CodexNativeExecutableIdentityTests.swift` (new); and
13. `Tests/StornautInvestigationTests/InvestigationMachineCoordinatorBindingSourceTests.swift` (new); and
14. `Tests/StornautInvestigationTests/SignedRuntimeContractTests.swift`.

A fifteenth path or line 3,901 blocks implementation. The fourteenth path is
the existing Task 39 composition fixture whose former placeholder receipt hash
must now be derived from the canonical receipt contract. iv-a0 owns the generated
build-provenance contract, installed-native read-only identity shared with the
worker, one deterministic cohort runtime receipt plus strict binding/admission
join, one fixed disposable source fingerprint, one complete binding and eight
fresh scenario-specific configurations. Configuration derivation is pure and
does not create or remove caller paths; iv-b2 owns materialization and retained
attempt-base identity. c0b-i authoring remains owned by
iv-b2 after all three components exist. The checked-in input contains only
canonical manifest rules and artifact-relative names, never a commit/hash claim.
After creating and checking its clean detached worktree, the snapshot wrapper
passes only its sealed commit. The plugin uses that commit in its declared
output path, and the generator independently reconstructs and byte-validates
the remaining provenance as described in section 2.1. Verifier
implementation is intentionally deferred to iv-b2. iv-a0 must not publish a
capsule or spawn a product/gate process.

### 4.1.1 iv-a-r — post-review acceptance closure

Originally frozen at three non-document paths and 900 changed lines. A RED
unsupported-tree case exposed exact early-failure manifest residue, so the
accepted completion scope is four non-document paths and remains within the
same 900-line ceiling:

1. `scripts/verify-clean-validation-snapshot-contract`;
2. `Sources/StornautInvestigationDiagnostic/InvestigationRuntimeDiagnosticComposition.swift`; and
3. `Tests/StornautInvestigationTests/InvestigationHandoffConcreteCompositionTests.swift`; and
4. `scripts/with-clean-validation-snapshot`.

This closure turns the provenance negative matrix into repeatable tests and
makes the actual inherited-handoff App acknowledgement reconstruct, retain and
project the one canonical Task 38 receipt. A valid-shape foreign digest is
rejected before acknowledgement. It adds no process, filesystem, root, model,
network or readiness authority and completes before iv-b1.

### 4.2 iv-b1 — dynamically split handoff and settlement

The former exact-eight-path / 3,600-line aggregate is superseded. Combining the
injected semantic state machine with Darwin sibling discovery, executable
identity, descriptor transport, spawn/wait/reap authority and structural
verification would make one review result hide two distinct trust surfaces.
The accepted order is now iv-b1a followed by iv-b1b.

#### 4.2.1 iv-b1a — semantic outcome and ownership state machine

Exactly six non-document paths, at most 2,400 changed lines:

1. `Package.swift`;
2. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationOwnerOnlyCapsule.swift`;
3. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationFixedGateHandoff.swift` (new);
4. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationMachineGateHandoffReceipt.swift` (new);
5. `Tests/StornautInvestigationTests/InvestigationMachineGateCoordinatorHandoffTests.swift` (new); and
6. `Tests/StornautInvestigationTests/InvestigationOwnerOnlyCapsuleTests.swift`.

The index-only validation snapshot `db4e936` (tree
`412da586d13fae7fd53937231217778b5d9ffd52`) contains exactly these six paths,
with 2,113 additions and 3 deletions. Its clean staged-only
focused run passed 48/48 tests in two suites; the clean staged-only affected
suite passed 785/785 tests in 55 suites; Debug compiled through tests; and the
clean staged-only Release target build exited 0. Initial independent review found
four P1 defects: settlement before
terminal admission, transport failure reaching success, settlement after close
uncertainty, and ownership release after spawn/transfer uncertainty. All four
were repaired tests-first in the same bounded scope. Three independent post-fix
review groups found no unresolved P0-P2. iv-b1a is complete/non-admitting; iv-b1b
is current.
No global serial, `scripts/verify --full`, root/sudo, real App/helper/driver/gate
launch, XPC, model/auth or network attempt was run for iv-b1a.

iv-b1a returns only a typed handoff/transport/settlement receipt; it cannot
construct the broad final coordinator receipt. Only a definite no-spawn outcome
may mint a never-handed-off proof. Exact settlement requires the matching exact-
gate-reaped proof after terminal transport admission. If spawn or descriptor
transfer is uncertain, neither proof may be minted and settlement/unlink is
forbidden. The live ownership object is retained in a process-lifetime
quarantine, deliberately preserving ownership and possible residue until process
exit rather than misclassifying uncertainty as safe release. This quarantine is
a fail-closed terminal state, not success, recovery or zero-residue evidence.
The borrower protocol, raw FD, settlement token and proof factory remain
target-internal; no path, generic callback or forgeable proof may escape.

#### 4.2.2 iv-b1b — Darwin authority and structural closure

Design review replaces the tentative four-path shape with exactly six
non-document paths and at most 3,200 changed lines:

1. `Sources/StornautInvestigationMachineLaunchSupport/DarwinInvestigationFixedGateHandoffSystem.swift` (rewrite, approximately 220-280 lines);
2. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationFixedGateDarwinLifecycle.swift` (new, approximately 750-850 lines);
3. `Tests/StornautInvestigationTests/InvestigationFixedGateDarwinLifecycleTests.swift` (new, at most 750 lines);
4. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
5. `scripts/verify-investigation-boundaries`; and
6. `scripts/verify-contract`.

iv-b1b owns sibling executable identity, one immutable deadline, descriptor
hygiene, bounded frame drain, spawn classification, signal/TTY handling, exact
wait/reap and structural target/source admission. It does not reopen iv-b1a
semantics or own the aggregate serial. The rewritten adapter remains the narrow
system call edge; the new injected lifecycle owns deterministic orchestration
and deadline/error precedence; its dedicated tests cover executable flags, one
immutable deadline, metadata drift, FD close/EOF/overflow, signal forwarding,
TTY restoration and exact wait/reap without launching the real production gate.

No separate real-subprocess fixture is added. The accepted c0b-iii PTY suite
already covers physical session/process-group/TTY topology, while iv-b1 is
explicitly scoped away from a real production-gate attempt. Repeating that
physical fixture here would duplicate evidence and broaden authority rather than
close the Darwin adapter seam. Any seventh non-document path or line 3,201
blocks implementation and requires a new scope/cost preflight.

The tests-first workflow state is frozen as:

1. Step 1 test preparation: complete;
2. Step 2 Swift unit-test knowledge and global context: complete;
3. Step 3 exact six-path / 3,200-line scope: frozen; and
4. Step 4 deterministic injected-lifecycle RED tests: next.

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
| `repositoryHEAD` + build-source identity | generated `InvestigationMachineBuildProvenanceReceiptV1` over the clean validation commit/tree/manifest | binding v2 carries the commit and direct prompt/schema/facade hashes; iv-a0 output and final coordinator receipt carry the provenance-receipt digest | runtime Git, install/runtime sidecar, caller/env fields, self-hash |
| App/helper/driver identities | one current installed binding observation | after build receipt, before configs | constants or stale report |
| prompt/schema/facade hashes | exact current resources/source identities joined by the sealed build receipt | before binding construction | caller strings or independent mutable files |
| Task 38 runtime receipt | one typed cohort receipt plus strict configuration projection | created once before binding; hash covers ID/schema/capabilities; exact projection reaches every App admission | per-config receipt, digest-only input or App-side replacement |
| Codex native executable | shared installed-native resolver plus held read-only node | resolve/open/hash/revalidate before first config seal; later staged digest must match | wrapper hash/caller URL/old capability report |
| source fixture/fingerprint | one fixed disposable fixture plus its canonical Task 36 projection contract | materialize once in iv-b2 before plans; reuse one fingerprint across eight | user repository, prior mutable session or eight snapshots |
| complete signed binding | iv-a0 authoritative builder | only after all preceding joins agree | individual binding fields from caller |
| inherited-handoff App receipt admission | iv-a-r canonical receipt reconstruction and retained typed projection | after strict configuration decode and before acknowledgement | shape-valid foreign digest or App-side replacement |
| eight roots/plans/configs | iv-a0 fixed scenario-set builder | fresh after complete binding; fixed scenario order | input files or scenario selector |
| projected cohort | sealed c0b-i author | after all eight canonical configs validate | ad hoc encoder |
| capsule identity/digest | sealed c0b-ii owner | after projected cohort, before gate spawn | pathname or copied FD integer |
| gate transport receipt | sealed c0b-iii gate on FD 1 | concurrently drained, then strict-decoded after exact reap | stdout prose or semantic success |
| settlement result | retained c0b-ii owner | only after one exact-gate-reaped proof | gate prediction or Boolean |
| final coordinator receipt | iv-b2 CoordinatorSupport receipt | last; binds iv-a0 provenance/configuration, iv-a-r admission closure, iv-b1a semantics, iv-b1b transport, exact wait/reap and settlement | root/readiness claim |

The runtime order is fixed: zero-argument/identity/TTY validation -> sealed
build receipt -> installed identity -> installed-native identity -> iv-b2 fresh
source projection -> one Task 38 receipt -> iv-a0 complete binding -> eight
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
| iv-a0 | every binding field source; source/build non-conflation; canonical runtime receipt construction; eight shared receipt/source rows; native replacement before/during/after hash; caller/path/env rejection | focused Swift tests; generated receipt validation; clean validation snapshot contract; no runtime Git/sidecar | capsule, product/gate spawn, inherited-handoff App acknowledgement, root, serial/full |
| iv-a-r | complete provenance negative matrix; actual inherited-handoff App receipt reconstruction, retention and acknowledgement; valid-shape foreign digest rejection | focused script/Swift tests and exact affected suite; no new process/filesystem authority | capsule, product/gate spawn, root, serial/full |
| iv-b1a | pre-publication/publish failures; definite-no-spawn, exact-reap and transfer-uncertain outcomes; prepared/terminal admission; transport failure precedence; close uncertainty; settlement success/residue/failure; proof reuse and deadline precedence | no raw FD/path/generic callback; exact one-shot proofs; process-lifetime ownership quarantine on uncertainty | Darwin physical behavior, real gate/sudo chain, App/XPC, serial/full |
| iv-b1b | deterministic injected lifecycle for executable flags/metadata drift; single-deadline spawn/drain/wait/reap; pipe/EOF/overflow; signal/TTY restoration; descriptor close uncertainty; exact empty process group | exact six-path source/test/target/verifier boundary; gate source immutable; accepted c0b-iii PTY topology reused; coordinator never claims root semantics | separate real-subprocess/production-gate fixture, semantic redesign, real sudo chain, App/XPC, aggregate serial/full |
| iv-b2 | zero/nonzero argv, activation environment, fixed eight-config call count/order, bounded final receipt, all iv-a0/iv-a-r/iv-b1a/iv-b1b failure mappings | exact target graph; Debug/Release coordinator and gate objects; gate narrow positive/forbidden negative controls; ordinary App/Release absence; historical c0b-i/ii/iii replay; exact scope/mutation gates | real root/model/network/App run, full |

Named verifier modes are reserved as follows. iv-b1b owns its handoff contract
mode; iv-b2 owns the remaining aggregate modes:

- `--iic0b-iv-a-binding-contract-only`;
- `--iic0b-iv-b1-handoff-contract-only`;
- `--iic0b-iv-b2-composition-contract-only`,
  `--iic0b-iv-b2-staged-scope-contract-only`,
  `--iic0b-iv-source-contract-only` and
  `--iic0b-iv-component-boundary-only`.

iv-a0, iv-a-r, iv-b1a and iv-b1b run RED focused tests, exact affected suites
and applicable targeted builds, then receive independent implementation review.
iv-b2 implements and runs all
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

This preflight records iv-a0, iv-a-r and iv-b1a as implemented, reviewed and
complete/non-admitting. iv-b1a is accepted at snapshot `db4e936` / tree
`412da586d13fae7fd53937231217778b5d9ffd52`; three independent post-fix review
groups found no unresolved P0-P2.
It does not claim iv-b1b or iv-b2 is implemented or accepted. It does not
prove real sudo/root FD, TTY, descendant or containment behavior; installed
multi-epoch success; Codex capabilities; public networking; global zero residue;
machine readiness; or ADR 0018 acceptance. It creates no cleanup/Trash/Executor
authority, does not enable production Deep Dive and introduces no dependency or
license decision.

## 8. Frozen Outcome

At baseline `ced4da2`, c0b-i, c0b-ii and c0b-iii implementation/verifier slices
are complete and non-admitting. c0b-iv is now frozen as
iv-a0 -> iv-a-r -> iv-b1a -> iv-b1b -> iv-b2. iv-a0 and iv-a-r are
complete/non-admitting; iv-b1a is also complete/non-admitting, and iv-b1b is the
current frontier at Step 4 RED tests after Steps 1-2 completed and Step 3 scope
freeze. The
earlier active-plan wording that named ii-c0b-ii-a3 as current is superseded by
the accepted implementation evidence and this preflight. ii-c remains blocked
until all five children have been
implemented, reviewed and pushed.
