# Phase D Task 39B2c L3c3c-ii-b5b-iii-b2a0 Typed Physical Bridge Review

> Status: complete / non-admitting
>
> Date: 2026-08-24
>
> Implementation commit: `65f85c5adbb01b41b1bf9a5f787951f9feb4660d`
>
> Parent: `7c114e09c915e2685545872101e7c5854ce2cffd`
>
> Implementation tree: `7df0d5597f498e3588823885d226bdd02befc058`
>
> Immutable completion-seal commit:
> `3f62678306d982edf986acf8a2ef12c3c4081741`
>
> Next frontier: iii-b2a Darwin outer/inner physical adapter

## 1. Result

iii-b2a0 closes the package-only typed bridge between the iii-b1 injected
cohort and the future iii-b2a Darwin outer/inner physical adapter. It preserves
the exact predecessor transcript and digest already owned by continuity, issues
one immutable selection-bound invocation, and defines strict canonical physical
ownership/completion result bytes without weakening the existing opaque local
proofs.

The accepted implementation changes exactly eight non-document paths and 2,198
lines against the frozen parent: 2,150 additions and 48 deletions. This remains
inside the eight-path / 2,200-line ceiling. The completion seal replays the exact
implementation commit, parent, tree, path set, line count and same-path
substitution failures.

This checkpoint is non-admitting. A decoded physical result is an untrusted DTO,
not an `InvestigationMachineSingleEpochResult`, continuity proof, containment
proof, execution authority, readiness receipt or product admission.

## 2. Implemented Contract

- `InvestigationMachineSingleEpochInvocation` is package-only, `Sendable`,
  `Equatable` and non-`Codable`. It binds the exact selected epoch, canonical
  predecessor transcript, predecessor SHA-256 and complete prior helper identity
  for a successor. Genesis and successor use distinct transcript domains.
- Invocation decoding requires the expected selection, exact field order/count/
  lengths, exact EOF, canonical re-encoding, transcript hash equality, cohort
  identity, ordinal continuity, non-reused epoch identity and complete helper
  equality.
- The predecessor remains the sole continuity source. It creates the invocation
  only after its existing one-shot selection consume succeeds. Concurrent or
  repeated sender-side issuance therefore has exactly one winner.
- The composing protocol receives the full invocation. Its default adapter
  preserves existing in-process composers by forwarding only the prior helper; a
  physical composer must explicitly override the invocation requirement.
- `InvestigationMachineSingleEpochPhysicalResult` has separate ownership and
  local-completion domains. It binds outer attempt, whole capsule/input, exact
  epoch/scenario/projection, complete App/helper identities, claim and installed-
  L2 digests, deadlines and the applicable release/driver/local-completion
  digests. All identity, digest, deadline, canonical-byte and scenario mutations
  fail closed.
- A local opaque result may project canonical physical bytes. Decode deliberately
  cannot recreate the private ownership, release, retirement, driver-observation
  or local-completion proof objects. The DTO exposes no conversion into
  `InvestigationMachineSingleEpochResult`,
  `InvestigationMachineCompletionMaterial` or the continuity join.

iii-b2a must therefore bind the exact request bytes, ownership acknowledgement,
exact response bytes, independently observed child/peer identity, EOF and
terminal evidence before one private call site may mint an opaque admitted token.
Receiver-side replay rejection belongs to that iii-b2a state machine; iii-b2a0
does not claim it merely because sender-side issuance is one-shot.

## 3. Verification Evidence

| Gate | Result |
| --- | --- |
| exact implementation scope | 8 non-document paths / 2,198 changed lines passed |
| focused bridge suite | 6 top-level tests / 10 parameterized cases passed |
| combined bridge + continuity + cohort selection | 36 tests / 3 suites passed |
| affected Investigation selection | 580 tests / 43 suites passed |
| `scripts/verify-contract` | passed, including semantic, replay, exact-scope and immutable-seal mutations |
| `scripts/verify-investigation-boundaries` | passed, including package/source and Debug/Release Machine Driver projections |
| `scripts/verify-app-release-boundaries` | passed, including App and final-artifact authority boundaries |
| clean staged-only serial regression | 1,462 tests / 76 suites passed; 93.860 seconds test time; 151.805 seconds complete step |
| Xcode Debug diagnostic build | passed in 29.6 seconds |
| Xcode Release Machine Driver build | passed in 19.2 seconds |
| independent post-fix review | semantic, verifier and cross-group review found no unresolved P0-P2 |

The clean staged-only serial and applicable boundary/build gates used the exact
implementation tree `7df0d5597f498e3588823885d226bdd02befc058`. Coverage was
skipped because this workflow has no repository coverage threshold and the
configured `utree` coverage parser does not support Swift. This does not replace
the focused, combined, affected, serialized, mutation or artifact evidence.

## 4. Review and Seal Closure

Tests-first work began with the expected compile failure for the absent typed
bridge. Semantic review then found an impossible predecessor-UUID acceptance
window. Later post-fix review found three P1 false-authority, replay and verifier
gaps. The final implementation closes all four issues by validating predecessor
identity relationships, preserving the DTO/admission separation, enforcing
one-shot sender issuance and sealing every implementation path plus the preflight
against same-path substitution. Final semantic, verifier and cross-group review
reports no unresolved P0-P2.

The accepted implementation identity is:

- commit `65f85c5adbb01b41b1bf9a5f787951f9feb4660d`;
- parent `7c114e09c915e2685545872101e7c5854ce2cffd`;
- tree `7df0d5597f498e3588823885d226bdd02befc058`; and
- immutable seal `3f62678306d982edf986acf8a2ef12c3c4081741`.

## 5. Non-Claims and Next Step

iii-b2a0 ran no authoritative full verifier, root operation, installed App or
helper, real XPC, model, authentication or network flow. It launched no product
process and performed no real Codex App Server run on 2026-08-24. It proves no
Darwin FD 8/9 transport, inner-led PGID, child/peer observation, EOF/terminal
join, receiver-side replay rejection, installed topology, machine readiness or
product availability.

ADR 0018 remains Proposed, Task 39 remains incomplete and production Deep Dive
remains `.implementationUnavailable`. The current checkpoint is iii-b2a. The
remaining order is:

```text
iii-b2a -> iii-b2b -> ii-c0b -> ii-c -> L3c3d -> L3c4
```

Only a green ii-c may accept ADR 0018. Only L3c4 may claim machine readiness and
consume Task 39's remaining authoritative full verifier.
