# Phase D Task 39B2c ii-c Machine Campaign Preflight

> Status: frozen / ii-c-a and ii-c-b complete/non-admitting / ii-c-c implementation current; unique privileged attempt not consumed
>
> Date: 2026-08-30
>
> Baseline: `2b30a157c14bc507351b10bd521e710987860f71`
>
> Remaining order: ii-c-c -> L3c3d -> L3c4

## 1. Decision

The one no-model privileged machine gate is split before implementation so the
unique real attempt is not spent on an unreviewed packaging or evidence path:

1. **ii-c-a — static installed topology.** Build, sign, copy and admit the
   fixed diagnostic driver, gate and coordinator as one closed App bundle.
   This checkpoint is non-privileged and does not execute the installed tools.
2. **ii-c-b — runtime-owner and campaign harness.** Correct the installed
   root-owned gate admission contract, implement the owner-private evidence
   harness and verifier, and prove it with non-root fixtures/dry runs only.
3. **ii-c-c — unique real campaign.** Freeze source and artifacts, install
   once, perform the non-executing sudo policy probe, obtain the trusted human
   prompt attestation, durably arm once, execute the outer driver at most once,
   independently verify evidence, uninstall and prove zero residue.

This split does not add Tasks. It is the bounded implementation sequence inside
the already approved ii-c checkpoint. ADR 0018 remains Proposed.

## 2. ii-c-a Exact Scope and Budget

The current implementation checkpoint may change exactly these eleven
non-document paths and at most 3,800 changed non-document lines:

1. `Package.swift`;
2. `Sources/StornautInvestigationMachineGateSupport/InvestigationMachineFixedGateLauncher.swift`;
3. `Sources/StornautInvestigationMachineGateCoordinatorSupport/InvestigationMachineGateCoordinatorComposition.swift`;
4. `Stornaut.xcodeproj/project.pbxproj`;
5. `Stornaut.xcodeproj/xcshareddata/xcschemes/StornautInvestigationDiagnosticApp.xcscheme`;
6. `scripts/stornaut-r5-local-lifecycle`;
7. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
8. `Tests/StornautInvestigationTests/InvestigationClosedMachineArtifactInstallerTests.swift` (new);
9. `scripts/verify-investigation-boundaries`;
10. `scripts/verify-app-release-boundaries`; and
11. `scripts/verify-contract`.

Category ceilings are: Package/API 120, Xcode project/scheme 650, installer
500, tests 850 and verifiers 1,680. The aggregate ceiling and each category
ceiling are independent. A twelfth path, line 3,801, runtime owner-contract
change, new schema/protocol field, or installation/campaign execution stops
implementation for re-preflight.

## 3. ii-c-a Closed Topology

`Package.swift` exports the existing GateSupport and CoordinatorSupport targets
as static library products. Only each enum and `run` entry becomes public so a
native Xcode tool target can call it; all other package implementation remains
closed. The case-sensitive Gate target path is normalized to the tracked
lowercase `tools/StornautInvestigationMachineGate`.

The diagnostic Xcode project adds exactly two native tool targets:

| Target | Product | Support product | Signing identifier |
| --- | --- | --- | --- |
| `StornautInvestigationMachineGateNative` | `StornautInvestigationMachineGate` | `StornautInvestigationMachineGateSupport` | `com.eriklee.stornaut.investigation.machine-gate` |
| `StornautInvestigationMachineGateCoordinatorNative` | `StornautInvestigationMachineGateCoordinator` | `StornautInvestigationMachineGateCoordinatorSupport` | `com.eriklee.stornaut.investigation.machine-gate-coordinator` |

They mirror the driver's arm64, ad-hoc manual-signing, non-hardened,
`-parse-as-library`, Debug/Release tool settings. Both become explicit
diagnostic-App dependencies and explicit diagnostic-scheme build entries.
Their `CodeSignOnCopy` products are fixed siblings of the driver under
`Contents/MacOS`. Ordinary Debug/Release App, Lifecycle helper and the
dependency-free Release shell remain free of both tools and support namespaces.
The CoordinatorSupport build plugin remains attached to that package target; a
controlled Xcode build must prove generated provenance compiles through the
new native target.

