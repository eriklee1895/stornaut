# Phase D Task 39B2c L3c3c-ii-c0a Projection-in-Capsule Preflight

> Status: scope and contract frozen; implementation not started
>
> Date: 2026-08-23
>
> Baseline: `326c7d576d89236c18de61f39b18cc66b0f438d9`
>
> Scope: package-only projected-cohort binary contract and fixed intake only;
> no producer, product composition, launch, authentication, model, root or
> readiness work

## 1. Decision

A dependency inversion blocks the previously documented order. The accepted v1
`InvestigationCohortCapsule` epochs carry opaque configuration bytes and binding
digests, but not the complete `InvestigationInstalledL2IdentityProjection` that
the typed single-epoch composer requires. The root Machine driver may not decode
product configuration JSON to reconstruct that projection. The newer
[ii-b5b-i exact-path preflight](phase-d-task-39b2c-l3c3c-ii-b5b-i-exact-path-preflight.md)
assigned production projection integration to c0, so ii-b5b-iii cannot safely
compose the artifact until a strict binary carrier exists.

The corrected remaining order is:

```text
ii-c0a projection-in-capsule contract
-> ii-b5b-iii production/artifact composition
-> ii-c0b non-root capsule author + launcher/TTY/FD hygiene
-> ii-c privileged no-model gate
-> L3c3d
-> L3c4
```

This preflight supersedes only conflicting live sequence statements. Historical
reports retain the sequence and evidence true at their checkpoints.

## 2. Preserve v1 and Add One Enclosing Contract

c0a must preserve every accepted v1 `InvestigationCohortCapsule` and
`InvestigationCohortEpoch` byte unchanged. It adds a new package-only,
non-`Codable` strict binary value, provisionally named
`InvestigationProjectedCohortInput`, containing exactly:

1. the canonical encoded existing cohort capsule, unchanged;
2. a projection count equal to `8`;
3. one zero-before-hash whole-input digest; and
4. exactly eight canonical encoded
   `InvestigationInstalledL2IdentityProjection` values in capsule epoch order.

The enclosing type has its own domain-separated `HandoffBinaryTranscript`, fixed
tag order and bounded size. Construction and decode pair each projection with
the corresponding existing epoch row and fail closed unless all four bindings
match exactly:

- `projection.epochUUID == epoch.epochUUID`;
- `projection.configurationNonce == epoch.configurationNonce`;
- `projection.configurationSHA256 == epoch.configurationSHA256`; and
- `projection.signedRuntimeBindingSHA256 ==
  epoch.signedRuntimeBindingSHA256`.

The nested capsule and every projection must independently pass strict decode,
self-digest validation and byte-identical canonical re-encode. The enclosing
input must also byte-identically re-encode after decoding. Its zero-before-hash
whole-input digest commits to the unchanged encoded capsule, declared count and
all eight complete encoded projections. Missing, duplicate, reordered, unknown,
malformed, oversized, noncanonical or digest-drifted fields fail closed.

`InvestigationMachineFixedCapsuleIntake` is updated to decode this enclosing
input and return the internally selected paired epoch plus typed projection. It
still accepts no caller-selected ordinal, scenario or path.

## 3. Explicit Non-Duties

c0a is binary contract/intake integration only, not a producer. It contains no
JSON or product-schema decoder, product configuration path, authentication,
model/provider, root, launcher, App, XPC, network, write, receipt or readiness
behavior. It does not construct a projection from product configuration, author
or seal a capsule file, invoke sudo, or add product membership. Root
DriverSupport receives paired typed values from strict binary intake and never
parses product JSON.

## 4. Frozen Scope and Budget

Exactly eight non-document paths may change, with at most 2,600 total added and
deleted non-document lines:

