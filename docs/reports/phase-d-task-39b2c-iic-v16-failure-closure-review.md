# Phase D Task 39B2c ii-c-c v16 failure-closure review

> Status: complete / non-admitting
>
> Date: 2026-09-13
>
> Baseline: `9bc6d8d879bcae500137879b8ad5080d72f136ca`
>
> Campaign: `469fd1d1-f9fd-4a3c-a0e6-f72f586f5e72`
>
> Attempt: `fa83c861-a7e2-4903-bf64-9eb08c757f74`

## Outcome

The one authorized v16 campaign is durably consumed, rejected and
non-retryable. Its checked schema-v9 disposition binds all nine raw artifacts,
the exact four-event hash chain, source commit/tree, zero capability invocation
counts, zero retained credential bytes, one-shot launcher sidecars, current
fixed-runtime absence and the exact dual persistent-Gate state containing the
retained v13 and consumed v16 attempts.

The explicit four-argument joint verifier keeps schema-v8's historical
single-snapshot semantics unchanged. A standalone v13 replay now fails closed
because the Gate has legally advanced. The joint path cross-binds the frozen v13
disposition and its retained attempt/capsule to schema v9, then holds both
evidence trees, both reports, all phase and raw-artifact descriptors, all
launcher-sidecar descriptors and the dual Gate descriptors through the final
identity/digest/watch revalidation. It closes them only after the verdict.

The v16 closed reason remains
`postArmFailure/receiptInvalid/exited-82/receipt-eof/terminal-eof/cleanup-02`.
Exit 82 maps to driver `containmentUncertain`; cleanup mask `02` maps only to
outer `.terminateFailed`. The evidence preserves no termination errno or exact
mechanism. The exact-driver AMFI `-423` log is retained only as a non-causal,
non-campaign-bound supplemental observation and is not used for credential
validity or admission.

## Scope and review fixes

The final checkpoint changes exactly five non-document paths and 1,291
non-document lines, below the 14-path / approximately 4,000-line split gate.
It contains no production runtime or authority change.

Independent review found and closed:

- P1: predecessor raw-artifact and launcher-sidecar descriptors were initially
  released before the joint verdict. The final implementation holds and
  revalidates every relevant descriptor/watch through the verdict; a regression
  proves in-place raw and sidecar mutation is rejected.
- P2: the report initially named possible termination errno/mechanisms not
  preserved by the evidence. The final report states only `.terminateFailed` and
  explicitly says errno/mechanism are unknown; the structural contract forbids
  the removed speculative phrases.

Both independent post-fix reviewers reported no unresolved P0–P2.

## Validation

- shell syntax, diff whitespace and both verifier self-seals: pass;
- failure-disposition structural contract: pass;
- canonical v16 standalone read-only replay: pass;
- canonical v13 → v16 joint read-only replay: pass;
- `InvestigationMachineCampaignEvidenceTests`: 109 tests, 0 failures;
- `InvestigationMachineTargetBoundaryTests`: 64 tests, 0 failures;
- `scripts/verify-contract --iic-c-contract-only`: single exit 0.

No `sudo`, root action, privileged campaign, model/auth/network call or
authoritative full verifier was run during this closure. The v16 campaign was
not retried.

## Remaining gate

This checkpoint is evidence closure only and is non-admitting. The next work is
a tests-first diagnosis and repair of the driver status-82 entry failure and the
secondary termination diagnostic. A later privileged replacement campaign
requires a new pushed repair checkpoint and fresh explicit user authorization.
L3c3d, L3c4, Task 39 readiness, Task 40 and production Deep Dive remain blocked.