The local lifecycle installer treats driver, gate and coordinator as a closed
three-role table. For every role it preserves no-follow descriptor identity,
regular-file/one-link/0755 metadata, exact arm64, bounded size, strict ad-hoc
signature, fixed identifier, designated requirement, CodeDirectory hash,
SHA-256 and pre/post node stability. It proves same-role built = staging =
installed identity. The driver alone retains the fixed machine-claim service
association. The App remains the atomic copy/removal unit; no separate
privileged tool copy is added.

## 4. ii-c-a Tests and Gates

Tests first cover the exact five-executable diagnostic inventory; two new
native targets and scheme entries; three machine-tool copy members; fixed
products, source paths and signing identifiers; ordinary/Release-shell absence;
complete three-role built/staging/installed equality; missing, swapped,
symlinked, hard-linked, wrong-mode/owner/group/architecture/size/signature/ACL
artifacts; mutation before move/bootstrap; and uninstall/rollback validation.
The disposable validation action may retain its historical
`validate-machine-driver` spelling but must validate the complete closed
machine-tool set.

Validation order is structural RED -> focused tests -> affected tests -> one
staged-only serial regression -> targeted Debug diagnostic App plus standalone
Debug/Release tool builds -> final-Mach-O/ordinary-App/Release-shell boundaries
> independent review. ii-c-a stops after those focused checkpoint gates; the
remaining clean authoritative `scripts/verify --full` belongs only to L3c4 and
is not spent or used as a debugging loop here.

ii-c-a does not run `install`, `uninstall`, `launchctl` system operations, sudo,
the installed coordinator/gate/driver, product XPC, Codex auth/model/network or
the unique machine campaign.

## 5. ii-c-b Required Closure

The installed bundle is normalized to root ownership. The current non-root
handoff accepts the Gate only when its owner equals the coordinator's UID 501.
That deliberate mismatch blocks real installed execution and must remain
untouched in ii-c-a. ii-c-b must define and prove the exact root-owned immutable
Gate admission without relaxing its path, descriptor, mode, link, flags, ACL,
xattr, SHA, loaded-image, signing or sibling constraints.

ii-c-b also owns a non-privileged campaign harness with a fresh controlling PTY,
`setsid`/`TIOCSCTTY`, coordinator foreground/session leadership, inherited FD 3
receipt pipe, bounded concurrent drain, strict receipt decode, and an
owner-private raw-evidence writer/verifier. No dry-run fixture may execute sudo
or a root-installed artifact.

Live status (2026-08-31): ii-c-b was split into ii-c-b1 and ii-c-b2. The
root-owned Gate admission half is complete/non-admitting at implementation
`77cde61` / tree `9c59f241`; ii-c-b2 now owns only the non-privileged
PTY/FD3/raw-evidence harness and verifier.

The mandatory ii-c-b2 cost split is frozen in
[ii-c-b2 Split Preflight](phase-d-task-39b2c-iic-b2-split-preflight.md). Its
implementation checkpoints are b2a1 evidence producer, b2a2 independent
verifier and b2b PTY/FD 3 transport. They remain one ii-c-b2 deliverable and
do not add roadmap Tasks.
The [b2a1 completion audit](phase-d-task-39b2c-iic-b2a1-evidence-producer-review.md)
records implementation `e3555ec` / tree `f38783f`, 31/31 focused tests and
zero unresolved P0-P2 after review-finding closure. The
[b2a2 completion audit](phase-d-task-39b2c-iic-b2a2-independent-verifier-review.md)
records implementation `294bdb2` / tree `dbbffbba`, exact 6 paths / 1,999
lines and zero unresolved P0-P2 after closure. b2b then completed at
implementation `a08d0f6` / tree `62cb658e`, including its focused and physical
transport matrix, 53 boundary tests, Debug/Release component gate, one 911-test
serialized regression and independent review. Those tests are not repeated in
ii-c-c.

## 6. Campaign Evidence and Attempt Consumption

The ii-c-c evidence root is fresh, owner-private and contains six ordered
phases: preflight, install, authorization, driver/epochs, uninstall and verifier.
Protocol-native receipts remain canonical binary bytes. Strict JSON records
cover source/build identity, built/staging/installed identities, policy probe,
trusted-human prompt attestation, no-auth/model/network counters, per-epoch L2
and residue projections, uninstall and global post-teardown evidence. A
canonical manifest records each relative path, role, byte count and SHA-256 and
rejects extras, symlinks, hard links and traversal.