1. `Sources/StornautInvestigationHandoffContract/InvestigationProjectedCohortInput.swift`;
2. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineFixedCapsuleIntake.swift`;
3. `Tests/StornautInvestigationTests/InvestigationHandoffTransportContractTests.swift`;
4. `Tests/StornautInvestigationTests/InvestigationMachineFixedCapsuleIntakeTests.swift`;
5. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
6. `scripts/verify-contract`;
7. `scripts/verify-investigation-boundaries`; and
8. `scripts/verify-app-release-boundaries`.

No existing capsule source, new target, dependency, product path or generated
fixture is in scope. If implementation cannot fit this exact ceiling, stop and
split before coding.

## 5. Historical Replay Must Be Immutable First

The three verifier scripts are shared mutable infrastructure. Before adding c0a
semantics, implementation must make the completed ii-b0a frame/capsule replay
immutable at `35946583cfb286dd2ac20aab23fe12668f232d83` and freeze the
ii-b5b-ii-d historical replay at
`d89d201448a99281a554d9b3fca00512b4f0c0be`. Each replay reconstructs its
historical tree/files and validates recorded parent/tree/path/mode/budget facts
with checkpoint-specific contracts. Later shared-verifier growth must neither
break nor silently widen historical evidence.

## 6. Tests-First Matrix

Initial tests must be RED because the enclosing projected-cohort type and paired
intake do not exist. Implementation then closes:

| Area | Required cases |
| --- | --- |
| v1 preservation | golden existing capsule/epoch bytes and digest remain byte-identical |
| canonical input | eight ordered projections plus unchanged capsule round-trip byte-identically |
| four-way binding | independent epoch UUID, nonce, configuration SHA and binding SHA mutations fail |
| nested strictness | malformed/noncanonical capsule or projection, bad count/order/tag/length/trailing bytes and nested self-digest drift fail |
| whole-input digest | changing capsule, count or any projection byte invalidates the zero-before-hash digest |
| fixed intake | FD-0 intake returns only the internally selected paired epoch/projection and preserves exact typed values |
| boundaries | new type stays package-only/non-`Codable`; no product schema, authority or product membership enters |
| replay | ii-b0a and ii-d immutable historical replays remain green; current-verifier substitution mutations fail |
| scope | exactly eight paths, correct modes, no deletion/binary diff and at most 2,600 changed lines |

Mutation coverage must remove/reorder the projection list, bypass each binding,
weaken canonical re-encode or either digest, alter accepted v1 bytes, widen a
declaration to public/`Codable`, introduce JSON/path/process/network authority,
weaken either historical replay, add a ninth path or exceed budget.

## 7. Validation Funnel

After tests-first implementation, run: structural scope/dependency/authority/
canonical-byte/replay gates -> focused transport and intake plus affected
Investigation tests -> `scripts/verify-contract` ->
`scripts/verify-investigation-boundaries` ->
`scripts/verify-app-release-boundaries` -> applicable SwiftPM/Xcode Debug and
Release artifact projections -> one clean staged-only serialized SwiftPM
regression -> independent implementation and cross-boundary review with no
unresolved P0-P2.

No authoritative full verifier belongs to c0a. It also performs no App/helper/
driver launch, XPC, sudo/auth, model, network or machine-topology write.

## 8. Deferred Producer and Admission Boundaries

After c0a is green, ii-b5b-iii consumes the paired `epoch.projection` contract
while wiring the existing typed composer into production/artifact composition;
it does not author the input.

ii-c0b owns the actual non-root producer: strict product configuration decode,
projection construction from the already validated configuration and signed
runtime binding, sealed owner-only `0600` capsule authoring, and sudo-shaped
launcher/TTY/FD hygiene. It remains non-root and non-admitting. If its fresh
scope/cost preflight exceeds the repository limit, split c0b before coding.

ii-c alone owns the privileged no-model machine gate and possible ADR 0018
acceptance. L3c3d owns the authenticated model candidate. L3c4 alone owns
readiness and the remaining authoritative full verifier. Task 39 remains
incomplete and production Deep Dive remains unavailable.
