# Phase D Task 39A Code Review and Completion Audit

> Status: Complete; tests-first contract/composition foundation, focused
> regression, independent post-fix review, serialized SwiftPM regression and
> one uninterrupted 23/23-stage authoritative `scripts/verify --full` passed.
>
> Date: 2026-08-16
>
> Baseline:
> `af8efb40f3a592c72e23f0e806e1a74cccd158f3`
>
> Scope: strict signed Investigation runtime contract, report verification,
> server-owned turn identity binding and a package-closed diagnostic facade

## 1. Current Decision

Task 39A is complete as the contract and reusable composition foundation for
Task 39B. It does not launch Codex, link a DEBUG App diagnostic composition,
install the fixed helper topology or claim
`signedInvestigationRuntimeReady`.

Task 39 remains incomplete. Checkpoint 39B must still compose and exercise the
current-source signed Debug App/helper machine gate, independently prove the
capability, enforced-control and adversarial-denial planes, and prove zero
runtime residue. Normal product Deep Dive remains
`.implementationUnavailable`; Task 44 remains its sole admission gate.

## 2. Delivered Boundary

Task 39A adds:

- a strict `SignedInvestigationRuntimeDiagnosticConfiguration` that binds the
  nonce, source, build, App/helper, service, runtime receipt, provider,
  resources and owner-only diagnostic paths;
- a strict `SignedInvestigationRuntimeReport` with independent capability,
  production-evidence, denial and residue planes;
- closed ready/blocked/failed verdict derivation rather than caller-supplied
  readiness;
- a package-only admission receipt that can be minted only from a ready report;
- a `SignedInvestigationRuntimeReportVerifier` that revalidates exact report
  bytes, canonical fingerprint, configuration binding, admission identity,
  expiry and nested capability evidence;
- physical per-component symlink rejection for owner-only configuration and
  report paths, including ancestor symlinks;
- a package-owned production-session protocol and public narrow diagnostic
  facade that forwards validated App Server lines to the existing Task 38
  coordinator;
- server-assigned turn identity binding, with identity mismatch, line-read
  failure and closing-persistence failure entering the protocol-lost terminal
  path and revoking the facade identity;
- structural checks that keep the diagnostic session owner package-only and
  reject Executor, cleanup, authorization and synthetic capability-worker
  reachability.

No App target, UI, disclosure, Review projection, Policy, authorization,
Executor, Trash or normal-product availability surface changed.

## 3. Scope and Cost Audit

The checkpoint changed 11 non-document source, test and script paths and added
approximately 3,300 non-document lines. It stayed below the Task 39 hard split
gate of 14 non-document files or approximately 4,000 added lines.

Task 39B is a separate independently reviewed and pushed checkpoint. This
prevents the signed-App machine gate from recreating the oversized Task 36–38
review surfaces.

## 4. Tests-First and Focused Evidence

The final focused matrix passed:

| Focus | Result |
| --- | ---: |
| `SignedRuntimeContractTests` | 11/11 passed |
| `InvestigationRuntimeDiagnosticFacadeTests` | 5/5 passed |
| `StornautInvestigationTests` | 77/77 passed |
| Investigation structural boundaries | passed |
| Documentation links | passed |
| Diff hygiene | passed |

The complete serialized SwiftPM regression used the Swift 6.3-supported
command `swift test --no-parallel`:

```text
829 tests in 32 suites passed after 98.652 seconds
```

Evidence:

```text
/tmp/stornaut-task39a-swift-serial-1786849045.log
SHA-256 dae62720db18dbdaf6a8ecc49d1f61ebe817d69d0fb835a83582476be8c73d3c
```

`swift test --parallel false` was rejected by the current Swift 6.3 CLI during
argument parsing and ran no tests. The implementation brief now records the
supported `--no-parallel` form.

## 5. Independent Review and Repairs

The initial independent review was stopped after it expanded beyond the
checkpoint diff. The replacement review was time-boxed to the Task 39A diff
and P0–P2 findings. It found three P1 issues and one P2 issue:

1. a valid nested capability report could be repackaged into a different
   outer report without revalidating its canonical signed evidence;
2. the verifier trusted construction-time expiry instead of rechecking the
   admission time;
3. a production-session line-read failure did not immediately fail closed and
   revoke the facade identity;
4. path checks rejected a leaf symlink but could accept an ancestor symlink.

Tests were added before each repair. Follow-up self-review also closed:

- verification after the report has been atomically written to its configured
  output path, rather than requiring the output to remain absent forever;
- facade identity revocation after a transition failure even when runtime
  cleanup succeeds.

The final independent post-fix review used authenticated Codex
`gpt-5.6-luna`, session
`01a0087f-58bf-7a30-b532-06ee5445d377`, and reported:

```text
No P0-P2 findings.
```

Model review is review evidence only. It is not signed-App containment,
capability observation or Task 39B admission evidence.

## 6. Authoritative Verification

One uninterrupted final `scripts/verify --full` passed all 23 ordered stages:

```text
Verification passed in full mode.
scripts/verify --full  265.13s user 79.08s system 38% cpu 14:51.15 total
```

Evidence:

```text
/tmp/stornaut-task39a-verify-full-1786849157.log
SHA-256 f3e480a6bf192e5a87a70b25ab213976e937d7e039696d92953a8f486698a109
```

Important stage evidence:

- XCUITest and screenshot contracts passed;
- the full SwiftPM stage passed 824 tests in 32 suites;
- bounded Investigation benchmarks passed;
- App tests/snapshots, Debug build/signing, bundle validation and
  Debug/Release fixture boundaries passed;
- all source boundaries, Rule Compiler, verifier contract, docs/diff,
  Phase C product and sealed signed-App Trash receipt gates passed.

The sealed Task 35 real Trash/recovery mutation was not rerun.

## 7. Scope and Safety Audit

Task 39A does not:

- invoke a real model or infer containment from model success;
- create a signed-App machine report or admission verdict;
- edit `~/.codex/config.toml`;
- install, start or remove the fixed helper/runtime topology;
- access a real user investigation path;
- add production Deep Dive UI or availability;
- add Review, cleanup, Policy, authorization, Executor or Trash authority;
- change release, notarization, FDA/TCC or distribution claims.

The contract keeps capability observation, configured controls, enforced
denials and residue as separate evidence. Only Task 39B can assemble those
planes from the current-source signed App/helper diagnostic.

## 8. Next Gate

Task 39B is the next checkpoint. Before implementation it receives its own
scope/cost preflight and must split again if it would exceed the same
14-file/approximately-4,000-line hard gate.

Task 39 completes only after 39B independently passes:

- current-source signed Debug App/helper binding;
- one bounded real authenticated Codex investigation;
- all required capability, enforced-control and adversarial-denial evidence;
- failure-path drain and zero residue;
- focused and serialized tests;
- independent P0–P2 review;
- one uninterrupted authoritative `scripts/verify --full`;
- independent commit and push.
