# Phase D Task 39B2c-L3c3b Scope and Trust Preflight

> Status: Pre-coding split frozen; L3c3b-i is next
>
> Date: 2026-08-18
>
> Baseline: `95debd5c969b1da21bf1d435a5426f7f1f95ec3e`
>
> Scope: native diagnostic-only Machine-driver packaging and fixed installed-
> topology admission; no live install, launch, handoff, model, readiness or full
> verifier

## 1. Decision

L3c3b cannot remain one implementation checkpoint. The live checkout separates
two independently security-sensitive surfaces:

1. Xcode must produce one fixed-signing native command-line tool and embed it
   only in `StornautInvestigationDiagnostic.app`; and
2. the root-owned installer and L2 observer must accept and prove the exact
   built/staged/installed driver without acquiring launch or process authority.

Combining the Xcode/package graph, scheme, copy phase, artifact verifier, root
installer, L2 domain/reader and all affected tests exceeds the repository's
fourteen-path review ceiling. L3c3b is therefore split before coding into
`L3c3b-i native packaging -> L3c3b-ii installer and L2 admission`.

## 2. Current-Checkout Evidence

The existing SwiftPM executable is intentionally not an explicit package
product. Its toolchain-derived ad-hoc identifier does not satisfy the fixed
accepted identifier. The Xcode project contains six native targets and two
helper-only copy phases; the diagnostic scheme builds only the App, helper and
tests. Ordinary and diagnostic App gates currently prove the driver absent.

The local lifecycle installer also rejects the driver at built, staging and
installed paths. Existing bundle permission checks prove root ownership, no
symlink, no group/world write and single-link regular files after staging, but
they do not yet establish driver-specific nesting, `0755`, arm64 shape, static
signing identity or executable hash.

L2 currently observes seven fixed artifact roles. Its binding carries complete
App/helper signing evidence only. `DarwinRootTopologyArtifactReader` already
provides the correct descriptor/hash/signing/re-observation pattern used for the
helper; adding a driver role can reuse this implementation without adding a
driver process, activation, mutation or Codable surface.

## 3. Frozen Split

### L3c3b-i — Native Diagnostic-Only Packaging

Create one Xcode command-line target whose final signing identifier is exactly
`com.eriklee.stornaut.investigation.machine-driver`, product name is exactly
`StornautInvestigationMachineDriver`, architecture is arm64 and signing is
manual ad-hoc with no App entitlements. The target compiles the existing
`Tools/StornautInvestigationMachineDriver/main.swift` and links one new narrow
static package facade. The facade exposes only a no-argument asynchronous
`run() -> Int32` that delegates to the package-scoped Machine entry point; it
must not expose the Machine target as a general library product. The existing
SwiftPM driver uses the same main source and facade.

The diagnostic App gains one exact driver target dependency and a separate
`Copy Investigation Driver` phase with one CodeSignOnCopy member. Its helper
phase remains helper-only. The ordinary App, helper and all test targets gain no
driver dependency or copy phase. The diagnostic scheme explicitly builds the
driver; the ordinary scheme remains unchanged.

The artifact gate must prove:

- ordinary Debug and Release Apps contain no driver;
- diagnostic Debug contains exactly the fixed nested regular executable;
- mode `0755`, single hard link, arm64-only shape and bounded size;
- `codesign --verify --strict` on the driver and deep/strict on the App;
- exact signing identifier, designated requirement, CodeDirectory hash and
  executable SHA-256; and
- no Executor/Trash/cleanup or readiness symbols enter the native driver.

The installer remains deliberately blocked on a present driver until L3c3b-ii;
L3c3b-i changes no root-owned staging or installed-state admission.

Frozen possible non-document paths, at most 2,500 added lines:

1. `Package.swift`
2. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDriverSupport.swift` (new)
3. `Tools/StornautInvestigationMachineDriver/main.swift`
4. `Stornaut.xcodeproj/project.pbxproj`
5. `Stornaut.xcodeproj/xcshareddata/xcschemes/StornautInvestigationDiagnosticApp.xcscheme`
6. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
7. `scripts/verify-investigation-boundaries`
8. `scripts/verify-app-release-boundaries`
9. `scripts/verify-contract`

No App source or App unit-test change is expected. If the native tool cannot be
proven with these paths, stop and split or revise the topology before coding.

### L3c3b-ii — Installer and L2 Driver Admission

Migrate the fixed local lifecycle installer from driver-absent to exact
driver-present admission. Built, staging and installed validation must bind the
same exact nested regular executable across owner/group, mode, link count, arm64
shape, complete static signing identity and executable SHA-256 before any
bootstrap, move or installed-state success. No live install is performed by this
checkpoint; tests use built artifacts and disposable staging-shaped fixtures.

Add `.machineDriverExecutable` to the package-closed L2 artifact roles. Extend
`LifecycleRootTopologyBinding` with complete driver signing evidence. The
installed binding reader must compare every nested signed binding dimension to
the fixed installed driver's static evidence and fixed Machine-claim service.
The Darwin artifact reader must require the driver at its fixed path with
root:wheel `0755`, one link, bounded size, exact descriptor SHA-256, exact static
signing evidence and a second node observation after signing. Installed proof
requires `.presentValid`; post-teardown proof naturally requires `.absent` via
the closed `allCases` set.

This checkpoint adds no driver process observation. The driver process may still
be executing while it observes the post-teardown path; process exit belongs to
the later launcher/handoff lifecycle. No schema migration is required because
the L2 binding remains non-Codable and the signed driver binding already covers
the complete identity.

Frozen possible non-document paths, at most 3,000 added lines:

1. `Sources/StornautLifecycle/LifecycleRootTopologyObservation.swift`
2. `Sources/StornautLifecycle/DarwinRootTopologySupport.swift`
3. `Sources/StornautInvestigationMachine/InvestigationLifecycleTopologyCollector.swift`
4. `Tests/StornautLifecycleTests/LifecycleRootTopologyObservationTests.swift`
5. `Tests/StornautLifecycleTests/DarwinRootTopologySupportTests.swift`
6. `Tests/StornautInvestigationTests/InvestigationLifecycleTopologyCollectorTests.swift`
7. `Tests/StornautInvestigationTests/InvestigationLifecycleTopologyTestSupport.swift`
8. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
9. `scripts/stornaut-r5-local-lifecycle`
10. `scripts/verify-investigation-boundaries`
11. `scripts/verify-app-release-boundaries`
12. `scripts/verify-contract`

`LifecycleServiceRegistration.swift`, the launchd plist, ordinary signing/bundle
scripts, Machine host, App source and package/Xcode graph stay unchanged.

## 4. Validation Funnel

Each implementation checkpoint follows structural -> focused -> affected suites
-> targeted App/binary or disposable staging gate -> independent review -> one
clean staged serial. Neither checkpoint runs `scripts/verify --full`.

L3c3b-i builds diagnostic Debug and ordinary Debug/Release artifacts and proves
their exact driver membership/signing. L3c3b-ii reuses that current-source built
artifact, exercises installer validation only against disposable copies, and
tests L2 installed/post-teardown observations with injected fixtures. No
`install`, `uninstall`, `launchctl bootstrap`, driver execution or model call is
permitted.

## 5. Safety Boundary

This preflight changed no product code, installed nothing, launched nothing and
did not modify `~/.codex/config.toml`. Production Deep Dive remains unavailable.
L3c3b-i is next. L3c3c-i remains the mandatory repository-external
launcher/handoff spike and ADR; packaging evidence cannot substitute for it.
