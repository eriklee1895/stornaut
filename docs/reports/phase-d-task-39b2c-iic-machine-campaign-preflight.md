# Phase D Task 39B2c ii-c Machine Campaign Preflight

> Status: frozen / ii-c-a and ii-c-b1 complete/non-admitting / ii-c-b2 current/non-admitting
>
> Date: 2026-08-30
>
> Baseline: `2b30a157c14bc507351b10bd521e710987860f71`
>
> Remaining order: ii-c-b2 -> ii-c-c -> L3c3d -> L3c4

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

The policy probe is exactly `/usr/bin/sudo -kNnv`; zero exit blocks before arm,
while nonzero is only a necessary condition. The privileged argv is exactly:

```text
/usr/bin/sudo -kN -p 'Stornaut Task 39 ii-c administrator authorization: ' -- /Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautInvestigationMachineDriver
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
