# Phase D Task 39B2c ii-c Resolved Root-Driver Lineage L2 Completion Audit

> Status: complete / non-privileged / non-admitting
>
> Date: 2026-09-03
>
> Implementation: `474f63455f7f962f5537fdd9f6d7e55e01242c51`
>
> Cross-UID correction: `b664299983a6311dde4ee6982f180ba9b7fab1ab`
>
> PID-reuse post-fix: `b4c632e68e2f28ef67b9734bce82dac61bdc7bed`
>
> Final verifier closure: `849e454de2cfd07f3d326e2a5df0c0a305678f0c`
>
> Accepted tree: `f6c36d2fb18f0a742e7ff26568e2eff67cc8784b`
>
> Next and only frontier: ii-c-c unique real machine campaign

## 1. Result

The L2 production and evidence composition is implemented. The zero-argument
driver emits the fixed framed `ResolvedRootDriverClaimV1` before business
execution, stops itself after committing that claim, and emits the 180-byte
completion-v3 only after the eight-epoch work completes. The Gate reads the
exact bounded claim, resolves and validates the stopped root driver, continues
the owned process group only after validation, and preserves exact retirement
proof.

CampaignSupport and the independent verifier reconstruct and bind the complete
driver output: the four-byte big-endian claim length, fixed 1,006-byte canonical
lineage claim and 180-byte driver-completion-v3. The evidence path joins these
bytes to the outer attempt, projected input, epoch parents, evidence-bundle
digest, Gate output digest and final receipt without changing the Gate or final
receipt schemas.

The first implementation was not accepted unchanged. It incorrectly required
the UID-501 Gate to obtain a UID-0 driver's audit token through
`task_name_for_pid`. The cross-UID correction uses public libproc/sysctl, BSM
and PID-based Security observation instead. PID version and all audit-token
words remain canonical driver-reported and sealed; the Gate does not claim to
observe them independently. The PID-reuse post-fix uses PID plus start identity
and does not confuse a new process at a reused numeric PID with the retired
lineage instance.

## 2. Exact Scope and Checkpoint Accounting

The review-driven corrections are separate frozen checkpoints, not one
retrospective diff against the original 3,950-line L2 ceiling.

| Checkpoint | Commit | Tree | Parent | Exact scope |
| --- | --- | --- | --- | --- |
| L2 state machine and evidence composition | `474f63455f7f962f5537fdd9f6d7e55e01242c51` | `13ce41f3957701daaca46a5613e40acfcc6224bb` | `cd8fc5d8645a8d40fb7571e4be41b8b9d1a70725` | 15 non-document paths / 3,797 changed lines |
| Cross-UID observation correction | `b664299983a6311dde4ee6982f180ba9b7fab1ab` | `8ac3c409e56b5216a2715ec5eb59d729302d849b` | `474f63455f7f962f5537fdd9f6d7e55e01242c51` | 5 paths / 412 changed lines |
| Safe PID-reuse post-fix | `b4c632e68e2f28ef67b9734bce82dac61bdc7bed` | `d099939defebc83374c0bdc8452f938d13aa90d4` | `b664299983a6311dde4ee6982f180ba9b7fab1ab` | 2 paths / 31 changed lines |
| Final verifier closure | `849e454de2cfd07f3d326e2a5df0c0a305678f0c` | `f6c36d2fb18f0a742e7ff26568e2eff67cc8784b` | `b4c632e68e2f28ef67b9734bce82dac61bdc7bed` | 3 paths / 393 changed lines |

The verifier review found one P1 mutation-oracle weakness. Commit `849e454`
fixed it, and the post-fix review of tree `f6c36d2` returned no finding.

## 3. Contract and Behavior Closure

The implementation closes claim-before-business ordering, exact self-stop, the
1,190-byte output projection, direct exec and one/two-monitor successor shapes,
public cross-UID live observation, PID-plus-start lineage and retirement, safe
PID reuse, exact claim/completion/evidence/output joins, epoch-parent binding,
independent reconstruction and historical replay. It does not infer lineage
from argv, environment, capsule paths or mutable external files, and it does
not require the initial sudo child to be the resolved driver's direct parent.

## 4. Validation Evidence

| Evidence | Result |
| --- | --- |
| L2 structural/source matrix | 8/8 passed |
| Cross-UID validator focused matrix | 8/8 passed |
| Sudo-shaped launcher focused matrix | 28/28 passed |
| Exact physical/boundary regression | 1/1 passed |
| Original L2 historical contract replay | exit 0 |
| Current cross-UID aggregate contract | exit 0 |
| Single clean staged-only serial invocation | 1,878 tests / 99 suites; failed with 27 issues under broad timing/process pressure |
| Exact low-load closure | seven targets, 109/109 passed: `12 + 22 + 23 + 16 + 6 + 1 + 29` |

The single clean staged-only serial invocation was **not green** and was not
rerun: 1,878 tests in 99 suites failed with 27 issues under broad timing/process
pressure, concentrated in pre-existing timing, process and performance suites.
The seven exact low-load target reruns all passed, 109/109. This audit records
the failed serial plus exact closure; it does not claim that the serial passed.

## 5. Review Findings and Closure

The independent source post-fix review returned no finding. The initial
verifier review found one P1: its mutation oracle did not prove rejection of
every required cross-UID contract mutation. Commit `849e454` fixed the oracle;
the final post-fix verifier review of tree `f6c36d2` returned no finding. There
are no unresolved P0–P2 findings for this checkpoint.

## 6. Non-Claims and Next Step

No L2 work or validation used root or `/usr/bin/sudo`, installed or uninstalled
the fixed service, launched the real campaign, called a model, used network
access or ran `scripts/verify --full`. The unique privileged attempt remains
unconsumed.

Task 39 remains incomplete, ADR 0018 remains Proposed and production Deep Dive
remains unavailable. The current and only frontier is the `ii-c-c` unique real
machine campaign, followed strictly by `L3c3d -> L3c4`; L3c4 alone owns final
admission and the remaining authoritative full verifier.
