# Phase D Task 39B2c iii-b2b-1a-1 Outer Observation Review

> Status: complete / non-admitting
>
> Date: 2026-08-26
>
> Baseline and implementation parent:
> `31347396b922537e7f11540e47c394fb873c28db`
>
> Staged validation commit:
> `31f7ed3d7432eec5e4e9c63eda35d1688b0a29c7`
>
> Implementation commit:
> `fe4f6add2d752e0241af9379fa67bbdf8d56b8a3`
>
> Implementation tree:
> `6bd6d38471b4fdfb6e0392d65d8d281b2bf62d28`
>
> Immutable seal commit:
> `2c31a7c9d3c1c9ae39445e3147f84721f389d729`
>
> Seal tree:
> `5dc95c4a0735dc3eacfb38e77204245b23e9ce35`
>
> Next frontier: iii-b2b-1b zero-argument entry and final non-admitting
> artifact

## 1. Result

iii-b2b-1a-1 is complete and remains non-admitting. The fixed Machine driver
now has a concrete outer-owned observation path that:

- observes the complete installed-driver identity before the child is started
  and after terminal retirement, and requires byte-identical canonical
  digests;
- revalidates the exact inner driver PID/version/PPID/PGID/ASID/audit-token
  identity and the exact App identity/topology before accepting ownership;
- accepts original App/helper absence only for conclusive `ESRCH` or numeric
  identity reuse, while unreadable, malformed or same-version drift remains a
  closed failure;
- revalidates the canonical helper-sealed claim evidence against the selected
  nonce, App/helper identities, L1 audit session and UID, four zero residue
  counters and release deadline;
- preserves one-shot actor state across reentrancy, cancellation and absolute
  deadline checks; and
- constructs the production composition with one shared concrete observer for
  ownership and terminal observation.

The implementation does not create readiness evidence. It supplies the
outer-owned facts required by the existing package-closed admission join.

## 2. Scope and Immutable Identity

The implementation changed exactly eight non-document paths. Its `2,770`
insertions plus `30` deletions equal exactly `2,800` changed lines, at the
frozen checkpoint ceiling. Source/test/script modes are fixed: Swift sources
and tests are `100644`; the three verifier scripts are `100755`.

The immutable seal binds the implementation commit, parent, tree, exact path
set, modes and exact changed-line count. For every one of the eight paths it
constructs an equal-line-count single-byte same-path substitution, preserving
the budget so the substitution must be rejected specifically by the completed
tree check rather than by a coincidental line-count failure.

## 3. Validation

| Gate | Result |
| --- | --- |
| concrete outer-observation structural gate | exit 0 |
| complete App/Release boundary | exit 0; SwiftPM and Xcode Debug/Release driver positive controls, closed-image negative controls and Release fixture passed |
| staged validation identity | commit `31f7ed3d`; tree exactly `6bd6d384` |
| sole staged-only serialized regression | 1,535 tests / 80 suites passed; 98.200 seconds test time; 167.56 seconds wall time |
| maximum benchmarks | all five explicitly skipped from the ordinary serial |
| final seal-focused test | 1/1 passed |
| complete verifier contract after seal | exit 0, including eight equal-line same-path substitutions |
| diff hygiene | `git diff --check` passed; no unstaged drift |
| implementation review | production, tests and verifier groups ended with no unresolved P0-P2 |
| seal review | independent verifier review confirmed the 3-file seal, all eight same-path mutations and all self/source hashes; no P0-P2 |
| coverage | skipped: no configured Swift incremental-coverage gate |

The App/Release gate and serialized regression each ran once for the accepted
implementation tree. They were not repeated for the verifier-only seal. The
seal contract initially exposed two test-oracle issues: the changed-line count
must include additions and deletions (`2,800`, not only `2,770` insertions), and
an append-only tamper was rejected by the saturated budget before reaching the
tree check. The final equal-line substitution fixture closes both evidence
issues without changing production code.

## 4. Review Adjudication

An adversarial pass raised three questions, all independently rechecked against
the complete construction path:

1. Exact claim-request equality is validated by the helper and the inner claim
   client, the only layer retaining the random request. The outer validates the
   immutable canonical evidence carriage plus independent child/App topology;
   its nonzero request-binding check is therefore structural, not the source of
   request authenticity.
2. L1 is a fresh helper-sealed same-retire observation created after audit
   session drain, worker exit, runtime-root removal and lease removal. The
   outer then independently observes App/helper disappearance and unchanged
   driver state. A second L1 scan is not part of the frozen split.
3. The retirement outcome has a `fileprivate` initializer and one production
   mint site after leader-last reap, post-reap empty-group observation and
   descriptor closure. The protocol booleans are projections of possession of
   that opaque capability, not caller-provided claims.

The final production/test/verifier adjudications contain no unresolved P0-P2.

## 5. Non-Claims and Remaining Order

This checkpoint did not install or launch the fixed App/helper, invoke real
XPC, request root or `sudo`, call Codex or App Server, read subscription auth,
access the network, run the no-model privileged gate, create a machine-ready
report or run `scripts/verify --full`. ADR 0018 remains Proposed, Task 39
remains incomplete and production Deep Dive remains unavailable.

The strict remaining order is:

```text
iii-b2b-1b zero-argument entry/final artifact
-> ii-c0b non-root capsule author and launcher/TTY/FD hygiene
-> ii-c privileged no-model installed-driver gate
-> L3c3d one authenticated real-success pending candidate
-> L3c4 sealed final admission and authoritative full
```
