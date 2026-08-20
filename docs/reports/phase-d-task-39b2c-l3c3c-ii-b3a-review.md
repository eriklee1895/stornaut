# Phase D Task 39B2c-L3c3c-ii-b3a Fixed Handoff Adapter Review

> Status: Complete; fixed FD 7/root-peer/bootstrap transport, stable peer
> observation, irreversible credential drop, exact post-drop evidence,
> structural/final-artifact gates, one staged-only serial and independent
> post-fix review passed; non-admitting
>
> Date: 2026-08-20
>
> Implementation commit: `62f8b0fe8a7c60106bfbbc3caf65f2585c7d0ac7`
>
> Validated tree: `df31f7d74f0628933c0df3ce80adc41c37ab5b2f`
>
> Staged validation commit: `9a0455bc3c5524f08de35bc22ed35820b44a63b3`
>
> Scope: fixed channel/root-peer/drop primitives only; no complete leaf
> conformance, native entry composition, App/helper launch, real XPC, install,
> privilege, model/auth, readiness or authoritative full verifier

## 1. Outcome

L3c3c-ii-b3a is complete. The DEBUG-only diagnostic package now owns one
concrete, one-shot App-side handoff adapter. It reads creation-time
`LOCAL_PEERTOKEN` evidence from fixed FD 7, applies the existing Machine-driver
admission policy before consuming the 32-byte STNP bootstrap, and retains the
exact stable process/signing observation for ii-b3c's later configuration join.
The observation is explicitly current-peer self-consistency, not independently
installer-authenticated provenance.

The adapter enforces a checked five-second bootstrap bound and a maximum
140-second epoch. Exact frame reads/writes run on a private serial queue with
bounded `poll`/nonblocking `recv`/`send`, one-shot continuation resolution and
cancellation that shuts down only the owned descriptor. App-side completion
performs write half-close only; driver-side EOF/EXIT ownership remains outside
this checkpoint.

Credential transition is fixed to UID 501/GID 20. The adapter independently
resolves the bounded directory group set, rechecks the continuous clock
immediately before the first irreversible syscall, then executes
`initgroups -> setgid(20) -> setuid(501)`. It validates real/effective/saved
IDs, all supplementary groups, the complete audit-token identity, and exact
`EPERM` results for `setuid(0)`, `seteuid(0)` and `setgid(0)`. Any concurrent
I/O, deadline expiry, partial transition, evidence drift or replay makes the
single epoch terminal.

## 2. Scope, Cost and Artifact Identity

The implementation changed exactly the eight frozen non-document paths and
2,193 added-or-deleted lines (2,182 additions, 11 deletions), below the
2,200-line ceiling. `Package.swift`, Xcode graph, native harness, pure App leaf,
Runtime transport, helper, Machine client and product composition remained
unchanged.

The implementation and staged validation commits share parent
`59d82511c3fbafc0a167fd72b41186213a16f440` and the exact tree
`df31f7d74f0628933c0df3ce80adc41c37ab5b2f`. The implementation commit is
pushed to `origin/main`.

Verifier source identity at that tree is sealed as follows:

- `scripts/verify-investigation-boundaries`: `5f3e38284d321de3b55755f6d0c779ffb5e626998eec1603dd08bd5b741a0506`;
- `scripts/verify-app-release-boundaries`: `9e1ecb771ef3e35eba71a509a307d809771e7f9c98a11b2bd2122df050de0211`; and
- normalized `scripts/verify-contract`: `3b18677cbf3a5df4ecf0d2a561a9e0c9c6f507134cccafbce1d7fed9ba671588`.

## 3. Prompt-to-Artifact Completion Checklist

