# Phase D Task 39B2c ii-c Resolved Root-Driver Lineage Preflight

> Status: frozen / L1 complete / L2 implementation current / non-privileged / non-admitting
>
> Date: 2026-09-01
>
> Baseline: `81a747e43e90f7ca3f941fa2e6aefd171eab470a`
>
> Remaining order: L2 composition -> ii-c-c unique machine
> campaign -> L3c3d -> L3c4

## Decision

The completed evidence-verification prerequisite proves that all eight epochs
name one stable `outerDriverProcessID`. It does not prove that this PID is the
exact fixed root driver descended from the Gate's `/usr/bin/sudo` cohort. Stock
macOS sudo may exec in place or insert one or more PTY/monitor descendants. The
invalid assertion `Gate direct sudo child == root driver parent` is forbidden.

The accepted model has two identities and one explicit resolution:

```text
InitialSudoLaunchIdentity
  -> zero or more same-cohort sudo descendants
  -> ResolvedRootDriverIdentityV1
  -> eight per-epoch driver children
  -> complete cohort retirement
```

`InitialSudoLaunchIdentity` remains the exact waitable child returned by
`posix_spawn(/usr/bin/sudo)`. `ResolvedRootDriverIdentityV1` is the driver that
the Gate resolves while it is alive and stopped before business execution. The
driver parent PID is evidence only; it is never required to equal the Gate or
the initial sudo PID.

## Data Channel and Schema Decision

The root driver must write one strict self-sealed lineage claim before any epoch
work and stop itself immediately after the complete claim is committed to its
existing stdout pipe. The Gate already exclusively owns that pipe. It reads the
exact bounded claim, observes the claimed process while stopped, validates its
kernel, audit, executable and signing identity, then continues the owned group.
Only afterward may the existing eight-epoch completion be written.

The raw Gate transport and final coordinator receipt schemas remain unchanged.
The Gate hashes the complete child output bytes, so the existing authenticated
raw receipt already binds the lineage claim plus completion. CampaignSupport and
the independent verifier reconstruct the exact output bytes as:

```text
4-byte big-endian claim byte count
canonical lineage claim bytes
driver-completion-v3 bytes
```

`driver-completion-v3` binds the lineage-claim SHA-256 and evidence-bundle
SHA-256. The coordinator changes only its expected output byte count. The Gate
transport receipt remains the authoritative output length/digest and physical
retirement record; the final coordinator receipt continues to bind its digest.

This avoids a Gate/final-receipt migration while still making every lineage byte
independently reconstructible. Claim bytes are never selected from argv,
environment, capsule paths or mutable external files.

## Canonical Lineage Contract

The claim is one canonical binary transcript with a self-hash and fixed maximum.
It binds the outer attempt UUID and whole projected-input SHA-256, then carries:

- PID, pidversion, start seconds/microseconds, PPID, PGID and Unix SID;
- audit session ID and all eight audit-token words;
- real/effective/saved UID and GID plus the bounded supplementary group vector;
- exact fixed driver path; stable executable node identity and SHA-256;
- static/live signing identifier, designated-requirement SHA-256, CodeDirectory
  hash and ad-hoc flag; and
- claim-observed monotonic time and the canonical self-hash.

The Gate validates two stable process samples around live signing and fixed-node
observation. Root real/effective/saved IDs and groups must be exact. The audit
token must repeat PID, pidversion, ASID and EUID. The process must be a member of
the Gate's owned recovery PGID and coordinator Unix SID. Live signing uses the
claim's audit token with `kSecGuestAttributeAudit`; PID-only fallback is
forbidden. Fixed path/node/SHA/static signing must match every installed-L2
projection in the sealed cohort.

Resolution permits exactly two kinds:

1. `execContinuity`: the initial sudo PID/start identity became the driver; or
2. `containedSuccessor`: the driver is a bounded descendant of the initial sudo
   launch within the same owned PGID/SID.

The descendant chain is acyclic, has unique PID/start identities, includes the
initial sudo launch and ends at the resolved driver. Every edge is sampled while
both adjacent nodes are observable. A disappeared or reparented intermediate
that prevents this proof is uncertainty, not an inferred success.

