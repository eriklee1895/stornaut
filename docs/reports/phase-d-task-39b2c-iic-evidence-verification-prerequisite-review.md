# Phase D Task 39B2c ii-c Evidence Verification Prerequisite Completion Audit

> Status: complete / non-privileged / non-admitting
>
> Date: 2026-09-01
>
> Implementation: `3ba34d47104b25e834ba0d14c28c6405b1077c67`
>
> Tree: `38964e5253d074c943d0df3b922972c04fb4ebf2`
>
> Parent: `3e49956f6f8e44d5d191d47c9e86856dd00d6966`
>
> Next frontier: real-sudo resolved root-driver lineage prerequisite

## 1. Result

The ii-c evidence-verification prerequisite is complete and remains
non-privileged and non-admitting. The producer, Swift campaign consumer and
independent Python verifier now share one atomic nine-field epoch wire. Each
persisted epoch retains the canonical admission material required to recompute
its admission transcript rather than trusting a carried digest.

Offline validation now revalidates terminal EOF, process identities,
absence/reap facts, mode, deadline, Installed-L2 semantic and temporal
constraints, and normal-result driver observations. The eight-row bundle
reconstructs its canonical cohort and projected input, validates successor
continuity, and requires one stable outer-driver PID across all epochs.

The campaign and independent verifier derive the claim, helper-identity and
completion-binding digests from authoritative binary evidence. They parse the
complete fixed raw Gate frame and 410-byte payload, reconstruct the 160-byte
prepared payload and 172-byte prepared frame, and join Gate output to the
reconstructed driver completion and final coordinator receipt.

This checkpoint does not authenticate the root driver as a descendant of the
real sudo cohort. That deliberately remains the next prerequisite.

## 2. Exact Scope and Budget

Relative to the frozen baseline, the accepted implementation changes exactly
thirteen non-document paths: 3,383 additions and 299 deletions, or 3,682 changed
lines. Every per-path ceiling and the aggregate 4,000-line ceiling are enforced
by the staged-scope gate and passed on the accepted tree.

| Path | Changed | Ceiling |
| --- | ---: | ---: |
| `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinOuterInnerProtocol.swift` | 582 | 610 |
| `Tests/StornautInvestigationTests/InvestigationMachineDarwinOuterInnerProtocolTests.swift` | 490 | 530 |
| `Sources/StornautInvestigationMachineCampaign/main.swift` | 80 | 90 |
| `Sources/StornautInvestigationMachineCampaignSupport/InvestigationMachineCampaignEvidenceContract.swift` | 751 | 770 |
| `Tests/StornautInvestigationTests/InvestigationMachineCampaignEvidenceTests.swift` | 812 | 850 |
| `scripts/verify-investigation-runtime-machine-report` | 328 | 340 |
| `scripts/verify-investigation-boundaries` | 394 | 400 |
| `scripts/verify-contract` | 127 | 150 |
| `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineZeroArgumentEntry.swift` | 2 | 5 |
| `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinOuterInnerComposition.swift` | 1 | 5 |
| `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineHelperEpochContinuity.swift` | 27 | 35 |
| `scripts/verify-app-release-boundaries` | 73 | 80 |
| `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift` | 15 | 20 |

The implementation changes no `Package.swift`, Gate transport schema, final
coordinator receipt schema, product target or Xcode graph.

## 3. Implemented Closure

- Epoch evidence carries canonical ownership, acknowledgement, decision and
  owner material and independently recomputes `admissionSHA256`.
- Decoding rejects malformed framing, trailing bytes, zero request bindings,
  identity drift, invalid absence/reap claims, invalid mode/deadline
  relationships and invalid normal-result observations.
- Installed-L2 evidence is independently evaluated against its semantic
  contract and temporal window.
- A failed containment proof terminalizes the one-shot admission; only one
  successful proof may advance to evidence commit. Evidence commit is the
  cancellation/deadline linearization point.
- The eight-epoch bundle reconstructs the canonical cohort and projected input,
  validates successor continuity and rejects cross-epoch outer-driver-parent
  drift.
- CampaignSupport owns campaign evidence validation; the executable does not
  duplicate DriverSupport decoding.
- Raw Gate validation parses all 422 frame bytes and all 410 payload bytes,
  reconstructs the prepared frame, binds the independently observed outer
  coordinator identity, and joins the persisted `spawnObserved` identity.
- The independent Python verifier repeats the semantic and cross-artifact joins
  without importing or calling CampaignSupport.
- Canonical diagnostic-envelope validation admits exact LF only and rejects
  CRLF, leading/trailing bytes, missing LF and noncanonical Base64.
- The three-MiB bundle limit and matching writer allowance are admitted without
  weakening the sixteen-MiB campaign harness bound.
