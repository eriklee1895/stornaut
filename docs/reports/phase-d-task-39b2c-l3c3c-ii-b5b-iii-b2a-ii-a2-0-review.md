# Phase D Task 39B2c L3c3c-ii-b5b-iii-b2a-ii-a2-0 Review

> Status: complete / non-admitting; a2-0 closed
>
> Date: 2026-08-24
>
> Baseline: b46120d3161b5992018f4b990382bd6ced49d599
>
> Implementation commit: 7817305be493e87531c76a4fd0b950f8077500e8
>
> Implementation tree: 6f773007e047aa88b682fe9c44ee055c620dd30a
>
> Next frontier: a2-i inherited-PGID App session

## 1. Result

a2-0 is complete. The inner side can now reconstruct a complete, canonical but
explicitly untrusted invocation and epoch request from FD-8 bytes without
already possessing the outer selection. The pre-existing trusted decode APIs
delegate to that decoder and then independently require exact equality with the
outer-held selection, so self-consistency is not promoted into trust.

The implementation changes exactly eight non-document paths and 703 lines
against baseline b46120d, plus the already tracked a2 scope/trust preflight.
This is below the frozen eight-path / 1,800-line ceiling. It adds no package or
Xcode graph edge, Darwin launch/session/retirement authority, public entry or
product availability.

## 2. Closed Contract

- InvestigationMachineSingleEpochInvocation.decodeUntrusted(_:) tries the
  genesis and successor transcript domains and accepts exactly one candidate.
- Candidate decoding reconstructs all selection axes from canonical bytes,
  revalidates epoch/projection joins, predecessor and previous-helper semantics,
  and requires exact re-encoding.
- InvestigationMachineDarwinEpochRequest.decodeUntrusted(_:) decodes the nested
  invocation, verifies its digest, deadline and scenario-derived closed mode,
  and requires exact re-encoding.
- The legacy expected-selection decoders retain the only trust join: exact
  equality against the caller's independently held selection.
- Both decoded values remain package-only, non-Codable and incapable of minting
  ownership, admission, containment, continuity or cleanup authority.

## 3. Verification and Review

| Gate | Result |
| --- | --- |
| exact implementation scope | 8 non-document paths / 703 changed lines; 9 paths including preflight |
| focused self-decode suites | 19 tests / 2 suites passed |
| affected Investigation selection | 605 tests / 45 suites; one historical physical-spawn fixture failed once, then passed in isolated serial and in the staged serial |
| scripts/verify-contract | passed, including five semantic mutations and six scope negative controls |
| scripts/verify-investigation-boundaries | passed, including exact source seals and SwiftPM Debug/Release projections |
| scripts/verify-app-release-boundaries | passed, including independently measured Xcode Debug/Release projections |
| staged-only serial regression | 1,487 tests / 78 suites passed; test run 98.867 seconds, verifier stage 166.596 seconds |
| independent grouped review | no unresolved P0-P2 |

The verifier review specifically confirmed that each semantic mutation is
rejected by its corresponding a2-0 semantic marker rather than by an unrelated
source or self seal. The self seal, exact path/mode/budget gate and both SwiftPM
and Xcode Mach-O projections match the committed implementation.

Coverage was skipped because this checkpoint has no repository coverage
threshold and Swift line coverage would not measure its shell/Git-index
contract. No authoritative full was run; the single staged serial is the only
product-source regression for this checkpoint.

## 4. Non-Claims and Next Step

a2-0 did not launch the installed App/helper/XPC, install anything, use root or
sudo, call Codex, authenticate, use a model or network, mint a physical result,
accept ADR 0018, claim machine readiness or enable production Deep Dive.

a2-i now owns only the existing session's closed topology policy: fixed App
spawn with inherited inner PGID, exact App PPID/PGID observation and direct-
child-only terminal handling. It retains the frozen eight-path / 3,200-line
ceiling and reuses the existing STNP/STNH state machine. The remaining order is:

    a2-i -> a2-ii -> iii-b2b -> ii-c0b -> ii-c -> L3c3d -> L3c4

Task 39 remains incomplete, ADR 0018 remains Proposed and production Deep Dive
remains .implementationUnavailable.
