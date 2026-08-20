# Phase D Task 39B2c-L3c3c-ii-b4 Fixed Helper-Claim Client Preflight

> Status: Scope/cost, dependency, state-machine and tests-first contract frozen;
> implementation current; non-admitting
>
> Date: 2026-08-20
>
> Baseline: `5acbe22f8b278dd1bd5ba6db0aaa75fb18e3e68b`
>
> Scope: documentation and current-source inspection only; no source/test/script
> implementation, App/helper launch, real XPC, install, privilege, model/auth,
> serial regression or authoritative full verifier

## 1. Decision

L3c3c-ii-b4 remains one bounded implementation checkpoint. It adds the only
concrete root-driver machine-claim client inside
`StornautInvestigationMachineDriverSupport`. The target gains one one-way
dependency on `StornautInvestigationHandoffContract`; package-scoped wire types
are visible across targets in the same package, so no public access widening is
required. `StornautLifecycle`, `StornautInvestigationMachine`, the helper/server
and the shared wire remain unchanged.

The client never accepts a service, path, endpoint, authorization, connection
epoch, release challenge or deadline from a caller. Compile-time constants bind:

- service `com.eriklee.stornaut.lifecycle.machine-claim`;
- helper `/Library/Application Support/Stornaut/Stornaut-R5-Diagnostic.app/Contents/MacOS/StornautLifecycleHelper`; and
- helper signing identifier `com.eriklee.stornaut.lifecycle.helper`.

ii-b5 supplies only the already-validated typed retirement handle, exact App
identity, shared outer-epoch deadline and explicit previous-helper identity.
DriverSupport constructs the claim request, generates the connection epoch and
release challenge, performs the XPC calls,
returns the opaque typed claim evidence with one retained claimed-session token,
and later accepts only that token to release. ii-b5 inserts installed-L2 between
those two package calls but receives no transport-selection authority.

## 2. Frozen Call Graph and State Machine

```text
DriverSupport fixed client
  idle
  -> observe fixed helper static identity
  -> create exactly one privileged NSXPCConnection(fixed service)
  -> set exact code-signing requirement before activate
  -> dispatch CLAIM once
  -> strict XPC reply + CLAIM_EVIDENCE decode
  -> bind connection PID/EUID/ASID to complete helper audit token
  -> Security dynamic lookup by audit token
  -> require fixed path and static == dynamic signing identity
  -> claimed(retained connection, evidence, internal session token)

ii-b5 performs installed-L2 using the returned helper identity

  claimed
  -> generate fresh release challenge internally
  -> dispatch CLAIM_RELEASE once on the same retained connection
  -> strict CLAIM_RELEASED echo/deadline validation
  -> observe the exact original helper identity absent before acknowledged bound
  -> prove local connection invalidated and session terminal
  -> released
```

Any failure before dispatch is `unavailable`. Once claim or release dispatch may
have crossed the external boundary, missing/malformed reply, interruption,
invalidation, cancellation, helper-exit ambiguity or deadline ambiguity is
`outcomeUnknown`. No retry or second connection is possible. A future epoch must
construct a new client, observe a different complete helper identity and repeat
the fixed static/dynamic join plus installed-L2.

## 3. Helper Identity and Exit Evidence

No broad Lifecycle client or service probe is reused. The claim evidence already
contains the helper PID, PID version, ASID, EUID and all eight audit-token words.
The retained XPC connection exposes PID/EUID/ASID. DriverSupport joins both, then
uses the audit token with Security `SecCodeCopyGuestWithAttributes`, checks
dynamic validity, resolves the dynamic static code and requires its exact path
and signing identity to equal a fresh strict static-code observation at the fixed
helper path. The helper must be ad-hoc signed as installed by this local-only
diagnostic topology.

The process probe is identity-aware and read-only: it re-observes the original
PID and complete audit-token identity. `ESRCH` or a reused PID with a different
identity proves the original helper absent; permission, malformed identity or an
unchanged live identity at the acknowledged deadline is ambiguity, never
success. It does not signal, kill, bootout or mutate the helper. Server-side
escrow/listener terminal semantics remain owned by the existing helper server;
client-side stale state is proved by its one-shot terminal state, exact helper
absence and invalidated retained connection. Global service absence is not
required because launchd may create the next fresh helper.

## 4. Frozen Scope and Cost

At most ten non-document paths and 3,200 added-or-changed lines:

