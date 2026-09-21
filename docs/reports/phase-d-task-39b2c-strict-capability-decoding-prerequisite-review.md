# Phase D Task 39B2c Strict Capability Decoding Prerequisite Review

> Status: Complete; independently committed before the 39B2c machine contract
>
> Date: 2026-08-17
>
> Baseline:
> `b7993c875c8faa95a1769ad47551f4e833f8c4d6`
>
> Scope: strict unknown-field rejection and derived-outcome validation for the
> reused authoritative capability runtime report; no signed-App machine run,
> real model invocation, product Investigation or readiness verdict

## 1. Decision

This narrow prerequisite is complete. `CapabilityRuntimeDiagnosticReport` and
every nested evidence projection now reject unknown fields instead of relying
on the permissive synthesized `Decodable` behavior. The report also
reconstructs its derived outcome from validated evidence and requires exact
equality with the serialized outcome.

The repair was separated from the 39B2c deterministic machine-contract
checkpoint after independent review found the decoding defect. Keeping it in
the same checkpoint would have raised the non-document working diff above the
approximately 4,000-added-line review split limit. The repair was not reduced
or hidden to remain below that limit.

This checkpoint does not assemble or verify a Task 39 machine candidate, run a
signed App/helper topology, invoke `gpt-5.6-luna`, claim
`signedInvestigationRuntimeReady` or enable production Deep Dive.

## 2. Closed Schema Drift

The authoritative capability report is reused by Task 39 machine admission.
Before this repair, its top-level report and nested outcome payloads could
silently accept unknown JSON fields. That allowed a newer or adversarial
producer to attach unvalidated semantics while the older verifier still
decoded the document.

The implemented closed decoding now:

- requires the exact top-level keys for
  `CapabilityRuntimeDiagnosticReport`;
- requires schema version 2;
- rejects unknown fields in capability metadata, capability and integrity
  evidence, worker evidence, lifecycle evidence and repository evidence;
- requires `CapabilityRuntimeDiagnosticOutcome` to contain exactly one known
  case key;
- requires `signedRuntimeReady` to contain an empty object;
- allows only `reasonKeys` in `signedRuntimeBlocked` and
  `externalStateBlocked`;
- validates bounded, non-empty and unique reason keys through the existing
  closed constructors;
- reconstructs the complete report from decoded evidence and requires the
  serialized outcome to equal the newly derived outcome.

Encoding remains explicit and symmetric with the closed wire contract.

## 3. Tests First

The focused regression injected:

- one unknown top-level report field; and
- one unknown field inside the `signedRuntimeReady` outcome payload.

Before the fix, both malformed documents decoded successfully and the focused
test failed twice. After the strict decoders were implemented, the same test
passed. The complete capability diagnostic contract suite then passed.

Additional existing and new contract coverage verifies exact nested keys,
closed enum cases, component bounds, schema version and derived-outcome
consistency.

## 4. Validation

| Gate | Result |
| --- | --- |
| exact top-level/outcome unknown-field regression | passed after first proving two red failures |
| complete `CapabilityRuntimeDiagnosticContractTests` | 38/38 passed; one Xcode-helper-only case explicitly skipped |
| structural Investigation boundary | passed |
| structural Codex no-Executor boundary | passed |
| parallel complete `StornautCodexTests` | one provider-catalog preflight exceeded its 5-second limit under suite load; all other effective cases passed |
| exact provider-catalog retry | passed in 0.709 seconds |
| serialized complete `StornautCodexTests` | 255 tests in 15 suites passed in 39.854 seconds |
| staged diff hygiene | passed |

The exact serial retry confirmed that the parallel-suite failure was resource
contention rather than a product regression. No test expectation or timeout
was weakened.

The code-only staged diff changes two paths with 637 additions and no
deletions. Its SHA-256 is
`57999dcb6c1abb6561719c2978e2ccbfc337c58f1b44757f0e26a80247c21b24`.

This prerequisite intentionally does not run `scripts/verify --full`.
The authoritative full verifier remains reserved for the frozen 39B2c machine
checkpoint after its machine driver, failure matrix and review are complete.

## 5. Independent Review

The first machine-contract post-fix review found this strict-decoding defect as
one P1. The focused red test reproduced it before implementation.

An authenticated `gpt-5.6-luna` read-only review then inspected only the
staged two-file prerequisite. It confirmed:

- all relevant capability report layers reject unknown fields;
- the outcome decoder enforces exactly one closed case and exact payload keys;
- the top-level report reconstructs and compares the derived outcome;
- no readiness, containment or product-availability claim was introduced.

The post-fix conclusion is `No unresolved P0-P2 findings.`

| Evidence artifact | SHA-256 |
| --- | --- |
| original machine review that found the P1 | `48b5dc04947ab607d91accce7651d2fbfab3cda98dcb1ae0e6e5a18d12a48d72` |
| focused red regression | `b0649fbe5f8710d85e320053d6f2fb6de389d62896d046a53be84cf5eed75df3` |
| focused green regression | `9062a0054a3b70f620d127cf98641c69cc25e7c588f521d2c642459a810fc116` |
| strict-decoding post-fix review | `cc43ab50149a021ab36bc1574b5260b21ac821d7056c26a631b776aaaea21c3b` |
| exact provider-preflight retry | `f2c3e340d849c5c974ced5332e90c2202cd76f45cc8285cbf4604e60eacd6658` |

The reviewer ran in a read-only sandbox and could not create Swift/Xcode cache
directories. The local validation funnel above executed the focused and full
test suites.

## 6. Safety Audit

This prerequisite does not:

- invoke a model or treat model success as containment;
- install, load, start or uninstall the fixed lifecycle topology;
- run a production Investigation or failure matrix;
- create or accept a machine-admission receipt;
- enable normal-product Deep Dive;
- add cleanup, Trash, Policy, authorization or Executor authority;
- modify `~/.codex/config.toml`;
- broaden localhost, private, link-local or Unix-socket access;
- coordinate or terminate unrelated Node, Chrome, Cursor, Claude or MCP
  processes;
- change release, notarization, FDA/TCC or distribution claims.

No new dependency or license is introduced.

## 7. Next Gate

The 39B2c deterministic machine contract remains next. Its candidate verdict
must stay `evidenceContractValidatedMachineAdmissionPending`; candidate JSON
cannot self-assert `signedInvestigationRuntimeReady` or create a final
admission receipt.

After the deterministic candidate verifier is independently accepted, the
separate signed-App current-machine driver owns the bounded real-model run,
eight-scenario failure matrix, independent evidence planes, teardown and
zero-residue proof. Task 44, not Task 39, remains the only gate that may enable
normal-product Deep Dive.
