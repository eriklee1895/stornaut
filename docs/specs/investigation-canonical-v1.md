# Stornaut Investigation Canonical and Accounting Contract v1

> **Status:** Normative for Phase D / Task 36. This is the single
> implementation truth for the codec, source manifest, priority, clocks,
> budget lifecycle, runtime observations, persisted web provenance and
> signed-runtime capability matrix.
>
> **No authority:** Nothing in this contract creates Policy, selection,
> confirmation, Trash, Executor or authorization authority.

## 1. Canonical Binary Grammar

The codec name is `StornautInvestigationCanonicalV1`.

Every digest input is exactly:

```text
magic || encoded-domain-text || encoded-root-record
```

where `magic` is the 21 ASCII bytes:

```text
STORNAUT-INV-CANON-1\0
```

All multibyte integers, counts, lengths and tags are big-endian. The only value
encodings are:

| Value | Exact bytes |
| --- | --- |
| nil | `00` |
| false | `01` |
| true | `02` |
| UInt64 | `10` + 8-byte big-endian UInt64 |
| Int64 | `11` + 8-byte big-endian two's-complement Int64 |
| text | `20` + 8-byte big-endian UInt64 UTF-8 byte count + exact UTF-8 bytes |
| bytes | `21` + 8-byte big-endian UInt64 byte count + exact bytes |
| array | `30` + 8-byte big-endian UInt64 element count + each element as 8-byte big-endian encoded-byte count + encoded value |
| record | `40` + 8-byte big-endian UInt64 field count + each field as 2-byte big-endian UInt16 tag + 8-byte big-endian encoded-value count + encoded value |

The encoded domain is the ordinary `text` value immediately following the
magic. The root value must be a record.

The decoder has a maximum nested canonical-value depth of `8`. Every schema
also has a complete digest-input byte bound:

| Domain | Maximum complete digest-input bytes |
| --- | ---: |
| `stornaut.test.empty.v1` | `65_536` |
| `stornaut.test.primitives.v1` | `65_536` |
| `stornaut.investigation.target.v2` | `4_096` |
| one encoded `InvestigationTargetV2` value | `16_384` |
| `stornaut.investigation.target-set.v1` | `65_536` |
| `stornaut.investigation.plan.v1` | `2_097_152` |
| `stornaut.investigation.source.v1` | `536_870_912` |

Lengths/counts are checked before allocation. The decoder never reserves a
caller-declared length until it proves the value is within the owning schema
bound and within remaining input bytes.

The `536_870_912` source-domain limit is the complete canonical digest input,
including metadata. It does not raise the independent `268_435_456`-byte sum
limit for exact source payloads in §4.1.

### 1.1 Strict decoding

- Every record schema below defines the exact required tag set. All tags,
  including optional-value tags, must be present exactly once.
- Unknown, duplicate, omitted or out-of-order tags are rejected.
- A required non-optional field cannot contain nil.
- Optional fields encode nil at their required tag when absent.
- A value type must exactly match the tag table.
- All UInt64/count/length values use exactly eight bytes; shorter or longer
  integer forms do not exist.
- Text must be valid UTF-8 and is not Unicode-, case-, locale-, slash-,
  path- or percent-normalized. Composed and decomposed text are distinct.
- Dates are Int64 microseconds since Unix epoch, truncated toward zero before
  range checking. Non-finite or out-of-range dates are rejected.
- Booleans never encode as integers.
- Every enum token is one of the exact ASCII tokens in this document.
- Trailing bytes, length mismatch and nested value overrun are rejected.
- SHA-256 retains all 32 bytes; display uses all 64 lowercase hexadecimal
  digits.
- JSON, plist, reflection, native memory layout, dictionary iteration and
  `Hashable.hashValue` are forbidden for canonical identity.

### 1.2 Array rules

There are only two array classes:

1. **ordered** — encode the supplied semantic order and reject an input whose
   order violates the owning schema;
2. **canonical-set** — require unique values already sorted by unsigned
   lexicographic comparison of each element's complete canonical bytes.

The encoder validates but never silently sorts. The exact class for every
array field appears in the record tables.

## 2. Fixed Domains and Enum Tokens

Digest domains:

```text
stornaut.investigation.target.v2
stornaut.investigation.source.v1
stornaut.investigation.target-set.v1
stornaut.investigation.plan.v1
```

Target kind:

```text
unknown-large-consumer-v1
unexplained-space-gap-v1
classification-conflict-v1
unknown-producer-v1
stale-or-insufficient-evidence-v1
```

Source binding kind:

```text
snapshot-v1
classification-snapshot-v1
space-ledger-measure-v1
```

Space Ledger measure key:

```text
unknown-residual-v1
```

Source row kind:

```text
scan-session-v1
path-snapshot-v1
classification-v1
evidence-v1
space-ledger-v1
```

Storage column value kind:

```text
text-v1
int64-v1
```

Budget preset:

```text
focused-v1
balanced-v1
thorough-v1
```

Priority tier:

```text
measured-v1
unmeasurable-v1
```

Required capability tokens:

```text
direct-read-v1
shell-v1
unified-exec-v1
live-search-v1
public-command-network-v1
browser-or-direct-fetch-v1
image-inspection-v1
skills-v1
subagents-v1
```

These map one-to-one to the current
`CapabilityRuntimeCapability.required` cases:
`directRead`, `shell`, `unifiedExec`, `liveSearch`,
`publicCommandNetwork`, `browserOrDirectFetch`, `imageInspection`, `skills`
and `subagents`.

`DomainToken` is an open lexical type, not arbitrary Unicode. Its exact
grammar is:

```text
byteLength = 1...128
allowedByte = ALPHA / DIGIT / "-" / "." / "_"
```

Every scalar must therefore be one ASCII byte in
`[A-Za-z0-9._-]`. Whitespace, controls, non-ASCII, percent escapes and all
other punctuation are invalid. The owning field may impose a closed subset;
otherwise any token satisfying this grammar is valid.

## 3. Record Schemas

### 3.1 `SourceBindingV1`

| Tag | Field | Type | Rule |
| ---: | --- | --- | --- |
| 1 | kind | text enum | required |
| 2 | snapshotID | optional text | present or nil |
| 3 | classificationID | optional text | present or nil |
| 4 | measureKey | optional text enum | present or nil |

Valid combinations:

- `snapshot-v1`: tag 2 text; tags 3–4 nil;
- `classification-snapshot-v1`: tags 2–3 text; tag 4 nil;
- `space-ledger-measure-v1`: tags 2–3 nil; tag 4 text.

### 3.2 `TargetIdentityV2`

This is the root for `stornaut.investigation.target.v2`.

| Tag | Field | Type |
| ---: | --- | --- |
| 1 | schemaVersion | UInt64, exactly `2` |
| 2 | scanSessionID | text |
| 3 | scanScopeID | text |
| 4 | targetKind | text enum |
| 5 | sourceBinding | `SourceBindingV1` record |

`InvestigationTargetID` is:

```text
target-<SHA-256(TargetIdentityV2 canonical bytes) as 64 lowercase hex>
```

### 3.3 `PriorityV1`

| Tag | Field | Type |
| ---: | --- | --- |
| 1 | tier | text enum |
| 2 | score | UInt64 |

