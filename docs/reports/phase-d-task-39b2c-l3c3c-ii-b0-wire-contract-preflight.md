# Phase D Task 39B2c-L3c3c-ii-b0 Wire Contract Clarification Preflight

> Status: Split frozen after iterative independent review; ii-b0a complete;
> ii-b0a/ii-b0b/ii-b0c complete; ii-b1 current
>
> Date: 2026-08-19
>
> Baseline: `8b6c780bd8d537074755aca6b736317101baecde`
>
> Scope: documentation and current-source inspection only; no source/test/script
> implementation, serial regression, App/driver launch, install, sudo, model/auth
> use or full verifier

The parent ii-b split correctly separated six trust surfaces, but its ii-b0
contract still contains one contradictory digest encoding, one missing capsule
identity field and several unnamed frame-payload byte layouts. Freezing tests or
APIs against that text would permit two conforming implementations to emit
different bytes. This preflight resolves those ambiguities and splits ii-b0
before implementation.

## 1. Decision

The implementation order becomes:

```text
L3c3c-ii-b0a frame/capsule contract
-> L3c3c-ii-b0b claim/release wire contract
-> L3c3c-ii-b1 authority-free App inherited-FD leaf
-> L3c3c-ii-b2 handle-free helper response migration
-> L3c3c-ii-b3 concrete App drop/no-auth retirement adapter
-> L3c3c-ii-b4 fixed helper-claim client
-> L3c3c-ii-b5 fixed single-epoch driver composition
-> L3c3c-ii-c0 TTY/capsule launcher spike and invocation freeze
-> L3c3c-ii-c one no-model privileged machine gate
```

Both b0a and b0b extend one non-product target named
`StornautInvestigationHandoffContract`. It depends only on Foundation and
CryptoKit and remains unused by every product target until later checkpoints.
b0a owns common primitives, STNH frames and payloads including the one retirement-
handle encoding, plus the cohort capsule. b0b reuses that handle transcript and
adds claim, evidence, release and Data-only XPC contracts.

No b0 checkpoint owns a socket, XPC connection/listener, filesystem, Security
lookup, process, signal, network, model, cleanup implementation or state-machine
transition. In particular, b0b defines the bytes and field meanings of a release
deadline; b2 alone owns `claim -> installed-L2 barrier -> release`, timer
replacement and post-reply helper-exit ordering.

## 2. Findings Requiring the Split

### 2.1 Digest encoding was contradictory

The parent preflight says common STNC digests are raw 32-byte SHA-256 values but
later declares request `configurationSHA256` as lowercase ASCII 64 bytes. The
current Lifecycle handle and signed-runtime domain use a validated 64-hex
`String`, but that domain representation does not need to become a second binary
wire representation.

The corrected rule is:

- every SHA-256 value inside STNH/STNC/capsule binary wire is exactly 32 raw
  bytes;
- a shared `InvestigationHandoffSHA256` value stores exactly those 32 bytes and
  is not `Codable`;
- later adapters accept only an exact lowercase 64-hex domain string and decode
  it once to the raw value, or encode a raw value once to lowercase 64-hex when
  an existing domain API still requires it; and
- no binary decoder accepts ASCII hex, uppercase hex, a 64-byte digest payload
  or an alternate representation.

This makes the shared target the only binary wire truth without changing the
existing JSON/domain contracts prematurely.

### 2.2 The capsule omitted the configuration nonce

The parent preflight requires a unique epoch/config UUID and requires
`CONFIGURATION_ACK` to return the decoded configuration nonce, but its row list
does not commit that nonce. The corrected row carries two distinct UUIDs:

- `epochUUID`, created by the outer driver for transport/lifecycle identity; and
- `configurationNonce`, exactly
  `SignedInvestigationRuntimeDiagnosticConfiguration.nonce`.

Both are nonzero. The outer-attempt UUID, all eight epoch UUIDs and all eight
configuration nonces are pairwise distinct. The App must return the committed
configuration nonce after strict configuration decoding; matching only the
configuration digest is insufficient.

### 2.3 Nonempty frame payloads had no exact layout

`DROP_EVIDENCE`, `CONFIGURATION_ACK`, `HANDLE` and `ACK` were described only as
"exact versioned fixed-binary" payloads. Their exact domains, tags and values
are now frozen below. b0a owns their codecs; b1 owns runtime frame-order and
partial-I/O state transitions.

