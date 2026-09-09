# Phase D Task 39B2c ii-c-c v12 failure disposition

> Status: consumed / non-admitting / non-retryable
>
> Date: 2026-09-09
>
> Frozen source: `212320fa9f05cad52a40fb9ce02ed7bf73543b04`
>
> Campaign: `2aca496d-83c7-4ab3-8ef4-f433ce9ea493`
>
> Attempt: `9d713dd7-30b4-49a5-96b1-9afdf482f1c2`

## Result

The one authorized v12 invocation durably recorded exactly `prepared →
armedConsumed → spawnUncertain`. It produced eight bounded artifacts and no
driver epoch, coordinator receipt, diagnostic output, manifest, external seal,
uninstall record or global post-teardown record. The attempt is classified as
`consumedPostArmAuthorizationDeadlineExhaustion`; admission is rejected and retry is
forbidden.

The arm event was recorded at UTC microsecond `1788918410396173`; the
`spawnUncertain` event was recorded at `1788922001861654`, an elapsed
`3,591,465,481` microseconds. That exceeds the configured 1,400-second campaign
horizon. The exact schema-v2 failure reason is
`postArmFailure/transportUncertain/wait-unavailable/receipt-open/terminal-open/cleanup-1e`.
The human attestation records the fixed prompt and operator action with zero
retained credential bytes. Source control flow establishes that the old
post-arm authorization path contained two operations without an enforced
operation deadline: the fixed prompt relay and the subsequent
`readpassphrase` call. The durable timeline cannot distinguish which operation
accounted for the elapsed interval. It therefore supports only the bounded root
cause `unboundedPostArmAuthorizationPathExceededCampaignDeadline`; it does not
establish whether the entered credential was valid or attribute the delay to a
specific operation.

## Gate residue loss

At `2026-09-09T04:12:03Z`, the read-only failure verifier successfully joined
the exact v12 attempt/capsule and preserved v11 attempt/capsule in the fixed
Gate base. Their byte counts and SHA-256 values are retained as a prior
observation in the checked disposition. At `2026-09-09T04:19:28Z`, the same
verifier first observed that the entire Gate base was absent. Searches of the
user cache tree, temporary directories, Trash, Spotlight inventory and open
unlinked files found no recoverable copy.

No command or unified log establishes which process removed the directory. The
credential-focused test executed one selected test and only created and removed
its own system-temporary fixture. A separate disk-cleanup session started after
the absence was first observed. The machine was under disk pressure and the
Gate was stored under `~/Library/Caches`, so system cache eviction is compatible
with the observation, but it is not claimed as the cause. The checked record
therefore states `externalGateCacheResidueLost` with
`unattributedExternalRemoval`; it does not recreate either capsule or present
their earlier hashes as live evidence.

This exposes a distinct persistence-design defect: security-critical campaign
residue cannot rely on a purgeable cache location. Moving future Gate state to
an owner-private Application Support location is a separate prerequisite before
any new privileged campaign.

## Remaining gate

The v12 durable evidence tree remains intact and is independently verifiable.
The missing Gate residue prevents v12 from satisfying machine admission and
does not permit reuse of its attempt. L3c3d, L3c4, Task 39 readiness, Task 40
and production Deep Dive remain blocked. Any v13 campaign requires a new
explicit authorization after the credential-deadline and persistent-Gate
repairs are independently reviewed and pushed.