After terminal output, the existing exact initial-child wait/reap and complete
recovery-group empty proof remain mandatory. PID reuse is compared by
PID+pidversion+start identity: a reused PID is not the original process, but the
new process must not be admitted into the old cohort.

## Frozen Implementation Split

The complete closure is estimated above one checkpoint's 4,000-line limit, so it
is frozen once as two implementation checkpoints. No third prerequisite or
recursive split is permitted.

### L1 — Contract, Collector and Pure Validator

L1 may change exactly these eleven non-document paths and at most 3,900
changed non-document lines:

1. `Package.swift` — 20;
2. `Sources/StornautInvestigationHandoffContract/InvestigationResolvedRootDriverLineageContract.swift` (new) — 520;
3. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineResolvedRootDriverClaim.swift` (new) — 520;
4. `Sources/StornautInvestigationMachineGateSupport/InvestigationMachineResolvedRootDriverValidator.swift` (new) — 700;
5. `Tests/StornautInvestigationTests/InvestigationResolvedRootDriverLineageContractTests.swift` (new) — 480;
6. `Tests/StornautInvestigationTests/InvestigationMachineResolvedRootDriverClaimTests.swift` (new) — 420;
7. `Tests/StornautInvestigationTests/InvestigationMachineResolvedRootDriverValidatorTests.swift` (new) — 600;
8. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift` — 80;
9. `scripts/verify-investigation-boundaries` — 350;
10. `scripts/verify-contract` — 140; and
11. `scripts/verify-app-release-boundaries` — 80.

L1 owns canonical encode/decode, injected driver self-observation/claim creation,
injected Gate validation, direct/one-monitor/two-monitor resolution, PID-reuse
and retirement semantics. It does not add a production seam, connect the claim
to startup, read from a real Gate pipe, run sudo or alter any transport/receipt
schema.

### L2 — Driver/Gate State Machine and Evidence Composition

L2 starts from the pushed L1 tree and may change exactly these fourteen
non-document paths and at most 3,950 changed non-document lines:

1. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineZeroArgumentEntry.swift` — 350;
2. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDriverSupport.swift` — 30;
3. `Sources/StornautInvestigationMachineGateSupport/InvestigationMachineGateTransport.swift` — 260;
4. `Sources/StornautInvestigationMachineGateSupport/InvestigationMachineFixedGateLauncher.swift` — 300;
5. `Sources/StornautInvestigationMachineGateSupport/DarwinInvestigationMachineFixedGateSystem.swift` — 350;
6. `Sources/StornautInvestigationMachineCampaignSupport/InvestigationMachineCampaignEvidenceContract.swift` — 250;
7. `Sources/StornautInvestigationMachineCampaign/main.swift` — 180;
8. `Tests/StornautInvestigationTests/InvestigationMachineZeroArgumentEntryTests.swift` — 350;
9. `Tests/StornautInvestigationTests/InvestigationSudoShapedDriverLauncherTests.swift` — 550;
10. `Tests/StornautInvestigationTests/InvestigationMachineCampaignEvidenceTests.swift` — 400;
11. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift` — 60;
12. `scripts/verify-investigation-runtime-machine-report` — 300;
13. `scripts/verify-investigation-boundaries` — 350; and
14. `scripts/verify-contract` — 200.

L2 owns claim-before-business startup, self-stop, exact claim read, Gate live
validation, group continuation, completion-v3 reconstruction, epoch-parent join,
raw-receipt output digest join and independent Python replay. The existing
non-root sudo-shaped fixture must exercise exec-continuity and contained-
successor shapes. It must not execute `/usr/bin/sudo`.

## Explicit Boundaries and Non-Claims

- No root operation, sudo, install/uninstall, launchctl mutation, real campaign,
  model/auth/network operation or `scripts/verify --full` occurs in L1 or L2.
- The unique privileged attempt remains unconsumed.
- `Package.swift` may add only the authority-free contract dependency needed by
  GateSupport; Security stays in existing package-only targets. No product/Xcode
  target gains lineage or signing authority.
- DriverSupport and GateSupport remain independent; neither imports Core,
  Execution, CampaignSupport or product targets.
- Gate and final coordinator wire schemas remain unchanged.
- Existing evidence-verification checkpoint commit/tree and historical replay
  remain immutable.
- Production Deep Dive remains unavailable, Task 39 remains incomplete and ADR
  0018 remains Proposed.

## Tests and Gates

Both checkpoints follow structural -> one combined focused command -> one
staged-only serialized Investigation regression when required -> applicable
component/final-image gate -> independent review. The aggregate contract does
not duplicate the component build. L1 and L2 each get their own exact staged
scope gate and baseline.

Required mutations include canonical framing/trailing bytes/self-hash; attempt
and whole-input drift; PID/pidversion/start/PPID/PGID/SID/ASID/audit-token
drift; non-root IDs/groups; path/node/SHA/signing drift; chain gap/cycle/duplicate
and unrelated sibling; exec-continuity versus one/two monitor success; missing or
duplicate claim; claim without stopped driver; epoch outer-parent mismatch;
completion lineage-digest drift; raw-output digest drift; live residue; and
PID reuse.

L1 focused validation is one command covering the three new suites and affected
zero-argument/boundary tests. L2 focused validation is one command covering
zero-argument, sudo-shaped Gate, campaign evidence and target-boundary suites.
No headless or full verifier is run.

After L2 is implemented, reviewed and pushed, the next action is the unique
ii-c-c machine campaign. No further design or implementation prerequisite may be
inserted.

## L1 Completion Update

L1 completed at implementation `83f6271ace2d52cc2ba170aae559a2d1fcc46864`
and accepted tree `98289e2b5764571b7a3a8a108d992905da6712ea`; historical
verifier replay compatibility followed at `cf4041c346c2703092ddc46e7b45769c29ff2ffb`.
The completion audit is
[phase-d-task-39b2c-iic-resolved-root-driver-lineage-l1-review.md](phase-d-task-39b2c-iic-resolved-root-driver-lineage-l1-review.md).
L2 is now the only active lineage checkpoint.

## L2 Scope Amendment — 2026-09-01

Tests-first implementation and physical-boundary review showed that the original
fourteen-path allocation put two required responsibilities in the wrong files.
`InvestigationMachineDriverSupport.swift` needs no change because the existing
zero-argument entry owns the driver startup state machine. In contrast, the
canonical output-size projection is owned by
`InvestigationMachineGateCoordinatorComposition.swift`, and the existing
non-root handoff fixture needs one narrow regression proving that the new live
path check fails closed before spawn. The original fourteen-path list in the L2
section is therefore superseded by this exact fifteen-path implementation scope:

1. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineZeroArgumentEntry.swift` — 950;
2. `Sources/StornautInvestigationMachineGateCoordinatorSupport/InvestigationMachineGateCoordinatorComposition.swift` — 30;
3. `Sources/StornautInvestigationMachineGateSupport/InvestigationMachineGateTransport.swift` — 320;
4. `Sources/StornautInvestigationMachineGateSupport/InvestigationMachineFixedGateLauncher.swift` — 300;
5. `Sources/StornautInvestigationMachineGateSupport/DarwinInvestigationMachineFixedGateSystem.swift` — 650;
6. `Sources/StornautInvestigationMachineCampaignSupport/InvestigationMachineCampaignEvidenceContract.swift` — 250;
7. `Sources/StornautInvestigationMachineCampaign/main.swift` — 180;
8. `Tests/StornautInvestigationTests/InvestigationMachineZeroArgumentEntryTests.swift` — 800;
9. `Tests/StornautInvestigationTests/InvestigationSudoShapedDriverLauncherTests.swift` — 550;
10. `Tests/StornautInvestigationTests/InvestigationMachineCampaignEvidenceTests.swift` — 400;
11. `Tests/StornautInvestigationTests/InvestigationFixedGateHandoffPhysicalTests.swift` — 60;
12. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift` — 60;
13. `scripts/verify-investigation-runtime-machine-report` — 300;
14. `scripts/verify-investigation-boundaries` — 350; and
15. `scripts/verify-contract` — 200.

The aggregate ceiling remains 3,950 changed non-document lines. The amendment
does not add a new prerequisite, authority surface or acceptance stage. It only
places already-required L2 behavior at its actual owners and reallocates the
unchanged aggregate budget after the shared terminal-deadline, live executable-
path and independent evidence-review findings. All explicit boundaries,
non-claims, validation ordering and the transition directly from accepted L2 to
the unique `ii-c-c` machine campaign remain unchanged.
