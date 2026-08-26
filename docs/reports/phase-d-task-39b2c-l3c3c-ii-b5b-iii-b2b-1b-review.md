# Phase D Task 39B2c iii-b2b-1b Zero-Argument Entry Review

> Status: complete / non-admitting
>
> Date: 2026-08-26
>
> 1b-i implementation commit:
> `6b2608258d59787bca592012086a2377d647473e`
>
> 1b-i parent:
> `912a01fc0b14d4d659aea38b1a1c75d00fee32bb`
>
> 1b-i tree:
> `462d40bfc36954ec60c533e946bbd0019470aa88`
>
> 1b-ii implementation commit:
> `1c8ab1d5c06f87f7d2af548228835adcd43a1ae9`
>
> 1b-ii parent:
> `6b2608258d59787bca592012086a2377d647473e`
>
> 1b-ii tree:
> `d7b6c05fdb90f0db693e8f506e45eae5b98a45f9`
>
> Immutable seal commit:
> `a314b855f9e5d15d3bf7789d95533369b7cb1349`
>
> Seal tree:
> `aac9d81a7275e964999ebe1d0d9d057bd8db34a4`
>
> Next frontier: ii-c0b non-root capsule author and launcher/TTY/FD hygiene

## 1. Result and Split

iii-b2b-1b is complete and remains non-admitting. Its zero-argument
entry/artifact scope was split before closeout into two independently reviewable
parts without widening product authority:

- **1b-i production entry** owns root/argc and fixed FD 8/9 role selection,
  outer FD 0/1/2/7/8/9 admission, installed-driver observation, the existing
  fixed capsule intake and eight-epoch Darwin cohort, canonical completion
  artifact construction, final descriptor revalidation and bounded FD-1
  commitment. The inner branch delegates once to the existing fixed inner role.
- **1b-ii binary/verifier closure** pins exact SwiftPM and Xcode Debug/Release
  positive projections, product/helper negative controls, source/scope
  boundaries and immutable verifier identity. It adds no production behavior.

The package-only canonical completion artifact binds the attempt UUID, capsule
hash, projected-input hash, exact eight-epoch count and zero-before-hash
completion digest. It contains no helper identity, retirement handle, terminal
proof, capability report or readiness claim.

## 2. 1b-i Implementation and Review Closure

The 1b-i commit changed exactly five non-document paths and 2,434 lines
(2,358 insertions plus 76 deletions). One staged-only serialized invocation
passed 1,550 tests in 81 suites. Final production and test reviews had no
unresolved P0-P2 after four P1 findings were fixed tests-first:

1. **Cancellation precedence:** composition cancellation can conceal terminal
   observation or exit-classification uncertainty, so it maps to containment
   uncertainty unless a typed post-containment cancellation proves exit 83 safe.
2. **Darwin pipe identity:** an anonymous pipe may legitimately report
   `st_dev == 0`; the validator requires a nonzero kernel inode and valid file
   type instead. FD-0 regular-file/device provenance remains the intake's job.
3. **Wait/partial deadline:** the bounded writer checks its absolute deadline
   after a writable wait and between partial writes, including EINTR paths.
4. **Final-write commitment:** once the final canonical byte is written, the
   receipt is irrevocably committed; a later clock sample or cancellation cannot
   reclassify that success.

This preserves the fail-closed order: containment uncertainty dominates
cancellation, while protocol/descriptor/output failure cannot become success.

## 3. 1b-ii Binary and Verifier Closure

The 1b-ii commit changed exactly four non-document paths and 971 lines
(939 insertions plus 32 deletions). It closed exact current projections for the
SwiftPM driver and Xcode Debug/Release driver while retaining the ordinary App,
diagnostic surfaces, lifecycle helper and dependency-free Release shell as
negative controls.

| Evidence | Result |
| --- | --- |
| accepted 1b-i staged-only serialized regression | 1,550 tests / 81 suites passed; one invocation, no retry; not repeated by verifier-only 1b-ii |
| exact SwiftPM/Xcode current projections | passed |
| `scripts/verify-contract` | exit 0 |
| complete App/Release boundary | exit 0 |
| grouped and cross-group implementation review | no unresolved P0-P2 |
| immutable seal marker | 1/1 passed |
| post-seal `scripts/verify-contract` | exit 0 |
| seal micro-review | no unresolved P0-P2 |

The verifier-only seal binds the accepted 1b-ii implementation tree and rejects
source, test, script, mode, path-set and projection drift. It changes no runtime
behavior.

## 4. Completion Audit

| Frozen requirement | Concrete evidence | Result |
| --- | --- | --- |
| zero-argument fixed role selection | 1b-i production entry and focused role/ordering tests | covered |
| accepted intake/cohort/inner graph | direct composition plus target-boundary tests | covered |
| canonical non-admitting artifact | golden/mutation/self-digest tests and binary projection | covered |
| bounded exact stdout | EINTR, short/zero/error, wait and deadline tests | covered |
| fixed error precedence | cancellation/uncertainty and status tests | covered |
| Debug/Release reachability and product absence | positive and closed-image negative controls | covered |
| scope and immutable identity | 5-path 1b-i, 4-path 1b-ii and verifier-only seal | covered |
| no premature admission | no live privileged/model gate or readiness artifact | covered |

## 5. Non-Claims and Remaining Order

This checkpoint did not run `scripts/verify --full`, request root or `sudo`,
install or launch the real App/helper, invoke real XPC, run the Machine driver,
call Codex or App Server, read subscription auth, access the network, execute
the no-model privileged gate, accept ADR 0018 or create machine readiness.
App/Release evidence is build/static projection evidence, not live App execution.

Task 39 remains incomplete, ADR 0018 remains Proposed and production Deep Dive
remains unavailable. The strict remaining order is:

```text
ii-c0b non-root capsule author and launcher/TTY/FD hygiene
-> ii-c privileged no-model installed-driver gate
-> L3c3d one authenticated real-success pending candidate
-> L3c4 sealed final admission and authoritative full
```
