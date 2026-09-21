# Phase D Task 39B2c-L3c3b-ii Installer and L2 Admission Review

> Status: Complete; exact installer and L2 Machine-driver admission proved
>
> Date: 2026-08-18
>
> Baseline: `2a0ac20862d85d65cd22a2b7faad2cadda54be8b`
>
> Scope: fixed built/staging/installed driver admission and package-closed L2
> evidence; no live install, launch, handoff, model, readiness or full verifier

## 1. Decision

L3c3b-ii is complete. The local lifecycle installer now admits the packaged
Machine driver only after proving one exact regular arm64 executable across the
built, root-owned staging and installed planes. The evidence binds owner/group,
mode `0755`, one hard link, the 16 MiB limit, descriptor SHA-256, fixed signing
identifier, ad-hoc status, designated-requirement bytes, CodeDirectory hash and
the fixed Machine-claim service. Staging is validated before move; the installed
plane is revalidated before and after bootstrap admission. Status, recovery and
uninstall validate the fixed installed driver independently and do not require a
surviving local build.

The package-closed L2 topology now has eight artifact roles, including the fixed
Machine-driver executable. Its non-Codable binding carries complete driver
signing evidence. The Darwin reader proves the fixed root-owned node, exact hash,
signing evidence and post-sign node identity. Installed proof requires the driver
present-valid; post-teardown proof continues to require every closed role absent.
The Machine collector joins all five signed-driver dimensions both while reading
the installed binding and again at the injected-reader retirement boundary. No
driver PID/process observation or cleanup/Executor authority was added.

## 2. Exact Scope and Cost

The accepted implementation changes exactly twelve non-document paths:

1. `Sources/StornautLifecycle/LifecycleRootTopologyObservation.swift`
2. `Sources/StornautLifecycle/DarwinRootTopologySupport.swift`
3. `Sources/StornautInvestigationMachine/InvestigationLifecycleTopologyCollector.swift`
4. `Tests/StornautLifecycleTests/LifecycleRootTopologyObservationTests.swift`
5. `Tests/StornautLifecycleTests/DarwinRootTopologySupportTests.swift`
6. `Tests/StornautInvestigationTests/InvestigationLifecycleTopologyCollectorTests.swift`
7. `Tests/StornautInvestigationTests/InvestigationLifecycleTopologyTestSupport.swift`
8. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
9. `scripts/stornaut-r5-local-lifecycle`
10. `scripts/verify-investigation-boundaries`
11. `scripts/verify-app-release-boundaries`
12. `scripts/verify-contract`

The frozen implementation tree contains 1,844 additions and 71 deletions, below
the approved twelve-path / 3,000-added-line ceiling. Its accepted implementation
tree is `1c4a665151e6bca44d784c94b2a9c461217f83e2`. Package/Xcode graphs,
the launchd plist, Machine host, App/helper source and service-registration
schema did not change.

## 3. Tests First and Review Fixes

The mandatory unit-test workflow completed all seven steps and flushed its local
report. Four focused suites first compiled and failed only on the missing
contracts: Lifecycle role/binding/installed proof, Darwin fixed-node/signing
observation, collector five-dimensional joins, and installer/disposable verifier
admission. Coverage execution was skipped because no CI or user threshold applies
and these tests primarily freeze package-closed Swift and shell/Python contracts.

Independent grouped review found four P1 defects over successive review/fix
cycles, all closed tests-first before the serial regression:

1. the no-live-action verifier omitted the directly called
   `exact_file_metadata` helper;
2. `ditto` preserved caller-controlled extended ACLs into the purportedly
   root-owned staging tree;
3. a literal mutation denylist could miss an unknown mutator such as `touch`;
4. the first source seal reconstructed selected fragments and omitted executable
   top-level text between function declarations.

The final implementation recursively removes staging ACLs before validation and
rejects any ACL on the driver or any bundle node. A real named-user write ACL
negative fixture is rejected while the no-ACL signed artifact remains accepted.
The verifier scans the complete direct helper closure for readable diagnostics
and separately seals the raw bytes of the entire installer. The expected whole-
installer SHA-256 is
`3db2b0471504fde111f5fe610f516bb43a6b1f5e74ca800de8a2806f0d6ae8e6`
and lives outside the sealed file. A guarded inter-function `touch` mutation
changes the digest and is rejected without relying on the mutator name.

Final post-fix installer review, verifier review and cross-group review are all
empty. The final finding-set SHA-256 is
`37517e5f3dc66819f61f5a7bb8ace1921282415f10551d2defa5c3eb0985b570`.
Review artifacts are under `/tmp/stornaut_l3c3bii_review.MkwUTZ/`, including
`report.html`, `report.md`, the initial findings and the empty final post-fix
JSONL files.

## 4. Validation

| Gate | Result |
| --- | --- |
| Lifecycle root-topology focused | 14/14 passed |
| Darwin root-topology focused | 16/16 passed |
| Investigation lifecycle collector focused | 11/11 passed |
| trusted Machine/installer boundary focused | 7/7 passed |
| structural Investigation boundary | passed |
| verifier self-contract | passed |
| disposable validation-only signed-artifact smoke | positive passed; ACL negative rejected; zero residue |
| ordinary/diagnostic Release artifact boundary | passed, including six-case disposable matrix |
| affected Lifecycle regression | 207 tests in 24 suites passed |
| affected Investigation regression | 334 tests in 23 suites passed |
| clean staged-only serial regression | 1,067 tests in 51 suites passed |
| serial test / stage time | 83.168 / 123.475 seconds |
| validation commit | `46d3cb38a90ec6ded12082ea2ca1415d5ab5a096` |
| accepted implementation tree | `1c4a665151e6bca44d784c94b2a9c461217f83e2` |
| final independent review | no unresolved P0-P2 |

The clean staged-only serial ran exactly once from the generated validation
commit over the frozen index tree. Validation-commit tree and source index tree
were identical, the isolated worktree was removed, and there was no restart,
failed-stage retry or second serial execution. The maximum Tasks 36/37
benchmarks and real diagnostic/Trash tests remained skipped. Authoritative
headless and `scripts/verify --full` were not run; the remaining full is reserved
for L3c4.

One test-routing issue was made explicit during affected validation: the broad
`swift test --filter Investigation` selector also matches the maximum
Investigation benchmarks. It passed, but it is no longer an approved ordinary
debug loop. Future work uses exact focused suites, then the verifier-owned
serialized stage whose explicit skip list excludes maximum benchmarks.

## 5. Safety Boundary and Next Gate

This checkpoint built and inspected artifacts and executed only the explicitly
token-bound validation-only action against canonical disposable copies. It did
not run `install`, `uninstall`, `status`, `launchctl`, the App/helper/driver, or a
model; it made no readiness claim and did not modify `~/.codex/config.toml`.
Production Deep Dive remains unavailable. L3c3c-i, the repository-external
parent-owned launcher/handoff spike and ADR, is next; only L3c4 owns machine
readiness and the remaining authoritative full verifier.
