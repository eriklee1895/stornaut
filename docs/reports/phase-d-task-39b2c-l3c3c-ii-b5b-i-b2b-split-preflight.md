# Phase D Task 39B2c L3c3c-ii-b5b-i-b2b Split Preflight

> Status: i-b2b-a/i-b2b-b complete/non-admitting; i-b3 current; completion
> evidence: [i-b2b-b review](phase-d-task-39b2c-l3c3c-ii-b5b-i-b2b-b-review.md)
> Date: 2026-08-21
> Parent scope: i-b2b process/service readers plus narrow C identity support

## 1. Decision

Fresh current-source and cost audits found that the original combined ten-path,
2,600-line i-b2b scope has a realistic range of roughly 2,140 to 2,990 changed
lines. The lower bound leaves no room for executable C-object authority gates,
concrete Security/ServiceManagement tests or review repairs. i-b2b is therefore
split before coding rather than weakening its evidence surface.

The split changes no product capability or admission order:

1. i-b2b-a extracts read-only process identity and process/live-signing
   observation;
2. i-b2b-b adds the fixed, non-activating launchd service reader; and
3. i-b3 still owns composition while i-c still owns the DriverSupport join,
   opaque proof and legacy-owner closure.

Both checkpoints are non-admitting. Task 39 remains incomplete, ADR 0018
remains Proposed and production Deep Dive remains implementation unavailable.

## 2. i-b2b-a Identity and Process Reader

Ceiling: exactly eight non-document paths and at most 1,900 changed lines.

1. Package.swift
2. Sources/CInvestigationIdentitySupport/CInvestigationIdentitySupport.c
3. Sources/CInvestigationIdentitySupport/include/CInvestigationIdentitySupport.h
4. Sources/StornautInvestigationInstalledL2/InstalledL2ProcessReader.swift
5. Tests/StornautInvestigationTests/InstalledL2ProcessReaderTests.swift
6. Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift
7. scripts/verify-investigation-boundaries
8. scripts/verify-contract

The new C target exposes one POD identity and one identity-for-PID function. It
may use task_name_for_pid, TASK_AUDIT_TOKEN and bounded proc_pidinfo only to
distinguish vanished from inaccessible processes. It must expose and import no
signal, stop, wait, launch, enumeration, write, socket or process-control
surface. In particular proc_signal_with_audittoken remains confined to the
existing mixed CLifecycleSupport target, which InstalledL2 must not depend on.

The Swift reader owns role-specific App/helper entry points and a fixed current
machine-driver live-signing entry point. It accepts typed identities, never a
caller-selected PID, path, label, requirement, descriptor or syscall. Its race
sandwich is:

identity 1 -> fixed path 1 -> audit-token-bound live signing -> fixed path 2 -> identity 2

Only an initial ESRCH may produce process absence. Mid-observation disappearance,
path/signing failure or malformed evidence is unavailable; complete identity
drift is identity reuse. Both identities and both paths must exactly match.
Dynamic and derived static code are strictly validated and retain identifier,
designated-requirement SHA-256, raw CodeDirectory hash and ad-hoc state.

Required gates include source/header and built-object symbol allowlists,
full-audit-token tests, concrete current-process signing, dropped-second-read,
PID-only comparison, path weakening, PID-based Security lookup, omitted flags,
vacuous-test and staged-scope mutations.

## 3. i-b2b-b Fixed Service Reader

Ceiling: exactly six non-document paths and at most 1,300 changed lines.

1. Package.swift
2. Sources/StornautInvestigationInstalledL2/InstalledL2FixedServiceReader.swift
3. Tests/StornautInvestigationTests/InstalledL2FixedServiceReaderTests.swift
4. Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift
5. scripts/verify-investigation-boundaries
6. scripts/verify-contract

This checkpoint adds ServiceManagement.framework only. It uses the fixed plist,
label and service identifiers already owned by InstalledL2FixedPaths. It does
not invoke launchctl, bootstrap, bootout or kickstart and cannot activate a
service.

Absence requires two consistent structured samples in which the job is missing
and registration is notRegistered or notFound. Loaded evidence requires:

fixed registry 1 -> complete helper identity 1 -> complete helper identity 2 -> fixed registry 2

Both registry samples must be enabled, bounded, exact-label records containing
the expected helper PID. Missing PID, approval-required/unknown status,
contradictory samples, restart/PID reuse, malformed dictionaries or any lookup
failure remains unavailable. The reader emits only absent, loaded with the
complete expected helper identity, or unavailable. i-b3 performs the later
service/process/artifact/clock join.

## 4. Threat Model and Validation

Neither process nor service sampling is an atomic kernel snapshot. The paired
samples detect ordinary exit, exec, PID reuse, restart and signing drift. An
A-to-B-to-A exchange by a concurrent privileged writer is a residual outside
ADR 0018's serialized trusted-local-operator threat model; no checkpoint may
describe these observations as race-free or descriptor-bound.

Each child checkpoint follows structural, focused, affected, one staged-only
serial attempt, applicable object/artifact gates and independent review. No
child runs App/helper/XPC, install, sudo/root, model/auth/network or scripts/verify
--full. Only L3c4 owns readiness, final admission and the remaining full run.

## 5. Strict Order

i-b2b-a -> i-b2b-b -> i-b3 -> i-c -> ii-b5b-ii -> ii-b5b-iii -> ii-c0 -> ii-c -> L3c3d -> L3c4