Attempt state is an append-only, fsynced, hash-chained event stream:

```text
prepared -> cancelledBeforeArm            # not consumed
prepared -> armedConsumed -> spawnObserved|spawnUncertain -> terminal
```

`armedConsumed` is durable before the operation that can execute the fixed sudo
argv. Any crash or uncertainty after it is consumed and cannot be retried. A
mutable convenience marker is never an admission input. The checked campaign
receipt binds the complete content-root digest; raw evidence remains local and
external, following the Task 35 receipt-only precedent.

The policy probe is exactly `/usr/bin/sudo -knv`; zero exit blocks before arm,
while nonzero is only a necessary condition. The privileged argv is exactly:

```text
/usr/bin/sudo -N -p 'Stornaut Task 39 ii-c administrator authorization: ' -- /Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautInvestigationMachineDriver
```

The operator must attest that this exact prompt was observed before credentials
were entered. Human attestation is labeled as such and is not promoted to
machine-observed proof.

## 7. Eight-Scenario and Failure Rules

The ordered scenarios remain: success, cancellation, timeout, invalid envelope,
identity mismatch, transport loss, lifecycle recovery/parent crash, and
artifact cleanup failure. Their canonical outcomes remain respectively:
`succeeded`, `cancelled`, `timedOut`, `invalidEnvelopeBlocked`,
`identityMismatchBlocked`, `transportLossBlocked`, `lifecycleRecovered`, and
`artifactCleanupRecovered`.

Success alone has a final report and accepted final envelope. Cancellation,
timeout and invalid envelope start/admit a turn but end with a settled terminal
barrier. Identity mismatch does not start or admit a turn. Transport loss has no
settled terminal barrier. Lifecycle recovery and artifact cleanup failure must
show recovery attempted and completed. Every scenario retires artifacts and
drains the local runtime. The parent-crash fault kills only the disposable inner
scenario parent; the outer driver remains alive and continues only after exact
EOF, child/descendant/PGID absence and continuity admission.

Before `armedConsumed`, build, static gate, install, policy-probe, prompt setup
or explicit cancellation failures may be repaired without consuming the unique
attempt, but installed state must be safely removed or reported uncertain. From
`armedConsumed` onward, any absent/mismatched prompt, ambiguous spawn, missing or
malformed receipt, scenario mismatch, cleanup uncertainty, process residue or
verifier failure is terminal, non-admitting and non-retryable for that frozen
campaign.

## 8. ii-c-c Acceptance and Non-Claims

The unique campaign must prove exact current-source App/helper/driver/gate/
coordinator/plist/service binding, nonzero policy-probe result, exact prompt
attestation, exactly one zero-argument outer driver invocation, all eight fresh
epochs, pre/post driver identity, per-epoch full installed L2, exact helper
release/exit and fresh next-epoch helper, irreversible drop, strict EOF, and
zero child/descendant/channel/PGID plus global post-uninstall residue. The
persistent same-UID gate base is accepted only with the exact revalidated
`.owner-lock-v1` inode and no `attempt-*` or capsule nodes.

Only a green independently verified ii-c-c campaign may move ADR 0018 from
Proposed to Accepted. ii-c remains no-model and cannot claim Task 39 readiness.
L3c3d alone owns the authenticated real Codex attempt; L3c4 alone owns final
admission and the remaining authoritative full. Production Deep Dive stays
unavailable.

## 9. ii-c-c Exact Scope and Cost Amendment

This amendment freezes the final implementation inside the existing ii-c-c
checkpoint. It does not create another Task or named child checkpoint. The
baseline is component-gate prerequisite `622e7b99d57dfe482ccd37481fcdb4dcff87a0ec`,
tree `543adc4bed4f2f28ba66a3b8506e1a65b9cc7348`. It updates only the existing
closed-image verifier's exact CampaignSupport object inventory. The unique privileged attempt
remains unconsumed until every non-privileged gate below is green.

The implementation may change exactly these seventeen non-document paths and at
most 4,000 changed non-document lines (additions plus deletions):

