# Phase D Task 39B2c ii-c persistent Gate P2 review

> Status: implementation complete / non-admitting
>
> Date: 2026-09-10
>
> Baseline: `188d40e394a0205bcffd0718050421b09dffb071`
>
> Implementation: `783770515ac20d364ac698f7f4a291422606d71f`
>
> Tree: `06c8454f54c99dcb1d76637d13706d85c102ba9d`

## Result

P2 closes the future lock-only machine-admission evidence contract without
reconstructing or migrating the lost v11/v12 cache capsule. Future complete
cohorts emit global-post-teardown schema v3, binding the exact persistent Gate
relative path, base and lock device/inode/generation identities, one-entry
inventory, zero-byte lock and an acquired exclusive nonblocking lock. Schema v1
and v2 remain strict compatibility readers and can never admit a cohort.

The fixed future Gate is now persistent infrastructure at:

`~/Library/Application Support/com.eriklee.stornaut.task39-machine-gate`

The aggregate positive fixture creates the Gate only when absent. First creation
uses a same-filesystem private staging directory, descriptor-relative `0700`
directory creation, `O_CREAT | O_EXCL | O_NOFOLLOW_ANY | O_RESOLVE_BENEATH |
O_UNIQUE` lock creation with mode `0600`, held/named identity checks, strict
type/owner/mode/link/size/inventory checks and `fsync`. It publishes with
`renameatx_np` using `RENAME_EXCL | RENAME_NOFOLLOW_ANY |
RENAME_RESOLVE_BENEATH`, then revalidates both identities and the inventory. A
physical destination-symlink attack is rejected without changing the `0644`
target. The fixed Gate is not deleted after validation, avoiding a final-path
directory-removal race and matching the production persistent-infrastructure
contract.

## Scope

The implementation changed exactly eight non-document paths with 1,556 changed
lines, below the 14-path / 4,000-line checkpoint ceiling:

- campaign producer and persistent Gate observer;
- strict Swift evidence decoder;
- coordinator composition;
- campaign and target-boundary tests;
- independent machine-report verifier;
- Investigation boundary verifier;
- aggregate contract verifier.

No product UI, production Deep Dive availability, cleanup/Executor authority,
network policy or model selection changed.

## Validation

- `scripts/verify-investigation-boundaries
  --iic-c-preserved-capsule-contract-only`: exit 0.
- `scripts/verify-investigation-boundaries
  --iic-c-prearm-failure-source-contract-only`: exit 0.
- `scripts/verify-contract --iic-c-contract-only`: exit 0, including resealed
  semantic mutations, physical first-create, destination-symlink rejection and
  the schema-v3 positive verifier.
- `scripts/verify-app-release-boundaries
  --iic-b2b2-component-boundary-only`: exit 0 for Debug and Release campaign
  binaries. The gate was run non-interactively; no credential was entered and
  no privileged install occurred.
- Final frozen-tree `swift test --no-parallel`: 1,964 tests / 100 suites,
  zero failures, 217.635 seconds.
- `git diff --check`: exit 0.
- Machine-report verifier SHA-256:
  `06b9c7012e2884db6d50eb620b255247466922ddea9cfd31afb97739cb569dc4`.
- Aggregate verifier SHA-256:
  `91b11a38200efb379be91df76b45b16085199d4edb00fa1a5ae2f0a37cabbb5f`.

The persistent Gate was observed as UID/GID `501:20`, base mode `0700`, lock
mode `0600`, zero-byte single-link lock on the same device, and the historical
Caches Gate remained absent. No staging entry remained.

## Review closure

Independent runtime and verifier reviews found and closed the following issues:

- schema-v3 Swift decoding initially omitted the base/lock same-device join;
- verifier mutations initially failed on stale self-seals instead of their
  semantic invariant;
- schema-v2 compatibility assertions still expected the old pre-v3 rejection
  text instead of the new read-only/non-admitting result;
- descriptor and directory-stream close failures were not uniformly dominant;
- the first positive-fixture cleanup attempted a path-based directory removal,
  leaving a rename/replacement TOCTOU;
- a later persistent-base design still used path-based `touch`/`chmod` on first
  lock creation, allowing a symlink-follow race.

The final implementation removes Gate deletion entirely and uses the atomic
staging publisher above for first creation. Both reviewers report no unresolved
P0–P2.

## Admission boundary

P2 is complete but intentionally non-admitting. It ran no sudo, root install,
App/helper campaign, real model, network diagnostic or authoritative full
verifier. Historical campaigns v8 through v12 remain consumed, non-admitting
and non-retryable. The next legal step is one newly authorized privileged
replacement campaign bound to implementation commit `7837705`; only a green
cohort may unlock L3c3d, then L3c4. Task 40 remains blocked.
