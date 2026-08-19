# Phase D Task 39B2c-L3c3c-ii-b2a Typed Escrow/Deadline Review

> Status: Complete; non-connected Lifecycle-internal typed deadline/state
> primitive, structural admission, one combined staged serial and independent
> final review passed; non-admitting
>
> Date: 2026-08-19
>
> State/test commit: `7a25e5e`
>
> Pushed combined baseline: `bc9eddaf943ce006c1c9824dfb2e2d12cf35440c`
>
> Structural admission commit: `ec153e8`
>
> Combined validation snapshot: `bcb48e7fc39f0da6162d72af96032a0ed82a161d`
>
> Combined accepted tree: `1722b24fedd13be18764a984e500906f034d89df`
>
> Scope: pure package-scoped state/effect core and tests plus structural
> verifiers; no current escrow replacement, shared wire dependency,
> XPC/helper/Machine/App behavior, physical scheduler/exit, product graph,
> install, privilege, model/auth, readiness or full verifier

## 1. Outcome

L3c3c-ii-b2a is complete. The new Lifecycle-internal primitive freezes the
claim/release/post-reply deadline lifecycle before live integration:

```text
empty
-> claim pending/armed
-> release pending/armed
-> released awaiting reply dispatch
-> post-reply exit pending/armed
-> terminal
```

The core returns typed schedule/cancel effects but does not execute them. It owns
one lock-linearized state, exact ticket kind/generation/reservation/deadline
identity, stale-arm cleanup, checked wall/monotonic arithmetic, replay/binding
failure and immutable terminal results. The future adapter executes every effect
outside the core lock.

Release acceptance freezes the post-reply deadline from `releaseAcceptedNow`;
the reply closure must return before `replyDidDispatch`, which only arms the
retained deadline and can never extend it. Handle/config wall validity is mapped
once to a retained monotonic cap and also rechecked as a fresh cap, preventing
clock rollback from extending authority while forward jumps shorten it. Claim
request issued-at/valid-before is checked independently with the exact fifteen-
second maximum and is consumed after claim acceptance.

## 2. Scope, Cost and Artifact Identity

The combined implementation changes exactly the four approved non-document
paths:

1. `Sources/StornautLifecycle/LifecycleMachineRetirementEscrowDeadlineState.swift`;
2. `Tests/StornautLifecycleTests/LifecycleMachineRetirementEscrowDeadlineStateTests.swift`;
3. `scripts/verify-investigation-boundaries`;
4. `scripts/verify-contract`.

The mandatory budget split produced:

- a-i source/tests: 1,858 added lines, below 1,900;
- a-ii verifier scripts: 413 added-or-changed lines, below 700;
- combined: 2,271 added-or-changed lines, below 2,600.

The one serial snapshot has parent `bc9edda`, exactly the pushed a-i tree plus
docs-only validation status. Its tree `1722b24f...` equals the staged a-ii tree
and the final combined implementation tree. The index contained only the two
verifier scripts and had no unstaged non-document drift.

## 3. Prompt-to-Artifact Completion Checklist

| Requirement | Direct evidence | Result |
| --- | --- | --- |
| closed one-shot state | normal transition test plus terminal/replay/cancel tests | satisfied |
| three pending-arm states | normal path and callback-before-arm tests | satisfied |
| stale arm success cleanup | late arm returns one exact cancel; stale arm failure preserves record | satisfied |
| pending versus armed early callback | pending records late cancel; all three armed kinds self-cancel | satisfied |
| release/post-reply windows | exact five-second constants and epoch/handle minimum tests | satisfied |
| reply ordering | release creates no ticket; replyDidDispatch uses retained deadline only | satisfied |
| wall/request truth | retained/fresh caps, rollback, forward jump, tick and exact 15-second tests | satisfied |
| checked arithmetic | time, generation zero/max, claim/reply generation overflow tests | satisfied |
| replay/binding failure | duplicate claim/release/reply and every release binding axis terminal | satisfied |
| race linearization | sixteen concurrent claims plus eight deterministic two-order race outcomes | satisfied |
| package-only adapter surface | all future adapter declarations are package; internals remain private | satisfied |
| no authority | Foundation-only, no Codable/XPC/Dispatch/Task/filesystem/process/Security/Policy/Executor | satisfied |
| no live consumer | sole source owner; product/helper/Machine/DriverSupport/App references absent | satisfied |
| graph unchanged | Lifecycle dependency remains exactly CLifecycleSupport; protected blobs match baseline | satisfied |
| verifier anti-spoofing | scoped lexical checker plus six exact-diagnostic mutations | satisfied |
| exact four paths and budgets | executable baseline/path/blob/budget gate | satisfied |
| combined serial identity | snapshot parent/tree and current combined tree exactly match | satisfied |

No completion row relies on the serialized regression alone. Behavior, graph,
authority and verifier integrity each have direct artifact evidence.

## 4. Validation and Review

| Gate | Result |
| --- | --- |
| tests-first RED | missing typed deadline-state APIs produced expected compile failure |
| focused state suite | 19/19 passed |
| complete Lifecycle affected suite | 167 tests in 17 suites passed |
| focused coverage | 55/55 functions; 907/928 lines, 97.74%; 184/212 regions, 86.79% |
| fast deadline-state contract | exit 0 |
| `scripts/verify-contract` | exit 0; six mutations matched exact diagnostics |
| full `scripts/verify-investigation-boundaries` | exit 0; Debug/Release Machine binary gates included |
| sole combined staged serial | 1,162 tests in 57 suites passed |
| serial test / stage time | 82.377 / 122.815 seconds |
| snapshot identity | `bcb48e7` parent `bc9edda`, tree `1722b24f...` |
| final independent audit | no unresolved P0-P2 |

The lexer removes line comments, nested block comments and ordinary/triple
strings; regex literals/Regex/RegexBuilder are forbidden. Declaration checks are
attribute/modifier-aware. The six negative fixtures cover comment-only markers,
stale arm failure cleanup, armed-early self-cancel removal, reply deadline
extension, regex-only marker spoofing and attributed-public exposure, and each
must fail for its exact diagnostic.

## 5. Safety Boundary and Next Gate

ii-b2a completes only the typed state/deadline primitive. The current live
`LifecycleMachineRetirementEscrow`, Lifecycle XPC, helper main, Machine claim,
old JSON reply and unconditional helper deadline behavior are unchanged. No
physical timer, reply closure, helper exit or helper disappearance was executed
or observed.

ii-b2b is next. It must add the dedicated server-side shared-wire-to-Lifecycle
adapter and migrate the live escrow/XPC/helper/Machine server path, while leaving
ii-b4 as the sole fixed NSXPC client owner and keeping the adapter absent from
ordinary App and native DriverSupport/Mach-O.

The whole ii-b2 remains incomplete. ADR 0018 remains Proposed, Task 39 remains
incomplete, production Deep Dive remains unavailable, real Trash remains closed
and L3c4 exclusively owns readiness and the remaining authoritative full
verifier.