### 3.4 `InvestigationTargetV2`

| Tag | Field | Type | Array class |
| ---: | --- | --- | --- |
| 1 | schemaVersion | UInt64, exactly `2` | — |
| 2 | targetID | text | — |
| 3 | scanSessionID | text | — |
| 4 | scanScopeID | text | — |
| 5 | targetKind | text enum | — |
| 6 | sourceBinding | `SourceBindingV1` record | — |
| 7 | reasonKeys | array of text `DomainToken` | canonical-set; `1...16` |
| 8 | expectedAllocatedBytes | optional `ByteCountV1` encoded as UInt64 | — |
| 9 | uncertaintyPermille | UInt64 in `1...1_000` | — |
| 10 | relevancePermille | UInt64 in `1...1_000` | — |
| 11 | investigationCostPermille | UInt64 in `1...1_000` | — |
| 12 | priority | `PriorityV1` record | — |
| 13 | createdAtMicros | Int64 | — |

Tag 2 must equal the hash-derived ID of tags 3–6.

`ByteCountV1` is an unsigned integer in `0...Int64.max`. The strict binary
and `DomainJSON` decoders reject `Int64.max + 1...UInt64.max`; no caller may
construct an out-of-range value. This bound is part of the wire contract, not
an implementation convenience.

### 3.5 `StorageColumnV1`

| Tag | Field | Type |
| ---: | --- | --- |
| 1 | name | text |
| 2 | valueKind | text enum |
| 3 | textValue | optional text |
| 4 | int64Value | optional Int64 |

`text-v1` requires tag 3 text/tag 4 nil. `int64-v1` requires tag 3 nil/tag 4
Int64.

### 3.6 `SourceRowV1`

| Tag | Field | Type | Array class |
| ---: | --- | --- | --- |
| 1 | rowKind | text enum | — |
| 2 | primaryID | text | — |
| 3 | storageColumns | array of `StorageColumnV1` | canonical-set; column names unique |
| 4 | payloadByteCount | UInt64 | — |
| 5 | payloadSHA256 | bytes, exactly 32 | — |

The storage columns are all exact non-payload SQLite columns. Each name has
one required value kind:

| Row kind | Required column name → value kind |
| --- | --- |
| scan-session-v1 | `id` → text-v1; `started_at_ms` → int64-v1; `finished_at_ms` → int64-v1; `expires_at_ms` → int64-v1 |
| path-snapshot-v1 | `id` → text-v1; `session_id` → text-v1; `relative_path` → text-v1; `observed_at_ms` → int64-v1 |
| classification-v1 | `id` → text-v1; `snapshot_id` → text-v1; `disposition` → text-v1; `classified_at_ms` → int64-v1 |
| evidence-v1 | `id` → text-v1; `snapshot_id` → text-v1; `observed_at_ms` → int64-v1 |
| space-ledger-v1 | `id` → text-v1; `session_id` → text-v1 |

Column names and row kinds are ASCII. No extra/missing column is permitted.
For every row kind, `primaryID` equals the text value of its `id` storage
column. For `space-ledger-v1`, both `id` and `session_id` equal the selected
Scan session ID. Millisecond columns are exact SQLite Int64 values. The
`disposition` text must decode as the current closed `ReclaimDisposition`
enum; all ID/path text must pass its current typed Core decoder.

The raw Store-neutral row seam applies closed bounds before any canonical
buffer allocation: at most four storage columns, non-empty column names of at
most 64 UTF-8 bytes, and text values of at most 16,384 UTF-8 bytes. The
complete encoded `SourceRowV1` byte count uses checked arithmetic and must not
exceed the 512 MiB canonical-input bound. Violations yield
`sourceProjectionTooLarge`.

### 3.7 `SourceProjectionV1`

This is the root for `stornaut.investigation.source.v1`.

| Tag | Field | Type | Array class |
| ---: | --- | --- | --- |
| 1 | schemaVersion | UInt64, exactly `1` | — |
| 2 | scanSessionID | text | — |
| 3 | primaryScanScopeID | text | — |
| 4 | sourceRows | array of `SourceRowV1` | canonical-set; `(rowKind, primaryID)` unique |
| 5 | relevanceTokens | array of text `DomainToken` | canonical-set |

### 3.8 `TargetSetV1`

This is the root for `stornaut.investigation.target-set.v1`.

| Tag | Field | Type | Array class |
| ---: | --- | --- | --- |
| 1 | schemaVersion | UInt64, exactly `1` | — |
| 2 | orderedTargetIDs | array of text | ordered, exact Planner order |

### 3.9 `BudgetLimitsV1`

| Tag | Field | Type |
| ---: | --- | --- |
| 1 | wallClockNanoseconds | UInt64 |
| 2 | coordinatorTurns | UInt64 |
| 3 | probeCalls | UInt64 |
| 4 | probeReadBytes | UInt64 |
| 5 | probeOutputBytes | UInt64 |
| 6 | cumulativeContextBytes | UInt64 |
| 7 | concurrentProbes | UInt64 |
| 8 | consecutiveNoGainSteps | UInt64 |
| 9 | observedDirectToolStarts | UInt64 |
| 10 | observedTotalTokens | UInt64 |
| 11 | singleContextInputBytes | UInt64, exactly `262_144` |

### 3.10 `InvestigationPlanV1`

This is the root for `stornaut.investigation.plan.v1`.

| Tag | Field | Type | Array class |
| ---: | --- | --- | --- |
| 1 | schemaVersion | UInt64, exactly `1` | — |
| 2 | investigationID | text | — |
| 3 | scanSessionID | text | — |
| 4 | scanScopeID | text | — |
| 5 | sourceFingerprint | bytes, exactly 32 | — |
| 6 | budgetPreset | text enum | — |
| 7 | budgetLimits | `BudgetLimitsV1` record | — |
| 8 | targets | array of `InvestigationTargetV2` | ordered, exact Planner order |
| 9 | targetSetFingerprint | bytes, exactly 32 | — |
| 10 | createdAtMicros | Int64 | — |
| 11 | expiresAtMicros | Int64 | — |
| 12 | requestedCoveragePermille | UInt64 in `1...1_000` | — |
| 13 | remainingUnknownByteThreshold | optional UInt64 | — |
| 14 | requiredCapabilities | array of capability text enum | canonical-set |

The plan fingerprint is SHA-256 of this complete root. The target-set
fingerprint must equal the hash of tag 8's target IDs in the same order.
Plan construction, strict `DomainJSON` decoding and canonical-binary decoding
all reject any target sequence that is not the exact Planner order: measured
before unmeasurable, descending fixed-point priority score, then the closed
canonical tie-break bytes. Recomputing a self-consistent target-set or Plan
fingerprint does not make a reordered sequence valid. The Planner and Plan
validators use the same ordering implementation.
The complete encoded `InvestigationPlanV1` digest input, including magic and
domain, must not exceed `2_097_152` bytes. Exceeding the bound rejects Plan
construction; the Planner does not silently remove reasons or targets to fit.
This is the canonical binary identity bound, not the persistence-JSON bound.
The strict `DomainJSON` representation of one complete Plan must not exceed
`4_194_304` UTF-8 bytes. Exceeding either independent bound rejects without
truncation. Task 37 may use this one role-specific 4 MiB persistence allowance
for the strict Plan and no other generic Investigation payload.

