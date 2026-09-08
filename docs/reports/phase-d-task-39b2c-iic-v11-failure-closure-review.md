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
validity or exact root-cause claim.

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

## Validation

- focused post-fix selection: 6/6 passed;
- affected campaign evidence/harness/target-boundary suites: 152/152 passed;
- complete `scripts/verify-investigation-boundaries`: passed, including
  authority-closed Debug/Release MachineDriver rebuild and symbol projection;
- v9/v10/v11 independent external-evidence verifiers: 3/3 passed read-only;
- ii-c-c failure/source, evidence-verification source and deadline contracts:
  passed;
- ii-c-b2a2 independent verifier mutation contract: passed;
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
