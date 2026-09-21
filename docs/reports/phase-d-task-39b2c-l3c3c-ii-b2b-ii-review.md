# Phase D Task 39B2c-L3c3c-ii-b2b-ii Legacy Client Quarantine Review

> Status: Complete; broad Lifecycle concrete machine-claim client and transport
> removed, legacy helper server contract made helper-private, Machine production
> explicitly unavailable, exact source/Mach-O/mutation gates, one staged-only
> serial and independent review passed; non-admitting
>
> Date: 2026-08-20
>
> Implementation commit: `c923fa89b3b8270133f38fb456e3feb54d022d63`
>
> Validated tree: `555a979017122ef9c7166e4d434de1ef231692c9`
>
> Staged validation commit: `79906dacb596eac683a877026bdb5cc6f11dd2bf`
>
> Scope: legacy client quarantine and fail-closed Machine production only; no
> new fixed client, live server migration, App/helper launch, install, privilege,
> model/auth, readiness claim or authoritative full verifier

## 1. Outcome

L3c3c-ii-b2b-ii is complete. `StornautLifecycle` no longer exports or implements
the old machine-claim client, result/error transport, reply resolver, connection
owner, helper path/signing admission or request proxy. The current helper still
serves the historical one-selector contract, but that selector and its fixed
Mach service literal are now private declarations in `StornautLifecycleHelper`.
They are server-only and cannot be imported as a broad Lifecycle client surface.

`InvestigationMachineDriverHost.production` now throws the typed
`implementationUnavailable` error before it constructs a claimant or touches
handoff/topology dependencies. The injected host, claimant, store and topology
paths remain deterministic semantic oracles. Machine-local source uncertainty
uses `InvestigationMachineRetirementClaimSourceError.outcomeUnknown`; it no
longer depends on the deleted Lifecycle transport type. Once the injected source
reports post-dispatch uncertainty, that external-state outcome continues to take
priority over racing cancellation, as required by the accepted L3c2a-ii safety
contract.

This checkpoint intentionally creates no replacement client. The future fixed,
one-shot `NSXPCConnection` owner remains exclusively assigned to ii-b4.
ii-b2b-iii is next and owns migration of the live helper to the new handle-free
server façade, single escrow/timer owner and strict reply ordering.

## 2. Scope, Cost and Design Correction

The original ten-path preflight proved insufficient under real artifact
validation. A built ordinary Debug main image still contained the public
Lifecycle service-selection accessor even after the concrete client was
deleted. Moving or renaming the namespace inside the same Swift target did not
remove it. The scope was therefore corrected before acceptance to add only
`StornautLifecycleHelper/main.swift`, where the legacy selector and fixed service
literal could be made private without changing listener, escrow, admission or
reply behavior.

The accepted implementation changes exactly eleven non-document paths and
2,041 added-or-deleted non-document lines (1,173 additions, 868 deletions), below
the corrected 3,000-line ceiling and the repository's 14-path/4,000-line split
threshold. It changes no Package manifest, Xcode project, scheme, new server
source or product availability flag. The implementation commit also updates the
governing preflight, for twelve total committed paths.

## 3. Prompt-to-Artifact Completion Checklist