For `CandidatePolicyV1`, tags 10–13 are not caller-selected:

- `createdAtMicros` is the injected planning time;
- `expiresAtMicros` is the earlier of the retained Scan-session
  `expires_at_ms` converted exactly to microseconds and
  `createdAtMicros + wallClockNanoseconds / 1_000`; preset wall-clock values
  are all exact multiples of 1,000 nanoseconds;
- `requestedCoveragePermille` is exactly `900`;
- `remainingUnknownByteThreshold` is exactly `1_073_741_824` bytes.

Plan expiry is an admission-freshness deadline. Once an unexpired Plan has
atomically entered a run, the run's separate monotonic wall-clock budget begins
at `runStart`; Plan expiry does not shorten or extend that admitted runtime
budget.

Tag 14 contains exactly the nine required capabilities in the canonical-set
order proved by the golden vector. Missing, extra or duplicate capabilities
reject Plan construction and decoding.

## 3.11 Strict `DomainJSON` projection

The binary canonical format is the only identity/fingerprint encoding.
Task 36 values also use one strict persisted/debug JSON projection so
`DomainJSON` round trips cannot drift identity:

- every object rejects unknown, omitted or duplicate semantic keys;
- every optional key is present and encodes JSON `null` when absent;
- schema versions encode as JSON integers;
- IDs encode as their validated string;
- enum values encode as the exact versioned wire tokens in §2, not Swift case
  names;
- `InvestigationFingerprint` encodes as exactly 64 lowercase hexadecimal
  characters and decodes to exactly 32 bytes;
- canonical timestamps encode as signed Int64 Unix microseconds in fields
  named `createdAtMicros` / `expiresAtMicros`; they never encode as JSON
  floating-point dates;
- byte counts, factors, scores, counters and limits encode as nonnegative JSON
  integers accepted only when exactly representable by the owning UInt64
  bound;
- arrays retain their owning ordered/canonical-set contract;
- `InvestigationSourceBinding` uses the exact four-key object
  `kind/snapshotID/classificationID/measureKey`, with absent values encoded
  as null and the same valid combinations as `SourceBindingV1`;
- `InvestigationTarget` uses the exact keys represented by
  `InvestigationTargetV2`, with `id` as the JSON spelling of canonical
  `targetID`;
- `InvestigationPlan` uses the exact keys represented by
  `InvestigationPlanV1`, with `id` as the JSON spelling of canonical
  `investigationID`;
- derived IDs, priorities and fingerprints are recomputed after strict decode
  and mismatches reject.

The `DomainJSON` decoder is duplicate-aware before typed decoding; a parser
that collapses duplicate object keys is non-conforming. Integer tokens are
parsed from their exact decimal lexeme into checked signed/unsigned 64-bit
storage without passing through IEEE-754 `Double`. Tests include omitted
versus explicit-null optionals, duplicate keys, `2^53 - 1`, `2^53`,
`2^53 + 1`, `Int64.max`, `Int64.max + 1`, `UInt64.max`, negative values for
unsigned fields and decimal overflow.

Existing source row payloads remain their existing byte-identical
`DomainJSON` representation under §4; Task 36 does not rewrite those schemas.
`LegacyInvestigationTargetV1` retains only its old v1 JSON fixture shape and
cannot decode as the new `InvestigationTarget`.

## 4. Source Projection Manifest

Task 36 does not invent a second canonical serialization for existing Core
domain rows. The source manifest binds the exact bytes already stored by
`EvidenceStore`:

1. load the row and all required non-payload columns;
2. enforce Store column/payload identity checks;
3. decode the payload into its exact typed Core value;
4. require `DomainJSON.encode(decoded) == exactStoredUTF8Bytes`;
5. enforce the row-kind payload limit;
6. hash the exact stored UTF-8 payload bytes;
7. build `SourceRowV1` from all non-payload columns, byte count and digest.

The raw payload is not copied into the Investigation session row; only the
bounded manifest and source fingerprint persist.

Maximum-size construction and verification are two-pass streaming operations:

1. a repeatable source cursor emits exact Store rows in canonical
   `SourceRowV1` order from one pinned Store snapshot;
2. pass one validates/decodes one payload at a time, computes its exact row
   metadata/digest, validates strict monotonic row order and checked aggregate
   byte/count bounds, and submits each normalized row to one caller-owned,
   non-escaping `InvestigationManifestSink`;
3. pass two re-emits the same rows, rejects any count/byte/digest drift, and
   feeds one write-only `InvestigationCanonicalHashSink` incrementally after
   pass one has proved every enclosing encoded length;
4. neither pass builds the complete source payload, `SourceRowV1` array or
   canonical SourceProjection bytes in memory.

The pass-one sink accepts exactly one normalized row metadata value at a time
and may fail the operation; Task 37 supplies the Store-owned prepared-statement
sink inside its pinned transaction. Task 36 tests may supply a discard or
bounded fixture sink. The pass-two sink exposes only checked encoded-byte
count and final SHA-256 metadata. It never returns accumulated `Data`; a
materializing sink is permitted only for the small fixed golden vectors and
is unavailable to production projection APIs.

The canonical-set order is still unsigned lexicographic order of each complete
encoded `SourceRowV1`, not SQL text order. Because `(rowKind, primaryID)` is
unique and precedes all other varying fields, the Store may obtain the
candidate order from their complete encoded text values, but Swift must
reconstruct each complete row encoding and compare it with the immediately
previous encoding. Relevance tokens use the same incremental canonical-set
validation. A cursor that changes between passes fails closed.

Canonical `SourceProjectionV1` validation applies the same raw storage-column
count/name/text bounds immediately after decoding one row's columns and before
canonical column re-encoding, ordering checks or row-kind semantic matching.
This keeps constructor, Store projection and persisted canonical validation on
one allocation-before-validation boundary; an over-bound column shape yields
`sourceProjectionTooLarge`, not a later `storageMismatch` or
`nonCanonicalOrder`.

### 4.1 Exhaustive membership and bounds

The selected projection contains:

- exactly one terminal usable `scan_sessions` row;
- exactly one `space_accounting` row decoded as the complete `SpaceLedger`;
- every `path_snapshots` row for the selected session and primary scope;
- every `classifications` row whose snapshot is in that exhaustive set;
- every `evidence` row whose snapshot is in that exhaustive set;
- all and only the relevance tokens supplied to planning.

No top-N sampling or silent truncation is allowed. Bounds:

| Dimension | Limit |
| --- | ---: |
| path snapshots | 100,000 |
| classifications | 100,000 |
| evidence total | 100,000 |
| evidence per snapshot | 100 |
| source rows total | 300,002 |
| relevance tokens | 256 |
| storage columns per source row | 4 |
| storage column name | 64 UTF-8 bytes, non-empty |
| storage text value | 16,384 UTF-8 bytes |
| ordinary row payload | 1 MiB |
| Space Ledger payload | 16 MiB |
| sum of all exact payload bytes | 256 MiB |
| complete canonical SourceProjection digest input | 512 MiB |

