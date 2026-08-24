# Phase D Task 39B2c L3c3c-ii-b5b-iii-b2a-ii-a2 Scope/Trust Preflight

> Status: frozen; a2-0 current
>
> Date: 2026-08-24
>
> Baseline: `cec75c2b3385ad44b0a78d63c48ba833c86dcf94`
>
> Scope: finish the package-closed Darwin App/protocol/terminal composition
> behind the already sealed a1 transport. No public zero-argument driver entry,
> real installed App/helper/XPC, sudo/root execution, Codex/model/network,
> readiness claim or authoritative full verifier.

## 1. Why a2 is split before coding

The a1 closure proves only the outer/inner process and FD 2/8/9 transport. The
remaining a2 work spans three independent trust transitions:

1. the inner receives request bytes only on FD 8, while the current strict
   decoder requires an outer-owned `expectedSelection`;
2. the existing App session makes the App its own process-group leader and owns
   group-wide retirement, while the accepted topology requires the App to
   inherit the inner-led PGID and forbids the inner from signalling its own
   process group; and
3. only the outer may join EOF, direct-child exit, reap-last/empty-group, helper/
   L1 absence and unchanged driver observation into the existing one-shot
   admission actor.

Combining these changes would touch four already sealed state machines and more
than the 14-path / 4,000-line preflight threshold. a2 is therefore frozen as:

```text
a2-0 self-contained untrusted request/invocation decode
-> a2-i inner-owned App session with inherited inner PGID
-> a2-ii outer/inner protocol, terminal evidence and admission join
-> iii-b2b zero-argument entry/final artifact
```

These are internal checkpoints of one a2 gate. They may be fixed within their
budgets but will not be recursively split again unless a new P0/P1 proves the
frozen ownership model impossible.

## 2. a2-0 — Self-contained untrusted decode

### Contract

- Add one package-only `InvestigationMachineSingleEpochInvocation` decoder that
  reconstructs a complete candidate selection from canonical bytes.
- Distinguish genesis and successor by their exact transcript domains; require
  exactly one candidate decoder to succeed.
- Validate outer-attempt UUID, capsule/input hashes, canonical epoch and
  projection, ordinal/scenario/projection joins, predecessor transcript/digest
  and previous-helper semantics, then require exact re-encoding.
- Add a package-only `InvestigationMachineDarwinEpochRequest` decoder that uses
  that invocation, preserves the exact outer deadline and derived closed mode,
  and requires exact re-encoding.
- Preserve both existing `decode(..., expectedSelection:)` APIs by delegating to
  the self-contained decoder and then requiring exact equality with the caller's
  independently held selection.
- The decoded values remain non-`Codable`, untrusted and incapable of creating
  ownership, admission, containment, continuity, process or cleanup authority.
  a2-ii still compares them with the outer's c0a plan selection.

### Exact scope and budget

At most seven non-document paths and 1,800 changed non-document lines:

1. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineSingleEpochPhysicalBridge.swift`;
2. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinOuterInnerProtocol.swift`;
3. `Tests/StornautInvestigationTests/InvestigationMachineSingleEpochPhysicalBridgeTests.swift`;
4. `Tests/StornautInvestigationTests/InvestigationMachineDarwinOuterInnerProtocolTests.swift`;
5. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
6. `scripts/verify-contract`; and
7. `scripts/verify-investigation-boundaries`.

No App-release verifier, Package/Xcode graph, Darwin spawn/session/identity/
retirement source, App/Diagnostic/Lifecycle/Machine target or public entry may
change in a2-0.

### Tests-first gate

- genesis and all seven successor ordinals self-decode exactly;
- the existing expected-selection decoder still rejects every foreign axis;
- wrong domain, wrong field count/tag/length/order, nested non-canonical bytes,
  predecessor mismatch, helper drift and trailing bytes fail closed;
- request self-decode preserves the exact deadline and closed scenario mode;
- request/invocation remain non-`Codable` and expose no admission conversion;
- focused tests, affected Investigation tests, contract/investigation boundary
  gates, one staged-only serial and independent review; no full.

## 3. a2-i — Inner-owned inherited-PGID App session

The existing `InvestigationMachineDarwinEpochSessionFactory` cannot be reused
unchanged: it sets `POSIX_SPAWN_SETPGROUP` with pgroup zero, requires
`App.PGID == App.PID` and retires that group. Under the accepted topology the
inner is already the group leader; group signalling from the inner would signal
itself and violate outer ownership.

a2-i therefore adds one closed topology policy to the existing session machinery
instead of copying the STNP/STNH business state machine. It must:

- spawn only the fixed diagnostic App, with one-element argv, empty environment,
  fixed FD 7 and `POSIX_SPAWN_CLOEXEC_DEFAULT` without `SETPGROUP`;
- require `App.PPID == inner PID` and `App.PGID == inner PGID` in the existing
  two-stage App identity observation;
- preserve the exact pre-drop/drop/configuration/claim/L2/release/App protocol;
- on normal completion wait/reap only the direct App child and never signal a
  process group; on failure close FD 7 and use only direct-child fallback; and
- return only existing opaque ownership/local-completion values.

Maximum eight non-document paths and 3,200 changed lines: the existing Darwin
epoch session and App identity sources, their two existing focused test files,
the target-boundary test and three verifier scripts. A copied second business
state machine, new target, C shim, App source or public entry is forbidden.

## 4. a2-ii — Terminal evidence and sole admission join

a2-ii owns one package-only outer/inner composition actor. It consumes the a1
session once, sends the exact a2-0 request, drives the existing inner/outer
protocol actors and joins only authority-free observations. The inner sends
ownership before release; outer independently re-observes inner/App topology
before acknowledgement. Normal completion sends one result then EOF; parent
crash sends no result.

Only the outer owns exact-group TERM/KILL, waitable inner leader, reap-last and
post-reap-empty proof. Existing claim evidence already carries the exact L1
residue bound to the claimed helper; existing claim-client release/abort paths
independently prove the original helper absent. a2-ii may expose a narrow
injected terminal-observation seam, but `StornautInvestigationMachineDriverSupport`
must not import `StornautLifecycle`, `StornautInvestigationMachine`, Core, Codex
or Execution. Concrete machine wiring remains in the already approved later
composition/entry gates.

Maximum twelve non-document paths and 3,800 changed lines: at most one new
composition source and one focused test, the existing outer-inner session,
protocol, single-epoch/continuity seams only when required, target-boundary test
and three verifiers. No second admission token initializer, second continuity
mint, public entry, package graph change or product availability change is
allowed.

## 5. Non-claims and remaining order

All three checkpoints use only injected or same-UID disposable fixtures. They
do not run the installed signed topology or administrator ceremony. `iii-b2b`
still owns zero-argument role routing and final artifact projection; `ii-c0b`
owns non-root capsule/TTY/FD launcher evidence; `ii-c` owns the unique no-model
privileged machine attempt and ADR 0018 decision; `L3c3d` alone owns the real
authenticated Codex App Server run; and `L3c4` alone owns readiness and the
remaining full verifier.

```text
a2-0 -> a2-i -> a2-ii -> iii-b2b -> ii-c0b -> ii-c -> L3c3d -> L3c4
```

Task 39 remains incomplete and production Deep Dive remains
`.implementationUnavailable`.
