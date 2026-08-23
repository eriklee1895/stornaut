# Phase D Task 39B2c L3c3c-ii-c0a Projection-in-Capsule Review

> Status: complete / non-admitting
>
> Date: 2026-08-23
>
> Implementation commit: `c7cab4dc265b4f31826e566a57f44c9f4f364d70`
>
> Parent: `e4a95d4916a55a6bc2854c1b2168c98f7245cd0f`
>
> Tree: `6064cccce400cd07f7ebdc4653a2496c67c83434`
>
> Next frontier: ii-b5b-iii production/artifact composition

## 1. Result

ii-c0a closes the dependency inversion identified by the preflight without
changing the accepted v1 capsule or epoch bytes. A package-only, non-`Codable`
`InvestigationProjectedCohortInput` now encloses the unchanged canonical cohort
capsule together with exactly eight complete
`InvestigationInstalledL2IdentityProjection` values in epoch order. The fixed
FD-0 intake decodes that enclosing value and returns each epoch only with its
bound typed projection through the existing internally ordered, one-shot plan.

The pushed implementation changes exactly eight non-document paths against the
frozen parent: 1,758 additions and 105 deletions, or 1,863 changed lines. This is
within the eight-path / 2,600-line ceiling. It adds no target, dependency,
product producer, public API, runtime authority or admission surface.

## 2. Implemented Contract

- The enclosing binary transcript has its own domain, fixed field order, fixed
  projection count of eight and a 1,069,056-byte upper bound. It embeds the
  canonical encoded v1 capsule unchanged rather than redefining capsule or epoch
  fields.
- A zero-before-hash whole-input SHA-256 commits to the unchanged capsule,
  declared count and all eight complete encoded projections. Decode requires
  exact digest equality and byte-identical canonical re-encoding.
- The nested capsule and each installed-L2 projection pass their existing strict
  decoder, self-digest and canonical encoding rules. Wrong domain/version/tag/
  length/count, malformed or trailing data, nested digest drift and outer digest
  drift fail closed.
- Construction pairs projections with capsule epochs in order and requires exact
  equality for epoch UUID, configuration nonce, configuration SHA-256 and signed
  runtime-binding SHA-256. Missing or reordered projections and any independent
  four-way binding mutation fail.
- `InvestigationMachineFixedCapsuleIntake` still reads only immutable FD 0 with
  the previously sealed ownership, mode, ACL, xattr, metadata and bounded-read
  checks. It now strictly decodes the projected-cohort input and carries both the
  whole-capsule and whole-input digests.
- The actor-owned plan retains one shared, non-replayable cursor. `takeNext()`
  derives the next paired epoch/projection internally and preserves the ordinal/
  scenario check; callers cannot select an ordinal, scenario, projection or path.

Accepted source seals include:

- projected-cohort contract:
  `f60d4f92da42293ff044c29756fc55692ce354035f49b9a3ec415166c89b885a`;
- fixed capsule intake:
  `d4898e6f9196a169d29107a40063238adf52d9fd8842e2bacdf9b433e09c1dd6`;
- contract verifier:
  `048caef6461bea96574ee9cc9759c1bf350819444c1ed799472c841be8082190`;
- Investigation boundary verifier:
  `7e68e8054b6f8b366e986f5cb63b144586183585b477b095f8e2760699883c18`; and
- App release boundary verifier:
  `6509467e0ac5106d1a3bd6a8b5c1f1ffdbd4796fda77f894f1cbb4f79317ea3b`.

## 3. Tests-First and Validation

The focused contract/intake/boundary selection passed 90 tests in six suites.
It covers unchanged v1 bytes, exact count/order, the zero-before-hash rule, all
four binding dimensions, nested and outer strictness, legacy-capsule rejection,
FD-0 provenance, paired typed selection and shared-cursor exhaustion.

The affected Investigation selection passed 536 tests in 40 suites. The clean
same-tree staged-only serialized regression then passed 1,418 tests in 73 suites
with zero failures; test execution took 95.385 seconds and the complete serial
step took 155.713 seconds.