Exceeding a bound yields `sourceProjectionTooLarge`; it does not create a
partial Plan. IDs must be unique, every classification/evidence parent must be
present, session/scope/root identities must match, the session payload must
contain the exact primary completed scope, and expired/corrupt rows fail
closed.

Task 36's maximum-size benchmark must prove no complete source-payload or
canonical-projection buffer is retained. On the current supported Apple
Silicon development machine, the 300,002-row streaming projection with the
256 MiB generated payload boundary must complete within 60 seconds and keep
incremental resident-memory growth attributable to projection below 192 MiB
plus the single largest admitted payload (16 MiB). Peak memory is the
process-lifetime kernel high-water value from
`task_vm_info_data_t.ledger_phys_footprint_peak` minus the footprint sampled
immediately before projection; periodic row sampling is not sufficient
evidence. Ordinary Swift test suites exclude the source and Candidate Planner
benchmarks. The authoritative full verifier invokes each benchmark separately
with `swift test --no-parallel --filter <exact-test-name>` so neither benchmark
shares a process with unrelated tests or with the other benchmark. The
checked-in benchmark report records the machine, exact command and observed
values; exceeding either source threshold blocks Task 36 rather than raising
it without review.

### 4.2 Immutable manifest and exact rejoin barriers

Task 37 persists:

- source fingerprint;
- complete ordered `SourceRowV1` manifest as normalized bounded rows, not one
  aggregate session JSON payload;
- relevance tokens as bounded ordered rows, not one unbounded session field;
- the selected session/scope IDs.

Recomputation re-runs the exhaustive membership query and verifies both “no
manifest row changed/disappeared” and “no qualifying row was added.” It occurs
at exactly these boundaries:

1. Investigation session insertion;
2. Task 38 runtime admission immediately before ephemeral `thread/start`;
3. any explicit source refresh before a later `turn/start` (ordinary active
   runs use the admitted in-memory projection and do not re-read Store);
4. terminal advisory normalization before report/session atomic commit;
5. crash-recovery normalization before any partial report is promoted;
6. continuation-plan construction;
7. Investigation report → current Review projection;
8. any Agent proposal → current `CleanupPlanBuilder` join.

History-only rendering does not rejoin current state and displays the last
verification status. Any other future Store API that joins Investigation data
to current product state must first be added to this exhaustive list by a
versioned contract change. Mismatch is typed stale/corrupt.

## 5. Deterministic Priority

`ByteCountV1` is bounded to `Int64.max`. For measured bytes:

```text
mib = ceil(expectedAllocatedBytes / 1_048_576)
numerator = mib * uncertaintyPermille * relevancePermille
score = floor(numerator / investigationCostPermille)
```

All values are UInt64 and every multiplication is checked. With:

```text
expectedAllocatedBytes <= Int64.max
uncertaintyPermille <= 1_000
relevancePermille <= 1_000
```

the maximum numerator is `8_796_093_022_208_000_000`, below `UInt64.max`;
there is no saturation path. Overflow is invalid input.

- Known bytes use tier `measured-v1`, including a measured zero.
- Missing bytes use tier `unmeasurable-v1`; their score is
  `floor(uncertaintyPermille * relevancePermille /
  investigationCostPermille)`.
- Every measured tier sorts before every unmeasurable tier.
- Within a tier sort descending score, then ascending target-kind token,
  source-binding canonical bytes and reason-key canonical bytes.

This is the only priority arithmetic. Checked/wide/saturating alternatives are
not permitted.

### 5.1 `CandidatePolicyV1`

Task 36 uses one closed Swift-owned candidate policy. Callers and Codex cannot
supply thresholds, factors, rule ordering or arbitrary reason text.

Fixed values:

| Value | Exact v1 value |
| --- | ---: |
| large measured allocation threshold | `1_073_741_824` bytes |
| requested coverage | `900` permille |
| remaining measurable Unknown stop threshold | `1_073_741_824` bytes |
| base relevance | `700` permille |
| `relevance.large` increment | `100` permille |
| `relevance.developer` increment | `100` permille |

The large threshold is absolute and inclusive:
`expectedAllocatedBytes >= 1_073_741_824`. v1 has no scope-relative threshold.
The remaining-Unknown stop predicate is strict:
`measurableRemainingUnknownBytes < 1_073_741_824`; equality does not stop.

Only these relevance tokens are accepted:

```text
relevance.large
relevance.developer
```

They are a unique canonical-set. Unknown or duplicate tokens reject planning.
`relevance.large` adds 100 only to a target with measurable expected allocated
bytes at or above the large threshold. `relevance.developer` adds 100 only to
a classification-backed target whose retained category is one of:

```text
packageAndBuildCaches
rebuildableProjectArtifacts
toolRuntimesAndImages
largeRepositoriesAndHistory
unknownLargeConsumers
```

The relevance result is `min(1_000, 700 + applicable increments)`. A
snapshot-only target without a retained classification and every ledger-only
target are ineligible for `relevance.developer`. Ledger-only targets may
receive `relevance.large` when measurable.

Kind factors:

| Target kind | uncertaintyPermille | investigationCostPermille |
| --- | ---: | ---: |
| `unknown-large-consumer-v1` | `750` | `250` |
| `unexplained-space-gap-v1` | `1_000` | `800` |
| `classification-conflict-v1` | `1_000` | `350` |
| `unknown-producer-v1` | `850` | `400` |
| `stale-or-insufficient-evidence-v1` | `700` | `300` |

The selected Scan session is usable only when:

- its terminal state is `completed`, `partial` or the existing Quick Scan
  `cancelled`;
- it is not `failed`;
- the selected primary scope appears exactly once in `completedScopes` and
  not in `unfinishedScopes`;
- because Phase D selects exactly one primary root, any `unfinishedScopes`
  entry is ineligible; there is no secondary-scope exception in v1;
- the exact same-session Space Ledger contains no `coverageGaps`,
  `unknownIncludesUnmeasurable == false`, `unmeasurable.status == measured`
  with exactly `0` bytes, and status is exactly `reconciled`. A
  permission/boundary-limited subtree is
  represented by a typed `coverageGap` with unmeasurable bytes and therefore
  blocks v1 planning even if a malformed or future session also claims the
  primary scope completed;
- its retained `expires_at_ms` is strictly later than injected planning time;
- the exact same-session Space Ledger and exhaustive selected-scope source
  projection pass §4.

This predicate is the single normative
`InvestigationSourceEligibilityV1` used by planning, Task 37 insertion/rejoin,
Task 42 baseline admission and Task 44 final validation. No App-layer
`completed`-only predicate may narrow or widen it independently.

This does not change the existing Quick Scan `cancelled` state. Investigation
cancellation remains governed by §§6 and 9 and has no standalone persisted
terminal `cancelled` state.

The v1 eligibility result is typed:

- `eligible`;
- `terminalStateIneligible`;
- `primaryScopeMissingOrDuplicate`;
- `primaryScopeUnfinished(reason: ScanScopeCompletionReason)`;
- `permissionOrBoundaryLimited(snapshotIDs: bounded sorted IDs)`;
- `sourceExpired`;
- `sourceMissing`;
- `sourceCorrupt`;
- `sourceStale`.

The bounded snapshot IDs come only from exact retained Space Ledger
`coverageGaps`; they are evidence for recovery/display, not paths or new
authority. No untyped “limited” Boolean/string exists. Tests include:

- eligible `completed`, `partial` and existing Quick Scan `cancelled` sessions
  with one completed primary scope and zero unfinished scopes/gaps;
- primary-scope `permissionDenied`, `cancelled`, `interrupted`,
  `metadataChanged`, `scannerFailure` and `storeFailure`;
- a contradictory fixture that claims primary completion but contains a
  permission gap, which returns `permissionOrBoundaryLimited`;
- stale, expired, missing and corrupt source variants.

Classification-backed eligibility excludes `protected`. Ordinary
`readyToReclaim` is not a candidate. One exceptional
`readyToReclaim` classification may become `classification-conflict-v1` only
when its retained risk is `high` or `critical`, or its confidence is not
`high`; this detects a contradictory persisted safety shape and grants no
cleanup authority.

For every non-Protected classification, collect all applicable reason keys,
then select exactly one target kind for that classification/snapshot binding
using this precedence:

1. `classification-conflict-v1` when the exceptional contradictory
   `readyToReclaim` predicate above is true;
2. `unknown-large-consumer-v1` when disposition is `unknown` and measured
   allocated bytes meet the inclusive large threshold;
3. `unknown-producer-v1` when disposition is `unknown` or
   `reviewRecommended` and `producer == nil`;
4. `stale-or-insufficient-evidence-v1` when disposition is `unknown` or
   `reviewRecommended` and at least one required evidence key is missing or
   any retained Evidence row for the snapshot is `stale` or `expired`.

The resulting target uses the classification/snapshot source binding. All
applicable reasons are retained even when a higher-precedence kind wins.
Thus one classification source binding produces at most one target and Plan
construction never has to discard a lower-precedence duplicate.

If an exhaustive selected-scope snapshot has no classification, it produces
one snapshot-bound `stale-or-insufficient-evidence-v1` target only when:

- `relativePath != "."`;
- allocated bytes are measured;
- allocated bytes meet the inclusive large threshold.

Its reason is `reason.classification-missing`. It cannot become
`unknown-large-consumer-v1` because the Unknown disposition is not present.
Smaller, unmeasurable and root snapshots without a classification produce no
candidate in v1.

The compact policy index therefore retains one derived `isRoot` Boolean for
every snapshot candidate. It is computed only from the strict retained
`relativePath` while that row is decoded; the path itself is then released.
`isRoot == true` exactly when the strict value is `"."`. The Planner neither
reconstructs nor guesses path text later.

Fixed reason keys are:

```text
reason.classification-high-risk
reason.classification-low-confidence
reason.classification-missing
reason.evidence-expired
reason.evidence-stale
reason.required-evidence-missing
reason.rule-miss
reason.space-unknown-residual
reason.unknown-producer
```

For a classification target, its exact `missingEvidenceKeys` are also retained
as reasons. The Planner combines fixed and exact missing-evidence tokens,
deduplicates, and explicitly sorts by complete canonical text bytes before
constructing the target. The canonical encoder itself still never sorts. More
than 16 combined unique reasons yields `candidateReasonLimitExceeded`; reasons
are never truncated.

Fixed classification reason mapping is exact:

- `classification-high-risk` when risk is `high` or `critical`;
- `classification-low-confidence` when confidence is not `high`;
- `unknown-producer` when producer is nil;
- `required-evidence-missing` when `missingEvidenceKeys` is nonempty;
- `rule-miss` when `ruleID` is nil;
- `evidence-stale` when at least one retained row is `stale`;
- `evidence-expired` when at least one retained row is `expired`.

A fixed reason is not added when its exact predicate is false. Current
evidence does not add a reason. Multiple stale/expired rows add each fixed key
at most once. The selected target kind already carries the unknown-large or
space-gap semantic and is not duplicated as another reason token.

The eligible reconciled Space Ledger produces at most one ledger-bound
`unexplained-space-gap-v1` target with subtype `unknown-residual-v1` when
`unknown.bytes` is measurable and greater than zero. No ledger target is
created for measured zero, unavailable bytes, coverage gaps, unmeasurable
bytes or a non-reconciled status, and no path/snapshot is invented.

Coverage-limited and inconsistent ledgers fail
`InvestigationSourceEligibilityV1`; they are not planner branches in v1.

After classification/snapshot and ledger candidate construction, duplicate
`(kind, sourceBinding)` or duplicate derived target IDs fail closed. Plan
construction additionally rejects any repeated source binding.

## 6. Clock and Atomic Admission

Both scientific elapsed time and the terminal barrier use injected Swift
`ContinuousClock` instants. Wall calendar time is metadata only.

- `runStart` is sampled once when the serial coordinator actor transitions an
  admitted run from `ready` to `running`, immediately before runtime workspace
  or thread startup. Setup therefore consumes the selected duration.
- Before every scientific admission, the actor samples `now` and computes
  monotonic `elapsed = runStart.duration(to: now)`.
- A negative/non-representable duration is runtime failure.
- Admission succeeds only while `elapsed < limit`; equality closes admission.
- Every mutation has a strictly increasing UInt64 coordinator ordinal.
- The actor evaluates all facts received at one ordinal using the normative
  stop precedence before admitting another operation.
- The first transition from `open` to `closing` is an atomic compare-and-set.
  Its sampled instant is T0 and can never change.
- If multiple causes are pending, the stop evaluator's precedence chooses the
  cause at the single next actor ordinal. Later causes are recorded as
  degradations but do not replace T0 or the primary cause.

The same `ContinuousClock` measures T0+15, T0+45, T0+135 and T0+140
seconds.

The closed `InvestigationStopReason` tokens are `coverageReached`,
`remainingUnknownBelowThreshold`, `budgetExhausted`, `noEvidenceGain`,
`userStopped` and `userCancelled`. User stop and cancellation are distinct
immutable primary causes; neither is inferred from another stop condition.

The normative stop precedence evaluated after every accepted evidence delta
and before every new Swift-owned admission is:

1. containment, lifecycle, runtime identity or strict protocol loss:
   block/fail and drain;
2. user cancellation: record `userCancelled` as the immutable primary cause,
   close admission and drain; after a successful barrier and atomic commit,
   persist `partial(userCancelled)` rather than a standalone cancelled state;
3. user stop: record `userStopped` as the immutable primary cause, close later
   admission and drain; after a successful barrier and atomic commit, persist
   `partial(userStopped)`; a later final event cannot overwrite it;
4. a hard limit exhausted or the next reservation would exceed it:
   `budgetExhausted` with the exact dimension;
5. an identity-valid observed direct-tool/token ceiling reached:
   `budgetExhausted` marked event-time observed;
6. requested coverage reached;
7. remaining measurable Unknown below the plan threshold;
8. consecutive verified no-gain limit reached;
9. continue.

Unavailable token usage is a degradation and proves neither exhaustion nor
remaining capacity. Unmeasurable Unknown cannot satisfy a byte threshold.
Pause is not a scientific stop reason.

## 7. Budget Reserve / Commit / Release

For unsigned limit `L`, consumed `C`, amount `A`:

```text
reserve succeeds iff A > 0 && C <= L && A <= L - C
```

Exactly `L` is admitted. All arithmetic is checked.

