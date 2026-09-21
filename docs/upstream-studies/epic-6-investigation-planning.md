# Epic 6 Investigation Planning and Budget Upstream Study

> **Status:** Accepted for Task 36 implementation; no upstream source code
> is copied and no dependency is added.
>
> **Date:** 2026-08-15
>
> **Implementation baseline:** authoritative pushed Phase C / Task 35 closure
> `86ee2aa9428cfc71036e18dcb2c1349ec248ec73`; Task 36 is materialized directly
> on this baseline and does not inherit any synthetic replay commit.
>
> **Decision:**
> [ADR 0017](../adr/0017-investigation-planning-and-stop-semantics.md)
>
> **Normative low-level contract:**
> [Investigation Canonical v1](../specs/investigation-canonical-v1.md). Its complete codec/schema,
> source-manifest bounds, priority arithmetic, clock/resource lifecycle,
> receipt-versioned runtime normalization, persisted URL grammar and
> capability matrix override every summary in this study.

## 1. Question

Phase D needs a deterministic Candidate Planner and a bounded scientific
investigation loop. This study asks:

1. Which planning, budget and stop decisions can Swift enforce before work
   begins?
2. Which Codex App Server facts are available only after a turn or tool event?
3. How can Stornaut expose useful 10/30/60-minute Deep Dive presets without
   falsely claiming exact in-flight token or direct-tool preemption?
4. How should target priority remain deterministic across input order,
   process, architecture and persistence round trips?
5. Which behavior may be borrowed from upstream documentation without copying
   orchestration code or transferring authority to the model?

Task 36 is Core-only. It does not launch Codex, call a model, migrate the
Evidence Store, change the App, accept disclosure, persist an Investigation
or enable production Deep Dive.

## 2. Environment

| Item | Observed |
| --- | --- |
| Date | 2026-08-15 |
| macOS | 26.5.1, build 25F80 |
| Architecture | arm64 |
| Xcode | 26.6, build 17F113 |
| Swift | 6.3.3 |
| Repository baseline | Authoritative pushed Phase C / Task 35 closure `86ee2aa9428cfc71036e18dcb2c1349ec248ec73` |
| Evidence Store schema | v3 |
| Runtime foundation | R6 `go`; production Deep Dive still unavailable |

Task 36 was materialized directly on the authoritative pushed Task 35 closure;
the synthetic planning replay commits were neither merged nor cherry-picked.
Official-document freshness was rechecked at `2026-08-15T02:18:26Z`; both pinned commits
remained retrievable and no contract-relevant semantic drift was observed.

## 3. Upstream Snapshot