| Requirement | Direct evidence | Result |
| --- | --- | --- |
| fixed FD 7 and root peer before bytes | adapter obtains `LOCAL_PEERTOKEN`, admits full root identity, then reads STNP; call-order test and structural order gate | satisfied |
| stable evidence without false authenticity claim | package-only result API returns exact process/signing evidence after repeated identity/path/signing reads; expected-SHA inputs and public result surface are forbidden | satisfied |
| exact bootstrap and epoch bounds | injected clock tests cover overflow, early/equal/late bootstrap, expired STNP and over-140-second epoch | satisfied |
| exact bounded frame I/O | header/payload bounds, direction/sender/epoch joins, nonblocking physical socket smoke, deadline and transport failures | satisfied |
| no cooperative-executor blocking | private serial queue plus checked continuation; semaphore bridges structurally forbidden | satisfied |
| cancellation/completion one-shot | lock-owned resolver tests prove exactly one winner; only the winner shuts down owned FD 7 | satisfied |
| no drop during suspended I/O | read/drop and write/drop reentrancy tests prove terminal rejection and no `initgroups`; pending I/O cannot later succeed | satisfied |
| live deadline before irreversible drop | before/equal/after boundary tests plus structural `deadline < initgroups < setgid < setuid` proof | satisfied |
| fixed UID/GID/group algorithm | bounded user/group resolution, exact 16 selected groups, actual-group comparison and fixed syscall order tests | satisfied |
| complete post-drop evidence | real/effective/saved IDs, audit identity, group set and all three root-regain `EPERM` probes covered | satisfied |
| terminal/replay behavior | partial, duplicate, reordered, concurrent and post-terminal operations fail closed | satisfied |
| package/source authority closure | DEBUG/package-only adapter and evidence API; no argv/environment/path/persistence/network/model/cleanup/readiness authority | satisfied |
| ordinary/release images remain closed | ordinary Debug main, Debug dylib, preview dylib, ordinary Release and diagnostic Release shell are negative controls | satisfied |
| exact scope and cost | canonical real-index gate plus extra-path, over-budget and deleted-path temporary-index mutations; observed 8 / 2,193 | satisfied |
| one valid serial and independent review | exact pushed tree passed once; final runtime/verifier reviews report no unresolved P0-P2 | satisfied |
| no premature admission | no launch/XPC/install/privilege/model/auth/report/readiness/full; ADR 0018 remains Proposed | satisfied |

## 4. Validation Evidence

| Gate | Result |
| --- | --- |
| App adapter focused | 14 tests in 1 suite passed, including read/drop, write/drop and deadline boundary cases |
| Lifecycle admission focused | 10 tests in 1 suite passed |
| Machine boundary focused | 11 tests in 1 suite passed |
| affected regression | 521 tests in 43 suites passed on the final runtime tree |
| `scripts/verify-contract` | exit 0; canonical peer/scope gates, source/self seals and peer/scope/final-image mutations passed |
| `scripts/verify-investigation-boundaries` | exit 0; package/source/authority, deadline/drop order and Debug/Release Machine-driver closure passed |
| `scripts/verify-app-release-boundaries --investigation-handoff-only` | exit 0; targeted build/test and five-image App-adapter absence matrix passed |
| sole staged-only serial | 1,234 tests in 59 suites passed; five maximum benchmarks explicitly skipped |
| serial timing | 79.932 seconds test time; one validation commit, no restart or retry |
| serial identity | validation `9a0455b...`, implementation `62f8b0f...`, identical tree `df31f7d...` |
| independent review | runtime and verifier final reviews found no unresolved P0-P2 |
| diff hygiene | exact 8 paths / 2,193 lines, clean index after commit, `git diff --check` passed |

The targeted Xcode artifact gate emitted only the repository's existing Swift
dependency-scan warnings. It launched no App/helper and performed no root or
external-state mutation. No authoritative full verifier ran; L3c4 still owns
Task 39's remaining full.

## 5. Independent Review and Repairs

Review findings were repaired tests-first before the tree and serial were sealed:

1. terminal epochs could still reach credential drop; terminal admission is now
   checked before any drop work;
2. physical readiness could cross the deadline before `recv`/`send`; the clock
   is rechecked after `poll`;
3. cancellation and completion could race descriptor shutdown; one lock-owned
   resolver now selects the sole winner;
4. the bootstrap concurrency test did not actually suspend in the bootstrap
   read; the injected gate now targets the exact 32-byte read;
5. the checkpoint lacked an executable exact staged scope/cost gate; canonical
   and mutation modes now enforce it;
6. the final-image matrix omitted Debug code-bearing dylibs; Debug dylib and
   preview images are now exact negative controls;
7. credential drop could race an in-flight frame operation; `!ioInProgress` and
   read/write overlap tests now close it terminally;
8. credential drop did not freshly enforce the epoch deadline; it now rechecks
   immediately before `initgroups`, with equality rejected;
9. the contract tested only mutated indexes, not the real staged index; the
   canonical gate now runs first;
10. staged deletions were hidden by `ACMR`; `ACMRD` plus a deleted-path mutation
    now seals the exact path set; and
11. verifier source/self seals drifted during the fixes; all final hashes now
    match the validated/pushed tree.

The final independent runtime and verifier reviews have no unresolved P0-P2.

## 6. Non-Admission and Next Gate

This checkpoint is non-admitting. It does not make the adapter reachable from
the native entry, conform the partial adapter to the complete App-leaf protocol,
start the App Server, launch the App/helper, invoke real XPC, install or execute
a privileged artifact, call a model, consume authorization, prove installed-L2
or make a readiness claim.

ADR 0018 remains Proposed. Task 39 remains incomplete. Production Deep Dive
remains `.implementationUnavailable`; only ii-c may accept ADR 0018, only L3c4
owns machine readiness and Task 39's remaining authoritative full verifier, and
only Task 44 may admit normal-product Deep Dive.

The strict next checkpoint is L3c3c-ii-b3b start-to-retire-only Lifecycle seam.