## 3. Common Binary Primitives

All integers are big-endian. `Int64` uses two's-complement bytes. UUIDs are the
canonical 16 raw bytes in network order. SHA-256 values are 32 raw bytes. ASCII
domains are exact, case-sensitive and contain no NUL. No integer, UUID, digest
or date is encoded as text.

### 3.1 STNC tagged transcript

Every tagged transcript begins with magic `0x53544e43` (`STNC`) as `UInt32`,
followed by fields encoded as:

```text
UInt16 tag | UInt32 byteLength | payload bytes
```

Tag `0` is the exact bounded ASCII domain. Tag `1` is version `UInt32 == 1`.
Business tags begin at `2` and increase contiguously. The enclosing contract
provides the maximum transcript and per-field sizes before a decoder may
allocate. Duplicate, missing, reordered, zero-length, unknown or trailing fields
fail. No field count, padding, alignment, extension or optional-tag range exists
in version 1.

Every domain is `1...64` ASCII bytes. Unless a narrower bound is stated, a
non-capsule transcript and each of its fields are bounded to 4,096 bytes. The
following narrower complete-transcript maxima apply: drop evidence, configuration
acknowledgement, retirement handle, handle acknowledgement, process identity, L1
residue, helper identity, release and released are each at most 1,024 bytes; owner
retirement is at most 512 bytes; claim request is at most 1,024 bytes; claim
evidence is at most 4,096 bytes. A cohort epoch is at most 66,048 bytes and the
outer cohort is at most 1,048,576 bytes. Lengths are admitted against the exact
expected schema before allocation or nested decoding.

Nested transcripts are carried as their complete STNC bytes. A nested decoder
must validate its own exact domain, version, field set and maximum length.

### 3.2 UTC microseconds

Wire time is a positive signed `Int64` count of UTC microseconds since 1970. The
wire owns that integer directly. b0 does not hash `Date` and does not perform
independent rounding. Later adapters convert any finite positive domain `Date`
once with the single shared checked rule
`floor(timeIntervalSince1970 * 1_000_000)`, reject only non-finite, nonpositive or
out-of-`Int64` values, and reuse that admitted integer for construction and
hashing. No adapter rejects a valid current domain value merely because it has
sub-microsecond precision. Flooring applies to event times and validity bounds;
it can conservatively shorten authority by less than one microsecond and can
never extend it. A Date reconstructed for a legacy domain object is derived from
the admitted integer and is never converted back to obtain wire bytes.

### 3.3 Scenario codes

The capsule and configuration acknowledgement use one fixed `UInt32` mapping:

| Code | Scenario |
| --- | --- |
| `1` | `success` |
| `2` | `cancellation` |
| `3` | `timeout` |
| `4` | `invalidEnvelope` |
| `5` | `identityMismatch` |
| `6` | `transportLoss` |
| `7` | `lifecycleRecovery` |
| `8` | `artifactCleanupFailure` |

This is the canonical `SignedInvestigationRuntimeDiagnosticScenario.allCases`
order. Zero and every other value fail. The shared target does not import the
Investigation module; later adapters perform an exhaustive mapping.

## 4. STNH Frame Contract

The frame magic is `0x53544e48` (`STNH`), version is `1`, and the header is
exactly 56 bytes:

```text
UInt32 magic
UInt16 version
UInt16 kind
UInt32 payloadLength
UInt32 sequence
UUID epochUUID                         // 16 raw bytes
UInt64 epochDeadlineNanoseconds
UInt32 senderPID
UInt32 senderPIDVersion
UInt32 senderEffectiveUID
UInt32 senderAuditSessionID
```

The deadline is an absolute system-wide `mach_continuous_time` value converted
to nanoseconds by the runtime owner. b0a rejects zero and represents the value
without arithmetic; later runtime code owns future-window and overflow checks.
PID, PID version and ASID are nonzero, PID is greater than one, and epoch UUID is
nonzero.

The epoch UUID is the ADR 0018 random per-frame nonce: one fresh value is created
for each epoch and repeated by all eleven frames in that epoch. There is no second
frame nonce. Sequence resets to `1` for every epoch; version 1 requires
`kind.rawValue == sequence`, so each kind appears exactly at the sequence shown in
the table and no sequence value is reusable or skippable.

