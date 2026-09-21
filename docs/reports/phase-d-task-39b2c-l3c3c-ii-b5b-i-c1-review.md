# Phase D Task 39B2c L3c3c-ii-b5b-i-c1 Review

> Status: complete / non-admitting
> Date: 2026-08-22
> Next frontier: i-c2 legacy installed-owner closure

## 1. Scope and Result

i-c1 completed the one-way DriverSupport join from the exact typed projection,
claim evidence, one extracted installed-L2 semantic observation and repeated
post-drop App identity to an opaque proof. The implementation is commit
`bdebf9c26d24e676c595004c2b15c1177aa008f2`, parent
`ae9675dd1ce29faae67fd32c72a570bc7b247d3d`, tree
`b4a23e87ddc79a944cc58cc96cc1e24deef41c58`. It changed exactly eight
non-document paths with 1,021 insertions and 71 deletions, below the frozen
eight-path / 1,800-line ceiling.

The final test-only commit `74877ec7a1cdd442e8333a1fd77c259edd67a36c`
has tree `f9a3609044853d1a1777ab6a611e8f336932690e` and changes only
`InvestigationMachineTargetBoundaryTests.swift` by 13 insertions and three
deletions. It corrects the existing `driverRuntime` boundary expectation; it
does not alter the production join, proof, package graph or verifier.

## 2. Implemented Contract

DriverSupport now has a one-way dependency on
`StornautInvestigationInstalledL2`; the extracted target does not import back
into DriverSupport, Machine or Lifecycle. The epoch commitment binds the exact
projection to the epoch UUID, configuration nonce, configuration SHA-256 and
signed-runtime-binding SHA-256 before orchestration.

The single-epoch composer passes the exact projection, App identity, claim
evidence, epoch UUID and deadline to one installed-L2 observer call. It then
re-observes the App after identity drop and requires exact equality before proof
minting. The final join rechecks projection, claim, semantic observation, App,
helper, configuration nonce and both wall/continuous deadline orderings. Only
that complete sequence may create the package-scoped opaque proof.

The proof is `Sendable`, `Equatable` and non-`Codable`, with no public/package
field or initializer, JSON, report, receipt or readiness surface. The join
accepts no caller-selected path, PID, service, descriptor or endpoint, performs
no physical reads itself and does not change claim release or retirement order.

## 3. Verification and Review

- tests-first RED failed on the missing observer/protocol surface before
  implementation;
- focused and affected join regression: 17 tests in two suites passed;
- i-c1 TargetBoundary case: 1/1 passed on the final test-only tree;
- `scripts/verify-contract`, the full investigation-boundary verifier,
  canonical join gate and staged-scope gate exited 0;
- real Debug and Release machine-driver final-Mach-O gates passed;
- projection/claim/observer/repeated-App mismatch, call cardinality, proof
  order, opaque/non-`Codable` surface, dependency direction, parallel/physical
  reader, authority, canonical-source and scope mutations passed; and
- production, verifier and cross-group review artifacts at
  `/tmp/stornaut_iic1_review.ZYvMrA/` report no unresolved P0-P2.

The checkpoint's only serial ran 1,355 tests in 69 suites on the implementation
tree in 85.761 seconds, with 90.12 seconds wall time and five maximum benchmarks
skipped. It was not rerun or restarted. That run recorded two issues in the
same static `driverRuntime` boundary case. The final
test-only tree corrected that expectation and the exact case passed 1/1.
Post-fix/validation review found no unresolved P0-P2 and accepted this precise
test-only closure as sufficient for the non-admitting checkpoint; it does not
rewrite the historical serial as fully green.

## 4. Non-Admission and Next Gate

i-c1 is complete and non-admitting. This checkpoint did not run
`scripts/verify --full`, launch the App/helper, invoke real XPC, install an
artifact, use sudo/root, call a model, read auth or access a network.

i-c2 is current and remains limited to legacy installed-owner closure and the
exactly-one-owner structural proof; it must not change the i-c1 join or opaque
proof semantics. Task 39 remains incomplete, ADR 0018 remains Proposed,
production Deep Dive remains `.implementationUnavailable`, and L3c4 alone owns
readiness, final admission and the remaining authoritative full verifier.
