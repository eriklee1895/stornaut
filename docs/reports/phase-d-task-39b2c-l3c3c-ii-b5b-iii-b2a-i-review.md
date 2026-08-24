# Phase D Task 39B2c L3c3c-ii-b5b-iii-b2a-i Supervisor Admission Review

> Status: complete / non-admitting
>
> Date: 2026-08-24
>
> Baseline: `79cc78c5f1169faa0820a6377a0d512e2034b0ef`
>
> Implementation commit: `2f3a116be4644829fc513bcc2287c6bd2a1ea0ec`
>
> Implementation tree: `dbe8e06f3e0c5bfb96e383348a0b870b8d7dad5f`
>
> Post-review closure commit: `6f6579834b3f5a707ab7b35152e5425e4260c6ad`
>
> Accepted implementation tree: `62994279cc5a262dee3a490d845dc2f32a8fa4b6`
>
> Immutable completion-seal commit:
> `30ee32e02fd1ce5fe45a55f64f083f9294c85695`
>
> Seal tree: `5da28b05a639e7edd12e9eea74a0c77460b9941b`
>
> Next frontier: iii-b2a-ii-a Darwin physical session composition

## 1. Result

iii-b2a-i closes the package-only canonical supervisor protocol and the sole
opaque admission seam between the iii-b2a0 physical DTO and the existing
single-epoch continuity join. It defines canonical request, ownership,
acknowledgement, decision and result messages; consumes every receiver state
one-shot; and makes replay, reordering, cancellation or foreign evidence
terminally uncertain rather than retryable.

The original implementation changed exactly ten non-document paths and 3,236
lines. Independent review then identified four protocol and two verifier
findings. Because adding their tests and negative controls to the original
review surface would exceed its 3,600-line ceiling, the correction was frozen
as a separate r1 checkpoint: exactly eight non-document paths and 977 changed
lines. The final three-path / 76-line seal replays both immutable checkpoints,
their exact identities, scopes and same-path substitution failures. The net
baseline-to-seal implementation remains exactly ten non-document paths and
4,139 changed lines.

This checkpoint is non-admitting at the product and machine levels. Its
file-private admitted token can be minted only by the validated package actor;
a decoded physical DTO cannot construct that token, a single-epoch result, a
containment proof or a continuity proof by itself.

## 2. Implemented Contract

- Canonical package-closed request, ownership, acknowledgement, decision and
  result transcripts use distinct domains, strict field order and bounds,
  canonical nested re-encoding and exact EOF.
- The receiver actor consumes its request/ownership/decision/terminal states
  exactly once. Duplicate, concurrent, replayed, reordered, cancelled or
  mismatched traffic leaves no reusable success state.
- Normal admission joins the exact request and ownership bytes, independent
  inner/App identity and process-group observations, the outer-created absolute
  deadline, response/control EOF, expected termination and absence/reap
  evidence, and identical initial/inner/final driver-observation digests.
- Parent-crash admission requires the corresponding crash decision, zero result
  bytes and the stricter terminal evidence for that scenario.
- There is exactly one private admitted-token minting call site. Raw physical
  DTOs expose no self-admission or continuity conversion API.
- Generic containment proof construction rejects admitted physical results.
  The admitted-only proof binds the same private admission owner and exact
  terminal digest, and the completion join verifies that binding.
- The physical composer validates and uses the outer-created deadline rather
  than silently deriving a second inner deadline. Actor state is revalidated
  after every composer suspension before success can escape.

## 3. Review Corrections

The tests-first r1 closure reproduced and fixed all six independent findings:

1. all five iii-b2a-i source inputs are now covered by the App authority gate;
2. the contract verifier mutation-tests every App-gate source and raw-DTO
   admission boundary;
3. the transcript cap accepts the maximum valid configuration and every local
   encoding failure consumes actor state terminally;
4. normal admission requires the inner driver-observation digest to match both
   independent outer observations;
5. a composer result cannot escape after another task terminalizes the actor;
6. a foreign generic prover cannot seal an admitted result without its private
   owner and terminal digest.

The source authority scan uses Swift parser output rather than raw text, so
harmless comments and string literals remain valid while real calls, including
calls hidden in string interpolation, are rejected. Final post-fix and seal
review reported no unresolved P0-P2.

## 4. Verification Evidence

| Gate | Result |
| --- | --- |
| original implementation scope | 10 non-document paths / 3,236 changed lines |
| r1 closure scope | 8 non-document paths / 977 changed lines |
| immutable seal | 3 paths / 76 changed lines; exact commit/tree/scope/substitution replay passed |
| focused outer/inner suite | 12 tests / 1 suite passed |
| adjacent bridge/continuity suites | 35 tests / 3 suites passed |
| affected Investigation suite | 593 tests / 44 suites passed |
| `scripts/verify-contract` | passed, including implementation/r1 immutable replay and App-gate mutations |
| `scripts/verify-investigation-boundaries` | passed |
| `scripts/verify-app-release-boundaries` | passed, including harmless-text controls and interpolation rejection |
| Xcode Debug Machine Driver build | passed |
| Xcode Release Machine Driver build | passed |
| frozen accepted-tree serial regression | 1,475 tests / 77 suites passed; 92.401 seconds test time; 94.559 seconds complete step |
| independent post-fix and seal review | no unresolved P0-P2 |

The serialized regression and build/boundary gates apply to accepted
implementation tree `62994279cc5a262dee3a490d845dc2f32a8fa4b6`. The later
completion seal changes only boundary tests and verifier replay; its dedicated
test and complete `scripts/verify-contract` run passed. No duplicate full or
serialized run was used as a documentation proxy.

## 5. Non-Claims and Next Step

iii-b2a-i performed no Darwin process spawn, descriptor I/O, App/helper/XPC
launch, installation, root or privileged operation, model call, authentication,
network operation, public driver entry, product admission or authoritative full
verifier. It proves no fixed-path executable launch, FD 2/7/8/9 inheritance,
collision-safe relocation, physical PID/PGID observation, App group inheritance,
direct-child reap, bounded drain, exact-group TERM/KILL, reap-last or post-reap
empty state.

Those physical lifecycle obligations remain in iii-b2a-ii-a. The strict
remaining order is:

```text
iii-b2a-ii-a -> iii-b2b -> ii-c0b -> ii-c -> L3c3d -> L3c4
```

ADR 0018 remains Proposed until ii-c succeeds. Only L3c4 may claim machine
readiness and consume Task 39's remaining authoritative full verifier. Task 39
therefore remains incomplete, and production Deep Dive remains
`.implementationUnavailable`.