| Requirement | Direct evidence | Result |
| --- | --- | --- |
| remove broad concrete client | `LifecycleMachineClaimXPCClient` actor, initializer, `claim`, `activeConnection` and connection state removed from `LifecycleSupervisorXPC.swift`; source mutation restores are rejected | satisfied |
| remove reply/outcome transport | Lifecycle result/error types, reply resolver, reason sanitizer and identity adapter removed; Machine owns one internal uncertainty error | satisfied |
| remove helper path/signing admission from Machine | installed helper signing verifier and `LifecycleLocalInstallationContract`/Security wiring removed from `InvestigationMachineDriverHost.swift`; structural denylist covers reintroduction | satisfied |
| server-only legacy compatibility | the one-selector `LifecycleMachineClaimXPCWire` and exact service literal are private and uniquely owned by `StornautLifecycleHelper/main.swift`; broad Lifecycle exports neither | satisfied |
| no alternate client or caller-selected service | helper contains no proxy/client/active connection; Machine contains no Lifecycle wire/client/service/path selection; executable mutations restore and reject each axis | satisfied |
| production unavailable before effects | production factory body contains only parameter consumption followed by typed `implementationUnavailable`; test observes zero handoff/topology events | satisfied |
| injected semantics retained | claimant/store/topology and host injected-path tests cover success, replay, failures, cancellation and one-shot behavior | satisfied |
| external-state uncertainty priority | direct claimant and host tests prove ordinary transport cancellation remains `CancellationError`, while source-reported post-dispatch uncertainty remains `outcomeUnknown` during a cancellation race | satisfied |
| ordinary App main-image absence | Debug scans `Stornaut` plus optional `Stornaut.debug.dylib`; Release scans `Stornaut`; old wire/client/namespace/resolver/result/error symbols are absent; nested helper is deliberately not used as an absence target | satisfied |
| fail-closed artifact scanner | demangled-symbol failures return a distinct error; every runtime call handles it; source contract rejects bundle-root substitution, Debug dylib omission and fail-open return | satisfied |
| exact scope and budget | structural verifier audits the exact eleven non-document paths against baseline `ecd76e9…` and enforces 3,000 changed lines; observed 11 / 2,041 | satisfied |
| historical b1/b2 evidence preserved | old mutable-worktree scope traps replaced by exact fixed-commit parent/tree/path/budget audits for `147247f…` and `08184b0…` | satisfied |
| executable anti-spoofing | ten legacy source/ownership mutations plus four ordinary-App Mach-O gate mutations are rejected with exact diagnostics; verifier files and normalized contract file are source-sealed | satisfied |
| no authority expansion | no Package/Xcode change, replacement client, install, launch, privilege, model/auth, cleanup/Executor or readiness output | satisfied |
| one serial and independent review | exact staged validation tree passed once; three grouped reviews and cross-group contract review found no P0-P2 | satisfied |

## 4. Validation Evidence

| Gate | Result |
| --- | --- |
| focused four-suite gate | 34 tests in 4 suites passed |
| Lifecycle affected suite | 175 tests in 17 suites passed |
| Investigation affected suite | 308 tests in 25 suites passed |
| focused Machine source coverage | 38/44 functions (86.36%); 325/345 lines (94.20%); 97/111 regions (87.39%) |
| Lifecycle deletion/ownership coverage | source contract, helper-private ownership mutations and real Debug/Release main-Mach-O gates; helper was not launched for runtime coverage |
| `scripts/verify-contract` | exit 0, including fourteen new executable mutations and source/self seals |
| `scripts/verify-investigation-boundaries` | exit 0, including Debug/Release authority-closed driver binaries |
| `scripts/verify-app-release-boundaries` | exit 0; ordinary Debug/Release, diagnostic Debug, dependency-free Release shell, App tests and final artifacts passed |
| sole staged-only serial | 1,196 tests in 58 suites passed |
| serial test / stage time | 80.985 / 124.84 seconds |
| serial identity | validation `79906da…`, parent `ecd76e9…`, tree `555a979…`; implementation `c923fa8…` has the exact same tree |
| independent review | three grouped reviews plus cross-group review; no unresolved P0-P2 |
| diff hygiene | exact staged tree, no unstaged changes, `git diff --check` passed |

The App boundary initially produced two useful failures. First, the public
server-only namespace still leaked service-selection symbols into
`Stornaut.debug.dylib`; this caused the helper-private ownership correction.
Second, a previously unreachable Xcode configuration-list parser omitted the
literal `PBXNativeTarget` prefix; the project graph was unchanged and correct,
so the verifier anchor was fixed and source-sealed. Neither failure was bypassed
by weakening a denylist.

The focused coverage run intentionally did not launch the root helper. Deleted
Lifecycle client code and the helper-private declaration are admitted through
source parsing, mutation controls, compile tests and actual App/helper Mach-O
artifacts rather than unsafe runtime execution.

## 5. Non-Admission and Next Gate

This checkpoint remains non-admitting. It did not make the helper speak the new
handle-free claim/release protocol, link the non-product server into Xcode,
create a fixed client, perform installed-L2, prove helper disappearance or run a
real scenario. Machine production remains explicitly unavailable.

ADR 0018 remains Proposed. Task 39 remains incomplete. Production Deep Dive
remains `.implementationUnavailable`; only ii-c may accept ADR 0018, only L3c4
owns machine readiness and Task 39's remaining authoritative full verifier, and
only Task 44 may admit normal-product Deep Dive.

The strict next checkpoint is L3c3c-ii-b2b-iii.
