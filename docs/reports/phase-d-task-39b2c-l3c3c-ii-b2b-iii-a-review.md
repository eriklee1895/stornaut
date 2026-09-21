# Phase D Task 39B2c-L3c3c-ii-b2b-iii-a Handle v3 Review

> Status: Complete; strict v3 integer-microsecond handle, single-quantized
> escrow/transfer/server truth, exact nested consumers, structural/mutation
> gates, one staged-only serial and independent post-fix review passed;
> non-admitting
>
> Date: 2026-08-20
>
> Implementation commit: `29285c887a5e7cc4b70310de83940fcb7f69b488`
>
> Validated tree: `94d72463fd1f6a836616e407e8a1626880deea24`
>
> Staged validation commit: `7ae32eb583569da23014ca12fb90f148dcfa0a73`
>
> Scope: handle/escrow/transfer/server deadline truth only; no public live
> server facade, helper/Xcode/App linkage, fixed client, App/helper launch,
> real XPC, install, privilege, model/auth, readiness or authoritative full
> verifier

## 1. Outcome

L3c3c-ii-b2b-iii-a is complete. `LifecycleMachineRetirementHandle` now has
strict protocol version `3` and stores exactly one authoritative
`validBeforeUTCMicroseconds: Int64`. Its `validBefore` property is a computed
`Date` compatibility projection and is not encoded. The public Date initializer
performs the sole checked conservative-floor conversion; the strict decoder
accepts only the integer wire value.

The escrow entry and sealed reservation transfer retain that same integer.
The temporary legacy claim path compares the canonical integer, and the
non-product machine-claim server consumes the transfer integer directly rather
than converting a `Date` back to microseconds. Interactive retired responses and
App retirement evidence preserve the exact nested v3 handle.

This checkpoint intentionally did not connect the server to the live helper.
The helper-private legacy one-selector service and legacy timers remain for
replacement by iii-b. Machine production remains explicitly unavailable.

## 2. Scope, Cost and Artifact Identity

The implementation changes exactly the ten approved non-document paths and
1,191 added-or-deleted lines (1,160 additions, 31 deletions), below the frozen
1,800-line ceiling. No helper, Package manifest, Xcode project, App/runtime
production source, scheduler/effect source or release-boundary script changed.

The implementation commit is the direct child of the docs-only split baseline
`e351054a14f1448f41cf0a1d56155cdc91a85153`. Its tree
`94d72463fd1f6a836616e407e8a1626880deea24` exactly matches the sole staged
validation commit `7ae32eb583569da23014ca12fb90f148dcfa0a73` and that validation
commit has the same parent. The implementation commit is pushed to
`origin/main`.

## 3. Prompt-to-Artifact Completion Checklist

| Requirement | Direct evidence | Result |
| --- | --- | --- |
| strict v3 exact wire | exact six-key JSON tests; v2 Date-only, mixed and unknown fields reject | satisfied |
| checked one-time floor | Date initializer tests cover fractional input, nonpositive, non-finite and out-of-Int64 values | satisfied |
| one stored handle truth | parser-backed exact top-level property contract plus ordinary, attributed and setter-scoped hidden-property mutations | satisfied |
| computed Date only | stable projection/re-encoding test; exact CodingKeys and integer codec contract | satisfied |
| escrow/transfer integer identity | direct stored-value test and structural Entry/transfer assertions | satisfied |
| legacy claim integer equality | equivalent Date projections claim through one canonical integer; claim-vs-transfer remains one-winner | satisfied |
| server direct projection | deterministic lossy-Date counterexample succeeds only when the canonical transfer integer is consumed directly | satisfied |
| nested consumer preservation | legacy claim response, interactive retired response and App transport inspect exact nested integer JSON | satisfied |
| strict scope and cost | executable docs-bridge identity plus exact ten-path/1,800-line gate; observed 10 / 1,191 | satisfied |
| executable anti-spoofing | nine single-axis mutations cover version, hidden storage, Date codec, Entry/transfer Date storage, record and server re-quantization | satisfied |
| no authority or topology expansion | no helper/Xcode/App/runtime/effect/release-gate changes; no launch/install/privilege/model/auth/full | satisfied |
| one serial and independent review | exact validated tree passed once; grouped, post-fix and cross-group review have no unresolved P0-P2 | satisfied |

## 4. Validation Evidence

| Gate | Result |
| --- | --- |
| tests-first RED | 91 tests compiled; 28 issues mapped only to v2 Date wire and server re-quantization defects |
| final focused gate | 91 tests in 6 suites passed |
| Lifecycle affected | 181 tests in 17 suites passed |
| Investigation affected | 309 tests in 25 suites passed |
| focused coverage | 107 functions / 1,151 lines / 346 regions; 95.33% / 95.40% / 91.62%; server adapter 28/28 functions |
| canonical v3 contract mode | exit 0 |
| `scripts/verify-contract` | exit 0; nine exact-diagnostic mutations and verifier source/self seals passed |
| `scripts/verify-investigation-boundaries` | exit 0; exact scope plus Debug/Release authority-closed driver gates passed |
| sole staged-only serial | 1,208 tests in 58 suites passed |
| serial test / total wall time | 114.067 / 172.92 seconds |
| serial identity | validation `7ae32eb…`, implementation `29285c8…`, identical tree `94d7246…` |
| independent review | production and test groups clean; verifier parser P1 closed with ordinary/attributed/setter mutations; final cross-group review clean |
| diff hygiene | exact ten paths, no unstaged drift, `git diff --check` passed |

The verifier review found one real false-green class: an exact-property checker
that initially enumerated only `public let` could miss hidden stored properties.
Two post-fix reviews then supplied concrete attributed and `private(set)`
variants. The final checker classifies every depth-one `let`/`var` declaration,
rejects top-level attributes, and all three independent mutations are rejected.
The original reviewer and cross-group reviewer both concluded no unresolved
P0-P2 remain.

## 5. Non-Admission and Next Gate

This checkpoint is non-admitting. It did not expose a public server facade, link
the server product into the helper, replace the live helper route, create a fixed
client, perform installed-L2, prove helper disappearance or execute a real
signed-App scenario.

ADR 0018 remains Proposed. Task 39 remains incomplete. Production Deep Dive
remains `.implementationUnavailable`; only ii-c may accept ADR 0018, only L3c4
owns machine readiness and Task 39's remaining authoritative full verifier, and
only Task 44 may admit normal-product Deep Dive.

The strict next checkpoint is L3c3c-ii-b2b-iii-b public live facade/helper
integration.
