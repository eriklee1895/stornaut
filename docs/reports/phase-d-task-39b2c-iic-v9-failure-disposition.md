# Phase D Task 39B2c ii-c-c v9 failure disposition

> Status: verified consumed failure / non-admitting / non-retryable
>
> Date: 2026-09-07
>
> Frozen campaign: `fd4bac12-d40d-4470-b6d2-7dcd0f1661d0`
>
> Frozen attempt: `b856e976-e74a-4f6d-9079-0d6859fab67d`
>
> Historical status note: the user later authorized one independent v10
> campaign; this does not alter or permit reuse of any v9 evidence.
> The current v5 receipt preserves the byte-identical v3 receipt and binds the
> later v10 Gate residue without treating it as v9 success evidence.

## Result

The authorized v9 campaign is consumed and rejected as
`consumedDriverExecutionPolicyDenial`. Its durable event chain is exactly:

```text
prepared -> armedConsumed -> spawnUncertain -> terminal
```

The fixed App/helper/driver/Gate/coordinator topology was installed and the
operator completed the exact driver authorization prompt. The driver execution
did not produce a valid Gate/coordinator receipt. Cleanup removed the fixed App,
plist and launchd service, but the owner-private Gate base retains the exact
consumed attempt capsule. No evidence file or Gate residue was modified during
this disposition.

Because `armedConsumed` is durable, v9 cannot be retried and this repository may
not create v10 without a new explicit user authorization. v9 does not admit
ii-c, ADR 0018, L3c3d, L3c4, Task 39 or production Deep Dive.

## Root cause

The macOS unified log recorded `amfid` rejecting the fixed installed driver at
`2026-09-07T01:31:20.854626Z` with
`AppleMobileFileIntegrityError` code `-423`: the executable was ad-hoc signed or
used an unknown certificate chain. The installed artifact SHA-256 was
`e748a5171481a70e44864a4a9d8e6cd19d19d539bbd2731fff2f30be8633b676`,
its fixed signing identifier was
`com.eriklee.stornaut.investigation.machine-driver`, and its signature retained
the restricted `com.apple.application-identifier` entitlement.

The evidence timestamps independently place `armedConsumed` 25.623 seconds
before `spawnUncertain`; the driver prompt attestation records both prompt and
human action observed with zero retained credential bytes. The failure therefore
occurred after authorization, at the operating-system execution-policy boundary,
not during lifecycle install, prompt matching or credential capture.

## Preserved evidence

The checked receipt binds the nine existing evidence files, the exact source
commit `55c574d21449ca38838ee6b219c219e6671fe5b9`, tree
`da258decb2e12fd7c935a502090ef5fff125beb8`, build/runtime binding, all four
events and the then-current owner-private Gate residue:

```text
attempt-b856e976-e74a-4f6d-9079-0d6859fab67d/
  projected-cohort-c4e325d6a26ffb7b9eb074bd665d9fd7b84a2efe85c1e0b748486bce974b30eb.bin
```

At the original v2 disposition checkpoint, the capsule was 28,997 bytes with SHA-256
`74be60f6fab16aba9e73fc090bbcf6c38def74726473b8ddc61ca5d7b84459f8`.
The fixed App root, launchd plist, runtime root, service and fixed processes are
absent. This current observation does not substitute for missing durable
uninstall/global-teardown evidence.

The privacy-safe checked receipt is
[`task-39-iic-v9-failure-disposition.json`](evidence/task-39-iic-v9-failure-disposition.json).
It contains hashes and typed facts only, not credentials or raw model content.

## Post-disposition test mutation

During the later non-privileged `swift test --no-parallel` validation, the
historical `userOwnedTemporaryGateFailsClosedBeforeSpawn` physical fixture used
the fixed production Gate base. Its publisher classified the consumed v9 attempt
as stale and removed the exact attempt directory and capsule before creating and
settling its own fixture attempt. The serial run then failed the checked v9 test
with `consumed Gate attempt absent`. The Gate base ctime/mtime changed at
`2026-09-07T09:57:23Z`; the original owner-lock inode remains unchanged.

No exact capsule copy, deleted-open descriptor or Data-volume snapshot was
available after bounded recovery searches. The original v2 receipt remains
preserved byte-for-byte as
[`task-39-iic-v9-failure-disposition-before-test-mutation.json`](evidence/task-39-iic-v9-failure-disposition-before-test-mutation.json)
with SHA-256
`9a1af7d3c2750429b660be92805bb5f51b43da75360cfc05618899dd34b44252`.
The historical v3 receipt binds the remaining nine campaign artifacts, the
original Gate residue name/size/hash, the v2 receipt hash and the then-current
owner-lock-only physical state. It does not claim capsule recovery or successful
campaign cleanup. The incident does not change v9's
consumed/non-admitting/non-retryable classification, but it invalidates any
claim that the original Gate residue still exists.

After the independently authorized v10 attempt, the Gate base is no longer
owner-lock-only: it contains only the owner lock and v10's preserved consumed
attempt. The byte-identical v3 receipt is retained as
`task-39-iic-v9-failure-disposition-before-v10.json` at SHA-256
`f99206e49db2b9dde0b55e9c1f567875fb39cfb2b5d506c56712bd296a512fac`.
The current v5 receipt binds that predecessor and v10's current attempt/capsule;
the repository boundary gate separately pins v10's checked disposition. v10
residue is explicitly not evidence of v9 cleanup or success.

The physical fixture is now opt-in only and performs a discovery-time check
plus a second check immediately before `fixture.run(.success)` that the fixed
Gate base contains no preserved attempt. Structural mutation coverage pins both
guards and their ordering around fixture construction and execution.

The checkpoint's sole `swift test --no-parallel` run completed 1,932 tests in
99 suites with one issue: the checked v9 case correctly rejected the missing
attempt as `consumed Gate attempt absent`. The run was not repeated. After the
v3 disposition and fixture isolation repair, the exact v8/v3 checked cases,
the pure enablement case, the explicitly opted-in physical case with identical
before/after Gate-base inventory, and the focused source/disposition gates all
passed. This is an exact-case closure of the one serial issue, not a claim that
the original serial was green.

## Repair status and remaining gate

The local root-cause repair disables entitlement generation only for the
diagnostic MachineDriver Debug/Release target. Tests-first RED reproduced the
missing settings. After the repair, focused tests, structural source admission,
the real Debug diagnostic App build and the complete ii-c-a Debug/Release
component boundary passed; final MachineDriver artifacts keep the fixed signing
identifier and ad-hoc CodeDirectory while exposing zero entitlement bytes.

Independent review then found one P2 in the failure verifier: on an account
where the fixed Gate base did not exist, the v1 observation produced `absent`
instead of the closed receipt state `ownAttemptAbsent`. The verifier now
normalizes a missing Gate base only for v1 and rejects that condition for
residue-bearing profiles. The current v5 receipt preserves the v2/v3 chain and
binds the later v10 attempt without treating v10 residue as v9 evidence. The
frozen v9-v2 receipt remains byte-identical at SHA-256
`9a1af7d3c2750429b660be92805bb5f51b43da75360cfc05618899dd34b44252`.

This source repair is non-admitting. The separately authorized v10 campaign is
also consumed/non-admitting/non-retryable after deadline exhaustion. Until a
newly authorized replacement succeeds, L3c3d/L3c4 remain unproven, the authoritative
full verifier remains reserved, Task 39 remains incomplete, Task 40 stays
blocked and production Deep Dive remains unavailable.
