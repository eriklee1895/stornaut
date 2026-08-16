# Phase D Task 39B1b-i Code Review and Completion Audit

> Status: Complete; tests-first package-closed transport/composition,
> focused regressions, independent post-fix review, serialized SwiftPM
> regression and one uninterrupted 23-stage authoritative
> `scripts/verify --full` passed.
>
> Date: 2026-08-16
>
> Baseline:
> `53ddc6604ec511003fc78ba1898586865a8433e8`
>
> Scope: package-closed interactive Codex App Server client, dedicated
> non-product Investigation runtime composition, server-owned identity
> mapping and fail-closed asynchronous lifecycle integration

## 1. Current Decision

Task 39B1b-i is complete as the transport/composition checkpoint. The closed
Task 38 Investigation facade can now be composed with a stateful App Server
session without exposing a public package product, adding cleanup authority or
blocking an actor on asynchronous transport.

Task 39 remains incomplete. Checkpoint 39B1b-ii must still add the strict
DEBUG-only App diagnostic leaf and its Release activation boundaries.
Checkpoint 39B2 must then independently prove current-source signed-App
machine admission using a real bounded authenticated Codex Investigation,
three independent evidence planes and zero runtime residue. Normal product
Deep Dive remains `.implementationUnavailable`; Task 44 remains its sole
normal-product admission gate.

## 2. Delivered Boundary

Task 39B1b-i adds:

- a package-scoped stateful JSON-RPC App Server client with fixed official
  `openai`, `gpt-5.6-luna`, approval `never` and the admitted external sandbox
  profile;
- strict initialize, auth projection, ephemeral root start, turn start,
  thread metadata, interrupt, notification and one-shot retirement flows;
- response/notification demultiplexing that accepts only bounded validated
  JSON-RPC shapes and server-owned thread/turn identities;
- one bounded auth refresh during an active runtime phase without modifying
  `~/.codex/config.toml`;
- a non-public `StornautInvestigationRuntime` target depending only on
  `StornautCodex`, `StornautCore` and `StornautInvestigation`;
- an `InvestigationCodexSessionAdapter` that asynchronously preopens a root,
  synchronously claims it exactly once inside Store admission, injects the
  canonical prompt/context only on the first admitted turn and maps only
  server-returned identities;
- distinct pending turn reservations and active turns, preventing an
  asynchronous turn-start response from allowing premature settlement;
- fail-closed transport handling that revokes the facade run identity, drains
  lifecycle ownership and retires artifacts after turn-start or line-read
  failure;
- structural checks rejecting public product exposure, cleanup/Executor
  authority, direct process spawning, filesystem mutation and direct network
  clients in the composition target.

No App source, DEBUG activation, real model invocation, fixed runtime
installation, signed machine report, UI, Review, Policy, authorization,
Executor or Trash surface changed.

## 3. Scope and Cost Audit

The checkpoint changed 13 non-document source, test and script paths, adding
2,760 lines and deleting 122. It stayed below the Task 39 hard split gate of
14 non-document paths or approximately 4,000 added non-document lines.

The original 39B work was split before implementation into 39B1 and 39B2,
39B1 was split into 39B1a and 39B1b, and this checkpoint split 39B1b once more
before touching App sources:

- 39B1b-i owns only transport and package composition;
- 39B1b-ii owns the strict DEBUG App leaf and Release activation boundaries;
- 39B2 exclusively owns real-model signed-App machine admission.

This prevents a repeat of the oversized Task 36–38 review surfaces while
keeping every pushed checkpoint behind the authoritative full verifier.

## 4. Tests-First and Focused Evidence

The regressions cover:

1. complete multi-turn initialize/login/thread/turn/read/interrupt protocol;
2. response-before-notification ordering and closed notification handling;
3. fixed provider/model/approval/sandbox configuration and exact identities;
4. one-shot retirement and bounded auth refresh;
5. async root preopen followed by exact synchronous Store claim;
6. one-time canonical prompt/context injection and concurrent first-turn
   serialization;
7. metadata, interrupt and artifact retirement composition;
8. pending reservation settlement during asynchronous turn admission;
9. late response handling while the coordinator is closing;
10. fail-closed transport turn-start and line-read errors.