- Existing product-authority deny-lists and component/final-image exclusions
  remain closed.

## 4. Review Findings and Closure

Independent review initially found seven issue classes: missing outer-identity
join, zero request-binding acceptance, retry after failed containment proof,
noncanonical diagnostic-envelope acceptance, an unenforced component gate, a
duplicate audit-token mutation, and a hand-authored positive corpus that did not
cross all real consumers. Each finding was repaired tests-first.

The producer/DriverSupport and campaign/verifier post-fix reviews are empty. A
final exact-diff review also compared the budget-only compaction against the
pre-compaction blobs and found no semantic changes or unresolved P0-P2. The
retained review artifacts are:

- `/tmp/stornaut_task39_evidence_review.xY8cje/final_comments.json` — SHA-256
  `37517e5f3dc66819f61f5a7bb8ace1921282415f10551d2defa5c3eb0985b570`;
- `/tmp/stornaut_task39_evidence_review.xY8cje/report.html` — SHA-256
  `9a1a9fc7910c1f3cf79704dbb32f735c931a90c697d0e65ddd6ce521f1ae1860`; and
- `/tmp/stornaut_task39_evidence_review.xY8cje/report.md` — SHA-256
  `94794ff0cce2d358d48e1dc4d0ac12929290975e637adf54a0e7e13024c8e626`.

The repository-specific workflow fetch failed closed on the environment's
self-signed TLS chain and returned no custom workflows; the general and
security-boundary reviews completed normally.

## 5. Validation Evidence

| Command or evidence | Result |
| --- | --- |
| `git diff --cached --check` | exit 0 before implementation commit |
| `scripts/verify-investigation-boundaries --iic-evidence-verification-staged-scope-contract-only 3e49956f6f8e44d5d191d47c9e86856dd00d6966` | exit 0; exact 13-path set, every per-path ceiling and 3,682/4,000 aggregate budget passed |
| `scripts/verify-investigation-boundaries --iic-evidence-verification-source-contract-only` | exit 0 on the accepted source |
| `/usr/bin/swift test --no-parallel --filter 'Investigation(MachineCampaignEvidenceTests\|MachineDarwinOuterInnerProtocolTests)'` | 69/69 tests in 2 suites passed after final compaction; 23.791 seconds |
| `scripts/verify-contract --iic-evidence-verification-contract-only` | exit 0 after final compaction; source contract, all 15 mutations and embedded component/final-image gate passed |
| `scripts/verify-investigation-boundaries` | exit 0 after final compaction; Debug/Release driver binaries and Core/coordinator boundaries passed |
| `scripts/with-clean-validation-snapshot --staged -- /usr/bin/swift test --no-parallel --filter StornautInvestigationTests` | 934/934 tests in 62 suites passed on the semantically identical pre-compaction tree; wall time 3 minutes 14.25 seconds |
| `scripts/verify-contract` | aggregate exit 0 on the semantically identical pre-compaction tree |
| exact compaction review | test/mutation cardinalities, assertions, Python `require` conditions, mutation tuples and self-seals unchanged; no unresolved P0-P2 |

The final representation-only compaction removed 315 changed lines. It did not
remove a test, mutation, assertion or verifier condition. The targeted tests and
all directly affected structural/mutation/component gates were rerun on the final
tree; the already-green serialized suite and aggregate were intentionally not
duplicated. No authoritative `scripts/verify --full` was run because L3c4 owns
that final admission gate.

## 6. Non-Claims and Required Successor

This checkpoint ran no root operation, sudo, install or uninstall, system
launchctl mutation, installed driver/Gate/coordinator, real machine campaign,
product XPC, Codex authentication, model call or network operation. The unique
privileged ii-c-c attempt remains unconsumed.

The eight epoch records naming one stable `outerDriverProcessID` do not prove
that it is the exact signed root outer driver descended from this Gate's
`/usr/bin/sudo` invocation. Stock macOS `sudo` may insert a PTY monitor or other
session descendants; the Gate's direct sudo-child PID must not be equated with
the driver parent PID.

The immediate successor is the real-sudo resolved root-driver lineage
prerequisite. It must authenticate the root outer driver's PID, pidversion/start
identity, PGID, SID, audit session and fixed executable/signing identity; bind
that identity to the Gate/sudo descendant cohort and every epoch's driver-child
parent; and prove final retirement of the complete monitor/driver descendant
cohort. The invalid assertion `Gate direct sudo child == driver parent` must not
be restored.

ADR 0018 remains Proposed, Task 39 remains incomplete, and production Deep Dive
remains unavailable. The remaining order is:

```text
resolved root-driver lineage prerequisite
-> ii-c-c unique machine campaign
-> L3c3d
-> L3c4
```
