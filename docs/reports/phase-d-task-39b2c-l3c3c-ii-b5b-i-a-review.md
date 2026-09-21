# Phase D Task 39B2c-L3c3c-ii-b5b-i-a Projection Contract Review

> Status: Complete; strict installed-L2 identity projection, typed dual-clock
> binding, exact structural gates and independent review passed; non-admitting
>
> Date: 2026-08-21
>
> Implementation commit: `434faecaeae1b7e08472baa2e1462da942326b85`
>
> Parent: `1d8cf284a61d2a728f8ec99bb1b1f29ba0610612`
>
> Validated implementation tree: `95d83534e59547d4511ad00a7419385d3160a687`
>
> Staged validation commit: `2ecc5ffb97343708b5cff5c742da47f557da759b`
>
> Scope: exactly five non-document source/test/script paths; no producer,
> observer, DriverSupport join, App/helper/XPC launch, install, root, model,
> auth, network, readiness claim or authoritative full verifier

## 1. Outcome

ii-b5b-i-a is complete. `StornautInvestigationHandoffContract` now owns a
package-scoped, non-`Codable` binary projection with exactly fifteen canonical
fields, domain separation, canonical re-encoding and a zero-before-hash self
digest. It commits the epoch/configuration identities, wall-clock validity,
configuration and signed-binding digests, fixed App/helper/driver executable
and signing facts, the fixed machine-claim service and its own digest. It
contains no configuration body, path, endpoint, PID, descriptor, token, model,
provider or action authority.

The temporal contract accepts only the strict projection, typed machine-claim
evidence, epoch bootstrap and paired clock samples. It derives all four bounds
from those typed owners, binds projection epoch to bootstrap epoch and claim
investigation identity to the projection configuration nonce, and compares wall
and continuous clocks only within their own domains. Foreign projection/claim/
epoch combinations, rollback and strict expiry fail closed.

This checkpoint adds no projection producer or physical observation. Production
projection creation remains with ii-c0; physical installed-L2 observation and
the DriverSupport join remain in ii-b5b-i-b/i-c.

## 2. Scope and Artifact Identity

The implementation changed exactly the five frozen non-document paths and 1,086
lines: 1,057 additions and 29 deletions, below the 1,200-line ceiling:

1. `Sources/StornautInvestigationHandoffContract/InvestigationInstalledL2ProjectionContract.swift`;
2. `Tests/StornautInvestigationTests/InvestigationInstalledL2ProjectionContractTests.swift`;
3. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
4. `scripts/verify-contract`; and
5. `scripts/verify-investigation-boundaries`.

The implementation and staged-validation commits share exact tree
`95d83534e59547d4511ad00a7419385d3160a687`. Canonical identities are:

- projection/temporal contract: `ee5dac16fc6075008fd8b4cdd85a8ebafd45ba15a014fac16daff551453a1f4b`;
- focused tests: `7d947df4bf9a992ad409945eedf3bd43684fc29ee19e118895a2ff226384c344`;
- boundary tests: `256735af664fa8d6d84a423ae9f7b5380c568404de374040b0a4d0a933dc98db`;
- `scripts/verify-investigation-boundaries`: `5649adb669d26371201258e3be5ad19dbd24f27fd018f5ca4f2d3c60b34e354d`; and
- normalized `scripts/verify-contract` self-seal: `4d24f75957db348337f73ea9d063c1c0e6e75b3918f52c459091f558b52c7ee2`.

## 3. Tests and Review Repairs

The final focused suite has eleven top-level tests. It includes a literal
585-byte golden transcript and literal digests independent of the production
encoder, wrong magic/domain/version/tag/order/length/truncation/trailing/
oversize mutations, invalid UTF-8 with a recomputed self digest, exact lowercase
SHA construction, ten semantic invalid cases, both admitted CodeDirectory hash
widths, ten independent commitment-sensitivity axes and nine temporal invalid
axes. Representable `Int64.max`/`UInt64.max` comparisons prove the contract does
no cross-clock conversion or unchecked arithmetic.

Independent review found and closed the material issues:

- temporal inputs were changed from caller-composable raw deadlines to strict
  projection + claim evidence + bootstrap owners;
- the original self-oracle golden bytes were replaced with fixed literal bytes
  and literal SHA-256 values;
- epoch UUID and configuration nonce sensitivity, wrong domain, oversize,
  malformed identifier and maximum-value boundaries were added;
- the staged-scope gate now rejects deletion of a baseline-existing non-document
  path explicitly and has an executable negative control; and
- the completed ii-b5a verifier now replays its fixed implementation commit/tree
  rather than reinterpreting every later live index as an ii-b5a checkpoint.

The final code-guard and post-fix checks found no unresolved P0-P2. Reports were
kept under `/tmp` only.

## 4. Validation Evidence

| Gate | Result |
| --- | --- |
| focused projection suite | 11 top-level tests passed; 10 semantic invalid, 2 CDHash, 10 commitment and 9 temporal cases |
| affected projection + boundary run | initial 25-test combined run exposed two static-marker issues; only those exact two cases were rerun and passed |
| `scripts/verify-contract` | exit 0; historical replay, seven source mutations, source seals and staged scope/budget mutations passed |
| full `scripts/verify-investigation-boundaries` | exit 0; package/authority checks and exact Debug/Release driver projections passed |
| binary delta | Debug and Release each added only Foundation `String.init(data:encoding:)`; loaded libraries and owned symbols were unchanged; no write/process/network/signal authority |
| sole clean staged-only serial | 1,302 tests in 63 suites passed in 90.178 seconds; five maximum benchmarks skipped; one run with no retry |

The affected run is not described as a complete green rerun. The exact two
static failures were repaired and rerun; the sole staged serial subsequently
provided the clean whole-package regression over the exact accepted tree.

## 5. Non-Admission and Next Gate

ii-b5b-i-a is complete but non-admitting. It did not launch an App/helper, use
real XPC, install or mutate system state, use root, call a model, read auth,
access a network, create a machine report/receipt, claim readiness or run
`scripts/verify --full`. ADR 0018 remains Proposed, Task 39 remains incomplete
and production Deep Dive remains `.implementationUnavailable`.

The next frontier is ii-b5b-i-b's fresh extraction preflight. Current-source
cost review requires that extraction to be split again before coding so semantic
contract, artifact readers, process/service readers and observer composition do
not recreate a multi-thousand-line review surface. ii-c still exclusively owns
the DriverSupport join and legacy-owner closure; L3c4 exclusively owns machine
readiness and the remaining authoritative full verifier.
