# Phase D Task 39B2c L3c3c-ii-b5b-iii-b2a-ii-a1-v Review

> Status: complete / non-admitting; iii-b2a-ii-a1 closed
>
> Date: 2026-08-24
>
> Baseline: `72d506de45deccb0cc0d6337b04a8f0e7ad751eb`
>
> Implementation commit: `9556367f4f29fc656d4dd45f90b8a61a2ea35f3c`
>
> Implementation tree: `a66564f527004ea7065b5f6ffeca05a9c12e5fac`
>
> Immutable completion-seal commit:
> `75afc19b36ce92b2f94de1003244ce8ff071f78a`
>
> Seal tree: `019d92fe8128738e0691c18433277a8b3d0a250e`
>
> Next frontier: iii-b2a-ii-a2 App inheritance, protocol and terminal-evidence
> composition

## 1. Result

iii-b2a-ii-a1 is complete. The preceding a1-i checkpoint supplied the fixed
outer-to-inner self-spawn, FD 2/8/9 transport, independent driver-child
observation, bounded framing and one-shot endpoint retirement foundation. This
a1-v closure adds the missing production inner-role validator, exact
source/authority/Mach-O admission and an immutable implementation replay.

The implementation changes exactly seven non-document paths and 1,694 lines
against baseline `72d506d`, plus its preflight document. That remains inside the
seven-path / 2,400-line ceiling. The later seal changes only the existing Swift
boundary test and two verifier scripts. It binds the exact implementation
commit, parent, tree, eight changed paths and 1,694 non-document lines, and it
executes a real same-path substitution negative control for every implementation
path.

This checkpoint remains package-only, Debug-only where it owns dormant Darwin
authority and non-admitting. It cannot construct an admitted physical result,
continuity proof, product receipt or readiness verdict.

## 2. Closed Contract

- The inner role accepts only one-element argv, root driver identity,
  `PID == PGID`, the expected direct parent and a stable identity sandwich.
- FD 0, 1 and 7 must be absent with exact `EBADF`; FD 2, 8 and 9 must be open,
  pairwise distinct at both descriptor and underlying-node levels, and no other
  descriptor in `0...9` may be open.
- FD 8 must be a connected `AF_UNIX` stream socket with `O_RDWR`; FD 9 must be
  an `S_IFIFO` pipe with `O_WRONLY`; FD 2 must remain writable and unchanged
  before and after all validation. FD 2/8/9 must have `FD_CLOEXEC` cleared in
  the child.
- The validator observation is package-only and non-`Codable`; it carries no
  reusable descriptor, path, command, signal, admission or cleanup authority.
- All contradictory or unavailable observations fail before control/result I/O.
- The complete session and its sole production observer compile only under
  `#if DEBUG`. Release retains the exact pre-a1-v symbol/import projection and
  contains none of the new spawn/socket/write/session/observer authority.

## 3. Verifier and Review Closure

The semantic verifier rejects fixed-path/argv, closed-descriptor, CLOEXEC,
connected-Unix, node-alias, identity-sandwich, bounded-framing, shared-
retirement, public-surface, `Codable` and vacuous-test mutations. The focused
inner-role matrix independently covers 34 descriptor, identity and topology
mutations.

The initial artifact gate exposed dormant observer symbols in Release. The
implementation did not widen the Release allowlist; it moved the observer and
session behind the same Debug-only boundary. Fresh Release projection returned
to its prior exact hashes and contains zero new authority symbols.

The first implementation review found no unresolved P0-P2. One supplementary-
group suggestion to restrict root-stage supplementary groups to exactly `[0]`
was rejected against ADR 0018 and the accepted pre-drop identity contract: this
checkpoint observes root before the later independent
`initgroups -> setgid -> setuid` transition, so the proposed restriction would
contradict the approved lifecycle model. The separate seal review also found no
unresolved P0-P2.

Before sealing, the verifier labels for eight same-path substitutions were
placeholders. A controlled temporary-index reproduction proved that an appended
line in the session path was incorrectly accepted with exit `0`. The seal fixes
that P1 evidence gap by starting from implementation tree
`a66564f527004ea7065b5f6ffeca05a9c12e5fac`, replacing each path independently
and requiring the exact `iii-b2a-ii-a1-v completed tree drifted` rejection.

## 4. Verification Evidence

| Gate | Result |
| --- | --- |
| exact implementation scope | 7 non-document paths / 1,694 changed lines; 8 paths including preflight |
| focused outer/inner suite | 9 tests / 1 suite passed |
| inner-role mutation matrix | 34 cases passed |
| adjacent Darwin selection | 60 tests / 4 suites passed |
| affected Investigation selection | 603 tests / 45 suites passed |
| `scripts/verify-contract` | passed, including semantic mutations, a1-i replay and eight real same-path substitutions |
| `scripts/verify-investigation-boundaries` | passed, including exact Debug/Release package projections |
| `scripts/verify-app-release-boundaries` | passed, including Debug positive and Release/App/helper negative controls |
| Xcode Debug Machine Driver build | passed |
| Xcode Release Machine Driver build | passed |
| frozen staged-only serial regression | 1,485 tests / 78 suites passed; 113.690 seconds |
| implementation and seal review | no unresolved P0-P2 |

The serialized regression and build/binary gates apply to implementation tree
`a66564f527004ea7065b5f6ffeca05a9c12e5fac`. The later seal changes no product
source; its dedicated Swift test and complete `scripts/verify-contract` replay
passed. Coverage was skipped because this non-diff verifier/test-infrastructure
maintenance has no repository coverage threshold and Swift line coverage would
not measure the shell/Git-index tamper contract.

No authoritative full was run. The accepted validation funnel deliberately
uses one serialized regression for the implementation tree and does not repeat
it for documentation or seal-only changes.

## 5. Non-Claims and Next Step

iii-b2a-ii-a1 did not launch the installed App/helper/XPC, install anything,
use root or sudo, drive the canonical supervisor exchange through an App, call
Codex, authenticate, use a model or network, accept ADR 0018, mint machine
readiness or enable production Deep Dive. The real authenticated Codex App
Server run remains exclusive to L3c3d; L3c4 still exclusively owns final
admission and Task 39's remaining authoritative full verifier.

iii-b2a-ii-a2 now owns App process-group inheritance, complete canonical
request/ownership/acknowledgement/decision/result driving, helper continuity and
the outer terminal-evidence composition. The strict remaining order is:

```text
iii-b2a-ii-a2 -> iii-b2b -> ii-c0b -> ii-c -> L3c3d -> L3c4
```

Task 39 therefore remains incomplete, ADR 0018 remains Proposed and production
Deep Dive remains `.implementationUnavailable`.