The final focused matrix passed:

| Focus | Result |
| --- | ---: |
| Interactive App Server client | 4/4 passed |
| Production session adapter/facade | 11/11 passed |
| Complete `StornautInvestigationTests` | 92/92 passed |
| Complete `StornautCodexTests` | 240/240 passed; 8 explicit opt-in diagnostics skipped |
| Investigation structural boundary | passed |
| Codex no-Executor boundary | passed |

Evidence:

```text
/tmp/stornaut-39b1bi-investigation-tests.log
SHA-256 018409362285916ce3057f062417158fe22134cced345edf7f4f393e49e1f910

/tmp/stornaut-39b1bi-codex-tests.log
SHA-256 969110014889564f4aa2dbb4b8e8e208c17181d9ff21281d62ef9f3901e3d63c
```

The complete serialized SwiftPM regression passed:

```text
846 tests in 33 suites passed after 99.228 seconds
12 explicit opt-in diagnostics skipped
```

Evidence:

```text
/tmp/stornaut-39b1bi-serial-tests.log
SHA-256 428868d0e922338e53be7654a8d186212feafa42a4f2ccb89732183e1d4a074a
```

## 5. Independent Review and Repair

The independent P0–P2 review exercised the complete checkpoint diff and
identified one fail-closed state problem: a production transport turn-start
failure retired the adapter but could leave the facade/coordinator identity
appearing active.

A focused regression first reproduced the exact protocol sequence. The facade
now revokes its run identity and reuses the coordinator's shared
`failClosedTransport` path so lifecycle drain and artifact retirement complete
before the error returns. The same cleanup path covers line-read failure.

The final independent `gpt-5.6-luna` review covered the repair and reported:

```text
NO_UNRESOLVED_P0_P2
```

Model review is review evidence only. It is not capability observation,
signed-App containment, no-Executor proof or Task 39B2 admission evidence.

## 6. Authoritative Verification

One uninterrupted final `scripts/verify --full` passed all 23 ordered stages:

```text
Verification passed in full mode.
FULL_VERIFY_EXIT=0
FULL_VERIFY_SECONDS=900
```

Evidence:

```text
/tmp/stornaut-39b1bi-full-verify.log
SHA-256 ed8150c7b4015c86233236460044a8389e95d49d615fbd5f9115101e1a5c379a
```

Important timings and evidence:

- XCUITest passed in `541.686` seconds;
- the parallel SwiftPM stage passed in `62.631` seconds;
- Investigation maximum benchmarks passed in `33.375` seconds;
- App tests and snapshots passed in `44.001` seconds;
- Debug App build/sign and bundle validation passed;
- the Debug/Release fixture boundary passed in `111.357` seconds;
- source boundaries, documentation links and diff hygiene passed;
- the sealed Phase C signed-App Trash receipt passed without rerunning the
  real Trash/recovery mutation.

The full verifier's 15-minute wall time is primarily the required UI and
Debug/Release fixture gates, not an Investigation transport hang.

## 7. Scope and Safety Audit

Task 39B1b-i does not:

- invoke a real model or infer containment from model success;
- add a DEBUG App diagnostic activation surface;
- install, start or remove the fixed helper/runtime topology;
- create a machine report or `signedInvestigationRuntimeReady` verdict;
- edit `~/.codex/config.toml`;
- inspect a real user investigation path;
- add production Deep Dive UI or availability;
- add Review, cleanup, Policy, authorization, Executor or Trash authority;
- change release, notarization, FDA/TCC or distribution claims.

## 8. Next Gate

Task 39B1b-ii is the next independently reviewed and pushed checkpoint. It is
limited to:

- the strict DEBUG-only App diagnostic leaf;
- fake App/composition tests;
- normal-navigation isolation;
- Release activation and structural no-Executor boundaries.

It must pass its own scope preflight before implementation and remain below
the 14-path/approximately 4,000-added-line hard split gate. It must not launch
a real model, install the fixed topology, assemble a machine report or claim
signed runtime readiness. Those remain exclusively Task 39B2.