Kinds, sequences, directions, sender phase and payloads are closed:

| Kind/sequence | Direction | Sender EUID | Payload |
| --- | --- | --- | --- |
| `1 PRE_DROP_READY` | App -> driver | `0` | empty |
| `2 DROP_RELEASE` | driver -> App | `0` | empty |
| `3 DROP_EVIDENCE` | App -> driver | `501` | exact STNC below |
| `4 CONFIGURATION` | driver -> App | `0` | opaque `1...65,536` bytes |
| `5 CONFIGURATION_ACK` | App -> driver | `501` | exact STNC below |
| `6 HELLO` | App -> driver | `501` | empty |
| `7 HANDLE` | App -> driver | `501` | exact handle STNC below |
| `8 ACK` | driver -> App | `0` | exact STNC below |
| `9 RELEASE` | driver -> App | `0` | empty |
| `10 ALIVE` | App -> driver | `501` | empty |
| `11 EXIT` | driver -> App | `0` | empty |

All frames in one epoch carry the same epoch UUID and deadline. App PID, PID
version and ASID remain stable across the root-to-UID transition. Its EUID and
therefore its complete audit token change at the frozen point: PRE_DROP_READY uses
the admitted pre-drop root sender facts, while DROP_EVIDENCE and every later App
frame use the admitted post-drop UID-501 sender facts. DROP_EVIDENCE carries only
the post-drop audit-token words, which must project the same stable PID/PID-version/
ASID and new EUID 501 as its frame header. Driver identity remains stable and root.
The header is a claim and never substitutes for independent process/audit/signing
evidence. The b0a API exposes the closed metadata table; b1/b5 enforce state
transitions.

The exact single-frame decoder reads exactly 56 header bytes, validates kind-
specific length before allocation, then reads exactly the admitted payload and
rejects trailing bytes. The incremental stream decoder may accept any chunking,
emit zero or more complete frames and retain a bounded incomplete suffix for the
next call; bytes after one complete frame are parsed as the next frame rather than
called trailing. It may buffer at most one maximum frame, `65,592` bytes
(`56 + 65,536`), before it must either emit or fail. Stream EOF succeeds only with
an empty suffix. Both decoders reject oversized length, integer conversion
overflow, partial EOF and unexpected EOF. Every non-configuration payload is at
most 1,024 bytes. No version-1 extension kind exists.

### 4.1 Drop evidence

Domain: `stornaut.task39.handoff.drop-evidence`. Business tags are:

1. real UID, `UInt32`;
2. effective UID, `UInt32`;
3. saved UID, `UInt32`;
4. real GID, `UInt32`;
5. effective GID, `UInt32`;
6. saved GID, `UInt32`;
7. supplementary-group count, `UInt32 == 16`;
8. the 16 unique supplementary groups as one 64-byte payload of ascending
   `UInt32` values;
9. all eight post-drop audit-token words as one 32-byte payload of `UInt32`
   values;
10. `setuid(0)` failure errno, `UInt32 == EPERM`;
11. `seteuid(0)` failure errno, `UInt32 == EPERM`; and
12. `setgid(0)` failure errno, `UInt32 == EPERM`.

The admitted IDs are UID `501` for all three UID fields and GID `20` for all
three GID fields. The 16 groups are the sorted comparison projection of the
already-frozen first 16 directory-service results; this payload never determines
which returned entries were selected. Header PID/PID-version/EUID/ASID must match
the audit-token projection. The payload reports corroborating evidence only; the
driver repeats independent kernel and signing observations.

### 4.2 Configuration acknowledgement

Domain: `stornaut.task39.handoff.configuration-ack`. Business tags are:

1. epoch UUID, raw 16 bytes;
2. ordinal, `UInt32` in `0...7`;
3. decoded configuration nonce, raw 16 bytes;
4. scenario code, `UInt32` in `1...8`;
5. SHA-256 of the exact opaque configuration bytes, raw 32 bytes; and
6. signed-runtime binding SHA-256, raw 32 bytes.

The payload epoch UUID must equal the frame header. b3 maps the decoded
configuration to this tuple; b5 compares it with the admitted capsule row before
accepting `HELLO`.

### 4.3 Retirement handle and acknowledgement

