# Phase D Task 39B2c ii-c-b1 Root-Owned Gate Completion Audit

> Status: complete / non-admitting
>
> Date: 2026-08-31
>
> Implementation: `77cde61b8c09e739ab5268531e83bcd333dcdc28`
>
> Parent: `d120b0344c786557122b152dffdfcf02276216c8`
>
> Tree: `9c59f241ffbfc6bc6c2a6810a9a0ce2c57b23c4b`
>
> Next frontier: ii-c-b2 non-privileged PTY/FD3/raw-evidence campaign harness

## 1. Result

ii-c-b1 is complete and remains non-admitting. The fixed Gate executable is
now accepted only when its file identity is exactly `root:wheel` (`UID 0 / GID
0`). Gate and Coordinator process identity remains independently fixed at
`UID 501 / GID 20`; there is no root-or-current-user fallback.

Acquisition, pre-spawn revalidation and post-spawn revalidation all retain the
same closed checks for sibling path, held/named node identity, mode `0755`, one
hard link, flags zero, empty ACL, the sole allowed `com.apple.provenance` xattr
and descriptor-byte SHA-256. A post-spawn ownership drift enters the bounded
kill/reap uncertainty path rather than producing success evidence.

The non-root physical fixture does not manufacture root ownership. It proves
that a real temporary Gate owned by `501:20` fails before spawn with
`spawnFailedBeforeTransfer`, creates no Gate PID or PGID, restores foreground
control, removes the owner-only capsule and leaves no attempt residue. The
former seven-scenario user-owned physical matrix remains immutable historical
evidence at `373431d4` / tree `b08342e5`; it is not presented as current
root-owned success evidence.

## 2. Exact Scope

The implementation changes exactly seven non-document paths and reaches the
frozen ceiling exactly: 1,785 additions plus 115 deletions, or 1,900 changed
lines.

1. `Sources/StornautInvestigationMachineLaunchSupport/InvestigationFixedGateDarwinLifecycle.swift`
2. `Tests/StornautInvestigationTests/InvestigationFixedGateDarwinLifecycleTests.swift`
3. `Tests/StornautInvestigationTests/InvestigationFixedGateHandoffPhysicalTests.swift`
4. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
5. `scripts/verify-app-release-boundaries`
6. `scripts/verify-contract`
7. `scripts/verify-investigation-boundaries`

No package, Xcode topology, public API, schema or product-authority path was
added.

## 3. Verifier Closure

The current-tree verifier closes the exact source, test, scope and final-artifact
surface. It contains 51 source/test mutations, 22 component mutations and 13
function-binding/carrier mutations. The component entry always creates a fresh
independent Git repository from the staged tree, uses a sanitized `env -i`
Xcode environment, binds generated build provenance to that tree and rejects
arbitrary DerivedData reuse.

Review-driven hardening additionally closes symlinked closed-image entries,
stale build provenance, early-return and function-redefinition bypasses. The
three verifier scripts use `zsh -f`; a malicious `ZDOTDIR/.zshenv` sentinel is
proved not to load. The App verifier has a strict non-executable comment
carrier, normalized whole-file seal, independently pinned executable-shell
projection, and separate snapshot, source-contract Python body and runtime
seals. Dynamic-name, `functions[]`, `eval` and alias variants are syntactically
validated, re-sealed and then rejected by the pristine checker.

## 4. Validation Evidence

| Command or evidence | Result |
| --- | --- |
| focused lifecycle + physical rejection + target-boundary selection | 28 tests in 3 suites passed |
| `scripts/verify-investigation-boundaries --iic-b1-root-owned-gate-source-contract-only` | exit 0 |
| `scripts/verify-investigation-boundaries --iic-b1-root-owned-gate-staged-scope-contract-only 41f5dba...` | exit 0; 7 paths / 1,900 lines |
| `scripts/verify-app-release-boundaries --iic-b1-root-owned-gate-component-source-contract-only scripts/verify-app-release-boundaries` | exit 0 |
| `scripts/verify-contract --fixed-gate-deadline-cleanup-contract-only` | immutable historical replay exit 0 |
| `scripts/verify-contract --iic0b-iv-b1-handoff-contract-only` | immutable historical replay exit 0 |
| `scripts/verify-contract --iic-b1-root-owned-gate-contract-only` | exit 0; complete source/component/binding/scope negative matrix |
| `scripts/verify-app-release-boundaries --iic-b1-root-owned-gate-component-boundary-only` | exit 0 from one fresh independent staged-tree build; final-Mach-O and closed-image checks passed |
| `scripts/with-clean-validation-snapshot --staged -- /usr/bin/swift test --no-parallel --filter StornautInvestigationTests` | 860/860 tests in 60 suites passed; 62.496 seconds test time, 208.96 seconds wall time |
| grouped and cross-group independent review | four empty JSONL result files; no unresolved P0–P2 |

The clean serial's synthetic validation commit is
`a2105d48e71abc22e014cd524a16e78c36dbf1c0`; its tree equals the implementation
tree `9c59f241ffbfc6bc6c2a6810a9a0ce2c57b23c4b`. The snapshot and fresh component
directories were removed after validation.

The retained code-review reports are
`/tmp/stornaut_iicb1_final_review.9ZFHZE/report.html` (SHA-256
`541a97b42419df14531f07ade634a83c13e3869cf7e15d8e9f2b5c53887227f5`) and
`/tmp/stornaut_iicb1_final_review.9ZFHZE/report.md` (SHA-256
`81cdaa5f20dd16cf7f579a6c9319deb619fb2257ebaeae291bfb89e5f017e939`).
The custom repository review workflow was unavailable because its endpoint's
certificate chain failed local verification; the required general grouped and
cross-group review completed independently.

## 5. Non-Claims and Next Step

ii-c-b1 ran no sudo/chown, install/uninstall, system launchctl, installed
App/driver/Gate/Coordinator, product XPC or Codex auth/model/network operation.
It did not consume the unique ii-c-c privileged campaign and did not run
`scripts/verify --full`; L3c4 retains exclusive ownership of that final gate.

ADR 0018 remains Proposed, Task 39 remains incomplete and production Deep Dive
remains unavailable. The current frontier is now:

```text
ii-c-b2 -> ii-c-c -> L3c3d -> L3c4
```
