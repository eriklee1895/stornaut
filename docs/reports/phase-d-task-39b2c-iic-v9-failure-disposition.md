# Phase D Task 39B2c ii-c-c v9 failure disposition

> Status: verified consumed failure / non-admitting / non-retryable
>
> Date: 2026-09-07
>
> Frozen campaign: `fd4bac12-d40d-4470-b6d2-7dcd0f1661d0`
>
> Frozen attempt: `b856e976-e74a-4f6d-9079-0d6859fab67d`

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
The current v3 receipt binds the remaining nine campaign artifacts, the original
Gate residue name/size/hash, the v2 receipt hash and the current owner-lock-only
physical state. It does not claim capsule recovery or successful campaign
cleanup. The incident does not change v9's consumed/non-admitting/non-retryable
classification, but it invalidates any claim that the original Gate residue
still exists.

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
normalizes a missing Gate base only for v1 and rejects the same condition for
v2/v3. A test executes the extracted production `observe_system()` against a
nonexistent path for all three profiles and confirms that it creates no node.
The final read-only verifier self-seal is
`8b0e9eecbf0846e663a86c3781e077880df7294cdf6a934572f266e82135bfc0`;
its executable SHA-256 is
`848955e1ea62e194990163558f8217c47ad28b85bd4a8a6d1de0660b35ef40e1`.
Both current v8 and v9-v3 evidence checks, the failure-disposition structural
gate and 145 focused tests across four suites passed. A fresh independent
read-only review reported no actionable regressions. The frozen v9-v2 receipt
remains byte-identical at SHA-256
`9a1af7d3c2750429b660be92805bb5f51b43da75360cfc05618899dd34b44252`.

This source repair is non-admitting. A new replacement privileged campaign
requires separate user authorization, a fresh campaign/attempt UUID and a fresh
evidence root. Until it succeeds, L3c3d/L3c4 remain unproven, the authoritative
full verifier remains reserved, Task 39 remains incomplete, Task 40 stays
blocked and production Deep Dive remains unavailable.
