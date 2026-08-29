# Phase D Task 39B2c L3c3c-ii-c0b-iv-b1a Review and Completion Audit

> Status: complete / non-admitting
>
> Date: 2026-08-29
>
> Parent: `2a417626d27e55774aeb51fe759150edc7496ae5`
>
> Clean index-only validation snapshot:
> `db4e936bfd727e2d84b00559e96c2f7f3eff5266`
>
> Snapshot tree: `412da586d13fae7fd53937231217778b5d9ffd52`
>
> Next frontier: ii-c0b-iv-b1b Darwin authority and structural closure

## 1. Current Result

ii-c0b-iv-b1a is complete and remains non-admitting. The original iv-b1 scope mixed
an injected semantic ownership state machine with concrete Darwin executable,
descriptor and process authority. It is now deliberately split into:

- iv-b1a: typed borrowing outcome, ownership state machine, injected fixed-gate
  handoff semantics and non-forgeable typed receipt; and
- iv-b1b: the concrete Darwin sibling/FD/spawn/drain/wait/reap adapter plus its
  structural verifier closure.

The iv-b1a snapshot contains exactly six non-document paths and stays below its
2,400-line ceiling. The clean staged-only focused run passed 48/48 tests in two
suites, and the clean staged-only affected suite passed 785/785 tests in 55
suites. Initial independent review found four P1 defects; all four were repaired
tests-first in the same snapshot. Three independent post-fix review groups found
no unresolved P0-P2, so the semantic child is accepted as complete while
remaining non-admitting.

## 2. Closed Semantic Contract

- The Lease no longer collapses every borrower failure into a forged handed-off
  result. It carries a three-way typed outcome: definitely not spawned, exact
  gate reaped, or spawn/descriptor-transfer uncertainty.
- Only a definite no-spawn result may mint the one-shot
  `NeverHandedOffProof`. Only an identity- and digest-matching exact-gate-reaped
  result may mint the proof used for exact post-reap settlement.
- Prepared and terminal frames, outer wait status, gate identity, deadline,
  forwarded signal and transport success are joined before settlement. A
  transport failure cannot be projected as a successful handoff.
- Exact process reap, empty process-group observation and transport close are
  all terminal prerequisites. Close uncertainty dominates and forbids
  settlement even if earlier observations looked successful.
- The package-facing result is typed and non-forgeable. Raw file descriptors,
  paths, settlement tokens, proof factories and the injected system protocol do
  not escape the target-internal boundary.

### 2.1 Process-lifetime ownership quarantine

If spawn or descriptor transfer is uncertain, the implementation cannot prove
that the fixed gate never acquired the capsule and cannot prove that it is safe
to unlink or release the retained owner. It therefore mints neither settlement
proof, performs no settlement/unlink, and retains the live ownership object in a
process-lifetime quarantine.

The quarantine intentionally trades bounded possible residue for safety. Its
contents are released only by process teardown, not by the uncertain operation's
normal control flow. The outcome remains terminal failure/uncertainty; it is not
success, recovery, ownership release or zero-residue evidence. This closes the
unsafe alternative where a thrown borrower or mismatched proof could release the
base owner while a transferred descriptor or spawned gate might still exist.

## 3. Exact Scope

The six non-document paths in snapshot `db4e936` are:

1. `Package.swift`;
2. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationOwnerOnlyCapsule.swift`;
3. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationFixedGateHandoff.swift`;
4. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationMachineGateHandoffReceipt.swift`;
5. `Tests/StornautInvestigationTests/InvestigationMachineGateCoordinatorHandoffTests.swift`; and
6. `Tests/StornautInvestigationTests/InvestigationOwnerOnlyCapsuleTests.swift`.

The index records 2,113 additions and 3 deletions. The concrete Darwin adapter,
target-boundary test and verifier scripts are excluded from this snapshot and
belong to iv-b1b. Documentation paths do not count toward the implementation
budget.

## 4. Current Evidence

| Evidence | Result |
| --- | --- |
| clean index-only validation snapshot | `db4e936bfd727e2d84b00559e96c2f7f3eff5266`; tree `412da586d13fae7fd53937231217778b5d9ffd52` |
| exact implementation scope | 6 non-document paths; +2,113 / -3 |
| clean staged-only focused semantic/Lease run | 48/48 tests in 2 suites passed |
| clean staged-only affected suite | 785/785 tests in 55 suites passed |
| Debug compilation | passed through the staged-only test builds |
| clean staged-only Release target build | exit 0 |
| initial independent review | four P1 findings; no acceptance issued |
| tests-first repairs | all four P1 findings have code and regression-test repairs in the snapshot |
| three independent post-fix review groups | no unresolved P0-P2 |
| retained HTML review artifact | `/tmp/stornaut_iv_b1a_postfix_review.360tmH/report.html` |

This child intentionally owns no global staged serial, root/sudo attempt, real
App/helper/driver/gate launch, XPC, model/auth/network attempt or
`scripts/verify --full`. iv-b2 owns the sole aggregate c0b serial; ii-c and
L3c3d own the two real machine attempts; L3c4 owns final admission and the
remaining authoritative full verifier.

## 5. Initial Review Findings and Repairs

| P1 finding | Tests-first repair now present |
| --- | --- |
| settlement could occur before complete terminal admission | validate prepared/terminal identity, deadline, signal, exact outer wait and successful gate status before requesting exact-reap settlement |
| a transport failure receipt could still reach a successful handoff | require the terminal transport receipt to map to the completed status and agree with the outer gate wait classification |
| transport-close uncertainty could still be followed by settlement | make close uncertainty an overriding terminal error and never invoke settlement on that path |
| spawn/transfer uncertainty released retained ownership | mint no proof, perform no unlink/release and retain the owner in process-lifetime quarantine |

Three independent post-fix groups verified the final snapshot and found no
unresolved P0-P2. This closes iv-b1a review without admitting the concrete Darwin
or aggregate machine path.

## 6. Non-Claims and Next Step

iv-b1a does not prove concrete Darwin executable metadata, descriptor plumbing,
pipe liveness, signal forwarding, TTY restoration, bounded wait/reap or final
target/source admission. It does not run the fixed gate, accept ADR 0018, claim
machine readiness or enable production Deep Dive. Task 39 remains incomplete.

The current frontier is iv-b1b, which owns a tentative exact four-path /
1,800-line Darwin and structural follow-up. If its review demonstrates that a fifth
dedicated Darwin test seam is required, that fifth path must be explicitly
re-preflighted before implementation rather than silently exceeding the frozen
scope.