1. `Sources/StornautInvestigationMachineCampaign/main.swift` — 1,100;
2. `Sources/StornautInvestigationMachineCampaignSupport/InvestigationMachineCampaignHarness.swift` — 300;
3. `Sources/StornautInvestigationMachineCampaignSupport/InvestigationMachineCampaignEvidenceContract.swift` — 420;
4. `Sources/StornautInvestigationMachineGateCoordinatorSupport/InvestigationMachineGateCoordinatorComposition.swift` — 250;
5. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineSingleEpochComposition.swift` — 100;
6. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineSingleEpochPhysicalBridge.swift` — 160;
7. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinOuterInnerProtocol.swift` — 240;
8. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineZeroArgumentEntry.swift` — 200;
9. `Sources/StornautInvestigationMachineCampaignSupport/InvestigationMachineRawEvidenceWriter.swift` — 60;
10. `scripts/stornaut-r5-local-lifecycle` — 160;
11. `scripts/verify-investigation-runtime-machine-report` — 430;
12. `Tests/StornautInvestigationTests/InvestigationMachineCampaignEvidenceTests.swift` — 530;
13. `scripts/verify-investigation-boundaries` — 300; and
14. `scripts/verify-contract` — 110;
15. `Sources/StornautInvestigationMachineGateSupport/InvestigationMachineGateTransport.swift` — 10;
16. `Tests/Fixtures/InvestigationMachineGateStub/main.swift` — 10; and
17. `Tests/StornautInvestigationTests/InvestigationSudoShapedDriverLauncherTests.swift` — 10.

The 2026-09-01 implementation pre-arm review found that the original 600-line
executable allocation could not contain the fixed install/probe/uninstall
ceremony, truthful evidence projection and descriptor-safe external seal. The
per-path allocation above is therefore rebalanced before privileged execution:
the executable ceiling is 1,100 and the evidence-contract ceiling is 420 while
the exact seventeen-path and 4,000-line aggregate ceilings apply after the
pre-attempt macOS check proved combined `sudo -kN` options invalid. The narrow
correction uses `-knv` to invalidate/probe before arm and `-N` for the fixed
privileged launch, preserving the no-update credential-cache boundary. No
authority, artifact, target or roadmap scope is added.

The aggregate ceiling and every per-path ceiling are independent. An eighteenth
non-document path or line 4,001 stops coding for scope reduction inside ii-c-c;
it does not authorize another recursive checkpoint. `Package.swift`, the Xcode
project/schemes, Gate transport schema and coordinator final-receipt schema
remain unchanged. The raw-evidence writer may add only the role-semantic
validation entry; its durable publication algorithm remains unchanged. The
existing App/Release component gate runs unchanged and must prove that the
campaign remains package-only and absent from all product images.

### 9.1 Pre-arm and attempt identity

The installed coordinator remains zero-argument with normalized empty
environment and descriptors `[0,1,2,3]`. It authors the one fresh nonzero outer
attempt UUID through the already accepted cohort author. Before invoking the
Gate, it writes one bounded canonical pre-arm frame on FD 3 containing that UUID,
the exact generated repository HEAD/tree/source-manifest/build-provenance
identity, signed-runtime binding, whole capsule/input identity and the eight
canonical installed-L2 projections. It then blocks on the controlling terminal
for exactly one campaign control line bound to the pre-arm frame digest. No UUID,
path, selector or mutable token is accepted through argv or environment.

The campaign may install and spawn this blocked coordinator before arm. It must
validate the pre-arm frame, install transaction receipt and non-executing exact
`/usr/bin/sudo -knv` result, publish all pre-arm evidence, append `prepared`,
then append and durably publish `armedConsumed`. Only after the latter call
returns may it write the exact ARM line. The coordinator may call the existing
fixed Gate handoff only after validating that line. EOF, cancellation, malformed
control, digest drift or deadline before ARM exits without Gate/sudo execution.
After ARM, every outcome is consumed, terminal, non-admitting on failure and
never retryable for this frozen source campaign.

### 9.2 Prompt and credential boundary

After ARM, the campaign streams the child PTY to the operator and incrementally
recognizes exactly `Stornaut Task 39 ii-c administrator authorization: `. A
duplicate, drifted, oversized or missing prompt, terminal identity/foreground
group drift, deadline or EOF fails the consumed attempt. Before accepting input
it verifies `ECHO` and `ECHONL` are disabled. The operator's act of entering the
credential after seeing the exact prompt is recorded only as a trusted-human
attestation; machine prompt recognition is a separate fact and is not promoted
to proof of human observation.

