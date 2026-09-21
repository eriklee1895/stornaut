# Phase D Task 39B2c-L3c3c-ii-b5a0 Claim-Abort Review

> Status: Complete; same-client claim ambiguity and post-claim abort now prove
> terminal state or return typed uncertainty; non-admitting
>
> Date: 2026-08-21
>
> Implementation commit: `953d14935e9f9a19a303b92d1b6eeeb1b8619f73`
>
> Parent: `ce048e16f5b97de694ccd5928bd940d93950aec1`
>
> Validated implementation tree: `e904766917494fd34f6e3e373478a6ca3ad88054`
>
> Staged validation commit: `c1de3d3a9f0113786d324f08711d6d09e3b41204`
>
> Scope: five non-document paths; no App/helper launch, real XPC, install,
> privilege, model/auth/network, readiness claim or authoritative full verifier

## 1. Outcome

ii-b5a0 is complete. `InvestigationMachineClaimClient` now owns
`claimOrProveTerminal` and `abortAfterClaimAndProveTerminal`. An accepted claim
retains the exact session and evidence. A post-dispatch lost, malformed, unknown
or cancelled reply invalidates that session; without a fully attested exact
helper identity it returns `terminalResidueUncertain`, and with one it accepts
only an explicit pre-deadline absence observation.

Abort is legal only from the retained claimed state and is one-shot with
release. It consumes state before suspension, invalidates the same connection,
sends no release, opens no second connection and completes its terminal proof
in a detached task that does not inherit caller cancellation. Proof uncertainty
overrides the original failure; only successful terminal proof preserves it.
Only raw reason keys that exactly match the closed server enum preserve a typed
server rejection.

## 2. Scope and Identity

The implementation changed exactly five approved non-document paths and 799
added-or-deleted lines: 746 additions and 53 deletions. The ceiling was five
paths / 800 lines. The implementation commit and staged validation commit share
tree `e904766917494fd34f6e3e373478a6ca3ad88054`. Source identities are:

- ClaimClient: `ee373ff00fce08853fccb4c2087a0a47eed2feae6efc300fbd4c74e01f242a0a`;
- `scripts/verify-investigation-boundaries`: `c0a6e82245da95ff562a296366abbead8b8c20bd84d88a6781996787761530d9`;
- raw `scripts/verify-contract`: `03bbbe46abff7bb705ba6ed71e2d40a6ec03915174696b8d6d0afc170dedcd4c`; and
- normalized verifier self-seal: `759cdc62e29bcdb5e56f6e8b237309f270e3c6e79f9d4616e51ee8ed90ef9f12`.

## 3. Validation Evidence

| Gate | Result |
| --- | --- |
| focused claim-client suite | 19 test functions with parameter matrices passed |
| focused boundary group | 21 functions across 2 suites passed before the final exact-case addition; the final cancellation case then passed independently and the complete claim-client suite passed |
| affected Investigation regression | 382 tests in 28 suites passed in 7.065 seconds |
| `scripts/verify-contract` | exit 0; historical b4 tree, fixed b5a0 parent, exact source, alias/string bypass mutations, scope mutations and seals passed |
| full `scripts/verify-investigation-boundaries` | exit 0; authority-closed Debug/Release projections and source boundaries passed |
| independent review | runtime, tests, verifier, code-guard and validation-accounting reviews found no unresolved P0-P2 |

The checkpoint's sole staged-only serial ran once from validation commit
`c1de3d3a9f0113786d324f08711d6d09e3b41204`, tree
`e904766917494fd34f6e3e373478a6ca3ad88054`. It executed 1,281 tests in 61
suites in 121.602 seconds. One pre-existing Surveyor fixture test recorded
three issues; the serial was not green and was not restarted or repeated. The
requested skip names did not match the maximum benchmark test names, so those
benchmarks actually executed and passed; they are not reported as skipped.

The failure was reproduced as a path-sensitive fixture-harness issue specific
to the `/tmp` validation worktree. The fixture script's relative `$0`
repository-root calculation resolved to `/private` and rejected its intended
`/private/tmp` target. ii-b5a0 changed neither that test nor its script. Without
source changes, the exact failed case was rerun from a repository-sibling
worktree at the same commit/tree and passed 1/1. Per repository policy, only the
exact failed case was rerun. The final implementation tree remains exactly the
validated tree. This evidence is deliberately not described as a green or
clean serial.

## 4. Review Repairs

Review closed four material windows: malformed unknown server reasons can no
longer masquerade as known rejection; real claim-server state now proves
acceptance before lost/malformed/cancelled reply tests; proof failure overrides
the original error; and cancellation before entering abort cannot cancel the
detached terminal proof. Verifier review replaced substring-only ownership
checks with an exact canonical ClaimClient seal, executable alias/string
mutations and fixed historical scope parents. Debug/Release exact binary
projections were remeasured and remained free of prohibited authority imports.

## 5. Non-Admission and Next Gate

ii-b5a0 is complete but non-admitting. It did not launch the installed App or
helper, call real XPC, install or mutate system state, use root, call Codex, read
auth, access a network, mint a machine report or run `scripts/verify --full`.
ADR 0018 remains Proposed, Task 39 remains incomplete and production Deep Dive
remains `.implementationUnavailable`. ii-b5a typed/injected composition is the
current frontier; ii-c alone may accept ADR 0018 and L3c4 alone owns readiness.
