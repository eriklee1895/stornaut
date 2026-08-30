# Phase D Task 39B2c ii-c-a Static Installed Topology Completion Audit

> Status: complete / non-admitting
>
> Date: 2026-08-31
>
> Implementation: `81f185c1278e0f80a3a5de856d0b8cb93c810272`
>
> Parent: `bbbe35c505b79ee45bc1cf40e8a975644607b7d3`
>
> Tree: `7cf4db75a261895ba0c86b6876623daf900bb4db`
>
> Next frontier: ii-c-b root-owned Gate and dry-run campaign harness

## 1. Result

ii-c-a is complete and remains non-admitting. The signed diagnostic App now
contains the fixed driver, gate and coordinator as three explicit native tools.
The installer admits them as one closed, role-keyed artifact set across built,
staging and installed planes without running the installed tools or changing the
runtime owner contract.

The implementation changes exactly eleven non-document paths plus this
checkpoint's existing preflight update: 2,296 additions and 373 deletions, or
2,669 changed non-document lines. This remains within the frozen eleven-path /
3,800-line ceiling and every category ceiling.

## 2. Implemented Closure

- `Package.swift` exports GateSupport and CoordinatorSupport as static products.
  Only each support enum and its `run` entry became public; the remaining
  implementation stays package-closed.
- Xcode owns dedicated GateNative and CoordinatorNative executable targets,
  fixed arm64/ad-hoc identifiers, diagnostic-only target dependencies and three
  `CodeSignOnCopy` members under `Contents/MacOS`.
- CoordinatorNative uses an isolated configuration build directory, inherits the
  shared Swift module search root and carries an App-relative framework runpath.
  This removes the duplicate package-framework output collision in the
  Diagnostic App test graph.
- The local lifecycle installer validates driver, gate and coordinator by role:
  regular file, no symlink, one link, exact owner/group/0755, bounded nonzero
  size, arm64, strict ad-hoc signature, fixed signing identifier, designated
  requirement, CodeDirectory hash, SHA-256 and descriptor/path node stability.
- Built, staging and installed identities must match same-role to same-role. The
  machine-claim service field remains driver-only. Rollback and uninstall
  revalidate the exact App/node/identity before removal.
- The PID-unique staging App records transaction ownership before `mkdir`; if a
  signal lands in that window, rollback still removes only the exact fixed
  staging path after root:wheel/0755 and parent-inode checks. Fixed root and
  plist transaction ordering remains unchanged, avoiding cross-installer delete
  authority.
- Current-tree ii-c-a source, component, staged-scope and contract gates replace
  incompatible historical current-tree assertions while historical checkpoints
  remain immutable replay evidence. The installer is bound by exact SHA-256 and
  owner/mode/link/CDHash/node-stability/signal-order mutation controls.

## 3. Validation Evidence

| Command or evidence | Result |
| --- | --- |
| `swift test --filter InvestigationClosedMachineArtifactInstallerTests` | 6/6 passed |
| `swift test --filter InvestigationMachineTargetBoundaryTests` | 49/49 passed |
| Xcode `StornautInvestigationDiagnosticApp` tests | 15/15 passed |
| `scripts/verify-investigation-boundaries --iic-a-source-contract-only` | exit 0 |
| `scripts/verify-app-release-boundaries --iic-a-source-contract-only` | exit 0 |
| `scripts/verify-contract --iic-a-contract-only` | exit 0, including six installer mutations |
| `scripts/verify-investigation-boundaries --iic-a-staged-scope-contract-only` | exit 0; 11 paths / 2,669 changed lines |
| `scripts/verify-app-release-boundaries --iic-a-component-boundary-only` | exit 0 from fresh scratch DerivedData |
| clean staged-only `swift test --no-parallel --filter StornautInvestigationTests` | 856/856 tests in 60 suites passed; 45.050 seconds test time |
| grouped and cross-group final review | no unresolved P0-P2 |
| `utree flush` | exit 0 |

The accepted staged validation commit was `6b9cd2e`; its tree equals the
implementation tree `7cf4db75a261895ba0c86b6876623daf900bb4db`. The
isolated validation worktree was removed.

An exploratory all-package snapshot run was not used as acceptance evidence. It
ran 1,763 tests in 94 suites and exposed two out-of-scope/environment issues:
the historical Core bookmark test requires an app-scope bookmark entitlement
that the outer validation Seatbelt does not provide, and one coordinator
materializer cleanup case reported a transient errno. The bookmark case passed
in the ordinary SwiftPM environment and predictably failed alone under the same
snapshot sandbox; the coordinator case passed alone in a fresh snapshot and is
included in the green 856-test affected-target serial. No assertion was weakened
and no failing case was skipped inside the affected target.

## 4. Review Closure

The grouped Xcode/package, installer and verifier reviews initially found two
valid P1 issues: a staging-directory signal window and a verifier that only
checked the installer digest shape. Both were fixed tests-first. The final
installer uses safe transaction ordering, and the source contract now combines
an exact installer seal with six non-vacuous mutation fixtures. Final grouped
and cross-group review reports are empty. The retained HTML review report is
`/tmp/stornaut_iica_review.84py3D/report.html`, SHA-256
`c2b88fef13e443d6769bc4993fbcc32c1c71e79e49d3da50d5f081f11368cc1c`.

## 5. Non-Claims and Next Step

ii-c-a did not execute install or uninstall, query or mutate system launchd,
invoke sudo, run an installed driver/gate/coordinator, call product XPC, read
Codex authentication, call a model, use the network or consume the unique
privileged campaign. It did not run `scripts/verify --full`; L3c4 still owns the
remaining authoritative full.

ADR 0018 remains Proposed, Task 39 remains incomplete and production Deep Dive
remains unavailable. The current frontier is ii-c-b, followed by ii-c-c,
L3c3d and L3c4.
