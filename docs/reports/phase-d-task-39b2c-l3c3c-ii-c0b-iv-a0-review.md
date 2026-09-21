# Phase D Task 39B2c L3c3c-ii-c0b-iv-a0 Completion Audit

> Status: complete / non-admitting
>
> Date: 2026-08-29
>
> Parent: `4666f3f0dd7f5fa5b932e18c0133df425bbe8321`
>
> Candidate tree before completion-document updates:
> `98fbb7b14847ce16f7b1c34abcee41faf5db1699`
>
> Next frontier: ii-c0b-iv-a-r provenance/App admission closure

## 1. Result

ii-c0b-iv-a0 is complete and remains non-admitting. It closes the authoritative
build/source provenance, installed Codex native identity, Task 38 runtime
receipt, signed binding and pure eight-configuration derivation core required
by c0b-iv. It does not publish a capsule, launch the gate or App, request
privilege, call a model, use the network or make a machine-readiness claim.

The implementation changes exactly fourteen non-document paths against the
frozen parent: 3,676 additions and 37 deletions, or 3,713 changed lines. This is
within the frozen fourteen-path / 3,900-line ceiling. Final review moved the
remaining provenance negative matrix and inherited-handoff App receipt join to
the separately bounded iv-a-r acceptance closure rather than weakening tests
or exceeding this review surface.

## 2. Closed Contract

- A non-product build-tool plugin receives only the sealed validation commit.
  Its generator independently reconstructs and verifies the exact Git tree,
  canonical tracked-file manifest, file modes and prompt/schema/facade hashes
  inside the write-protected validation snapshot.
- Git runs with system/global/local behavior closed by fixed configuration
  overrides, lazy fetch disabled and irrelevant stderr discarded. Raw blobs are
  materialized with descriptor-level exact modes, independent of caller umask.
- Build provenance and Investigation source identity remain distinct. The
  binding carries the clean validation commit and semantic artifact identities;
  `sourceFingerprintSHA256` remains the canonical Task 36/38 source projection.
- Codex package discovery resolves the installed package but opens, hashes and
  retains the native executable identity. Capability, privacy, help/version and
  App Server paths execute only a staged native whose digest matches that held
  installed observation; the npm wrapper is not executed.
- One canonical Task 38 runtime receipt binds receipt ID, collaboration schema
  and the complete canonical capability set. The existing binding schema stays
  wire-compatible and the diagnostic composition rejects a receipt-digest
  mismatch on the legacy preparation path.
- The binding source joins build receipt, source fingerprint, current installed
  App/helper/driver observation and Codex native identity. It re-observes the
  full installed topology across the async Codex resolution window.
- The configuration set is a pure derivation: it creates no caller paths and
  performs no rollback or cleanup. It returns eight fixed-order scenario rows
  with fresh identities, one canonical focused plan deadline, one source
  fingerprint, one binding and one runtime receipt. Attempt-base
  materialization and retained identity remain iv-b2 authority.
- All new runtime/code paths are DEBUG-only or non-product package targets.
  The no-Executor structural boundary remains closed.

## 3. Exact Scope

The fourteen non-document paths are:

1. `Package.swift`;
2. `Plugins/StornautInvestigationBuildReceiptPlugin/plugin.swift`;
3. `tools/StornautInvestigationBuildReceiptGenerator/main.swift`;
4. `scripts/with-clean-validation-snapshot`;
5. `Sources/StornautInvestigationMachineGateCoordinatorSupport/Resources/InvestigationMachineBuildInputs.json`;
6. `Sources/StornautCodex/Runtime/CodexNativeExecutableIdentity.swift`;
7. `Sources/StornautCodex/Diagnostics/CapabilityRuntimeWorker.swift`;
8. `Sources/StornautInvestigation/InvestigationRuntimeProtocols.swift`;
9. `Sources/StornautInvestigationDiagnostic/InvestigationRuntimeDiagnosticComposition.swift`;
10. `Sources/StornautInvestigationMachineGateCoordinatorSupport/InvestigationMachineCoordinatorBindingSource.swift`;
11. `Sources/StornautInvestigationMachineGateCoordinatorSupport/InvestigationMachineCoordinatorConfigurationSet.swift`;
12. `Tests/StornautCodexTests/CodexNativeExecutableIdentityTests.swift`;
13. `Tests/StornautInvestigationTests/InvestigationMachineCoordinatorBindingSourceTests.swift`; and
14. `Tests/StornautInvestigationTests/SignedRuntimeContractTests.swift`.

Documentation and report-index updates do not count toward this implementation
budget. No binary path, deletion or fifteenth non-document path is present.

## 4. Validation and Review

| Evidence | Result |
| --- | --- |
| native-identity focused tests | 9/9 passed |
| binding/configuration focused tests | 5/5 passed |
| signed-runtime focused tests | 46/46 passed |
| topology focused case | 1/1 passed |
| complete `StornautCodexTests` affected suite | 268/268 passed; 16 suites |
| complete `StornautInvestigationTests` affected suite | 770/770 passed; 54 suites |
| restrictive-umask validation-snapshot contract | exit 0 |
| staged Debug CoordinatorSupport build | exit 0 |
| staged Release CoordinatorSupport build | exit 0 |
| structural no-Executor gate | exit 0 |
| exact final implementation scope | 14 non-document paths / 3,713 changed lines |
| staged/worktree whitespace checks | exit 0 |
| independent implementation review | no unresolved P0-P2 in iv-a0 scope |
| final delta review | one documentation P2 fixed before commit; no remaining P0-P2 |

The affected suites were run once after the code reached its final state. The
snapshot contract and Debug/Release target builds were then run from the staged
write-protected snapshot. No root/sudo, real App/XPC, authenticated Codex,
network/model attempt, staged global serial or `scripts/verify --full` was run.
Those are owned by later checkpoints.

## 5. Review Finding Closure

The implementation review found and closed these material issues before final
acceptance:

- repository-local Git/fsmonitor influence, lazy fetch and stderr-pipe deadlock;
- umask-dependent raw-blob modes;
- npm-wrapper execution after native verification;
- installed App/helper/driver drift across async Codex resolution;
- raw-path mutation and rollback in the configuration builder; and
- a cohort deadline inconsistent with the canonical focused plan.

The final review also confirmed that the capability ordering is the existing
canonical encoded-byte ordering fixed by golden vectors, not ordinary lexical
ordering. The post-review delta found one stale three-stage description in the
preflight; the gate matrix, validation flow and frozen outcome now consistently
use `iv-a0 -> iv-a-r -> iv-b1 -> iv-b2`.

## 6. Deferred Acceptance Closure and Non-Claims

iv-a-r owns exactly the still-open acceptance surface: the complete provenance
negative matrix and the actual inherited-handoff App acknowledgement's
reconstruction, retention and projection of the canonical Task 38 receipt,
including rejection of a shape-valid foreign digest. This is a three-path,
900-line maximum closure and adds no process, filesystem, root, model, network
or readiness authority.

Therefore this checkpoint does not make c0b-iv, ii-c, L3c3d, L3c4 or Task 39
complete. ADR 0018 remains Proposed and production Deep Dive remains
unavailable. The next implementation frontier is iv-a-r, followed by iv-b1,
iv-b2, the unique no-model privileged attempt, the unique authenticated Codex
attempt and final admission.
