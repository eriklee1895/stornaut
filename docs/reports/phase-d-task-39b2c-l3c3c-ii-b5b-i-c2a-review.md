# Phase D Task 39B2c L3c3c-ii-b5b-i-c2a Review

> Status: complete / non-admitting
> Date: 2026-08-22
> Implementation commit: `58332ccb9f78da203fb2380ca006c49f0f371c2b`
> Parent: `6e794274c8a427422e47df326231010b07f3413c`
> Tree: `59e6856e43b9c6c40cf057fcebfbfed9b6cedde7`
> Next frontier: i-c2b physical-owner closure

## 1. Scope and Result

i-c2a removes the legacy installed-phase semantic owner from the Machine and
Lifecycle path. The former dual-phase topology schema, installed predicate,
installed collector branch, loaded-service schema and ScenarioDriver consumer
are gone. The legacy collector now owns only the transition and fail-closed
post-teardown observation. The extracted `StornautInvestigationInstalledL2`
observer and the i-c1 DriverSupport join remain the sole installed-phase
semantic path.

The checkpoint changed fourteen non-document paths, with 917 insertions and 697
deletions (1,614 changed lines), within the frozen fourteen-path / 2,200-line
ceiling. The accompanying split-preflight update is documentation and is not
charged to that implementation budget.

This is deliberately not the final i-c2 physical-owner claim.
`PostTeardownExpectedTopologyBindingReader` still reads installed App, helper
and machine-driver signing evidence before transition. i-c2b must remove that
parallel physical read path and convert teardown observation to absence-only
inputs before the combined i-c2 checkpoint may claim exactly-one physical
ownership.

## 2. Implemented Contract

- `LifecycleRootTopologyObservation` is post-teardown-only. It has no phase,
  installed predicate or loaded-service success state.
- Every fixed artifact must be absent, both captured process identities must be
  absent or conclusively PID-reused, and the fixed service must be absent.
  Present, invalid, unavailable or unresolved evidence fails closed.
- `DarwinPostTeardownLifecycleServiceProbe` maps only the structured missing
  registry result to absence. A registered or unavailable service cannot prove
  teardown.
- `InvestigationLifecycleTopologyCollector` validates the one-shot claim and
  expected binding, rechecks root authority and deadline immediately before the
  transition, performs the transition exactly once, rechecks root/deadline
  afterward, and only then begins post-teardown observation.
- The returned cohort contains no installed observation. Scenario evidence
  requires only the authoritative i-c1 installed proof from the single-epoch
  path plus this collector's post-teardown proof.
- The collector remains one-shot and fail-closed across cancellation, transition
  error, stale window, root loss and uncertain teardown evidence.

## 3. Verifier Hardening

Independent review found that the first staged-scope gate checked only path and
line accounting while the semantic gate read working-tree files. A bad staged
blob paired with a good unstaged file could therefore pass. The final gate now
materializes the active Git index into a temporary root and reruns the same
canonical semantic validation over those exact staged blobs.

The review also found syntactic false-green variants around service absence,
the focused structural test, and collector/scenario boolean admission. The
final verifier seals the complete relevant declarations and includes mutations
for direct and aliased early returns, unreachable/vacuous tests, ordinary and
parenthesized `|| true`, installed-reader restoration, duplicate owners and
staged semantic drift.

Historical checkpoint budget accounting remains tied to the immutable
implementation commits without raising the original ceilings:

| Checkpoint | Normalized changed lines | Frozen ceiling |
| --- | ---: | ---: |
| i-b2b-a `9495808...` | 1,465 | 1,900 |
| i-b2b-b `8ef5a5c...` | 903 | 1,300 |
| i-b3 `a50dd81...` | 1,028 | 1,600 |
| i-c1 `74877ec...` | 1,234 | 1,800 |

Final verifier seals on the implementation commit are:

- `scripts/verify-contract` normalized SHA-256:
  `01c131c4769b63cf7e27f8af967bfd641fff7b82d1bc40926f0b60092b1ad837`;
- `scripts/verify-investigation-boundaries` SHA-256:
  `f144fabcd67ecc978180830dabaf56638b5901934796da16da96401dee750246`.

## 4. Validation and Review

- The tests-first RED compiled and failed with thirteen issues identifying the
  old installed semantic owner.
- The focused behavior suite passed 47 tests in six suites after implementation
  and again after the final API rename.
- The final affected command passed 70 tests in six suites, including the full
  Machine target-boundary suite.
- The exact six static cases implicated by the earlier serial failure passed
  six tests in one suite on the final implementation tree.
- The canonical i-c2a semantic-owner gate and index-backed staged-scope gate
  passed.
- `scripts/verify-contract` passed with the complete historical replay and the
  i-c2a canonical, mutation, staged-semantic, scope and budget controls.
- The full `scripts/verify-investigation-boundaries` gate passed, including real
  Debug and Release Machine-driver final-Mach-O checks.
- `git diff --cached --check` passed before the implementation commit.
- The final production-semantic, verifier, grouped and cross-group reviews
  found no unresolved P0-P2 findings. The supplemental code-review artifacts
  are under `/tmp/stornaut_ic2a_codeguard.20HMUZ/`.

The checkpoint's only staged-only serialized regression was not green: it ran
642 tests in 53 suites and reported eleven issues, all in static
`InvestigationMachineTargetBoundaryTests` because the verifier usage text had
temporarily been replaced with a generic placeholder. The usage text was
restored, and the six implicated cases then passed exactly on the corrected
tree. Independent final review accepted this precise closure for the
non-admitting checkpoint. The historical serial is not relabeled as green and
was not repeated.

## 5. Non-Admission and Next Gate

i-c2a did not run `scripts/verify --full`, launch or install the App/helper,
invoke real XPC, use sudo/root, read Codex auth, call a model or access a
network. It makes no machine-readiness, containment or product-availability
claim. ADR 0018 remains Proposed and production Deep Dive remains
`.implementationUnavailable`.

i-c2b is next. It must remove the remaining post-teardown signing/binding
reader, make artifact and process teardown evidence strictly absence-only, and
prove that the extracted InstalledL2 target is the only physical installed
evidence owner. Only after i-c2b can the aggregate i-c2 checkpoint close and
advance to ii-b5b-ii. L3c4 alone still owns final machine admission and the
remaining authoritative full verifier.
