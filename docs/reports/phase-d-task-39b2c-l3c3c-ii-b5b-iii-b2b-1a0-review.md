# Phase D Task 39B2c iii-b2b-1a-0 Helper Provenance Review

> Status: complete / non-admitting
>
> Date: 2026-08-26
>
> Baseline: `d643b8fd500be29736a962dcd0c270304b490828`
>
> Implementation commit: `53c5594da964ff3f6d5fdca4f2825a5e629b01c4`
>
> Implementation tree: `f9322fa0c71910ca96a44cf6d3a7f70e3245f1fa`
>
> Test-only prerequisite commit: `59d3bb7db9c99d1b2b8e15a95c1a70527b38533a`
>
> Immutable seal commit: `8361168320cab2aa3acf1ba4f57a76e1fe1aa32d`
>
> Seal tree: `19373b5dd1923d1d636fd088de29b52f78f7ce26`
>
> Next frontier: iii-b2b-1a-1 concrete outer ownership/terminal observers

## 1. Result

iii-b2b-1a-0 is complete. The physical ownership candidate and wire now carry
the exact canonical `InvestigationMachineClaimEvidence` rather than only its
digest. The outer-side semantic join re-encodes and hashes those bytes, then
binds them to the selected configuration nonce, App/helper identities, audit
session, user identity, four zero-residue counters and release deadline.

The implementation changed exactly eight non-document paths and 1,336
non-document lines, plus the frozen outer-observation preflight. The immutable
seal replays the exact implementation parent, tree, nine-path commit set, modes
and line count. Same-path substitutions of every implementation path are
rejected against the immutable tree.

This checkpoint carries helper provenance only. It does not prove App/helper
process disappearance or installed-driver stability; those remain the
independent outer-owned responsibility of iii-b2b-1a-1.

## 2. Validation and Review

| Gate | Result |
| --- | --- |
| provenance and wire focused tests | completed in implementation checkpoint; nested canonical mutations and coordinated foreign evidence rejected |
| App Server timeout prerequisite | exact case 1/1, runner suite 12/12 and serialized Codex target 259/259 passed; no production change |
| stale projection regression | initial boundary run reproduced 5 issues in exactly 2 historical marker tests; all 5 were updated to the named current SwiftPM/Xcode projections |
| focused boundary rerun | 3/3 exact tests passed |
| complete target-boundary suite | 38/38 passed |
| canonical provenance source gate | exit 0 |
| source-only App boundary gate | exit 0 |
| complete verifier contract | exit 0, including semantic, source-seal, scope and nine same-path tamper checks |
| complete Investigation boundary | exit 0, including fresh Debug/Release SwiftPM builds |
| complete App/Release boundary | exit 0, including Xcode Debug/Release builds, diagnostic App tests and final-Mach-O checks |
| staged-only serialized regression | 1,525 tests / 79 suites passed; test run 131.885 seconds, wall time 199.91 seconds; staged tree `19373b5d` |
| independent review | final three-file seal diff has no unresolved P0-P2 |
| coverage | skipped: no configured threshold, non-Flux execution and no production branch added by the seal |
| diff hygiene | `git diff --check` passed |

The first full Investigation-boundary attempt exposed a stale SwiftPM Release
owned-symbol hash. The undefined-symbol and load-command projections and the
5,503-line cardinality already matched. Two fresh current-tree builds and one
fresh immutable-`53c5594` build produced identical complete sorted owned-symbol
bytes with SHA-256
`459abfb64cf21475780a79ed8dd7c6088603b386f8a196dac14c282b49fcc08c`.
The previous value came from an incremental default `.build` artifact, whereas the
authoritative gate always uses a fresh private scratch directory. The seal now
pins the reproducible clean-build projection and keeps SwiftPM and Xcode
projections separately named.

## 3. Test-Generation Summary

The mandatory unit-test workflow completed with an empty defect set. One
existing boundary test entry was maintained to cover the current projection
names and immutable implementation metadata. The final result is all-pass; no
production defect was introduced or discovered. `utree flush` completed.

## 4. Non-Claims and Next Step

iii-b2b-1a-0 did not implement the concrete outer observers, invoke the
zero-argument installed driver, launch the App/helper, request administrator
authority, call Codex, use subscription authentication or public networking,
accept ADR 0018, emit a machine-ready report, enable Deep Dive or consume the
remaining authoritative full verifier.

The strict remaining order is:

```text
iii-b2b-1a-1 concrete outer ownership/terminal observers
-> iii-b2b-1b zero-argument entry/final artifact
-> ii-c0b non-root capsule author and launcher/TTY/FD hygiene
-> ii-c privileged no-model installed-driver gate
-> L3c3d one authenticated real-success pending candidate
-> L3c4 sealed final admission and authoritative full
```

Task 39 remains incomplete, ADR 0018 remains Proposed and production Deep Dive
remains `.implementationUnavailable`.
