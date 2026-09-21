# Phase D Task 39B2c ii-c-c v11 failure closure review

> Status: complete / non-admitting
>
> Date: 2026-09-08
>
> Executed campaign source: `8a286ea41d73b0874c6775cc6f79736f972782fe`

## Result

The authorized v11 privileged campaign is consumed, non-admitting and
non-retryable. Its durable event chain is `prepared → armedConsumed →
spawnUncertain → terminal`, it produced no epoch or completion artifacts, and
the fixed installed runtime is absent. The checked schema-v6 disposition binds
the nine retained artifacts, exact timeline, source identity, current v11 Gate
capsule and zero credential-retention attestation. It makes no credential
validity, campaign-exit-status or exact root-cause claim.

The legacy v11 event recorded only `campaign-incomplete`. Successor source now
projects the harness primary failure, exact POSIX wait result, receipt EOF,
terminal EOF and the five defined cleanup issues into a closed schema-v2
`spawnUncertain` reason. Historical schema-v1 bytes remain readable. The
Swift validator and both independent Python verifiers require one canonical
form, exit status 0...255, signals 1...31 and cleanup mask 0x00...0x1f.

The v9 and v10 current dispositions now bind the preserved v11 Gate residue;
byte-identical before-v11 snapshots preserve their earlier receipts. No
campaign evidence root was rewritten.

## Review closure

Independent review found and closed four issues:

- non-producible wait/cleanup values were initially accepted by schema v2;
- decimal wait values initially admitted non-canonical leading zeros;
- schema-v4 initially did not enforce the exclusive choice between its own
  preserved Gate attempt and a subsequent-campaign observation;
- the completed-but-non-admitting fallback initially projected
  `wait-unavailable/receipt-open/terminal-open` instead of the completed
  result's real wait and EOF observations.

Post-fix review found no unresolved P0–P2.

The resumed closure audit then found and fixed three additional non-admitting
evidence issues before merge: schema-v2 accepted individually valid but
producer-impossible primary/wait/cleanup combinations; the v11 disposition
treated an external launcher exit status as if the nine retained campaign
artifacts proved it; and byte-digest status pins preserved two superseded
frontier statements. Swift and both independent Python verifiers now enforce
the same minimal producer-state implications, the unbound exit status is an
explicit non-claim, and the active status gate checks semantic markers in
addition to file digests. The aggregate contract's historical
staged/worktree-divergence fixture was also corrected to mutate its historical
index blob rather than current HEAD source.

Final frozen-byte review then completed the same producer-state proof across
primary failure, exact wait, receipt/terminal EOF, cleanup bits and event-chain
shape. In particular it closed the remaining `diagnosticOverflow`,
`receiptInvalid`, `unexpectedResponse` and `childTerminated` implications, made
terminal-less schema-v2 failure exclusive to `transportUncertain`, and retained
the valid stopped-then-reaped `childTerminated/exited-0` path. The Python
verifier now also rejects malformed short reasons without leaking an
`IndexError`, and valid two-event pre-arm evidence bypasses the schema-v2
post-arm join. A stale v9-era sentence in the Phase D plan was marked historical
and included in the semantic status gate. Final grouped and cross-group review
found no unresolved P0–P2.

## Validation

- focused post-fix selection: 6/6 passed;
- affected campaign evidence/harness/target-boundary suites: 152/152 passed;
- complete `scripts/verify-investigation-boundaries`: passed, including
  authority-closed Debug/Release MachineDriver rebuild and symbol projection;
- v9/v10/v11 independent external-evidence verifiers: 3/3 passed read-only;
- ii-c-c failure/source, evidence-verification source and deadline contracts:
  passed;
- aggregate `scripts/verify-contract --iic-c-contract-only`: passed;
- ii-c-b2a2 independent verifier mutation contract: passed;
- final grouped runtime/verifier review and cross-group contract review: no
  unresolved P0–P2;
- serialized SwiftPM regression: 1,935 tests / 99 suites completed with one
  pre-existing load-sensitive performance threshold issue; the exact
  `cleanupPlanBuilderStreamsFourThousandRowsAndRetainsLateProfiles` case
  passed on the required isolated rerun in 1.644 seconds. The original serial
  run is not represented as green.

The authoritative full verifier remains reserved for L3c4 and was not run.
No root install, sudo, App launch, model, network or new machine campaign was
performed during this closure. An accidentally reached install prompt from a
historical aggregate contract was immediately cancelled without credential
entry; fixed paths, service and processes remained absent.

## Remaining gate

Task 39 remains active/incomplete. L3c3d still requires a green fresh privileged
cohort, and L3c4 still exclusively owns final readiness and the full verifier.
Task 40 and production Deep Dive remain blocked. Any further machine campaign
requires a new explicit authorization with fresh campaign/attempt UUIDs and a
fresh evidence root.