The exact `HANDLE` payload is one STNC transcript with domain
`stornaut.task39.handoff.retirement-handle` and business tags:

1. token UUID, raw 16 bytes;
2. investigation UUID, raw 16 bytes;
3. retire-operation UUID, raw 16 bytes;
4. configuration SHA-256, raw 32 bytes; and
5. handle-valid-before UTC microseconds, `Int64`.

All UUIDs and the timestamp are nonzero. The exact handle transcript is reused as
the nested handle field in a claim request; there is no second handle encoding.
For one epoch, handle investigation UUID must equal both the admitted capsule-row
configuration nonce and the decoded configuration nonce in CONFIGURATION_ACK. A
mismatch is terminal before `ACK` and before helper claim; configuration digest
equality alone cannot substitute for this identity join.

`ACK` is one STNC transcript with domain
`stornaut.task39.handoff.retirement-handle-ack` and one business field: SHA-256
of the complete exact HANDLE transcript, raw 32 bytes. It never echoes the token
or handle.

## 5. Cohort Capsule Contract

The complete capsule is one STNC transcript bounded to `1,048,576` bytes. Its
domain is `stornaut.task39.l3c3cii.cohort`. After common tags `0...1`, its actual
tags are exactly:

- tag `2`: outer-attempt UUID, raw 16 bytes;
- tag `3`: epoch count, `UInt32 == 8`;
- tag `4`: whole-capsule SHA-256, raw 32 bytes; and
- tags `5...12`: eight distinct nested epoch transcripts, where actual tag is
  `5 + ordinal`.

For hashing, the complete tag-4 digest payload is replaced by 32 zero bytes and
SHA-256 is computed over the otherwise final capsule bytes. Encoding then writes
the digest into that exact payload. Decoding repeats the zero-before-hash rule and
requires equality. No other byte is normalized.

Each nested epoch is a separate outer STNC field; there is no vector or table
wrapper field. The digest payload is actual tag `4`. Each epoch is an STNC
transcript with domain
`stornaut.task39.l3c3cii.cohort.epoch` and business tags:

1. ordinal, `UInt32` exactly `0...7` in outer tag order;
2. epoch UUID, raw 16 bytes;
3. scenario code, `UInt32` exactly `1...8` in the table above;
4. configuration nonce, raw 16 bytes;
5. configuration byte length, `UInt32` in `1...65,536`;
6. configuration SHA-256, raw 32 bytes;
7. signed-runtime binding SHA-256, raw 32 bytes; and
8. the exact opaque canonical configuration bytes.

The epoch descriptor and its configuration body are therefore interleaved inside
one nested epoch transcript. There is no separate fixed-descriptor region or
trailing configuration-body region. The complete outer layout is common tags
`0...1`, outer tags `2...12` in order, and within each outer tag `5...12` one
complete nested epoch with actual inner tags `0...9` in order.

The declared byte length equals the final field length. Configuration SHA-256 is
the digest of those exact bytes and therefore equals the existing
`machineConfigurationSHA256()` after strict lowercase-hex conversion. The binding
digest is SHA-256 of `SignedInvestigationRuntimeBinding` encoded independently by
JSONEncoder with exactly `.sortedKeys` and `.withoutEscapingSlashes`; no other
configuration field enters that digest. b0a accepts the already-computed raw
digests and does not import or decode signed-runtime domain types.

The capsule requires exact ordinal/scenario order, exactly eight distinct
canonical scenarios, and pairwise-distinct nonzero outer-attempt, epoch and
configuration UUIDs across the complete union of all 17 UUID values. Duplicate/
reordered/missing rows, digest mismatch, declared length drift, unknown tags/
versions/domains or trailing bytes fail.

## 6. Claim and Release Wire Contract

### 6.1 Claim request

Domain: `stornaut.task39.machine-claim.request`. Business tags are:

1. the complete exact retirement-handle STNC transcript;
2. nonzero claim-challenge UUID;
3. issued-at UTC microseconds, `Int64`;
4. request-valid-before UTC microseconds, `Int64`;
5. nonzero claim-connection-epoch UUID; and
6. absolute epoch-deadline nanoseconds, `UInt64`, exactly equal to the STNH
   `epochDeadlineNanoseconds` repeated by all eleven frames for the same epoch
   UUID.

