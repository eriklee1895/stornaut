# Phase D Task 39B2c L3c3c-ii-b5b-i-c2b Review

> Status: complete / non-admitting
> Date: 2026-08-22
> Aggregate baseline: `58332ccb9f78da203fb2380ca006c49f0f371c2b`
> Next frontier: ii-b5b-ii fixed Darwin epoch runtime

## 1. Result

i-c2b closes the remaining duplicate physical installed-evidence path. The
post-teardown topology path is now absence-only: it can prove that the eight
fixed artifacts, the exact captured App/helper identities and the fixed service
are gone, but it cannot reread or reinterpret installed signing, manifest, hash
or executable evidence. `StornautInvestigationInstalledL2` remains the sole
physical installed-evidence owner, joined once by DriverSupport.

The original two-file verifier closure grew beyond its frozen 800-line budget
after independent review required complete anti-bypass coverage. It was split
before commit into two one-file checkpoints. The completed chain is:

| Checkpoint | Commit | Parent | Tree | Scope | Changed lines |
| --- | --- | --- | --- | ---: | ---: |
| i-c2b-i implementation/tests | `773a91f81d644071dfc5a4d22dac77bb9bf5b576` | `fd101f85ef33091d293246a5962cdc337a80a818` | `d176dd09a9bec261849c2180c5e54e72699aa3a5` | 10 paths | 3,728 / 3,800 |
| i-c2b-ii-a boundary verifier | `0ae9214f371b4b9327b4b78c88d0eaa21eb55d5b` | `773a91f81d644071dfc5a4d22dac77bb9bf5b576` | `476340396a399213025fceee07768bbfa0986f00` | 1 path | 729 / 800 |
| i-c2b-ii-b contract replay | `06269bca03a5a7b2ca2319b8e029f3cecf7cc6de` | `0ae9214f371b4b9327b4b78c88d0eaa21eb55d5b` | `b0eee4bca2e9e0614178f6995d786c1c2511b4ce` | 1 path | 325 / 800 |

The aggregate semantic scope remains exactly the original twelve non-document
paths. Its combined size is intentionally not compared with the superseded
single-checkpoint 3,800-line cap; each recorded split checkpoint independently
satisfies its frozen ceiling.

## 2. Implemented Contract

- Artifact absence is proven only by one non-following `lstat` returning
  `ENOENT`. A present node, including a dangling symlink, remains present; all
  other errors remain unavailable.
- Process absence is proven only by `ESRCH`. Exact identity remains alive; a
  same-PID mismatch is classified as identity reuse; a different returned PID
  or another error remains unresolved.
- Post-teardown proof requires all eight fixed artifacts absent, both captured
  process identities absent or reused, and the fixed service absent.
- The collector validates the claim before transition, preserves the
  transition-before-observation barrier, rechecks root/deadline state and
  remains one-shot across success, failure and cancellation.
- The recorded helper identity is equal to the attested XPC peer across PID,
  PID version, audit session, effective UID and all audit-token words before
  any transition.
- No positive installed-state reader, signing/hash/manifest reconstruction or
  second physical installed-evidence owner remains in Lifecycle or Machine.

## 3. Validation

- Tests-first RED: one boundary test compiled and failed with 28 issues spanning
  the three planned residual-owner categories.
- Final clean staged focused gate: 73 tests in six suites passed.
- Final clean staged affected gate: 632 tests in 53 suites passed.
- The checkpoint's sole staged-only serialized regression passed 1,344 tests
  in 69 suites with the five maximum benchmarks skipped. This run preceded the
  later dangling-symlink correction and helper identity equality fix; those
  changes were closed by exact tests, the final focused/affected gates and fresh
  independent review. The serial was not repeated.
- Exact post-review regressions passed for the dangling-symlink `lstat` case and
  the mismatched recorded/peer helper identity case.
- `scripts/verify-investigation-boundaries` passed, including authority-closed
  Debug and Release Machine-driver binary checks.
- `scripts/verify-contract` passed with historical parent/tree/path/budget
  checks, staged-index isolation, the exact twelve-path aggregate replay and
  semantic mutation controls.
- `git diff --cached --check` and both zsh syntax checks passed before each
  verifier commit.

## 4. Review Closure

Independent reviews found and closed: the dangling-symlink `stat`/`lstat` test
gap, incomplete claim/helper-peer identity revalidation, aggregate baseline and
worktree/index mixing, obsolete positive-L2 assertions, classifier and upstream
adapter early-return aliases, observer/collector control-flow relocation,
process-proof/accessor drift and custom equality overrides. The final
implementation, boundary-verifier and contract-replay reviews report no
unresolved P0-P2 findings.

The final verifier pins the complete relevant production sources plus the
canonical installed owner/join, while retaining granular diagnostics and
mutation controls. Root `AGENTS.md` and `docs/**` are excluded from the
aggregate implementation path set; every other additional non-document path is
rejected.

## 5. Non-Claims and Next Step

i-c2b did not run `scripts/verify --full`, install or launch the App/helper,
invoke real XPC, use sudo/root, read Codex auth, call a model or access a
network. It makes no readiness or product-availability claim. ADR 0018 remains
Proposed and production Deep Dive remains `.implementationUnavailable`.

Aggregate i-c2 is complete/non-admitting. The next checkpoint is a fresh
scope/cost preflight for ii-b5b-ii fixed Darwin epoch runtime, followed by
ii-b5b-iii production/artifact composition, ii-c0, the single no-model
privileged ii-c gate, L3c3d real authenticated success and L3c4 final admission.