1. `Package.swift`;
2. one new `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineClaimClient.swift`;
3. optional second DriverSupport source only if physical identity/signing probes must be separated;
4. one new focused `Tests/StornautInvestigationTests/InvestigationMachineClaimClientTests.swift`;
5. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
6. `scripts/verify-investigation-boundaries`;
7. `scripts/verify-app-release-boundaries`;
8. `scripts/verify-contract`;
9. `Stornaut.xcodeproj/project.pbxproj` only if an unexpected explicit link is proven necessary; and
10. one existing DriverSupport test/source only if the package-only entry seam cannot be tested through the focused file.

Current estimate is 7–8 paths and 2,700–3,100 lines after independent review
required the full concurrency, ambiguity, identity and deadline matrix. Xcode is expected to remain
unchanged because the native target already links the DriverSupport product and
that product already links Security. Requiring `StornautLifecycle`, a public wire
change, helper/server change, Machine-host transport code, a caller-provided
service/path or a new system framework forces a new preflight before coding.
Verifier/mutation growth above roughly 750 lines also forces a cost re-audit.

## 5. Tests-First RED Contract

Focused injected tests must prove:

1. exactly one claim is dispatched and the retained connection remains live;
2. release cannot occur before the claimed session is returned to ii-b5;
3. exactly one release uses the same connection epoch, request digest and helper identity;
4. release success requires exact `CLAIM_RELEASED`, post-reply deadline and bounded original-helper absence;
5. static helper path/signing, dynamic audit-token signing and connection PID/EUID/ASID all join exactly;
6. every helper identity, signing, path, digest, challenge, epoch and deadline drift fails terminally;
7. pre-dispatch failure is unavailable, while every post-dispatch ambiguity or cancellation is `outcomeUnknown`;
8. invalidation is delayed until the released/exit outcome and occurs exactly once;
9. repeated/concurrent claim or release has one winner and no replay;
10. a next epoch rejects reused helper identity and succeeds only with a different fresh identity after terminal cleanup; and
11. output/session types are package-scoped, opaque, `Sendable`, non-`Codable` and contain no connection/path/service choice.

Server-side claim/release/reply-dispatch/timer race semantics are already covered
by the completed ii-b2b tests and are not duplicated. This checkpoint tests the
new client state, transport ordering, peer binding and exit observation.

## 6. Structural, Mutation and Final-Mach-O Gates

The source/package gate freezes:

- DriverSupport dependencies exactly `StornautInvestigationHandoffContract`;
- one fixed service and helper path literal;
- one concrete `NSXPCConnection` creation;
- exact claim then release selector use on one retained connection;
- static/dynamic Security join and complete audit-token binding;
- delayed invalidation, helper absence and terminal `outcomeUnknown`; and
- no `StornautLifecycle`, broad Lifecycle clients, caller configuration,
  network, write, cleanup, Policy, Executor, Trash, process spawn or signal API.

Mutation controls cover environment-selected service, caller helper path, broad
Lifecycle import/client, removed attestation, PID-only identity, immediate
post-claim invalidation, skipped release reply, skipped helper absence, second
connection/retry, `outcomeUnknown` downgrade, extra path, budget and deletion.

Final-Mach-O controls require the native Debug and Release driver to contain the
fixed service, XPC selectors, `NSXPCConnection`, audit-token/Security and helper
absence symbols. Ordinary App/diagnostic leaf/release-shell images remain
negative for the client type and fixed service. Existing authority-forbidden
imports remain closed; only the reviewed read-only XPC/Security/process-identity
projection is added. Xcode target/product ownership remains unchanged.

## 7. Validation Funnel and Non-Admission

```text
RED focused client tests
-> complete focused client suite
-> affected DriverSupport/Handoff/claim-server contract tests
-> structural and mutation gates
-> targeted Debug/Release SwiftPM driver builds
-> native Debug/Release final-Mach-O gate
-> one staged-only serial with five maximum benchmarks skipped
-> independent grouped review
-> implementation commit/push
-> completion audit/docs commit/push
```

`scripts/verify --full` remains forbidden before L3c4. ii-b4 does not run the
real fixed client, launch or install the App/helper, use sudo/root, perform L2,
call Codex/model/auth/network, create a report/receipt or claim readiness. ADR
0018 remains Proposed, Task 39 remains incomplete and production Deep Dive stays
`.implementationUnavailable`. The strict next checkpoint after completion is
ii-b5 fixed single-epoch composition.
