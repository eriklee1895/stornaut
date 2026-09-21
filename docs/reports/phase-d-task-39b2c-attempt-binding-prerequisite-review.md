# Phase D Task 39B2c Attempt-Binding Prerequisite Review

> Status: Complete; independently committed before machine admission
>
> Date: 2026-08-17
>
> Baseline:
> `79c527ae3c7eb5e70c5c1c2ab61e186daca9084a`
>
> Scope: exact cross-attempt binding for reused R5 capability evidence; no
> signed-App machine run, real product Investigation or readiness verdict

## 1. Decision

This narrow prerequisite is complete. Raw R5 capability worker evidence now
binds to the exact Task 39 nonce and complete signed runtime binding before it
can enter a Task 39 report. The binding follows the existing App → XPC → root
helper → caller-UID worker path and returns in the raw worker evidence.

The final Task 39 verifier still receives authoritative raw metadata, worker,
lifecycle and repository evidence. It reconstructs the capability receipt
internally and requires exact equality with the receipt embedded in the signed
Investigation report. A decoded receipt also reconstructs all four canonical
component projections from its validated report plus nonce/binding and rejects
any component-hash mismatch.

This checkpoint does not run the 39B2c machine driver, invoke a real model,
install the fixed local topology or claim `signedInvestigationRuntimeReady`.
Task 39 and production Deep Dive remain incomplete.

## 2. Closed Replay Window

The previous report contract allowed an older Ready capability report to be
wrapped after the fact by a fresh Task 39 report. A receipt containing only
outer hashes would not close that window because the wrapper could mint those
hashes after the older capability attempt finished.

The implemented contract now:

- derives one 256-bit capability-evidence binding from configuration schema,
  fresh nonce, the complete `SignedInvestigationRuntimeBinding`, expected model
  and expected provider;
- requires `CapabilityRuntimeWorkerEvidence` to carry the exact Investigation
  UUID and lowercase binding SHA-256;
- makes lifecycle supervisor wire protocol v2 require the binding on every
  `.start`; `.cancel` cannot carry one, and v1 is rejected;
- passes the binding through the App harness, XPC request, root helper and
  caller-UID worker argument list without an optional, empty or legacy
  fallback;
- makes the helper compare returned worker UUID/binding before accepting raw
  evidence;
- makes the final verifier reconstruct the receipt from the four authoritative
  raw inputs instead of trusting a serialized receipt;
- makes receipt decoding reconstruct canonical metadata, worker, lifecycle and
  repository projections and compare every component hash.

The complete signed binding includes repository HEAD, source fingerprint,
current App/helper/Codex hashes, runtime receipt, prompt/schema/facade hashes,
bundle identity and lifecycle service identity. Evidence from another nonce,
source tree, build or runtime receipt cannot be joined into the current
attempt.

## 3. Tests First

The focused tamper test changed each of:

- `metadataSHA256`;
- `workerSHA256`;
- `lifecycleSHA256`;
- `repositorySHA256`.

Before the fix, the exact test failed four times because every modified hash
decoded successfully. After canonical projection reconstruction was added, the
same test passed and the complete 20-test signed-runtime contract suite passed.

Additional contract coverage rejects:

- missing, short, uppercase or malformed bindings;
- protocol-v1 lifecycle requests;
- a binding on `.cancel`;
- foreign Investigation UUIDs;
- cross-nonce and cross-binding evidence reuse;
- unknown nested fields and verdict payload drift.

## 4. Validation

| Gate | Result |
| --- | --- |
| exact four-field component-hash tamper test | passed after first proving four red failures |
| complete `SignedRuntimeContractTests` | 20/20 passed |
| complete `StornautLifecycleTests` | 86/86 passed |
| complete `StornautCodexTests` | 253/253 passed; one Xcode-helper case explicitly skipped |
| complete `StornautInvestigationTests` | 111/111 passed |
| structural Investigation boundary | passed |
| structural Codex no-Executor boundary | passed |
| repository contract verifier | passed |
| dedicated diagnostic App test target | passed |
| `scripts/verify --headless` | 8/8 stages passed |
| headless serialized SwiftPM regression | 903 tests in 37 suites passed |
| documentation links and diff hygiene | passed |

Headless stage timings:

| Stage | Seconds |
| --- | ---: |
| source boundaries | 3.828 |
| localization contract | 0.034 |
| verifier contract | 3.943 |
| docs and diff | 0.234 |
| serialized SwiftPM tests | 71.589 |
| rule compiler | 15.483 |
| App contract tests | 19.194 |
| Phase C product gate | 5.301 |

The implementation changes eleven non-document paths with 942 additions and
117 deletions, below both checkpoint split limits. The frozen non-document diff
SHA-256 is
`4f70967b3352f008b3fbec59b3eef88764059f081e1f8b9ddb0687bcf4c0f364`.
The headless timing artifact SHA-256 is
`88fc4c13c1af39f0ede9c2b39b92283c7beba27f833b4f822f822dc6a032d38f`.

## 5. Independent Review

The first independent `gpt-5.6-luna` read-only review found one P2: serialized
component hashes were format-checked but not proven to match their embedded
evidence projections. That finding was reproduced with the four-field red
test and fixed by deterministic projection reconstruction.

The post-fix review confirmed:

- component hashes are recomputed and checked during decoding;
- fresh nonce and complete binding changes invalidate rewrapping;
- App → XPC → helper → worker propagation is mandatory and fail closed;
- lifecycle protocol v1 is rejected;
- final verification uses authoritative raw evidence;
- shell validation remains fail closed.

The post-fix conclusion is `No unresolved P0-P2 findings.` The reviewer ran in
a read-only sandbox and therefore could not create Swift/Xcode caches; the
local validation funnel above independently executed all tests.

| Review artifact | SHA-256 |
| --- | --- |
| initial review | `03e28d04f1cc7761758a35a39200c2c5e4ac5673dcfe5afb0378001c9660e7df` |
| post-fix review | `4bfc98d2669497b608dfa60ee574eda5ba80c36d4e1c56a316ae3c688c9c0552` |

## 6. Safety Audit

This prerequisite does not:

- invoke a model or treat model success as containment;
- install, load, start or uninstall the fixed lifecycle topology;
- run a production Investigation or failure matrix;
- enable normal-product Deep Dive;
- create cleanup, Trash, Policy, authorization or Executor authority;
- modify `~/.codex/config.toml`;
- broaden localhost, private, link-local or Unix-socket access;
- coordinate or terminate unrelated Node, Chrome, Cursor, Claude or MCP
  processes;
- change release, notarization, FDA/TCC or distribution claims.

No new dependency or license is introduced.

## 7. Next Gate

Task 39B2c machine admission remains the next gate. It owns:

- the tests-first machine verifier and failure matrix;
- current-source signed App/helper installation and invocation;
- one bounded authenticated `gpt-5.6-luna` Investigation;
- independent capability, enforced-control and adversarial-denial planes;
- cancellation, timeout, malformed-envelope, identity, transport, lifecycle
  recovery and artifact-cleanup cases;
- final teardown and zero-residue proof;
- the Task 39 completion report and sole Task 39 readiness verdict.

Task 44, not Task 39, remains the only gate that may enable normal-product
Deep Dive.