Credential relay uses only a bounded raw buffer in the campaign executable,
read with Darwin `readpassphrase(..., RPP_REQUIRE_TTY)`, written directly to
the child PTY and cleared with `memset_s` on every path. Credential bytes,
byte counts, timing and key
events never become `Data`, `String`, operation values, logs, stdout/stderr,
diagnostics, tests or evidence. The tests use a non-secret sentinel through an
injected relay and prove it is absent from every returned value and artifact.

### 9.3 Full per-epoch evidence and receipt chain

The existing single-epoch composition remains the only author of installed-L2
truth. It retains the canonical `installed-l2-proof` bytes already built from
the complete projection, claim evidence, eight artifact states, App/helper/
driver identities and signing facts, service state, timestamps, repeated App
identity and epoch deadline. The physical ownership wire carries those exact
bytes and their digest; no second L1/L2 fact model is introduced.

After each exact outer admission and terminal containment proof, one process-
local collector records the canonical projection, ownership, applicable normal
result, terminal evidence and their binding digests. After all eight rows and
plan exhaustion, the driver emits exactly one bounded canonical eight-entry
evidence bundle on stderr using an ASCII/base64 envelope, after all epoch
descendants are retired. It emits on stdout a small v2 completion that binds the
legacy attempt/capsule/input/count fields plus the bundle SHA-256. Gate stdout
limits and its transport schema remain unchanged.

The coordinator writes three ordered length-prefixed frames on FD 3: pre-arm,
the raw canonical Gate transport receipt, then the existing final coordinator
receipt, followed by EOF. The campaign accepts the PTY evidence envelope only
when its decoded bundle reconstructs the exact v2 completion whose SHA-256 is
the Gate receipt's output digest, and the raw Gate receipt's digest equals the
field authenticated by the final coordinator receipt. The independent verifier
repeats that complete chain and validates all eight ordinal/scenario/UUID/nonce/
projection/full-L2/retirement joins. Unauthenticated terminal bytes never become
evidence.

### 9.4 Evidence, install and teardown semantics

Every strict-JSON role gains an exact-key typed schema. Both the Swift producer
path and the independent Python verifier reject unknown/missing fields, wrong
types, zero or malformed identities/digests, placeholder objects, scenario or
ordinal drift, nonzero no-auth/model/network/credential-retention counters,
broken L2-to-residue joins and any cross-role mismatch. Attempt-event payloads
also become kind-specific and bind the pre-arm set, spawn classification and
terminal evidence set without a manifest/content-root hash cycle. A consumed
failed attempt records only the exact observed epoch prefix; it never fabricates
eight successful projections.

The lifecycle script emits bounded canonical transaction receipts from inside
the install and uninstall transactions while preserving its existing commands.
Install evidence binds the exact current built/staging/installed identities,
plist and loaded service; uninstall evidence binds the pre-removal installed
identity and exact App/root/plist/runtime/lease/service absence. Every post-arm
path invokes the fixed uninstall finalizer, then records global process/channel/
SID/PGID absence and the persistent Gate base containing only the revalidated
`.owner-lock-v1` inode with no attempt or capsule entry.

After manifest-last finalization, the campaign publishes the external seal as a
0600 single-link sibling with descriptor-relative exclusive create, bounded
write, file fsync, exclusive rename, parent fsync and no-follow reopen/readback.
It then invokes the independent verifier read-only. No evidence file contains a
credential or raw prompt input.

### 9.5 Tests and gates

RED tests are added only to the existing campaign-evidence suite. They cover
exact role schemas and cross-bindings, self-consistent forged manifests,
eight-epoch joins, pre-arm/ARM ordering, single spawn/no retry, fragmented or
duplicate prompt, echo-state rejection, credential sentinel non-retention,
three-frame FD 3 ordering, authenticated bundle reconstruction, cancellation
and mandatory teardown. The existing campaign-harness suite is run unchanged as
a regression. Structural/mutation assertions live in the existing Investigation
boundary and aggregate contract scripts rather than adding another test file.

Validation is strictly: structural source/mutation gates, focused campaign and
affected driver/coordinator suites, one staged-only serialized Investigation
regression, existing Debug/Release component/final-image gate, then independent
review. The already completed 911-test b2b serial is not repeated as a separate
run. No root/install/sudo/real campaign occurs until this full non-privileged
pre-arm funnel is green. `scripts/verify --full` remains reserved for L3c4.
