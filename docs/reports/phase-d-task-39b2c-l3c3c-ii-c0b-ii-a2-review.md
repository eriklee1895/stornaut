# Phase D Task 39B2c L3c3c-ii-c0b-ii-a2 Verifier Closure Completion Audit

> Status: complete / non-admitting
>
> Date: 2026-08-27
>
> Implementation commit:
> `f11eea42ef295f49b20e1c0f3912d4b32448b968`
>
> Parent: `030b2805660cf2f9b17cd06f0cfa77d78490a8ec`
>
> Tree: `d0683495ea37d0692677c98f491f3037eaedba4c`
>
> Next frontier: ii-c0b-ii-b owner-only capsule node

## 1. Result

ii-c0b-ii-a2 is complete and remains non-admitting. Together with the pushed
ii-c0b-ii-a1 implementation, it closes the exact seven-path ii-c0b-ii-a kernel
last-close ownership checkpoint. The aggregate consumes exactly 2,870 changed
lines, matching but not exceeding the frozen aggregate ceiling.

The implementation changes exactly four non-document paths and 889 lines
against the immutable a1 baseline. It adds no product feature flag, App or Xcode
membership, runtime launch, privilege, XPC, model, authentication, network or
machine-readiness path.

## 2. Closed Proof Surface

- The a1 implementation commit, tree, ownership source and focused-test source
  identities are pinned, and the original seven-path aggregate is admitted only
  as the exact three a1 paths plus four a2 paths.
- The ownership target remains package-internal, non-product and dependent only
  on `StornautInvestigationHandoffContract`; source inventory and forbidden
  authority checks reject broader reachability.
- Canonical DEBUG SILGen is normalized and sealed, with executable mutations
  proving that an extra `flock` call site or comment-only marker spoof cannot
  satisfy the contract.
- Debug SwiftPM objects provide the ownership positive control. Release objects,
  ordinary App/helper/driver/Machine objects and the complete diagnostic bundle
  provide negative controls. Machine Debug and Release inventories each require
  exactly seven target objects.
- Closed-image enumeration is materialized into a controlled inventory and
  propagates `find` and downstream scan failures rather than accepting an empty
  or partial scan.
- Standard bare `scripts/verify-contract` runs the ownership semantic, scope,
  mutation and immutable replay gates. The bare App/Release gate invokes the
  two-argument component verifier against its existing DerivedData instead of
  repeating its Xcode builds.
- c0b-i is replayed in a temporary worktree from implementation commit
  `2493e0f28e0c8d406b4efcdbf17713bde3633449` and tree
  `8155d64c4966fb83c332f7d195a92095e0af2ba9`, using its own frozen verifier and
  source identities. Current-tree revalidation is not substituted for that
  historical proof.

## 3. Exact Scope and Seals

The four non-document paths are:

1. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`
   — 81 added lines;
2. `scripts/verify-app-release-boundaries` — 331 added lines;
3. `scripts/verify-contract` — 149 added and 3 removed lines; and
4. `scripts/verify-investigation-boundaries` — 325 added lines.

Accepted SHA-256 identities are:

- target-boundary test:
  `ee0ee2918638c1289c7e136a0aa552c36d54c0a1b163f1b7eb281859d397d4bf`;
- App/Release verifier:
  `4015e672e3dd560735d78f5f118ca11dc980cb3778cae153f1d90a8139287ff9`;
- contract verifier:
  `0bc6acae096a3748ac2c29ab2db36370bde97c986dba812e92167082fa35ca87`;
- Investigation verifier:
  `41cb8dafbc8e0e7d817a9e6796284957a881429e8d6535d4f2f4678a3c3083bc`;
- normalized contract self-seal:
  `bf755e318c51d3bff09436d8b1290f72e6364aed82859279952f2981ab5ad107`;
  and
- normalized DEBUG SILGen seal:
  `186a1e96dcf613b2285d6db9daefc6053bd8a49a56480beb42635e83aad0fc77`.

The a1 child used 1,981 lines and the a2 child uses 889 lines. Their exact
seven-path aggregate is therefore 2,870 lines. No repair margin remains in this
aggregate; later work must not modify it implicitly.

## 4. Validation and Review

| Evidence | Result |
| --- | --- |
| ownership semantic mode | exit 0 |
| source-boundary mode | exit 0 |
| exact staged-scope mode | exit 0 |
| target-boundary focused test | 1/1 passed |
| bare `scripts/verify-contract` | exit 0; standard ownership wiring and mutations passed |
| component/closed-image gate | exit 0 |
| bare `scripts/verify-app-release-boundaries` | exit 0 after 843.296701375 seconds |
| exact final scope | 4 paths / 889 lines; aggregate 7 paths / 2,870 lines |
| syntax and whitespace | all three shell scripts parse; staged and worktree diff checks pass |
| independent verifier review | no unresolved P0-P2 |
| independent cross-boundary review | no unresolved P0-P2 |
| `bits-code-guard` final finding set | empty (`[]`) over all four final paths |

The final bare App/Release run started only after all four files reached their
final modification times. The same recorded execution completed with status
`completed`, exit code 0 and exact terminal marker
`Release App fixture boundary verification passed.` Earlier interrupted or
failed executions are not used as evidence.

The initial independent review found three issues: missing standard-verifier
wiring, marker/comment spoofability with an unbounded additional call site, and
failure loss during process-substitution enumeration. All three were fixed
before the final file freeze; two independent post-fix reviews then reported no
unresolved P0-P2.

No staged serial or `scripts/verify --full` was run. That is the frozen
validation ownership: c0b-iv owns the sole aggregate c0b staged-only serial and
L3c4 owns Task 39's remaining authoritative full verifier.

## 5. Prompt-to-Artifact Checklist

| Requirement | Concrete artifact/evidence | Status |
| --- | --- | --- |
| bind exact a1 implementation | commit/tree and source/test SHA checks in standard contract gate | complete |
| enforce exact seven-path aggregate | staged-scope gate plus wrong-baseline/path/mode/binary/delete/budget mutations | complete |
| freeze package-only target surface | target-boundary test and Investigation source gate | complete |
| reject semantic spoofing | normalized SIL seal plus extra-callsite and comment-spoof mutations | complete |
| prove component and final-image closure | Debug positive; Release/product/closed-image negative controls | complete |
| preserve c0b-i evidence | immutable historical worktree replay using frozen verifier | complete |
| propagate verifier failures | explicit command, inventory and scan status handling | complete |
| independent review | two final no-unresolved-P0-P2 reviews and empty final finding set | complete |
| remain non-admitting | no root/sudo, App/helper/driver launch, XPC, model/auth, network or readiness | complete |
| defer serial and full to their owners | no serial/full in a1 or a2 | complete |

## 6. Non-Claims and Next Step

This checkpoint does not publish or recover a capsule, transfer launcher/TTY/FD
authority, perform a privileged machine attempt, call the real Codex App Server
or admit machine readiness. ADR 0018 remains Proposed, Task 39 remains
incomplete and production Deep Dive remains unavailable.

The next frontier is ii-c0b-ii-b. It owns the owner-only canonical capsule node,
one-shot path-free descriptor lease and replacement-safe settlement/recovery. A
scope/cost preflight must confirm or split that checkpoint before coding.
