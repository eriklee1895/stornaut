# Phase D Task 39B2c L3c3c-ii-c0b-i Canonical Producer Completion Audit

> Status: complete / non-admitting
>
> Date: 2026-08-27
>
> Implementation commit:
> `2493e0f28e0c8d406b4efcdbf17713bde3633449`
>
> Parent: `e5ed33e27195d9252f02a89ab39664df3848f1ed`
>
> Tree: `8155d64c4966fb83c332f7d195a92095e0af2ba9`
>
> Next frontier: ii-c0b-ii owner-only capsule node fresh preflight

## 1. Result

ii-c0b-i is complete and remains non-admitting. It adds the DEBUG-only,
package-closed semantic producer that accepts exactly eight canonical signed
diagnostic configurations plus one path-free installed binding and returns the
already accepted ii-c0a `InvestigationProjectedCohortInput`. It does not create
the capsule filesystem node, launch a process, request privilege or make a
readiness decision.

The implementation changes exactly seven non-document paths against the frozen
parent: 1,894 additions and 6 deletions, or 1,900 changed lines. This exactly
meets, but does not exceed, the frozen seven-path / 1,900-line ceiling.

## 2. Implemented Contract

- One clock sample validates all eight inputs. Each input passes the existing
  strict decoder, byte-identical canonical re-encoding and configuration-digest
  check before installed-binding comparison or identifier generation.
- The producer requires exactly one member of every closed diagnostic scenario,
  eight unique nonzero configuration nonces and one identical complete signed
  runtime binding. Output order follows the fixed handoff scenario order, not
  caller order.
- The supplied non-`Codable`, path-free installed binding validates canonical
  App/helper/driver SHA-256 values, fixed identifiers and a lowercase 20- or
  32-byte CodeDirectory hash, then matches every corresponding signed-binding
  field.
- One provider call creates one outer-attempt UUID and eight epoch UUIDs only
  after semantic and installed-binding validation. All seventeen UUIDs,
  including configuration nonces, must be nonzero and globally unique.
- Every epoch carries the original canonical configuration bytes, exact
  configuration digest and existing capability-evidence binding digest. Every
  installed-L2 projection carries the complete path-free identity and checked
  UTC-microsecond validity time. The accepted ii-c0a constructor performs the
  final epoch/projection join.
- The App-leaf acknowledgement and producer share one exhaustive
  `InvestigationHandoffScenarioMapping`. No second scenario switch is accepted.
- The only production-facing constructor creates fresh clock/UUID sources. Test
  injection remains module-internal. Exact producer and focused-test source
  seals reject added wrapper entry points or vacuous test bodies.

## 3. Exact Scope and Seals

The seven non-document paths are:

1. `Sources/StornautInvestigationDiagnostic/InvestigationProjectedCohortAuthor.swift`;
2. `Sources/StornautInvestigationDiagnostic/InvestigationRuntimeDiagnosticComposition.swift`;
3. `Tests/StornautInvestigationTests/InvestigationProjectedCohortAuthorTests.swift`;
4. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
5. `scripts/verify-contract`;
6. `scripts/verify-investigation-boundaries`; and
7. `scripts/verify-app-release-boundaries`.

Accepted final source identities include:

- producer: `33036861e4edbd52cd96f8de3acd4843550365105a55ce32d63ab39a25789ea5`;
- focused tests: `95a8c01bb29e19020f56d29072ea991e95f3c96dca73fa8397a9bf8cb4454300`;
- target-boundary tests: `43e5f15a1fac2644934ecaa11207a182f8ac41c217d93bea56ad1a08b7d7bc1b`;
- Investigation verifier: `5796f79dfc4b2105116da98b19c054b4b89faece7dd8375495e68409463ad4d3`;
- App/Release verifier: `85d0f3fb465944421caaec0ea51bd5b385ae8d2228a966f5c0ec2799b192b5d6`; and
- normalized `verify-contract` self-seal:
  `70a3f80f40ad9cb00c433a7e62e810f3aafb2eedc979c254634c14214c89c047`.

The global source-boundary inventory now includes the new diagnostic producer
and the already completed zero-argument DriverSupport entry. The latter remains
governed by its exact source SHA plus the dedicated iii-b2b-1b Darwin call-shape
gate; no generic authority exception was added.

## 4. Tests and Verification

| Evidence | Result |
| --- | --- |
| focused/affected selection | 95 tests / 5 suites passed |
| full `scripts/verify-investigation-boundaries` | exit 0 |
| exact staged scope | 7 non-document paths / 1,900 changed lines; exit 0 |
| `scripts/verify-contract` | exit 0 |
| component binary matrix | Debug object and diagnostic dylib positive; Release, ordinary App and Machine Driver negative |
| command-failure and mutation controls | rejected as designed; scratch cleanup bound to exit/signals |
| independent final review | no unresolved P0-P2 |

The focused matrix covers adversarial input order, all strict-configuration
failures, validation ordering, every installed-binding field, 20/32-byte code
directory hashes, all identifier count/zero/collision cases, provider failure,
exact projection fields and canonical output round-trip. Source and mutation
gates reject public/`Codable` drift, injectable production construction, added
call sites or wrappers, duplicate scenario ownership, command/environment
selectors, write/process/network/cleanup/readiness authority and vacuous tests.

No staged-only serial or `scripts/verify --full` was run for this component-only
checkpoint. The accepted umbrella plan reserves one aggregate serial for
c0b-iv and the remaining authoritative full verifier for L3c4.

## 5. Prompt-to-Artifact Completion Checklist

| Requirement | Concrete evidence | Result |
| --- | --- | --- |
| strict eight-configuration semantic producer | `InvestigationProjectedCohortAuthor` plus invalid/canonical tests | complete |
| fixed scenario order and unique identity set | shared exhaustive mapper plus 17-UUID matrix | complete |
| complete installed binding projection | typed path-free binding, field equality and malformed-field matrix | complete |
| accepted c0a canonical bytes | `InvestigationProjectedCohortInput` construction and strict round-trip | complete |
| no JSON in root driver | product JSON remains in diagnostic target; DriverSupport receives only binary c0a input | complete |
| no premature authority or production reachability | source seals, mutation gates and final-image matrix | complete |
| exact scope and review budget | implementation commit/tree; 7 paths / 1,900 lines | complete |
| independent review and validation | 95 tests, source/scope/contract gates, no unresolved P0-P2 | complete |
| owner-only capsule node | reserved for c0b-ii | pending |
| launcher/TTY/FD and final composition | reserved for c0b-iii/c0b-iv | pending |

## 6. Non-Claims and Next Step

This checkpoint did not run as root or invoke `sudo`; install or launch the
App/helper/Machine Driver; open XPC; call Codex/App Server; access auth or the
network; create a capsule filesystem node; or make machine-readiness or product-
availability claims. ADR 0018 remains Proposed, Task 39 remains incomplete and
production Deep Dive remains unavailable.

The next step is the mandatory fresh scope/cost/ownership preflight for
ii-c0b-ii. It must prove a kernel-released exclusive ownership mechanism that
cannot mistake another live attempt for stale residue before any owner-only
capsule implementation begins.
