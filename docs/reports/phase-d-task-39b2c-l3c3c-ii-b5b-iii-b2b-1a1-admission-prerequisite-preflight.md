# Phase D Task 39B2c iii-b2b-1a-1 Admission Prerequisite Preflight

> Status: corrective prerequisite frozen after tests-first implementation
> review; non-admitting
>
> Date: 2026-08-26
>
> Baseline: `40aff485502a54f9443af60eff30a10d08b75173`

## 1. Why this prerequisite exists

The iii-b2b-1a-1 RED/GREEN loop exposed two cross-file invariants that cannot
remain duplicated or be deferred to the final verifier:

1. the outer initial/final driver digest must be byte-for-byte identical to the
   digest already consumed by the normal inner result; and
2. the one-shot outer admission must sample the monotonic clock immediately
   before minting its opaque admitted token, rather than relying only on an
   earlier terminal-observation timestamp.

The original eight-path 1a-1 scope did not include the two owning production
files or the existing protocol test. Continuing without an explicit split would
either duplicate a security-critical transcript or exceed the frozen path
inventory. This prerequisite is therefore isolated before the remaining 1a-1
implementation is sealed.

## 2. Exact non-document scope

Maximum three non-document paths and 300 changed non-document lines:

1. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineSingleEpochComposition.swift`
2. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinOuterInnerProtocol.swift`
3. `Tests/StornautInvestigationTests/InvestigationMachineDarwinOuterInnerProtocolTests.swift`

No protocol wire shape, target graph, public API, process authority, App/helper
launch, XPC operation, root operation, model call, network access or final
readiness claim is allowed.

## 3. Required behavior

- Promote the existing canonical driver-observation digest helper only to
  module-internal visibility; do not change its domain, field order, widths or
  size limits.
- Inject a monotonic clock into the existing package-closed admission actor for
  tests while retaining the fixed production clock in its package initializer.
- Perform the final clock read after all result/evidence decoding and admission
  digest construction and immediately before the sole admitted-token mint.
- Require `terminalEvidence.observedAtNanoseconds <= admittedAt < epochDeadline`.
- Preserve one-shot/cancellation behavior and all existing normal/parent-crash
  checks.

## 4. Validation and non-claims

Run the focused outer-inner protocol suite, affected single-epoch/physical
bridge suites, a targeted driver build, and an independent P0-P2 review. This
package-only prerequisite does not consume the staged serial or authoritative
full verifier reserved for the enclosing 1a-1/security checkpoint.

After it is committed, iii-b2b-1a-1 restarts from that commit and retains its
original eight-path ceiling for the App identity observer, concrete outer
observer, factory, focused/boundary tests and three verifier scripts.