The request-valid-before value is strictly after issued-at and no later than the
handle-valid-before value. The claim-connection-epoch UUID is generated by the
attested root client after the fixed helper connection and its peer identity have
been admitted but before CLAIM dispatch. It is fresh, nonzero, memory-only, bound
to that one retained XPC connection and never reused across a reconnect, helper
identity, claim or epoch. The client and helper retain it independently; request,
evidence, release and released must all equal that retained value. The request-
binding digest is SHA-256 over the complete exact request transcript. The token
occurs exactly once, inside the nested handle. No field is separately re-encoded
for hashing.

### 6.2 Nested evidence transcripts

Process identity domain: `stornaut.task39.machine-claim.process-identity`.
Business tags are role as one byte (`0x01` App or `0x02` helper), PID, PID version,
ASID and EUID as `UInt32`, then all eight audit-token words as one 32-byte payload.
The token must project the same four identity axes. App EUID is `501`; helper EUID
is `0`.

Owner-retirement domain: `stornaut.task39.machine-claim.owner-retirement`. Its
four one-byte business fields are ownership `0x02`, process-group terminated
`0x01`, stderr contained `0x01` and workspace removed `0x01`. No other value is
admitting.

L1-residue domain: `stornaut.task39.machine-claim.l1-residue`. Business tags are
investigation UUID, ASID `UInt32`, UID `UInt32`, observed-at UTC microseconds
`Int64`, then remaining audit-session members, matching leases, lease-root entries
and investigation artifacts as `UInt32`. All four counts are zero for admitting
evidence.

Helper process-identity digest domain:
`stornaut.task39.machine-claim.helper-identity`.
Business tags are PID, PID version, ASID and EUID as `UInt32`, followed by the
eight audit-token words as eight separate `UInt32` fields. SHA-256 of that complete
transcript is the helper process-identity digest used by release messages. The
digest deliberately excludes signing identifier, designated requirement,
CodeDirectory and fixed service/path binding. b2/b4 must independently admit those
signing/service facts for the same helper and retained connection epoch before
accepting claim evidence or emitting release; the process digest never substitutes
for that attestation.

Claim evidence does not carry a separate helper-identity-digest field. Its nested
helper process-identity transcript carries the complete admitted helper facts.
After strict validation, both peers independently re-encode those same facts under
the distinct helper-identity domain above and SHA-256 that complete transcript.
That derived value, not the process-identity transcript digest, is the claimed
helper process-identity digest in `CLAIM_RELEASE` and `CLAIM_RELEASED`. App
identity, helper identity, owner retirement and L1 residue are each nested as
their complete STNC
bytes, including nested magic and every nested tag/length field.

### 6.3 Claim evidence

Domain: `stornaut.task39.machine-claim.evidence`. Business tags are:

1. request-binding SHA-256, raw 32 bytes;
2. original claim-challenge UUID;
3. claim-connection-epoch UUID;
4. complete App process-identity transcript;
5. complete helper process-identity transcript;
6. App user ID, `UInt32 == 501`;
7. recorded-at UTC microseconds, `Int64`;
8. claimed-at UTC microseconds, `Int64`;
9. complete owner-retirement transcript;
10. complete zero-residue transcript; and
11. absolute release-deadline nanoseconds, `UInt64`.

The transcript is at most 4,096 bytes. It contains no request, handle, token or
reversible token projection. Recorded-at is no later than claimed-at. Contextual
validation additionally requires the digest/challenge/connection epoch and all
nested investigation/ASID/UID/identity facts to match caller-supplied immutable
expected values. b0b may compare only values already supplied to it; it performs
no process, Security, filesystem, XPC, clock or topology observation and does not
source a live/static expectation. b2/b4 own current-time checks, live/static
identity sourcing, installed-L2 joins, release legality and state transitions.

### 6.4 Release and released

`CLAIM_RELEASE` domain: `stornaut.task39.machine-claim.release`. Business tags
are request-binding SHA-256, fresh nonzero release-challenge UUID, claimed helper-
identity SHA-256, claim-connection-epoch UUID and absolute release-deadline
nanoseconds.

`CLAIM_RELEASED` domain: `stornaut.task39.machine-claim.released`. Business tags
are the same digest, challenge, helper digest and connection epoch, then
`exitScheduled` as exactly `0x01`, followed by absolute post-reply-exit-deadline
nanoseconds.

