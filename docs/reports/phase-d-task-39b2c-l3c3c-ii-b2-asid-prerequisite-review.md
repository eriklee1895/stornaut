# Phase D Task 39B2c-L3c3c-ii-b2 ASID Cohort Prerequisite Review

> Status: Complete; shared claim-evidence ASID semantics corrected, structural
> anti-spoofing gate added, completion-audit test supplement independently
> validated and pushed; non-admitting
>
> Date: 2026-08-19
>
> Implementation commit: `67fba7c088d922db04a66ce8eff9be30ba3d0f43`
>
> Implementation tree: `1c63963e2d817db7f5d5cd524803b735753a3da9`
>
> Implementation validation snapshot: `acdaeee92241df972b95dca87b382c535e36143a`
>
> Test-supplement commit: `915601227d27b2d382515b542d05727e24e1da8b`
>
> Test-supplement tree: `e44e67c748c9ee273567eecba70cb8dfe53afa75`
>
> Test-supplement validation snapshot: `e1c4618a598e8b984c768341cd4a59bab024f05c`
>
> Scope: semantic correction of one shared non-product claim-evidence join and
> one explicit decoder-negative supplement; no wire-layout, package graph,
> product target, escrow/XPC/helper/Machine behavior, install, privilege,
> model/auth, readiness or full verifier

## 1. Outcome

The ASID cohort prerequisite is complete. The shared claim evidence now models
the accepted local-only topology instead of requiring the App caller and root
helper to share an audit session:

```text
complete App identity     -> independently bound, including App ASID
complete helper identity  -> independently bound, including helper ASID
L1 residue ASID           -> exactly helper ASID
```

The normal fixture is App ASID `7`, helper ASID `9` and L1 residue ASID `9`.
The complete App and helper identity values still bind PID, PID version, EUID,
ASID and all eight audit-token words. Contextual validation still compares both
complete identities to immutable expectations; removing the false cross-process
ASID equality did not weaken either identity.

`InvestigationMachineClaimExpectation.auditSessionID` is renamed to
`helperAuditSessionID` and is derived only from the helper identity. The claim
evidence constructor and contextual validator both bind L1 residue to that
helper session. App-derived expectation assignment, App/helper ASID equality and
App/residue ASID equality are structurally forbidden in both operand orders.

The wire domain, version, field count, field order, length bounds and codec are
unchanged. The exact evidence golden remains 768 bytes. Only the fixture values
in the already-existing App ASID field and its audit-token ASID word changed from
`9` to `7`; no tag, length or new field was introduced.

## 2. Scope and Cost Audit

The final non-document surface remains the exact four paths frozen by the
preflight:

1. `Sources/StornautInvestigationHandoffContract/InvestigationMachineClaimContract.swift`;
2. `Tests/StornautInvestigationTests/InvestigationMachineClaimContractTests.swift`;
3. `scripts/verify-investigation-boundaries`; and
4. `scripts/verify-contract`.

Against the approved preflight baseline, the final surface is 372 additions and
16 deletions, or 388 added-or-changed lines. This is below the 500-line ceiling.
No `Package.swift`, Lifecycle, helper, Machine, App, Xcode project or scheme path
changed.

## 3. Prompt-to-Artifact Completion Audit

