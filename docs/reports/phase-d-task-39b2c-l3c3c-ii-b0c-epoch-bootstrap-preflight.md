# Phase D Task 39B2c-L3c3c-ii-b0c Epoch Bootstrap Prelude Preflight

> Status: Complete; implementation evidence in the separate ii-b0c review;
> ii-b1 current
>
> Date: 2026-08-19
>
> Baseline: `e7c6b1cfa35d8d7cefb3b03d58e73efe123d33ed`
>
> Scope: package-only epoch bootstrap bytes and tests; no App leaf, socket I/O,
> process launch, credential drop, helper claim, install, privilege, model/auth,
> readiness or full verifier

## 1. Blocking Contradiction

The ii-b1 preflight found that the frozen first-frame contract cannot be
implemented by the real zero-argument App as written:

1. `PRE_DROP_READY` is the first STNH frame and travels App -> driver;
2. every STNH frame must carry the driver/capsule-owned epoch UUID and absolute
   epoch deadline;
3. the App accepts no argv, environment, config path, filesystem mailbox or
   caller-selected endpoint; and
4. no driver -> App message precedes `PRE_DROP_READY`.

The b0a tests inject the UUID and deadline directly, which is correct for a byte
contract but cannot prove a source for those values in the later App leaf. The
App must not invent either value, derive them from PID/time, read them from a
path, or accept them through argv/environment. Any of those choices would break
the capsule join or reopen a caller-controlled input surface.

Therefore ii-b1 cannot begin until one smaller package-only checkpoint freezes
an exact driver-owned bootstrap prelude. This is a protocol-completeness fix,
not a new product capability.

## 2. Exact STNP Prelude

Before any STNH frame, the driver writes exactly one fixed 32-byte prelude on
its end of the already-created unnamed duplex socketpair:

```text
UInt32 magic                         // 0x53544e50, ASCII STNP
UInt16 version                       // exactly 1
UInt16 totalByteCount                // exactly 32
UUID epochUUID                       // 16 raw network-order bytes
UInt64 epochDeadlineNanoseconds      // big-endian, nonzero
```

All integers are big-endian. Version 1 has no optional, extension, padding or
trailing byte range. The epoch UUID and deadline are the exact already-admitted
capsule/runtime values later repeated by all eleven STNH frames. Both are
nonzero. The package-only decoder represents the absolute deadline without
reading a clock or performing deadline arithmetic.

The prelude carries no ordinal, scenario, configuration nonce/body/digest,
binding digest, PID, identity, path, token, handle, service, action or authority
field. It is not an STNH frame, does not consume sequence zero and does not
change the frozen `1...11` frame order.

## 3. Runtime Ordering and Joins

The later runtime checkpoints must use the following exact order:

```text
driver creates fresh socketpair and spawns fixed App on FD 7
-> driver writes one exact bounded STNP prelude immediately after spawn
-> App independently admits the inherited root peer before consuming bytes
-> App reads exactly 32 bytes and strictly decodes STNP
-> App sends PRE_DROP_READY with the exact prelude UUID/deadline
-> driver compares PRE_DROP_READY to both sent prelude and capsule row
-> existing DROP_RELEASE ... EXIT STNH sequence continues unchanged
```

The 32-byte write fits the bounded socket buffer and does not wait for an App
message. The App first performs peer admission and only then consumes it. A fresh socketpair is owned by
one epoch, so no prelude or partial decoder state is reused. Short read, EOF,
wrong magic/version/size, zero values, trailing bytes in a single-prelude decode
or mismatch at the PRE_DROP_READY/capsule join is terminal.

Responsibility remains split:

- **ii-b0c** owns only the fixed value type and exact encode/decode bytes;
- **ii-b1** owns the injected App-side state machine and consumes an admitted
  prelude value without opening a socket or reading a clock;
- the native diagnostic harness later admits fixed FD 7 as one connected
  `AF_UNIX/SOCK_STREAM` and supplies only closed facts to the public thin runner;
- **ii-b5** owns concrete driver write/read ordering, capsule comparison and
  the fresh per-epoch channel; and
- **ii-c/L3c4** remain the only privileged/machine-readiness gates.

## 4. Frozen Implementation Surface and Budget

ii-b0c may change exactly these five non-document paths and at most 900
added-or-changed lines:

1. `Sources/StornautInvestigationHandoffContract/InvestigationHandoffEpochBootstrapContract.swift`;
2. `Tests/StornautInvestigationTests/InvestigationHandoffEpochBootstrapContractTests.swift`;
3. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
4. `scripts/verify-investigation-boundaries`; and
5. `scripts/verify-contract`.

`Package.swift` remains unchanged because the target and test dependency already
exist. `scripts/verify-app-release-boundaries`, Xcode project/schemes, App,
Diagnostic, Runtime, Lifecycle, Machine, DriverSupport and helper sources remain
unchanged. Approaching the line ceiling requires another split before coding.

The new source imports Foundation only, remains package-scoped/non-`Codable`, and
contains no public API, filesystem, clock, socket, process, XPC, Security, signal,
network, model, cleanup or mutable state owner. Existing target/product/consumer
closure remains unchanged.

## 5. Tests-First and Validation Contract

Tests-first coverage must include:

- one exact 32-byte golden vector and round trip;
- magic, version, declared-size and endianness drift;
- zero UUID and zero deadline;
- every partial length `0...31`, 33-byte trailing input and oversized input;
- proof that no configuration, handle, token, identity or path bytes exist; and
- structural proof that the target remains test-only and authority-free.

Validation is: compile RED for the missing type -> focused bootstrap suite ->
complete handoff/Investigation affected tests -> Debug/Release contract target
build -> independent structural/verifier gates -> one clean staged-only serial ->
independent review -> commit/push. A failed serial is not rerun for a green
headline.

This checkpoint does not run App/XCUITest, `verify-app-release-boundaries`,
authoritative headless/full verification, sudo, install, a signed App, model or
auth. It cannot accept ADR 0018 or claim Task 39 readiness.

## 6. Status and Next Gate

ii-b0a and ii-b0b remain complete and are not reopened. ii-b0c completed the
first-frame origin correction; ii-b1 resumes with the corrected order and its
own exact-path preflight.

ADR 0018 remains Proposed, Task 39 remains incomplete, production Deep Dive
remains unavailable, real Trash remains closed and the remaining authoritative
full verifier remains reserved for L3c4.