| Gate | Result |
| --- | --- |
| exact eight-path / 1,863-line staged scope and file modes | passed |
| focused contract, intake and boundary selection | 90 tests / 6 suites passed |
| affected Investigation selection | 536 tests / 40 suites passed |
| `scripts/verify-contract` | passed |
| `scripts/verify-investigation-boundaries` | passed |
| `scripts/verify-app-release-boundaries` | passed |
| clean same-tree staged-only serial regression | 1,418 tests / 73 suites passed |
| independent final review | no unresolved P0-P2 findings |

The verifier now reconstructs and checks the immutable ii-b0a commit
`35946583cfb286dd2ac20aab23fe12668f232d83` and ii-b5b-ii-d commit
`d89d201448a99281a554d9b3fca00512b4f0c0be` before applying current c0a
semantics. Mutation coverage rejects substituting current verifier files into
either historical replay, removing replay failure propagation, weakening the
binary contract or bindings, introducing runtime/write/network authority, or
drifting the exact path, mode and line budget.

`scripts/verify --full` was deliberately not run. L3c4 alone owns the remaining
Task 39 authoritative full verifier and readiness decision.

## 4. Review Closure

The independent final implementation/verifier review found no unresolved
P0-P2 issues. In particular, the accepted tree preserves the old wire bytes,
does not let the root-side intake reconstruct product semantics, binds each full
projection before selection and keeps both the new contract and intake free of
producer, launch, authentication, model, network, write and readiness behavior.

## 5. Prompt-to-Artifact Completion Checklist

| Requirement | Concrete artifact or evidence | Result |
| --- | --- | --- |
| Preserve accepted v1 capsule and epoch bytes | unchanged capsule source plus byte-equality transport regression and `iic0a-v1-bytes` mutation | complete |
| Add one package-only, non-`Codable` enclosing input | `InvestigationProjectedCohortInput.swift`, target-boundary test and public/`Codable` mutations | complete |
| Carry exactly eight ordered complete projections | fixed count/field layout, round-trip tests and remove/reorder mutations | complete |
| Bind every projection to its epoch in four dimensions | constructor validation, four focused mutation cases and four verifier mutations | complete |
| Commit the whole input with zero-before-hash SHA-256 | independent digest test plus outer-digest mutation | complete |
| Enforce nested and outer canonical strictness | strict capsule/projection decode, byte-identical re-encode tests and nested/canonical mutations | complete |
| Return only the internally selected epoch/projection pair | `InvestigationMachineFixedEpochSelection`, one-shot actor cursor, intake tests and pairing mutation | complete |
| Preserve fixed FD-0 provenance and bounded intake | legacy intake checks, malformed/legacy input regressions and affected suite | complete |
| Freeze historical shared-verifier evidence | immutable ii-b0a/ii-d replay plus substitution and failure-propagation mutations | complete |
| Exclude producer and runtime authority | source/package checks and JSON/path/process/XPC/write/network/readiness mutations | complete |
| Hold exact scope and budget | commit/parent/tree binding; 8 paths, +1,758/-105, 1,863 changed lines | complete |
| Close regression and review | 90 focused, 536 affected, 1,418 serial and no unresolved P0-P2 | complete |

## 6. Non-Claims and Next Step

This checkpoint did not author a projected capsule from product configuration.
It did not run as root, install or launch an App, invoke XPC, read Codex
authentication, call a model, access the network, execute Trash or run the full
verifier. It therefore makes no claim about privileged execution, installed
topology, real-model success, containment, machine readiness or product
availability.

ADR 0018 remains Proposed, Task 39 remains incomplete and production Deep Dive
remains `.implementationUnavailable`. The next frontier is ii-b5b-iii
production/artifact composition. ii-c0b remains the later non-root capsule
producer/launcher checkpoint; ii-c, L3c3d and L3c4 retain their separately
frozen admission responsibilities.
