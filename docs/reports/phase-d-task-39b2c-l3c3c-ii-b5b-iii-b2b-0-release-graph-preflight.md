# Phase D Task 39B2c iii-b2b-0 Release Graph Closure Preflight

> Status: scope, trust boundary and tests-first matrix frozen; implementation
> not started
>
> Date: 2026-08-25
>
> Baseline: `d6ab789ada2d87d0422fb8175d3d82c70381b47c`
>
> Scope: source, test and verifier inspection only. No driver execution, App or
> helper launch, XPC, install, sudo/root operation, model/auth/network use,
> serialized regression or authoritative full verifier was used for this
> preflight.

## 1. Decision

The frozen iii-b2b checkpoint cannot safely remain one implementation. Its
eight-path / 2,800-line budget assumes that the already reviewed Darwin physical
graph is available to both final driver configurations. Current source instead
places all three mutually dependent physical files behind whole-file
`#if DEBUG` guards:

- `InvestigationMachineDarwinDriverChildObservation.swift`;
- `InvestigationMachineDarwinOuterInnerSession.swift`; and
- `InvestigationMachineDarwinOuterInnerComposition.swift`.

The original iii-b2b contract requires both Debug and Release driver artifacts
to be positive controls for the complete intended graph. Entry/output work plus
this Release correction would exceed the frozen path set. iii-b2b therefore
splits before coding:

```text
iii-b2b-0 Release graph closure
-> iii-b2b-1 zero-argument entry and final artifact
-> ii-c0b -> ii-c -> L3c3d -> L3c4
```

This is a release-reachability correction only. It does not connect the public
entry, consume FD 0, construct production ownership/terminal observers, execute
eight epochs or emit a result.

## 2. Exact Scope and Cost Ceiling

The checkpoint may change exactly these seven non-document paths:

1. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinDriverChildObservation.swift`
2. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinOuterInnerSession.swift`
3. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinOuterInnerComposition.swift`
4. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
5. `scripts/verify-contract`
6. `scripts/verify-investigation-boundaries`
7. `scripts/verify-app-release-boundaries`

The hard ceiling is seven non-document paths and 1,200 changed lines. The
checkpoint stops and splits again before crossing either ceiling. It must not
change `Package.swift`, `Stornaut.xcodeproj`, the executable `main.swift`, entry
support, focused physical behavior tests or product targets.

## 3. Frozen Trust Contract

The three source files form one atomic Release graph:

- the session uses the driver-child observer and the composition's session
  protocols;
- the composition uses the session's inner-role and bounded-message types; and
- the observer returns the non-conditional protocol identity.

All three whole-file guards must therefore be removed together. Their existing
package/internal/private visibility, exact imports, non-`Codable` types, fixed
paths/descriptors, spawn authority carve-outs, one-shot state, cancellation and
retirement behavior remain unchanged. No new product dependency or public
surface is permitted.

The existing pre-drop root identity semantics remain unchanged. In particular,
the accepted supplementary-group set is not narrowed to `[0]`: the a1-v review
already rejected that change because the root observer runs before the later
independent `initgroups -> setgid -> setuid` transition.

## 4. Artifact Contract

After this checkpoint:

- SwiftPM and Xcode Debug driver artifacts still contain the existing physical
  graph symbols and authority imports;
- SwiftPM and Xcode Release driver artifacts also contain the same intended
  graph and corresponding fixed authority imports;
- ordinary Debug/Release App images, the diagnostic App/main images, lifecycle
  helpers and the Release diagnostic shell remain negative controls; and
- source/verifier gates reject reintroducing any of the three file-level Debug
  guards or widening public, Codable, product, cleanup, network or arbitrary
  process authority.

Release reachability is not machine readiness. Production ownership/terminal
observer construction and public entry wiring remain iii-b2b-1 work.

## 5. Tests-First Matrix

The first RED test must assert all of the following from the repository source:

1. the exact three source paths exist;
2. none has a whole-file `#if DEBUG` / terminal `#endif` wrapper;
3. package/internal/private surface and the existing exact import map remain;
4. the verifier scripts contain a dedicated iii-b2b-0 semantic, scope and
   Debug/Release artifact contract; and
5. the final artifact gate treats both driver configurations as positive while
   retaining every existing closed-image negative.

The source-boundary test is expected to fail first against the baseline because
all three wrappers still exist. No behavioral test is rewritten: existing
session, composition and child-observation suites already cover the promoted
logic.

## 6. Validation Order

```text
source/scope RED
-> exact target-boundary test
-> affected session/composition tests
-> scripts/verify-investigation-boundaries
-> scripts/verify-contract
-> scripts/verify-app-release-boundaries
-> SwiftPM and Xcode Debug/Release driver projections
-> one staged-only serialized SwiftPM regression
-> independent implementation/verifier/cross-boundary review
```

The authoritative `scripts/verify --full` remains reserved for L3c4. This
checkpoint performs no root, installed-product, real-XPC, model, authentication
or network operation and makes no readiness or production Deep Dive claim.

## 7. Prompt-to-Artifact Checklist

| Requirement | Evidence required | Preflight state |
| --- | --- | --- |
| Split before exceeding iii-b2b budget | this frozen b2b-0/b2b-1 split | frozen |
| Release contains reviewed physical graph | Debug/Release source and Mach-O positive controls | pending |
| Product images remain closed | complete existing negative-image matrix | pending |
| Preserve behavior and trust surface | focused suites plus semantic mutations | pending |
| Preserve package/Xcode graphs | no manifest/project diff | frozen |
| Avoid execution/admission claims | no launch/root/model/full operations | frozen |
| Leave final production join to b2b-1 | no entry/observer factory/output wiring | frozen |

Task 39 remains incomplete. Production Deep Dive remains
`.implementationUnavailable`; only L3c4 may make the final machine-readiness
claim.