Both windows are strictly positive and at most `5_000_000_000` nanoseconds when
calculated by b2, and both are capped by the epoch deadline and separately checked
wall validity. b0b preserves absolute values and exact echoes; it does not decide
when release is legal. Zero/stale challenge, wrong connection/helper identity,
digest/deadline drift, unknown field/version/domain, length drift or trailing bytes
fails. Neither transcript contains a handle or token.

### 6.5 Frozen clock and ordering semantics

The wire owns already-admitted UTC-microsecond and continuous-nanosecond integers;
b2/b4 own clock capture and transition legality. Those later adapters must follow
these exact rules:

- capture each transition's wall and continuous clock once;
- compute request valid-before as
  `min(issuedAt + 15_000_000 microseconds, handleValidBefore)` with checked
  arithmetic; require `issuedAt < requestValidBefore` and current wall time
  strictly less than request valid-before; equality is expired;
- require `residueObservedAt <= recordedAt <= issuedAt <= claimedAt`, with
  `claimedAt < requestValidBefore`;
- require installed-L2 observation at or after `claimedAt` and strictly before
  the same wall expiry;
- convert `mach_continuous_time` ticks with checked integer arithmetic equivalent
  to `floor(ticks * numer / denom)` without floating point, saturation or wrapping;
- require the same nonzero absolute epoch deadline in every handoff frame and the
  claim request; and
- compute release and post-reply exit deadlines as the minimum of the epoch
  deadline, checked `nowContinuous + 5_000_000_000`, and checked
  `nowContinuous + remainingWallMicroseconds * 1_000`; require the result strictly
  greater than `nowContinuous`.

The helper establishes the release deadline when claim succeeds, but the driver
may send release only after the installed-L2 and repeated App-identity barriers.
b0b tests validate values and echoes with injected integer clocks only; they do not
read a clock or implement this state machine.

### 6.6 Data-only XPC selector

b0b owns exactly one Objective-C protocol, with Swift name
`InvestigationMachineClaimXPCWire` and explicit Objective-C name
`StornautInvestigationMachineClaimXPCWire`:

```swift
@objc(StornautInvestigationMachineClaimXPCWire)
public protocol InvestigationMachineClaimXPCWire {
    func claimMachineRetirement(
        _ request: Data,
        withReply reply: @escaping (Data?, String?) -> Void
    )

    func releaseMachineRetirement(
        _ request: Data,
        withReply reply: @escaping (Data?, String?) -> Void
    )
}
```

It contains no connection, listener, timeout or peer-authorization implementation.
Lifecycle and DriverSupport migrate to this one selector surface in b2/b4; duplicate
Objective-C claim protocols are forbidden after migration.

The Objective-C selectors are exactly
`claimMachineRetirement:withReply:` and
`releaseMachineRetirement:withReply:`. On one admitted connection, the helper may
receive exactly one CLAIM and, only after its successful reply, exactly one
CLAIM_RELEASE. Each callback is invoked exactly once. Success is exactly
`(nonNilData, nil)` and failure is exactly `(nil, nonemptyReasonKey)`; `(nil, nil)`
and `(nonNilData, nonNilReasonKey)` are protocol violations.

CLAIM and CLAIM_RELEASE request data are each at most 1,024 bytes before decoding.
CLAIM_EVIDENCE success data is at most 4,096 bytes and CLAIM_RELEASED success data
is at most 1,024 bytes. Failure keys are the following closed ASCII allowlist:

- `runtime.lifecycle.machine-claim.invalid-request`;
- `runtime.lifecycle.machine-claim.invalid-peer`;
- `runtime.lifecycle.machine-claim.empty`;
- `runtime.lifecycle.machine-claim.consumed`;
- `runtime.lifecycle.machine-claim.expired`;
- `runtime.lifecycle.machine-claim.mismatch`; and
- `runtime.lifecycle.machine-claim.unavailable`.

Reason keys are `1...128` ASCII bytes. Unknown, empty, non-ASCII or oversized
reply keys fail closed as `unavailable` without preserving caller-controlled
content. b0b freezes the interface, size and reply-value validators; b2/b4 own
the one-claim/one-release connection state and exactly-once dispatch
implementation.

## 7. Frozen Implementation Budgets

### 7.1 ii-b0a — Frame and Capsule Contract

Maximum nine non-document paths and 2,400 added/changed lines:

1. `Package.swift`;
2. `Sources/StornautInvestigationHandoffContract/HandoffBinaryTranscript.swift`;
3. `Sources/StornautInvestigationHandoffContract/InvestigationHandoffFrameContract.swift`;
4. `Sources/StornautInvestigationHandoffContract/InvestigationCohortCapsuleContract.swift`;
5. `Tests/StornautInvestigationTests/InvestigationHandoffTransportContractTests.swift`;
6. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
7. `scripts/verify-investigation-boundaries`;
8. `scripts/verify-app-release-boundaries`; and
9. `scripts/verify-contract`.

Tests-first coverage includes exact golden bytes, every frame kind/direction/length,
incremental header/payload input, partial EOF, all STNC structural failures, exact
scenario mapping, capsule zero-before-hash, all UUID/digest/order/length failures and
configuration-ack/handle/ack round trips.

b0a tests use fixed raw configuration/binding digest fixtures. They do not import
signed-runtime domain types or derive JSON/domain digests; adapter-side exhaustive
scenario mapping and digest derivation belong to b3/b5.

### 7.2 ii-b0b — Claim and Release Wire Contract

Maximum six non-document paths and 2,200 added/changed lines:

1. `Sources/StornautInvestigationHandoffContract/InvestigationMachineClaimContract.swift`;
2. `Tests/StornautInvestigationTests/InvestigationMachineClaimContractTests.swift`;
3. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
4. `scripts/verify-investigation-boundaries`;
5. `scripts/verify-app-release-boundaries`; and
6. `scripts/verify-contract`.

Tests-first coverage includes exact golden bytes, nested field permutation/omission/
duplication, microsecond drift, request-binding mutation, role/identity/retirement/
residue/timestamp mismatch, proof that response/release bytes contain no token,
release echo drift and exact Objective-C selector shape.

Each checkpoint follows RED evidence -> structural/source boundaries -> exact focused
tests -> affected suites -> one clean staged-only serial -> independent review ->
independent commit/push. Neither checkpoint runs `scripts/verify --full`, App/XCUITest,
sudo, install, signed product binaries, auth or a model. A failed staged serial is not
rerun for a green headline.

These budgets explicitly supersede the parent ii-b0 ceiling of nine paths / 2,800
lines. That estimate assumed three unspecified payload projections could share one
codec/test surface; the P1 audit proved the retirement-handle/frame/capsule and
claim/release schemas were not byte-complete and require a fourth source plus a
separate focused test. The additional two unique paths are therefore named protocol
work, not implementation growth hidden inside the old checkpoint.

The two checkpoints are independently reviewed and committed, not accumulated into
one 4,600-line review surface. Their combined unique maximum is eleven non-document
paths, while each checkpoint remains below the repository's fourteen-path / 4,000-
line mandatory split threshold. The line ceilings are independent worst-case review
bounds rather than a combined target. Approaching either checkpoint ceiling requires
a fresh split before coding continues.

## 8. Non-Claims and Next Gate

This preflight admits no implementation and consumes no serial, privilege or full-
verifier evidence. ADR 0018 remains Proposed, Task 39 remains incomplete, production
Deep Dive remains unavailable and the remaining authoritative full stays reserved for
L3c4. ii-b0a/ii-b0b completion evidence is in their separate reviews; ii-b1 is
current.

## 9. Independent Review Closure

Independent adversarial reviews found and closed:

- the raw-32 versus ASCII-64 configuration-digest contradiction;
- the omitted configuration nonce and configuration/handle identity join;
- unnamed frame payloads, sender semantics, sequence reset and frame-nonce
  ownership;
- ambiguous capsule tags, descriptor/body layout and zero-before-hash bytes;
- helper process-identity digest versus separate signing/service attestation;
- root-client ownership and one-connection freshness of the connection epoch;
- wall/continuous deadline ordering, Date normalization and exactly-once XPC
  reply shape;
- b0 byte/value ownership versus b2/b4 live observation and state transitions;
  and
- the parent budget supersession and independent b0a/b0b review surfaces.

Latest pre-implementation post-fix reviews reported no unresolved P0-P2. ii-b0a
and ii-b0b later completed under separate completion audits; ii-b1 is current. This
preflight itself consumed no serial, App, privileged, model or full-verifier
action.