| Requirement | Direct artifact and evidence | Result |
| --- | --- | --- |
| distinct App/helper ASIDs are valid | constructor, expectation and hand-built decoder positives use App `7`, helper `9` | satisfied |
| L1 residue belongs to helper session | production constructor and contextual validation join residue to helper; normal residue is `9` | satisfied |
| App ASID remains authenticated | complete expected-App identity equality plus foreign-App-ASID negative | satisfied |
| helper ASID remains authenticated | complete expected-helper identity equality plus foreign-helper-ASID negative | satisfied |
| constructor rejects App-bound residue | App `7` / helper `9` / residue `7` constructor negative | satisfied |
| decoder rejects App-bound residue | hand-built valid 11-field wire with only residue `7` mismatching helper `9` is rejected | satisfied |
| exact wire compatibility | unchanged encoder/decoder schema, unchanged 768-byte length and exact golden | satisfied |
| structural gate cannot be satisfied by prose | Swift lexical cleaner removes line comments, nested block comments and normal/triple strings before scoped checks | satisfied |
| forbidden equality is operand-order independent | scoped checker rejects both App/helper and App/residue equalities in both directions | satisfied |
| structural checker has executable controls | comment-only required join, string-only assignment and reversed invalid equality mutations all fail | satisfied |
| exact scope and budget | four approved paths, 388-line final surface | satisfied |
| no product/readiness expansion | no package/product/App/helper/Machine change; no full, install, privilege, model or auth run | satisfied |
| artifact identity is exact | implementation and supplement snapshots each resolve to their accepted staged tree | satisfied |

Passing regression alone is not used as completion proof. The table maps each
preflight obligation to the production source, a direct behavioral test or an
executable structural mutation control.

## 4. Validation

### 4.1 Implementation and verifier tree

| Gate | Result |
| --- | --- |
| tests-first RED | three distinct-ASID contract cases failed with `invalidValue` before the semantic correction |
| focused claim contract | 19/19 passed |
| affected Investigation regression | 281 tests in 24 suites passed |
| focused coverage | 42/42 functions; 574/576 lines, 99.65%; 169/171 regions, 98.83% |
| changed-function execution counts | evidence init 21; validate 13; expectation init 16 |
| `scripts/verify-investigation-boundaries` | exit 0 |
| `scripts/verify-contract` | exit 0, including all three dynamic structural mutations |
| sole implementation staged serial | 1,142 tests in 56 suites passed |
| implementation serial test / stage time | 82.019 / 124.729 seconds |
| snapshot identity | `acdaeee` tree equals implementation tree `1c63963e...` |

### 4.2 Completion-audit test supplement

The final prompt-to-artifact audit found one P2 evidence omission after the
implementation serial: the constructor had an explicit helper/residue mismatch
negative, while the decoder only had a positive distinct-ASID case. Production
decode already calls the same throwing initializer, so this was not a discovered
runtime bypass, but the preflight explicitly required independent constructor
and decoder regression evidence.

The omission was not hidden or folded into the prior serial. It was split into
one test-only path, recorded before execution, and validated independently:

| Gate | Result |
| --- | --- |
| focused claim contract | 20/20 passed; new decoder negative executed |
| exact supplement scope | one test path, 29 additions, no production/verifier change |
| sole supplement staged serial | 1,143 tests in 56 suites passed |
| supplement serial test / stage time | 80.407 / 127.037 seconds |
| snapshot identity | `e1c4618` tree equals supplement commit tree `e44e67c...` |
| independent final review | original P2 closed; no unresolved P0-P2 |

The supplement's outer transcript has the correct domain and all eleven fields.
Its request digest, challenge, epoch, identities, timestamps, owner retirement,
zero-count residue and deadline are valid. A neighboring positive uses the same
shape with residue ASID `9`; the negative changes only residue ASID to App ASID
`7`. The decoder rejection therefore directly proves the required helper join.

## 5. Safety Boundary and Next Gate

This prerequisite did not implement ii-b2 escrow states, clocks, deadline
replacement, XPC selectors, helper replies, Machine claimant migration, release
dispatch or helper-exit linearization. It did not run an App bundle gate,
authoritative headless/full verification, sudo, install/uninstall, a signed App,
model or auth.

The prerequisite is complete, but ii-b2 is not. The next frontier is the frozen
ii-b2a non-product typed escrow/deadline state checkpoint, followed by ii-b2b
XPC/helper/Machine integration. ADR 0018 remains Proposed, Task 39 remains
incomplete, production Deep Dive remains unavailable, real Trash remains closed
and L3c4 exclusively owns readiness and the remaining authoritative full
verifier.
