# Phase D Task 39B2c-L3c3c-ii-b2 ASID Cohort Prerequisite Preflight

> Status: Exact-path prerequisite frozen before ii-b2 escrow/XPC implementation
>
> Date: 2026-08-19
>
> Baseline: `808542e9f00b6cba11a57c9b059d97e4d5ed3fab`
>
> Scope: correct one over-constrained shared claim-evidence identity join; no
> wire-layout change, product-target dependency, escrow/XPC/helper/Machine
> behavior, install, privilege, model/auth, readiness or full verifier

## 1. Contradiction Found Before ii-b2 Coding

The frozen claim-evidence transcript carries complete App identity, complete
helper identity and helper-owned L1 residue as three independent nested values.
Each process identity already validates its own PID, PID-version, EUID, ASID and
eight audit-token words. The contextual expectation also compares both complete
identities to caller-supplied immutable values.

The current shared constructor adds two stronger joins:

```text
appIdentity.auditSessionID == helperIdentity.auditSessionID
l1Residue.auditSessionID == appIdentity.auditSessionID
```

Those joins contradict the accepted local-only topology:

- `LifecycleHelperListenerDelegate` requires the admitted App caller ASID to be
  different from the root launchd helper ASID before accepting the App
  connection;
- `LifecycleMachineRetirementEscrow` requires the same-retire L1 residue ASID
  to equal the helper identity ASID; and
- existing Lifecycle fixtures intentionally use distinct App/helper ASIDs while
  binding residue to the helper.

The ii-b0 wire preflight specifies the App and helper identities separately and
requires every nested identity fact to match its immutable expectation. It does
not state that the two processes share an audit session. L1 residue is evidence
about the helper-owned contained worker/audit-session lifecycle and therefore
joins the helper, not the App.

Changing Lifecycle fixtures or weakening the real helper admission would hide
the contradiction and is forbidden. ii-b2 must not start until the shared
contract represents the accepted topology.

## 2. Frozen Correction

The wire bytes, field order, domains, sizes and version remain unchanged. Only
the semantic joins change:

```text
App process identity
  -> self-consistent role=.app / EUID=501 / audit-token facts
  -> exact equality with expected App identity

Helper process identity
  -> self-consistent role=.helper / EUID=0 / audit-token facts
  -> exact equality with expected helper identity
  -> helper ASID == L1 residue ASID

L1 residue
  -> exact investigation UUID / helper ASID / App UID 501 / zero counts
```

`InvestigationMachineClaimExpectation.auditSessionID` is renamed to
`helperAuditSessionID` and is sourced from `helperIdentity.auditSessionID`. The
complete App identity comparison continues to bind the App ASID independently;
there is no loss of App identity evidence.

Tests must use different nonzero App and helper ASIDs in the normal golden
fixture. They must prove all of the following independently:

- distinct App/helper ASIDs are accepted when every nested identity is exact and
  residue matches the helper;
- residue equal to App ASID but different from helper ASID is rejected;
- foreign App ASID is rejected by complete expected-App identity equality;
- foreign helper ASID is rejected by complete expected-helper identity equality;
- helper/residue ASID drift is rejected at construction and decode; and
- the exact encoded evidence byte count/layout changes only where the fixture's
  already-present ASID bytes change; no field, tag or length changes.

## 3. Exact Scope and Cost

The prerequisite may change exactly four non-document paths and at most 500
added-or-changed lines:

1. `Sources/StornautInvestigationHandoffContract/InvestigationMachineClaimContract.swift`;
2. `Tests/StornautInvestigationTests/InvestigationMachineClaimContractTests.swift`;
3. `scripts/verify-investigation-boundaries`; and
4. `scripts/verify-contract`.

No `Package.swift`, Lifecycle, helper, Machine, App, Xcode project or scheme path
may change. Approaching the ceiling requires another split before coding.

## 4. Tests First and Gates

Validation order is:

```text
tests-first RED using distinct App/helper ASIDs
-> exact claim-contract focused tests
-> structural source gate for helper/residue join and absence of App/helper equality
-> affected Investigation target
-> focused coverage for changed shared functions
-> one clean staged-only serial
-> independent post-fix review
-> commit/push
```

The prerequisite does not run an App bundle gate because no product target,
package consumer or final Mach-O changes. `scripts/verify --full` remains
forbidden and reserved for L3c4.

## 5. Prompt-to-Artifact Preflight Audit

| Requirement | Direct current evidence | Decision |
| --- | --- | --- |
| App/helper ASIDs are actually distinct | helper listener source rejects equal caller/helper ASID | preserve distinct topology |
| L1 residue belongs to helper audit session | escrow record validation and helper-generated residue | bind residue to helper |
| App ASID remains authenticated | complete App identity transcript and expectation equality | no weakening |
| Helper ASID remains authenticated | complete helper identity transcript and expectation equality | no weakening |
| Wire truth remains single and exact | existing STNC evidence layout/golden bytes | semantic-only correction |
| No product graph change | exact four-path list excludes Package/Xcode/product sources | mandatory |
| No readiness/full claim | Task 39/L3c4 gates unchanged | preserved |

## 6. Non-Claims and Next Order

This prerequisite does not implement ii-b2 escrow states, clocks, deadlines,
XPC selectors, helper replies, Machine claimant migration or release/exit
linearization. After it is independently complete, ii-b2 remains split into a
non-product typed escrow/deadline checkpoint and a later product integration
checkpoint so the broad ordinary-App Lifecycle graph never acquires the shared
machine-claim wire through dead stripping.

ADR 0018 remains Proposed, Task 39 remains incomplete, production Deep Dive
remains unavailable, real Trash remains closed, and L3c4 exclusively owns
readiness plus the remaining authoritative full verifier.
