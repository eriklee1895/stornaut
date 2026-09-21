# Phase D Task 39B1a Code Review and Completion Audit

> Status: Complete; tests-first Store-path and async-lifecycle prerequisite
> closure, focused regression, independent post-fix review, serialized SwiftPM
> regression and one uninterrupted 23/23-stage authoritative
> `scripts/verify --full` passed.
>
> Date: 2026-08-16
>
> Baseline:
> `5ddbe1a275214cbc8350b09f19564cd69ad6eb63`
>
> Scope: exact Evidence Store v4 path binding, directly asynchronous
> Investigation lifecycle drain, actor-reentrancy/deadline preservation and a
> structural no-blocking-bridge gate

## 1. Current Decision

Task 39B1a is complete as the prerequisite checkpoint for Task 39B1b. The
signed diagnostic now binds the actual Store v4 location and the Investigation
coordinator can await lifecycle drain without a semaphore, synchronous XPC
reply or other blocking async bridge.

Task 39 remains incomplete. Checkpoint 39B1b must still add the package-closed
interactive transport and strict DEBUG App diagnostic leaf. Checkpoint 39B2
must then independently prove current-source signed-App machine admission with
a real bounded authenticated Codex Investigation, three independent evidence
planes and zero runtime residue. Normal product Deep Dive remains
`.implementationUnavailable`; Task 44 remains its sole admission gate.

## 2. Delivered Boundary

Task 39B1a:

- binds `SignedInvestigationRuntimeDiagnosticConfiguration.storePath` to the
  exact `LocalStoreConfiguration.evidenceDatabaseURL` location under
  `supportRootPath`;
- verifies the contract against a real temporary `EvidenceStore`, rather than
  comparing two duplicated path constants;
- changes `InvestigationLifecycleOwning.drain` to a directly `async throws`
  protocol;
- awaits lifecycle cleanup on start failure, protocol loss, settlement and
  recovery before retiring runtime artifacts;
- reloads actor-owned active-run state after asynchronous drain so token usage
  accepted during actor reentrancy is not overwritten by a stale snapshot;
- recomputes terminal phase and remaining Store deadline after drain so a
  lifecycle wait crossing 135 seconds cannot retire artifacts or persist a
  terminal command;
- extends `scripts/verify-investigation-boundaries` to discover every product
  SwiftPM target owning `InvestigationLifecycleOwning` and all App Swift
  sources, rejecting common semaphore, synchronous XPC, run-loop and
  process/file blocking bridges.

No package transport, App diagnostic target, real model invocation, fixed
runtime topology, machine report, UI, Review, Policy, authorization, Executor
or Trash surface changed.

## 3. Scope and Cost Audit

The checkpoint changed eight non-document source, test and script paths and
added 246 non-document lines with 16 deletions. It stayed well below the Task
39 hard split gate of 14 non-document paths or approximately 4,000 added
non-document lines.

The original 39B work was split before implementation into 39B1 and 39B2, then
39B1 was split again into 39B1a and 39B1b when Store/lifecycle prerequisites
would have pushed the transport/App leaf beyond its review budget. This is the
corrective task-size policy after Tasks 36–38 accumulated oversized review
surfaces.

## 4. Tests-First and Focused Evidence

The new regressions first demonstrated:

1. an asynchronous lifecycle drain allowed actor reentrancy and the old
   settlement code overwrote a token total accepted during suspension;
2. a drain crossing the exact 135-second deadline still retired artifacts and
   attempted terminal persistence;
3. a failed runtime start needed to await lifecycle drain before artifact
   retirement;
4. an alternate SQLite path could satisfy the old signed configuration despite
   not being the Store v4 path.

The final focused matrix passed:

| Focus | Result |
| --- | ---: |
| `StornautInvestigationTests` | 83/83 passed |
| focused changed-test matrix | 50 tests passed |
| Investigation structural boundaries | passed |
| Documentation links before final status edits | passed |
| Diff hygiene before final status edits | passed |

Focused evidence:

```text
/tmp/stornaut-task39b1a-investigation-1786852199.log
SHA-256 f0825d36a1f0181203ff0b72f20222b50709c8283ee282d2aa548ab88d38c00c
```

The complete serialized SwiftPM regression passed:

```text
833 tests in 32 suites passed after 99.857 seconds
```

Evidence:

```text
/tmp/stornaut-task39b1a-swift-serial-1786852212.log
SHA-256 7997c9b01a44c25e8de162393047fbcd380d21589c914dec8d5fbfeea1075fe2
```

## 5. Independent Review and Repairs

The initial post-fix independent review, session
`01a008a7-d8c8-7001-8b11-861acebce06c`, found two P1 issues and one P2 issue:

1. settlement reused actor state captured before an asynchronous lifecycle
   drain, allowing reentrant token updates to be lost;
2. settlement did not recheck the immutable terminal deadline after drain;
3. the Store-path test repeated the product path constant and the structural
   verifier scanned too narrow a source set.

All findings were repaired tests-first. The Store-path regression now creates
`LocalStoreConfiguration` and opens an actual `EvidenceStore`; the structural
gate dynamically scans product lifecycle-owner targets plus the App sources.

The final patch-only independent review used authenticated Codex
`gpt-5.6-luna`, session
`01a008af-2fd8-73d0-9657-f10b80f63315`, and reported:

```text
No P0-P2 findings.
```

Model review is review evidence only. It is not signed-App containment,
capability observation or Task 39B2 admission evidence.

## 6. Authoritative Verification

One uninterrupted final `scripts/verify --full` passed all 23 ordered stages:

```text
Verification passed in full mode.
real 883.38
user 265.68
sys 79.43
```

Evidence:

```text
/tmp/stornaut-task39b1a-verify-full-1786852333.log
SHA-256 801386a1c25900ff41cecf56e4080dcea5c6a9e7a5e663f92b353e69ec222218
```

Important evidence:

- XCUITest and screenshot contracts completed without a focus-loss retry;
- the serialized SwiftPM regression passed all 833 tests;
- Investigation and lifecycle structural boundaries passed;
- App tests, Debug/Release builds and source boundaries passed;
- Phase C product and sealed signed-App Trash receipt gates passed without
  rerunning the real Trash/recovery mutation.

## 7. Scope and Safety Audit

Task 39B1a does not:

- invoke a model or infer containment from model success;
- add the package-closed interactive transport or DEBUG App diagnostic leaf;
- install, start or remove the fixed helper/runtime topology;
- create a machine report or `signedInvestigationRuntimeReady` verdict;
- edit `~/.codex/config.toml`;
- access a real user investigation path;
- add production Deep Dive UI or availability;
- add Review, cleanup, Policy, authorization, Executor or Trash authority;
- change release, notarization, FDA/TCC or distribution claims.

## 8. Next Gate

Task 39B1b is the next independently reviewed and pushed checkpoint. Its
preflight remains limited to 10–12 non-document paths and fewer than 3,500
added non-document lines. It owns:

- the package-closed interactive Codex transport;
- the dedicated composition target;
- the strict DEBUG App diagnostic leaf;
- fake-transport App/composition tests;
- Release and structural no-Executor boundaries.

It must not launch a real model, install the fixed topology, assemble a machine
report or claim signed runtime readiness. Those remain exclusively Task 39B2.
