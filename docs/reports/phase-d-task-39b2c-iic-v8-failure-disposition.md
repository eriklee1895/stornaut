# Phase D Task 39B2c ii-c-c v8 failure disposition

> Status: verified consumed failure / non-admitting / non-retryable
>
> Date: 2026-09-05
>
> Frozen campaign: `64473a10-abfd-4a03-872b-eac1e1262242`
>
> Frozen attempt: `68c1b0e0-c609-4ff1-b468-b0b443753fa9`
>
> Historical status note: the user later authorized one fresh replacement v9;
> this does not change any v8 fact or permit v8 reuse.

## Result

The v8 privileged attempt is conclusively disposed as
`consumedTransportLoss`. Its durable event chain is exactly:

```text
prepared -> armedConsumed -> spawnUncertain
```

The third event records `campaign-incomplete`. The event sequence, attempt UUID,
strict payloads, monotonically increasing timestamps, prior-event SHA-256 links
and common evidence-set digest all validate. Because `armedConsumed` is durable,
the attempt cannot be retried.

This result does not admit ii-c, ADR 0018, L3c3d, L3c4, Task 39 or production
Deep Dive.

## Preserved evidence

The checked disposition binds the exact SHA-256 of the eight files that exist:

- source/build identity;
- installed identity;
- policy probe;
- human attestation;
- no-auth/model/network counters; and
- three attempt events.

The source evidence binds commit `a8963c44ab0a6a0db5331376c3e84c14b88ca453`,
tree `4ed7c6b2256b1f0554ca6837e24988d932430823`, the original pre-arm frame and
the original build/runtime digests. The human attestation says no credential
prompt or human credential action was observed, with zero retained credential
bytes. Auth, model and network invocation counts are all zero.

The checked disposition is
[`task-39-iic-v8-failure-disposition.json`](evidence/task-39-iic-v8-failure-disposition.json).
It contains hashes and identities only; it does not embed private paths or raw
credential/model content.

## Missing admission evidence

The verifier requires all of the following to remain absent:

- `manifest.bin`;
- external `seal.json`;
- coordinator and diagnostic output;
- uninstall evidence;
- global post-teardown evidence; and
- final verification input.

Their absence is evidence of an incomplete failed attempt, not evidence of
successful teardown. They cannot be reconstructed or appended after the fact.
The normal machine admission verifier consequently continues to reject v8.

## Current-system recovery observation

The read-only disposition verifier separately observed the current machine and
found no fixed Stornaut install root, launchd plist, runtime root, registered
fixed service or fixed Stornaut App/helper/driver/Gate/coordinator process. The
same-UID Gate base contains only its independently retained `.owner-lock-v1`
inode and no `attempt-*` or capsule entry.

This is a current recovery observation. It is deliberately not written into v8
and cannot substitute for v8's missing durable uninstall/global-teardown
artifacts.

## Verification contract

`scripts/verify-investigation-runtime-machine-failure` is a self-sealed,
read-only verifier separate from the success admission verifier. It uses exact
canonical paths, descriptor-relative no-follow reads, strict owner/mode/link
checks, canonical Foundation JSON round trips, canonical transcript decoding,
artifact hashes and live fixed-topology observation. It has no file-write,
install/uninstall, signal, process-termination, model, network or admission
authority.

Five focused failure-disposition tests prove that it accepts the exact failure
shape and rejects event tampering, unexpected completion artifacts, any
disposition that claims admission, path aliases and caller-controlled `HOME`
substitution. The checked v8 integration test snapshots the external evidence
tree before and after verification to prove the verifier did not modify it.

## Task 39 disposition and successor

L3c3d's authenticated real-model success and L3c4's sealed readiness both
depend on a green installed three-plane machine cohort. v8 cannot supply that
cohort. The later v9 authorization does not change that result. Until v9 is
green, those readiness conditions remain unproven.
No local implementation work may reinterpret this disposition as success.

The v8 gate is closed as `blocked/no-go`, but Task 39 itself remains incomplete.
The remaining final full is intentionally not run because its L3c4 precondition
is absent. Under the approved sequential plan, Task 40 remains blocked until a
Task 39 Ready baseline exists or the user explicitly approves a plan amendment.
Task 44 remains the only gate that may remove `.implementationUnavailable`, and cannot
do so without a newly authorized, fresh successful machine cohort.