| Dimension | Admission/commit point | Success | Failure/cancel/timeout | Crash/forced drain | Replay |
| --- | --- | --- | --- | --- | --- |
| turn | consume 1 immediately before writing one `turn/start` request | retained | retained, including send failure | retained in terminal ledger | same ordinal rejected |
| Swift context | consume exact UTF-8 bytes atomically with turn admission | retained | retained | retained | same ordinal rejected |
| Probe call | current `ProbeSessionBudget.reserveCall` before path access | retained | retained | retained | second call ordinal rejected |
| Probe read | current `reserveReadBytes` after canonical path admission, before access | retained | retained | retained | second reservation rejected |
| Probe output | after successful response encoding and per-call bound, atomically call current `reserveOutputBytes` | retained if commit succeeds | zero consumption if encoding/per-call/session commit fails; response discarded; retained if a later delivery/audit step fails | committed bytes retained | equal result cannot commit twice |
| Probe concurrency | acquire actor-owned lease before Probe call | release once after Probe terminal return | release once after terminal return | recovery owner releases only after lifecycle proves no Probe worker remains | duplicate/foreign release fails |
| no-gain | update after one valid normalized scientific step | gain→0; no-gain→+1 | invalid/cancel/protocol failure leaves unchanged | terminal path leaves unchanged | duplicate step rejected |

The concurrency lease ID is deterministic and unique inside the ledger-owned
run:

```text
probe-lease-<coordinatorOrdinal>
```

The lease carries the exact `InvestigationRunID` as a separate typed field.
This keeps the `DomainToken` identifier bounded even when a run ID itself is
at the 128-byte domain limit without weakening identity binding. The serial
coordinator actor owns the active lease set. A release requires the same exact
run ID, lease ID and acquisition ordinal. Underflow, duplicate/foreign release
or a live lease after a purported drain yields
`blocked(lifecycleDrainUnconfirmed)`. A crashed run is never resumed; recovery
may close leases only after the accepted lifecycle supervisor proves the audit
session and proxy owner empty.

Observed direct-tool/token ceilings are not reservations. Identity-valid count
or total `>= ceiling` atomically closes later admission and preserves overrun.

## 8. Runtime Event Normalization

Task 38 owns one receipt-versioned App Server adapter. Raw event payloads never
enter Core. Every accepted normalized event carries Investigation ID, run ID,
root session ID, thread ID, optional parent thread ID, turn ID, optional item
ID, closed kind, source method, coordinator ordinal and canonical raw-payload
SHA-256 for replay/conflict detection.

### 8.1 Root and child admission

1. `thread/start(ephemeral: true)` result supplies `thread.id` and
   `thread.sessionId`; both must be equal. The matching `thread/started`
   notification must carry the same identity before any turn admission.
2. Production never calls `thread/resume` or `thread/fork`.
3. A spawn edge is accepted only from a completed, identity-bound collaboration
   item on an already admitted parent turn. The runtime receipt pins exactly
   one closed wire schema for the run:
   - `collab-tool-call-v1`: item `type == "collabToolCall"`,
     `tool == "spawn_agent"`, exact `senderThreadId`, and exact nonempty
     `newThreadId` (or the documented singular `receiverThreadId` when
     `newThreadId` is absent);
   - `collab-agent-tool-call-v1`: item
     `type == "collabAgentToolCall"`, `tool == "spawnAgent"`, exact
     `senderThreadId`, and nonempty unique `receiverThreadIds`.
   A run never accepts both schemas. The adapter normalizes the exact parent
   thread, parent turn, spawn item ID and child IDs.
4. Every child ID must be new, non-root and unique. Before accepting any child
   turn/item/usage event, Task 38 performs `thread/read(includeTurns: false)`
   and requires `thread.id == childID`, `thread.parentThreadId == parentID` and
   `thread.sessionId == rootSessionID`.
5. A spawn key is `(parentThreadID, parentTurnID, spawnItemID, childThreadID)`.
   Equal payload-digest replay is a no-op; another payload for the same key,
   cyclic lineage, unknown parent or child event before metadata verification
   blocks the run.
6. Transport loss never reconnects to or resumes the thread; it closes
   admission and enters the terminal barrier.

### 8.2 Direct-tool starts

The replay key is `(threadID, turnID, itemID)`. The first identity-valid
`item/started` counts one only for the receipt-versioned closed tool set:

```text
commandExecution
mcpToolCall
the one receipt-pinned collaboration item spelling
webSearch
imageGeneration
imageView
```

Equal replay with the same canonical payload digest is a no-op. Another type or
payload for the key blocks. `fileChange`, an unknown tool-capable type, or an
MCP annotation that is not proven read-only blocks rather than disappearing
from accounting.

### 8.3 Token usage

The accepted wire event is `thread/tokenUsage/updated` with:

```text
threadId
turnId
tokenUsage.total { totalTokens, inputTokens, cachedInputTokens, outputTokens }
tokenUsage.last  { totalTokens, inputTokens, cachedInputTokens, outputTokens }
modelContextWindow?
```

All values are nonnegative UInt64 and
`cachedInputTokens <= inputTokens <= totalTokens`. For each admitted thread:

- equal `total` and equal payload digest is replay/no-op;
- any component decrease is invalid;
- equal `total` with another payload is conflicting replay;
- an increase replaces that thread's latest cumulative snapshot;
- run usage is the checked sum of each admitted thread's latest
  `total.totalTokens` exactly once;
- `last` and cached input are never added to the aggregate.

Each admitted turn records whether at least one matching usage event named that
turn. Terminal `turn/completed` does not itself invent usage. At terminal
barrier expiry, a terminal turn without matching usage makes run token quality
`usageUnavailable`; a live or unclassified descendant blocks finalization.
Equal terminal replay is a no-op; conflicting status for one thread/turn
blocks.

## 9. Terminal Barrier

At T0:

1. atomically close turn/Probe/context admission and record the primary cause;
2. send at most one `turn/interrupt` per active `(threadID, turnID)`.

From T0 through T0+15 seconds, accept only matching item, usage and terminal
events. Evidence from an unterminated turn is not promoted. Once all turns are
terminal, or at T0+15 seconds, invoke the idempotent audit-session drain.

By T0+45 seconds, the coordinator must prove:

- no live/unclassified descendant;
- audit session empty;
- managed proxy owner empty;
- no active Probe concurrency lease;
- ephemeral artifacts retired;
- the Store-owned terminal report/state transaction has begun.

The Store transaction retains Task 37's independent 90-second operation
deadline. By T0+135 seconds terminal truth must have committed; otherwise the
transaction is interrupted and rolled back. By T0+140 seconds the separate
five-second rollback/connection cleanup must have completed or the connection
is quarantined as `rollbackUnconfirmed`.

Outcomes:

- user cancellation + proved drain + successful terminal commit:
  `partial(userCancelled)`, preserving any previously verified evidence and
  retained unresolved-target lineage; a zero-finding partial is valid and a
  late successful model event cannot replace the primary cause;
- user stop + proved drain + successful terminal commit:
  `partial(userStopped)` under the same preservation and late-event rules;
- missing terminal event + proved forced drain:
  `blocked(runtimeTerminalUnobserved)`;