| Source | Version or commit | License | Material inspected |
| --- | --- | --- | --- |
| [OpenAI Codex](https://github.com/openai/codex/blob/c530bcd4cd46f2a26a839f7bb90c306a27c50d95/codex-rs/app-server/README.md) | `c530bcd4cd46f2a26a839f7bb90c306a27c50d95` | Apache-2.0 | `codex-rs/app-server/README.md`, App Server turn/thread event contract, ephemeral threads, cancellation and usage events |
| [OpenAI Agents Python](https://github.com/openai/openai-agents-python/blob/c0f2ff7d8f064fd4e15799ec1c1ae21e2e21cf6f/docs/running_agents.md) | `c0f2ff7d8f064fd4e15799ec1c1ae21e2e21cf6f` | MIT | Running agents documentation, `max_turns` behavior and `MaxTurnsExceeded` semantics |
| Current Stornaut source | reviewed Task 35 worktree | MIT | `ProbeRequest.swift`, `ProbeBroker.swift`, `CodexAppServerRuntime.swift`, Envelope v2, Settings budget presets |

Review-time local retrieval artifacts were not committed. Their content
digests were:

```text
OpenAI Codex App Server documentation
374ab930929047722ef574568736eb5318d5280cff252af71c367da2e147d9a7

OpenAI Agents running documentation
2cb2fca66acbff98f6098299b0d2f79a35a49398cc4345d928077b03db76272f
```

Context7 independently resolved the high-reputation official
`/openai/codex` index on 2026-08-15 and returned the same lifecycle semantics:

- `thread/start` may create an ephemeral thread;
- `turn/start` begins generation;
- `turn/interrupt` requests interruption;
- terminal truth arrives through `turn/completed`;
- `completed`, `interrupted` and `failed` are terminal turn states.

No upstream source code is copied. OpenAI Agents is a behavioral reference
only and is not a dependency.

## 4. App Server Findings

### 4.1 Thread creation and turn admission are separate

The App Server lifecycle explicitly separates:

```text
thread/start(ephemeral: true)
→ turn/start
→ item/* and usage notifications
→ turn/completed
```

This gives Stornaut a real pre-call boundary before `turn/start`. Swift can
refuse a new coordinator turn when:

- the wall-clock deadline has arrived;
- the admitted turn count is exhausted;
- required context cannot fit the remaining Swift-owned context-byte
  reservation;
- containment, lifecycle or runtime admission is no longer valid;
- cancellation has been requested.

Starting an ephemeral thread does not itself prove that a model turn was
admitted, completed or contained.

### 4.2 Interrupt is a request, not terminal proof

`turn/interrupt` accepts `(threadId, turnId)` and requests cancellation.
Success of that request is not a terminal outcome. Stornaut must continue to
read the stream until the matching:

```text
turn/completed(status: interrupted | completed | failed)
```

and then drain the accepted audit-session lifecycle and managed proxy owner.
If terminal identity or drain cannot be proved, the run is blocked/failed,
not safely cancelled.

This supports the Phase D pause correction:

```text
Pause requested
→ finish or bounded-interrupt the current admitted run
→ observe terminal turn state
→ drain the audit session
→ retain only verified partial evidence
→ Resume starts a new run
```

The product must not claim that it froze an in-flight tool call or preserved
an arbitrary process tree in place.

### 4.3 Token usage is event-time evidence

Current official App Server documentation says:

- `thread/tokenUsage/updated` streams separately from turn lifecycle;
- `rawResponse/completed.usage` is the exact upstream payload when supplied;
- `rawResponse/completed.usage` may be `null`;
- raw usage is not accumulated, estimated, persisted or replayed by that
  notification.

Current Stornaut runtime:

- explicitly opts out of `thread/tokenUsage/updated`;
- permits the method structurally but records no usage;
- validates `rawResponse/completed.usage` only as object-or-null and discards
  its values.

Therefore Task 36 may define typed observed-usage semantics, but it cannot
claim that the current runtime already enforces a token budget. Task 38 must
either:

1. subscribe to and normalize accepted token-usage events with exact
   thread/turn identity; or
2. report `usageUnavailable` as a typed degradation.

It must not estimate exact tokens from UTF-8 bytes, elapsed time, response
length or model prose. A successful model call is not token-accounting proof.

### 4.4 Direct Agent tools do not expose a universal pre-call budget hook

Canonical `item/started` / `item/completed` events identify command, web,
image, MCP and collaboration work after the App Server has admitted the model
turn. `item/completed` is authoritative for that item's result. The current
permission profile deliberately does not require per-command user approval,
an executable allowlist or a public destination-domain allowlist.

Consequences:

- Stornaut may count observed direct Agent tool starts/completions;
- it may request one bounded turn interruption after an observed ceiling;
- it may refuse every later turn;
- it cannot honestly promise that an in-flight turn will stop before the
  exact Nth direct tool invocation;
- tool-event loss or identity mismatch is a runtime/protocol failure, not
  zero tool usage.

A hard pre-call reservation is valid only where Stornaut owns the operation
boundary, such as a Probe Broker call, a Swift-built context append or a
future coordinator-owned typed operation.

## 5. Existing Stornaut Budget Boundary

`ProbeSessionBudget` already owns hard, pre-operation reservations for:

- maximum call count;
- maximum read bytes;
- maximum output bytes.

`ProbeBroker` reserves:

1. a call before target access;
2. estimated read bytes before reading;
3. after successful response encoding and per-call validation, output bytes
   atomically through `reserveOutputBytes` before returning the result.

If encoding, the per-call bound or session output commit fails, the response
is discarded and output consumption remains zero. Once committed, output
bytes remain consumed even if a later delivery or audit step fails.

The new Investigation budget must compose with this implementation rather
than create a second contradictory Probe budget. Task 38 may adapt a Task 36
limit projection into `ProbeBudgetLimits`; it must not let the model mint,
raise or reset those values.

Current runtime input bounds also provide independent structural ceilings:

- default App Server prompt: 256 KiB;
- default schema: 256 KiB;
- default input line: 2 MiB;
- Envelope v2 input: 1 MiB.

These are protocol safety limits, not user Deep Dive budget presets. The
smaller applicable limit always wins.

## 6. Budget Taxonomy

### 6.1 Hard admission limits

A hard limit is one Swift can evaluate before admitting the next bounded
operation. Task 36 defines these exact preset values:

| Dimension | Focused | Balanced | Thorough | Enforcement owner |
| --- | ---: | ---: | ---: | --- |
| Wall clock | 600 s | 1,800 s | 3,600 s | coordinator deadline |
| Coordinator/model turns | 4 | 12 | 24 | before `turn/start` |
| Probe Broker calls | 16 | 48 | 96 | `ProbeSessionBudget` |
| Probe read reservation | 8 MiB | 32 MiB | 64 MiB | `ProbeSessionBudget` |
| Probe output reservation | 2 MiB | 8 MiB | 16 MiB | `ProbeSessionBudget` |
| Swift-admitted model-context bytes, cumulative | 1 MiB | 4 MiB | 8 MiB | context builder |
| Concurrent Probe operations | 2 | 4 | 8 | coordinator/Broker admission |
| Consecutive verified no-gain steps | 2 | 3 | 4 | stop evaluator |

Additional fixed safety ceilings apply to every preset:

- no single Swift-built model input exceeds 256 KiB;
- no plan contains more than 512 admitted targets;
- no runtime request may exceed its lower protocol-specific bound.

The preset values are finite and monotonic. A larger preset increases
scientific opportunity but does not enable a capability unavailable in a
smaller preset.

All elapsed-time decisions use one injected `ContinuousClock`. The serial
coordinator samples immutable `runStart` atomically with its transition into
running and computes `runStart.duration(to: now)`. It samples immutable T0
exactly once at the first accepted fact whose normative precedence closes
scientific admission; later causes are secondary facts. Wall-calendar
timestamps are metadata only.

The wall-clock deadline stops admission of new scientific work. It does not
truncate the safety tail required to request interruption, observe terminal
turns, drain the audit session/proxy owner and commit a truthful terminal
record.

Phase D fixes the complete settlement envelope at **140 monotonic seconds**
from the first transition that closes scientific admission:

```text
T0:
  atomically close all new turn/Probe/context admission
  record the terminal cause
  send at most one turn/interrupt per active (threadID, turnID)

T0...T0+15s:
  consume matching item/usage/turn terminal events
  never promote evidence from an unterminated turn

when every admitted turn is terminal, or at T0+15s:
  invoke the idempotent audit-session drain

by T0+45s:
  prove the audit session empty
  prove managed proxy owner drained
  remove/retire ephemeral runtime artifacts
  begin the Store-owned terminal transaction

by T0+135s:
  atomically commit the verified report or blocked/failed record

by T0+140s:
  complete rollback/connection cleanup or quarantine the Store connection
```

The 140-second settlement envelope is not additional investigation budget.
The Store operation retains its independent 90-second deadline and separate
five-second cleanup bound after it begins no later than T0+45. Missing terminal
events with a successful forced drain produce
`blocked(runtimeTerminalUnobserved)`. An unproved audit-session/proxy drain
produces `blocked(lifecycleDrainUnconfirmed)`. A terminal Store commit failure
produces `failed(terminalPersistenceFailed)` with recovery metadata. None may
surface as cancelled, paused, budget-complete or successful.

### 6.2 Event-time observed ceilings

The following are not pre-call guarantees for the current App Server:

| Dimension | Focused | Balanced | Thorough | Truthful behavior |
| --- | ---: | ---: | ---: | --- |
| Observed direct Agent tool starts | 32 | 96 | 192 | request bounded interrupt when reached; refuse later turns |
| Observed total tokens | 100,000 | 300,000 | 600,000 | stop before later turns when a trusted event reaches the ceiling |

Observed token totals count the upstream total once. Cached input is a
breakdown of input and must not be added again. If only component counts are
available, Task 38 must define and test one non-double-counting normalization.

The ceiling applies to the complete same-investigation live session tree,
including spawned descendant threads/subagents. Root-thread-only accounting is
invalid.

If usage is absent:

- the observed token value is `unavailable`, never zero;
- the report records a typed degradation;
- wall-clock, turn, Probe and context hard limits remain enforceable;
- the UI must not claim “within token budget” or an exact remaining token
  amount.

If one turn crosses an observed ceiling, the final recorded value may exceed
the ceiling because it is post-event evidence. This is not a budget bypass:
the coordinator interrupts once when possible, admits no later turn, drains
the runtime and reports the exact observed overrun. The product must not label
the ceiling a hard cost cap.

### 6.3 Reservations and observations are not interchangeable

The domain must retain provenance:

- `reserved`: admitted by Swift before work;
- `observed`: accepted from an identity-bound runtime event;
- `unavailable`: the source did not supply an exact value;
- `invalid`: malformed, decreasing, duplicate-conflicting or identity-mismatched
  evidence.

Model-reported prose never updates any budget dimension.

### 6.4 Exact reservation arithmetic

All hard counters start at zero. For finite unsigned limit `L`, current
consumption `C` and requested reservation `A`:

```text
reserve(A) succeeds iff A > 0, C <= L, and A <= L - C
new consumption = C + A
```

Exactly `L` is admissible. Once consumption equals `L`, the evaluator reports
that dimension exhausted before another operation. `L + 1` is never admitted.
Checked subtraction/addition is mandatory.

Reservation lifecycle is dimension-specific:

- an accepted `turn/start` permanently consumes one turn even if it later
  fails or is interrupted;
- a Probe call permanently consumes one call once `ProbeBroker.execute` is
  admitted;
- Probe read reservation remains consumed once reserved, matching the current
  Broker's conservative semantics even if access later fails;
- Probe output bytes are consumed only after successful encoding, per-call
  validation and atomic session commit through `reserveOutputBytes`; a failed
  pre-commit path discards the response and consumes zero, while a committed
  amount survives later delivery/audit failure;
- Swift-built context bytes are consumed once the bytes cross into an accepted
  `turn/start`, even if that turn fails;
- Probe concurrency is an actor-owned lease: acquire only when
  `active < limit`, release exactly once on a normal terminal path, and during
  recovery release only after lifecycle evidence proves no Probe worker
  remains; underflow, duplicate/foreign release and leaked leases are
  failures;
- wall clock admits work only while `elapsed < limit`; equality closes
  admission;
- the Nth unique direct-tool start is observed and then closes further
  admission when count becomes `N`; the N+1th must never be intentionally
  admitted, although already-running descendants may emit late events;
- an observed token snapshot closes admission when aggregate
  `totalTokens >= ceiling`; the exact overrun is retained, never clamped.

After one successfully normalized scientific step:

- verified gain sets `consecutiveNoGain = 0`;
- a valid step with no verified gain increments by one using checked
  arithmetic;
- invalid/protocol-failed/cancelled steps do not increment or reset because
  their higher-precedence terminal path applies;
- equality with the configured no-gain limit stops before another step.

Every dimension receives `N-1`, `N`, `N+1`, failed-operation, interruption,
duplicate-release and overflow fixtures.

### 6.5 Normalized runtime observations

Task 36 defines Core-neutral observation values; Task 38 alone decodes current
App Server wire events. Every normalized observation contains:

- `InvestigationID` and `InvestigationRunID`;
- root `sessionID`;
- `threadID`, optional `parentThreadID`, and `turnID`;
- optional `itemID`;
- one closed observation kind;
- one source-method token;
- one bounded event ordinal assigned by the single serial coordinator.

Thread admission is closed:

1. the root comes from the exact ephemeral `thread/start` response and must
   have `thread.id == thread.sessionId`;
2. the runtime receipt selects exactly one normative collaboration schema for
   the run; a child is admitted only when that receipt-selected spawn edge
   identifies the normative sender/new-thread pair **and** current thread
   metadata confirms the same `parentThreadId` and root `sessionId`;
3. every parent must already be admitted;
4. unrelated, cyclic, duplicate-conflicting or unbound thread events are
   protocol failures;
5. production runs never `resume` or `fork` a stored thread; transport loss
   fails and drains the run rather than replaying a session.

Direct-tool accounting counts the first identity-valid `item/started` for each
unique `(threadID, turnID, itemID)` whose type belongs to the
receipt-selected closed direct-tool set in the normative specification. An
equal replay is a no-op. A duplicate with another type/identity is invalid.
`fileChange`, an unknown tool-capable item or a write-capable MCP annotation
blocks the run instead of being omitted from the count.

The current official `thread/tokenUsage/updated` payload is a cumulative
snapshot:

```text
threadID
turnID
tokenUsage.total { totalTokens, inputTokens, cachedInputTokens, outputTokens }
tokenUsage.last  { totalTokens, inputTokens, cachedInputTokens, outputTokens }
modelContextWindow?
```

For each admitted thread, Task 38 retains only the latest cumulative `total`
snapshot. An equal replay is a no-op; any field decrease, negative value,
`cachedInputTokens > inputTokens`, incompatible equal-version snapshot or
identity mismatch is invalid. The investigation aggregate is the checked sum
of the latest `total.totalTokens` from every admitted thread. It never sums
`last`, never adds cached input again and never sums cumulative snapshots over
time.

A terminal turn has complete observed usage only when an identity-valid usage
snapshot naming that same `turnID` arrives by the terminal barrier. Missing
snapshots yield `usageUnavailable`; they are not reconstructed. The terminal
barrier waits for every admitted active turn's matching `turn/completed` and
usage snapshot until its bounded windows expire. Finalization rejects a live
or unclassified descendant.

## 7. Turn and Step Semantics

OpenAI Agents defines `max_turns` as the maximum number of agent-loop LLM
calls and raises `MaxTurnsExceeded` after the limit. Stornaut adopts only the
behavioral lesson:

- count coordinator/model turns at their admission boundary;
- make the limit finite;
- produce a controlled partial outcome instead of silently looping.

Stornaut does not import the SDK, reuse its exception types or delegate
budget authority to it.

For Task 36:

- one **turn** is one admitted `turn/start`;
- one **Probe step** is one admitted Probe Broker invocation;
- one **direct tool observation** is one identity-valid canonical tool-item
  start;
- one **evidence step** is one normalized coordinator delta evaluated by the
  pure stop reducer.

These counters must remain separate. A model turn may contain zero or many
direct tool observations.

## 8. Evidence Gain

A step has verified evidence gain only when Swift accepts at least one new
bounded fact that changes the retained scientific state:

- a new identity-bound Evidence record for an admitted target;
- a target changes from unresolved to verified/resolved;
- measurable unexplained bytes decrease through a valid reconciliation;
- a new typed contradiction invalidates or narrows a hypothesis;
- a capability degradation truthfully narrows what can be concluded.

The following are not gain:

- model prose without accepted evidence;
- duplicated evidence or repeated source URLs;
- streamed partial text;
- a tool invocation with no accepted result;
- a finding that references an unadmitted ID;
- a proposed action, disposition, Policy result or confidence assertion;
- a lower byte estimate unsupported by current Store facts.

The no-gain counter resets only after verified gain. Invalid, failed,
cancelled or duplicate steps do not reset it.

## 9. Deterministic Candidate Priority

The conceptual priority remains:

```text
expected allocated bytes × uncertainty × user relevance
--------------------------------------------------------
             estimated investigation cost
```

Task 36 uses independent Swift integer code:

- expected bytes are converted to rounded-up MiB units for ranking only;
- uncertainty, relevance and cost are bounded integer permille values
  `1...1_000`;
- multiplication uses checked UInt64 arithmetic; the complete input bounds
  prove a maximum numerator of `8_796_093_022_208_000_000`, below
  `UInt64.max`;
- division uses integer floor;
- overflow is invalid input; there is no saturation path;
- no floating-point value is encoded or compared;
- all measurable targets form the first priority tier; an unmeasurable size is
  a separate later tier and is never encoded as `0 B`;
- final ties use target kind, retained source IDs and ordered reason keys.

The planner caps output at 512 targets and reports omitted counts and
measurable bytes conservatively. Input order cannot affect target identity,
priority, fingerprint or output ordering.

### 9.1 Closed candidate policy

The product terms “large rule miss”, “relevant” and “investigation cost”
cannot remain prompt-owned heuristics. `CandidatePolicyV1` therefore fixes:

- an inclusive absolute large threshold of `1_073_741_824` measured allocated
  bytes, with no scope-relative threshold in v1;
- requested coverage at `900` permille;
- remaining measurable Unknown stop threshold at `1_073_741_824` bytes, with
  a strict-below stop predicate;
- Plan expiry at the earlier of the retained Scan-session expiry and injected
  creation time plus the selected preset wall clock;
- base relevance `700`, plus at most `100` for closed token
  `relevance.large` and at most `100` for closed token
  `relevance.developer` under typed applicability rules;
- rejection of unknown or duplicate relevance tokens;
- fixed `(uncertainty, cost)` values:
  - unknown large consumer `(750, 250)`;
  - unexplained space gap `(1_000, 800)`;
  - classification conflict `(1_000, 350)`;
  - unknown producer `(850, 400)`;
  - stale/insufficient evidence `(700, 300)`.

One non-Protected classification/snapshot source produces at most one target.
The exact kind precedence is classification conflict, unknown large consumer,
unknown producer, then stale/insufficient evidence. All applicable fixed
reasons and exact missing-evidence keys remain on that one target. Ordinary
Ready is excluded; only a contradictory Ready safety shape — high/critical
risk or confidence below high — creates a conflict candidate.

A selected-scope snapshot with no classification creates only a
snapshot-bound missing-classification target when it is non-root, measurable
and at least the inclusive large threshold. The eligible reconciled Space
Ledger creates at most one gap target for measurable nonzero Unknown
residual. Coverage-limited or inconsistent ledgers fail source eligibility
instead of creating candidates. Measured zero creates no gap; unavailable
bytes are not converted to zero.

Every target has `1...16` canonical reasons. The complete canonical Plan
digest input is capped at `2 MiB`. Exceeding either bound rejects without
truncating reasons or silently dropping targets. These values are product
heuristics, not scientific truth; version changes require a new normative
contract and fresh benchmark/review.

### 9.2 Stable source bindings and IDs

Random IDs inside the pure Planner would make repeated output and continuation
lineage unstable. The caller therefore supplies one already-created
`InvestigationID` and one deterministic `now`. The Planner does not call
`UUID()` or read the wall clock.

Every target has exactly one strict `InvestigationSourceBinding`:

- snapshot: one retained `SnapshotID`;
- classification: one retained `ClassificationID` plus its exact
  `SnapshotID`;
- Space Ledger measure: the closed `unknown-residual-v1` key for the eligible
  reconciled retained ledger.

The enclosing target still carries the exact Scan session and scope. A
ledger-only binding invents no path.

`InvestigationTargetID` is derived from the full lowercase SHA-256 of a
versioned, domain-separated, length-prefixed canonical byte encoding of:

```text
target-v2
scanSessionID
scanScopeID
targetKind
sourceBinding
```

The result is `target-<64 lowercase hex>`. Reason ordering, priority and
current evidence are deliberately not part of target identity; they may
evolve while the retained source fact remains the same. Duplicate derived IDs
fail closed.

Source, target-set and plan fingerprints use separate domain tags and the same
unambiguous encoding discipline. The plan fingerprint includes the supplied
Investigation ID, exact source fingerprint, limits, thresholds, timestamps and
ordered target payloads. Tests inject identical `InvestigationID`/`now` when
asserting repeatability.

### 9.3 Normative canonical codec

Task 36 defines one internal codec named `StornautInvestigationCanonicalV1`.
It does not use `JSONEncoder`, plist encoding, locale-sensitive formatting,
reflection, `Hashable.hashValue`, native integer layout or dictionary order.

Every digest input is:

```text
ASCII bytes "STORNAUT-INV-CANON-1\0"
encoded domain string
encoded root record
```

The only value encodings are:

| Value | Encoding |
| --- | --- |
| nil | byte `00` |
| false / true | byte `01` / `02` |
| unsigned integer | byte `10` + exactly 8-byte big-endian UInt64 |
| signed integer | byte `11` + exactly 8-byte big-endian two's-complement Int64 |
| UTF-8 text | byte `20` + UInt64 byte length + exact UTF-8 bytes |
| opaque bytes | byte `21` + UInt64 byte length + bytes |
| array | byte `30` + UInt64 element count + for each element: UInt64 encoded-byte length + encoded value |
| record | byte `40` + UInt64 field count + for each field: UInt16 big-endian tag + UInt64 encoded-value length + encoded value |

Normative rules:

- a record's numeric tags are schema constants, strictly increasing, unique
  and never reused with a different meaning;
- every optional field is present; absence encodes as `nil`;
- ordered arrays must already satisfy their owning semantic order;
  canonical-set arrays must be unique and already sorted by unsigned
  lexicographic comparison of each element's complete canonical bytes; any
  other order is rejected and the encoder never silently sorts;
- enums encode their exact lowercase versioned ASCII wire token as text;
- booleans never encode as integers;
- byte counts use UInt64; signed deltas and timestamps use Int64;
- dates encode as signed microseconds since Unix epoch after deterministic
  truncation toward zero; non-finite/out-of-range dates are rejected;
- text preserves the exact Unicode scalar sequence: no NFC/NFD, case, slash,
  percent or locale normalization occurs; composed and decomposed strings are
  intentionally different;
- lengths count encoded bytes, not characters;
- trailing bytes, duplicate/out-of-order tags, non-minimal/missing fields,
  invalid UTF-8 and values outside the owning domain are rejected.

Digest domains are fixed ASCII tokens:

```text
stornaut.investigation.target.v2
stornaut.investigation.source.v1
stornaut.investigation.target-set.v1
stornaut.investigation.plan.v1
```

SHA-256 is computed over the complete codec bytes. The full 64 lowercase
hexadecimal digits are retained; no truncation is allowed.

Primitive golden vectors:

```text
domain: stornaut.test.empty.v1
encoded length: 61
SHA-256:
724b07f461c7690c1e0614abdbd72081d88622e2aab47183236b6bf8e049dc3b

domain: stornaut.test.primitives.v1
fields:
  1 = UInt64(0)
  2 = UInt64.max
  3 = Int64(-1)
  4 = text U+00E9
  5 = nil
  6 = text "focused"
  7 = array[text "a", text "b"]
  8 = true
  9 = text U+0065 U+0301
 10 = false
encoded length: 280
SHA-256:
56a27067b51cef0ebc1236d51200b250987fce1ee74832047fa2063ef0da9075
```

Checked-in fixtures must include the complete encoded hex for these vectors
plus target, source, target-set and plan vectors. Swift tests decode/re-encode
them byte-for-byte, mutate each field/tag/order/optional value and verify the
expected digest change or rejection.

### 9.4 Source fingerprint projection

`sourceFingerprint` is not caller text. The Planner constructs it from the
normative complete typed-row manifest: one terminal Scan-session row, one
complete same-session Space Ledger row, and exhaustive selected-scope
snapshot/classification/evidence rows. Each row binds the exact stored UTF-8
payload SHA-256 plus all non-payload identity columns; Store identity checks,
strict typed decode and byte-identical `DomainJSON` re-encode must pass.
Limits are exactly 100,000 rows per record family, 100 evidence rows per
snapshot, 300,002 total rows, 256 relevance tokens, 1 MiB ordinary payload,
16 MiB Space Ledger payload, 256 MiB aggregate exact source payload and
512 MiB complete canonical SourceProjection digest input. The canonical Plan
identity input is independently capped at 2 MiB and its strict persisted
`DomainJSON` representation at 4 MiB. Top-N truncation is forbidden.

Task 37 persists the source fingerprint and complete source-row manifest as
normalized bounded source-row and relevance-token rows owned by the
Investigation session, not as one aggregate JSON payload. It reloads and
recomputes exact membership and bytes at exactly eight rejoin barriers:
initial Store insertion, runtime admission, explicit active-run refresh,
terminal report normalization, crash recovery, continuation construction,
Review projection, and Agent proposal joining `CleanupPlanBuilder`.

The maximum-size path is repeatable two-pass streaming. One Store-owned pinned
SQLite snapshot emits one exact payload at a time in canonical row order;
Swift strict-decodes/re-encodes, hashes and releases it before advancing.
Pass one submits one normalized row metadata value at a time to a non-escaping
manifest sink; Task 37 binds that sink to a reused prepared statement inside
the pinned transaction. Pass two writes only to an incremental canonical hash
sink that returns digest/count metadata, never accumulated `Data`. Neither
Task 36 nor Task 37 retains the complete source payloads, full 300,002-row
manifest or canonical SourceProjection bytes. The second pass must reproduce
the same source-generation/count/length/sequence digest before its incremental
canonical digest is accepted. Rejoin callers provide only typed Investigation
ID plus a closed barrier and cannot provide Plan, expected manifest,
fingerprint or freshness.

Measured byte values use `ByteCountV1` in `0...Int64.max`; binary and strict
duplicate-aware `DomainJSON` reject larger UInt64 values, duplicate/omitted
keys and numeric conversion through floating point. The compact policy index
retains a derived `isRoot` bit but no path bytes so the missing-classification
rule remains implementable.

Task 37 owns one immutable source session and at most 16 immutable run-owned
Plans. Initial creation and continuation accept IDs/preset/time only; Store
builds each Plan and ordered run-target membership after a fresh pinned rejoin.
The runtime accepts IDs and loads the Plan inside Store immediately before
`thread/start`.

Store v4 bounds target-scoped evidence, report-scoped degradation and budget
rows/bytes per report/run and per Investigation. Only whole-Investigation
deletion cascades; direct child deletion is rejected. Maximum-size write
transactions have two-second busy acquisition, a 90-monotonic-second
deadline, cancellation/progress handling, proved rollback and fail-closed
connection quarantine. The entire continuation lineage shares immutable
retention expiry
`min(source expiry, session creation + 604_800_000 ms)`.

A mismatch produces typed stale/corrupt state and never falls back to IDs
alone. Task 36 tests only the pure projection and digest; Task 37 owns Store
recomputation and migration tests.

### 9.5 Legacy v1 target isolation

The unused v1 target may remain decodable only through a separately named
`LegacyInvestigationTargetV1` fixture/migration adapter. It is never returned
as a v2 target and is rejected by Candidate Planner, Plan construction, Store
v4 insertion, runtime admission and continuation.

Task 36 performs no lossy automatic upgrade. A future explicit migration may
create v2 only after it can reconstruct and verify Scan session, scope and
exact source binding from retained Store facts; otherwise the legacy record
remains non-admissible.

## 10. Stop Precedence

The pure evaluator applies this order after every accepted evidence delta and
before every next Swift-owned admission:

1. containment, lifecycle, runtime identity or strict protocol loss:
   block/fail and drain;
2. user cancellation: record `userCancelled`, close admission and drain;
3. user stop: record distinct `userStopped`, close later admission and drain;
4. a hard limit exhausted or the next reservation would exceed it:
   `budgetExhausted` with the exact dimension;
5. an identity-valid observed ceiling reached:
   `budgetExhausted` marked as event-time observed;
6. requested coverage reached;
7. remaining measurable Unknown below the plan threshold;
8. consecutive verified no-gain limit reached;
9. continue.

An unavailable token observation is a degradation, not proof of exhaustion or
remaining capacity. Unmeasurable Unknown cannot satisfy a byte threshold.

Pause is not a scientific stop reason. It is a later coordinator lifecycle
request that may result in a verified partial report and a new continuation
run.

## 11. Ownership and No-Executor Boundary

Swift owns:

- candidate generation and source binding;
- plan and target fingerprints;
- all configured limits;
- hard admission reservations;
- accepted runtime observation normalization;
- stop precedence;
- partial/final report admission.

Codex owns dynamic investigation strategy inside the admitted plan. It may
suggest a next hypothesis or that sufficient evidence exists. It cannot:

- add a target or increase a budget;
- mark a reservation consumed;
- reset a counter;
- declare containment;
- mint an action, Policy decision, selection or authorization;
- call Trash or Executor;
- promote Agent-only evidence to `Ready to Reclaim`.

Task 36 Core files must have no dependency on `StornautCodex`,
`StornautLifecycle`, Process execution, Trash, Policy authorization or
Executor types.

## 12. Alternatives Rejected

### Model-owned plan or stop

Rejected because model output is advisory and cannot be replayable authority.

### Exact in-flight token cap

Rejected because current App Server usage is asynchronous and may be absent.
Claiming a pre-call token guarantee would be false.

### Treat output bytes as exact tokens

Rejected because tokenization, hidden reasoning, cached input and provider
accounting are not derivable from UTF-8 output bytes.

### Exact direct-tool hard cap inside a turn

Rejected because direct Agent tool events are observed after turn admission
and the product intentionally avoids per-command approvals/allowlists.

### One combined “tool/Probe” counter with identical enforcement

Rejected because Probe calls are Swift-reserved while direct tools are
event-time observations. The UI may summarize them together only if it also
preserves their different enforcement quality.

### Floating-point priority

Rejected because architecture, compiler and serialization differences can
change ordering and fingerprints.

### Unknown size as zero

Rejected because permission and measurement gaps must not be presented as
`0 B` or silently deprioritized as known-empty data.

### Reusing OpenAI Agents orchestration

Rejected because it would add a Python dependency, duplicate the accepted
Codex runtime and blur Swift ownership. Only the finite-turn behavior is used
as a reference.

## 13. Code Reuse and Attribution

- OpenAI Codex code copied: none.
- OpenAI Agents code copied: none.
- New runtime or planning dependency: none.
- Required notice change: none.
- Existing repository license remains MIT.

The official HTTPS links above are pinned to the inspected commits and were
retrieved again at `2026-08-15T02:18:26Z`. Exact commits, licenses and
inspected files are recorded; behavioral descriptions are independently
implemented and covered by Stornaut tests.

## 14. Task Consequences

Task 36 may implement:

- strict Investigation IDs, target and plan domain;
- exact preset hard/observed budget contracts;
- a pure reservation/observation ledger;
- a pure stop evaluator;
- deterministic integer Candidate Planner;
- benchmarks and structural no-Executor checks.

Task 37 must not treat SQLite row-local DDL as proof of decoded Plan
membership, aggregate equality or legal lifecycle transitions. Its production
connection remains actor-private behind a deny-by-default
`sqlite3_set_authorizer`; fixed typed operations perform cross-row pre-commit
verification, and no raw handle/generic SQL path escapes. Task 37 must also
measure maximum-size insertion, rejoin, terminal, recovery and continuation in
Release configuration: three serial samples each, every sample at most 75
monotonic seconds under the immutable 90-second deadline and within the Task
36 streaming-memory bound. Failure is `capacityBlocked`, not permission to
relax identity or deadline contracts.

Task 38 must implement the real App Server event normalization and prove:

- token usage is observed or typed unavailable;
- direct tool observations are identity-bound;
- no later turn starts after a reached ceiling;
- interruption waits for terminal `turn/completed`;
- partial reports contain only verified evidence.

Task 39 must validate those semantics in the current-source signed-App runtime.
No Task before Phase D Task 44 may enable normal production Deep Dive.