- unproved audit-session/proxy/Probe drain:
  `blocked(lifecycleDrainUnconfirmed)`;
- terminal transaction failure:
  `failed(terminalPersistenceFailed)`.

Cancellation is an internal request/primary cause, never a persisted or UI
terminal state named `cancelled`. The three failure outcomes above likewise
may not surface as cancelled, paused, budget-complete or successful. Task 42
cannot publish a terminal UI state or promote evidence before this barrier and
transaction finish. T0+140 is the outer settlement bound, not additional
scientific budget. If rollback cleanup remains unconfirmed, Store health fails
closed and the prior nonterminal run remains for crash recovery.

## 10. Persisted Web Provenance

Every persisted Investigation web source field uses one type:
`PersistedWebProvenance`. No Store API accepts raw `URL`/`String`.

Input is at most 2,048 UTF-8 bytes and is parsed once with a strict RFC 3986
parser:

- scheme must be exact lowercase `https`;
- user/password and fragment are rejected;
- port is absent or exactly `443`, and canonical output omits it;
- host must already be ASCII lowercase; percent escapes, Unicode/IDN,
  trailing dot, empty label and labels outside `[a-z0-9-]` are rejected;
- each label is 1–63 bytes, cannot begin/end with `-`, total host is at most
  253 bytes and contains at least two labels;
- IPv4/IPv6 literals and numeric-only hosts are rejected;
- `localhost` and suffixes `.localhost`, `.local`, `.internal`, `.home`,
  `.lan`, `.test`, `.example`, `.invalid`, `.onion` are rejected;
- the source must carry the runtime's identity-bound successful public
  transport classification; DNS text alone is insufficient.

Canonical persisted origin is only:

```text
https://<host>/
```

Path, query and fragment bytes never persist. The type stores:

- optional canonical origin;
- one closed reason:
  `acceptedOrigin`, `pathRedacted`, `queryRedacted`,
  `pathAndQueryRedacted`, `rejectedNonPublic`, `rejectedMalformed`.

It never stores removed input. The single sanitizer is mandatory for report
evidence, findings, candidate proposals, continuation records, History and
export. Task 37 tests the SQLite database bytes do not contain unique sentinels
placed in credentials, paths, queries, fragments, percent encodings, signed
parameters, Home paths or rejected hosts.

## 11. Signed Runtime Evidence Matrix

Task 39 and Task 44 produce three separate matrices bound to the same current
signed App/helper/runtime receipt.

### 11.1 Capability observation

Each of the nine tokens has a separate record with
`advertised/configured/invoked/observed/reasonKey`, using the existing
`CapabilityRuntimeCapabilityEvidence` contract:

| Token | Required observation |
| --- | --- |
| direct-read-v1 | direct-read synthetic token returned through admitted command/direct-read evidence |
| shell-v1 | successful shell marker and matching advisory evidence |
| unified-exec-v1 | startup or interaction unified-exec source plus marker |
| live-search-v1 | completed web-search event plus matching evidence |
| public-command-network-v1 | managed-proxy public command marker |
| browser-or-direct-fetch-v1 | fetch marker plus matching evidence |
| image-inspection-v1 | completed image-view event plus image token |
| skills-v1 | runtime skill selection plus skill token |
| subagents-v1 | admitted spawn completion, child result event and child token |

### 11.2 Enforced-control verification

The twelve existing `CapabilityRuntimeIntegrityProperty.required` entries are
reported separately. Structural `noExecutorReachability`, signed identities,
lifecycle ownership and OS profile admission do not derive from model success.

### 11.3 Adversarial denial

Fresh nonce-bound attempts cover user-data write, descendant write,
IPv4/IPv6 loopback, private/link-local destinations, Unix socket and
Policy/Trash/Executor reachability. Each denial is attributed to the expected
control. Absence of a violation or a successful model call is not proof.

## 12. Normative Golden Vectors

The checked-in specification and fixtures contain complete encoded hex and
SHA-256 for:

1. empty record;
2. primitive boundary record;
3. `TargetIdentityV2`;
4. `SourceProjectionV1`;
5. `TargetSetV1`;
6. `InvestigationPlanV1`.

The vectors below were independently regenerated during specification review
from the grammar and tag tables. The review-only generator is not checked in
and is not a product dependency. The checked-in tests must use an
independent Swift implementation and compare byte-for-byte.

The `SourceProjectionV1` vector intentionally supplies short opaque payload
byte strings only to test manifest byte-count/digest encoding. Those sample
bytes are not valid complete `ScanSession` or `SpaceLedger` Store fixtures and
must never be inserted into `EvidenceStore` or used to bypass the strict typed
decode plus byte-identical `DomainJSON` re-encode required by §4. Product Store
tests use separate complete domain fixtures. Every canonical-set vector is
ordered by each element's complete encoded bytes, never by a selected field.

Complete encoded-byte order is not ordinary text lexical order because a text
value begins with tag `20` and its 8-byte byte length. The vectors therefore
intentionally use these validated sequences:

- Scan-session `storageColumns`:
  `id`, `expires_at_ms`, `started_at_ms`, `finished_at_ms`;
- Space-Ledger `storageColumns`: `id`, `session_id`;
- `relevanceTokens`: `relevance.large`, `relevance.developer`;
- `requiredCapabilities`:
  `shell-v1`, `skills-v1`, `subagents-v1`, `direct-read-v1`,
  `live-search-v1`, `unified-exec-v1`, `image-inspection-v1`,
  `public-command-network-v1`, `browser-or-direct-fetch-v1`.

The review-only generator accepts these arrays already ordered and raises on
duplicates or any non-increasing adjacent complete encoded values. It never
sorts them.

<!-- STORNAUT_CANONICAL_VECTORS_BEGIN -->
### Empty Record

encoded-bytes: 61
sha256: 724b07f461c7690c1e0614abdbd72081d88622e2aab47183236b6bf8e049dc3b
hex:

```text
53544f524e4155542d494e562d43414e4f4e2d310020000000000000001673746f726e6175742e746573742e656d7074
792e7631400000000000000000
```

### Primitive Boundaries

encoded-bytes: 280
sha256: 56a27067b51cef0ebc1236d51200b250987fce1ee74832047fa2063ef0da9075
hex:

```text
53544f524e4155542d494e562d43414e4f4e2d310020000000000000001b73746f726e6175742e746573742e7072696d
6974697665732e763140000000000000000a000100000000000000091000000000000000000002000000000000000910
ffffffffffffffff0003000000000000000911ffffffffffffffff0004000000000000000b200000000000000002c3a9
000500000000000000010000060000000000000010200000000000000007666f63757365640007000000000000002d30
0000000000000002000000000000000a20000000000000000161000000000000000a2000000000000000016200080000
000000000001020009000000000000000c20000000000000000365cc81000a000000000000000101
```

### TargetIdentityV2

encoded-bytes: 303
sha256: 69d186b12fa1322c34f07da86e4ab6be9e370d7f777f0e12ea7d41049f46b384
hex:

```text
53544f524e4155542d494e562d43414e4f4e2d310020000000000000002073746f726e6175742e696e76657374696761
74696f6e2e7461726765742e763240000000000000000500010000000000000009100000000000000002000200000000
0000001520000000000000000c7363616e2d666978747572650003000000000000001620000000000000000d73636f70
652d6669787475726500040000000000000022200000000000000019756e6b6e6f776e2d6c617267652d636f6e73756d
65722d7631000500000000000000604000000000000000040001000000000000001420000000000000000b736e617073
686f742d763100020000000000000019200000000000000010736e617073686f742d6669787475726500030000000000
000001000004000000000000000100
```

### SourceProjectionV1

encoded-bytes: 1246
sha256: 318e1e01fb438c631a72056fa167fe0c94fffe8426adb6b25358e4cd3cfcd9df
hex:

```text
53544f524e4155542d494e562d43414e4f4e2d310020000000000000002073746f726e6175742e696e76657374696761
74696f6e2e736f757263652e763140000000000000000500010000000000000009100000000000000001000200000000
0000001520000000000000000c7363616e2d666978747572650003000000000000001620000000000000000d73636f70
652d66697874757265000400000000000003e4300000000000000002000000000000024c400000000000000005000100
0000000000001820000000000000000f7363616e2d73657373696f6e2d76310002000000000000001520000000000000
000c7363616e2d66697874757265000300000000000001b2300000000000000004000000000000006240000000000000
00040001000000000000000b200000000000000002696400020000000000000010200000000000000007746578742d76
310003000000000000001520000000000000000c7363616e2d6669787475726500040000000000000001000000000000
0000624000000000000000040001000000000000001620000000000000000d657870697265735f61745f6d7300020000
000000000011200000000000000008696e7436342d763100030000000000000001000004000000000000000911000001
a33c68d40000000000000000624000000000000000040001000000000000001620000000000000000d73746172746564
5f61745f6d7300020000000000000011200000000000000008696e7436342d7631000300000000000000010000040000
00000000000911000001a3185c4c18000000000000006340000000000000000400010000000000000017200000000000
00000e66696e69736865645f61745f6d7300020000000000000011200000000000000008696e7436342d763100030000
000000000001000004000000000000000911000001a3185c5000000400000000000000091000000000000000f3000500
00000000000029210000000000000020edc8d1502fbc7eb3ae2776a241e2798ffed497c75c9d4788de7e6f3c39d6cce3
000000000000017f4000000000000000050001000000000000001820000000000000000f73706163652d6c6564676572
2d76310002000000000000001520000000000000000c7363616e2d66697874757265000300000000000000e530000000
000000000200000000000000624000000000000000040001000000000000000b20000000000000000269640002000000
0000000010200000000000000007746578742d76310003000000000000001520000000000000000c7363616e2d666978
747572650004000000000000000100000000000000006a40000000000000000400010000000000000013200000000000
00000a73657373696f6e5f696400020000000000000010200000000000000007746578742d7631000300000000000000
1520000000000000000c7363616e2d666978747572650004000000000000000100000400000000000000091000000000
000000a900050000000000000029210000000000000020eda271dbe120df713681205a8591352a9b1374cbea8a37dd74
b7efbd5d0b3e120005000000000000004d300000000000000002000000000000001820000000000000000f72656c6576
616e63652e6c61726765000000000000001c20000000000000001372656c6576616e63652e646576656c6f706572
```

### TargetSetV1

encoded-bytes: 201
sha256: 67d25b16ccba49e35619fbfdd2d55f9eeba27aaf121a695c9bb877c9b779aacd
hex:

```text
53544f524e4155542d494e562d43414e4f4e2d310020000000000000002473746f726e6175742e696e76657374696761
74696f6e2e7461726765742d7365742e7631400000000000000002000100000000000000091000000000000000010002
000000000000006130000000000000000100000000000000502000000000000000477461726765742d36396431383662
313266613133323263333466303764613836653461623662653965333730643766373737663065313265613764343130
343966343662333834
```

### InvestigationPlanV1

encoded-bytes: 1553
sha256: 7a929cf4c865c5ccb9f2fd9b314a99c189fcef28267aaf844db8a4efabe9c01b
hex:

```text
53544f524e4155542d494e562d43414e4f4e2d310020000000000000001e73746f726e6175742e696e76657374696761
74696f6e2e706c616e2e763140000000000000000e000100000000000000091000000000000000010002000000000000
001e200000000000000015696e7665737469676174696f6e2d6669787475726500030000000000000015200000000000
00000c7363616e2d666978747572650004000000000000001620000000000000000d73636f70652d6669787475726500
050000000000000029210000000000000020318e1e01fb438c631a72056fa167fe0c94fffe8426adb6b25358e4cd3cfc
d9df0006000000000000001320000000000000000a666f63757365642d7631000700000000000000da40000000000000
000b00010000000000000009100000008bb2c97000000200000000000000091000000000000000040003000000000000
000910000000000000001000040000000000000009100000000000800000000500000000000000091000000000002000
000006000000000000000910000000000010000000070000000000000009100000000000000002000800000000000000
0910000000000000000200090000000000000009100000000000000020000a00000000000000091000000000000186a0
000b00000000000000091000000000000400000008000000000000025b300000000000000001000000000000024a4000
0000000000000d0001000000000000000910000000000000000200020000000000000050200000000000000047746172
6765742d3639643138366231326661313332326333346630376461383665346162366265396533373064376637373766
30653132656137643431303439663436623338340003000000000000001520000000000000000c7363616e2d66697874
7572650004000000000000001620000000000000000d73636f70652d6669787475726500050000000000000022200000
000000000019756e6b6e6f776e2d6c617267652d636f6e73756d65722d76310006000000000000006040000000000000
00040001000000000000001420000000000000000b736e617073686f742d763100020000000000000019200000000000
000010736e617073686f742d666978747572650003000000000000000100000400000000000000010000070000000000
0000523000000000000000020000000000000019200000000000000010726561736f6e2e72756c652d6d697373000000
0000000020200000000000000017726561736f6e2e756e6b6e6f776e2d70726f64756365720008000000000000000910
0000000040000000000900000000000000091000000000000002ee000a0000000000000009100000000000000384000b
00000000000000091000000000000000fa000c000000000000003a400000000000000002000100000000000000142000
0000000000000b6d656173757265642d7631000200000000000000091000000000002a3000000d000000000000000911
00066517289880000009000000000000002921000000000000002067d25b16ccba49e35619fbfdd2d55f9eeba27aaf12
1a695c9bb877c9b779aacd000a0000000000000009110006651728988000000b000000000000000911000665174c5bc6
00000c0000000000000009100000000000000384000d0000000000000009100000000040000000000e00000000000001
3030000000000000000900000000000000112000000000000000087368656c6c2d763100000000000000122000000000
00000009736b696c6c732d7631000000000000001520000000000000000c7375626167656e74732d7631000000000000
001720000000000000000e6469726563742d726561642d7631000000000000001720000000000000000e6c6976652d73
65617263682d7631000000000000001820000000000000000f756e69666965642d657865632d7631000000000000001c
200000000000000013696d6167652d696e7370656374696f6e2d76310000000000000022200000000000000019707562
6c69632d636f6d6d616e642d6e6574776f726b2d7631000000000000002320000000000000001a62726f777365722d6f
722d6469726563742d66657463682d7631
```

<!-- STORNAUT_CANONICAL_VECTORS_END -->
