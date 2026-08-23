# Phase D Task 39B2c L3c3c-ii-b5b-iii-b2a0 Typed Physical Bridge Preflight

> Status: implementation and post-fix validation complete / non-admitting;
> completion commit seal pending
>
> Date: 2026-08-23
>
> Baseline: `7c114e09c915e2685545872101e7c5854ce2cffd`
>
> Scope: package-only invocation/result bridge between the iii-b1 cohort and
> the future Darwin outer/inner adapter; no process launch, descriptor I/O,
> App/helper/XPC, install, sudo/root, model/authentication/network use, product
> admission or authoritative full verifier

## 1. Decision

The frozen iii-b2a path set cannot safely connect the physical outer process to
the existing iii-a/iii-b1 typed state machine. A narrow prerequisite is required
before Darwin implementation. The corrected order is:

```text
iii-b2a0 typed physical bridge
-> iii-b2a Darwin outer/inner physical adapter
-> iii-b2b zero-argument entry and final artifact
-> ii-c0b -> ii-c -> L3c3d -> L3c4
```

Two current interfaces create the conflict:

1. `InvestigationMachineSingleEpochComposition` consumes the opaque predecessor
   but passes only `previousHelperIdentity` to the composer. The canonical
   predecessor transcript and digest required by the outer-to-inner request are
   therefore unavailable at the physical boundary. Reconstructing a second
   continuity chain in the adapter would create two sources of truth.
2. `InvestigationMachineSingleEpochResult` contains opaque in-process ownership
   or local-completion values. Their private proof members intentionally cannot
   be reconstructed from process-provided bytes, while the current outer join
   accepts only that in-process result. A physical proxy therefore has no valid
   value to return after decoding an inner result.

iii-b2a0 adds one canonical, package-closed transport material rather than
weakening the opaque local proofs. It does not implement supervisor framing,
self-spawn, FD 8/9, process identity observation or containment.

## 2. Step 3 TARGETS

The worktree is clean, so this is an explicit `non_diff` scope. The Swift
minimum testable units are:

| Source | Symbol / method target | Reason |
| --- | --- | --- |
| `InvestigationMachineSingleEpochComposition.swift` | `InvestigationMachineSingleEpochComposing.run(invocation:)` | Carry the exact predecessor material while retaining a default adapter for existing in-process composers. |
| `InvestigationMachineSingleEpochComposition.swift` | `InvestigationMachineSingleEpochComposition.run()` | Construct the invocation only from the already consumed predecessor and pass it once. |
| `InvestigationMachineHelperEpochContinuity.swift` | `InvestigationMachineHelperEpochContinuity.genesis/successor/consume` | Retain the exact canonical transcript whose digest already defines continuity, and emit one selection-bound invocation. |
| `InvestigationMachineHelperEpochContinuity.swift` | `InvestigationMachineHelperEpochPredecessor.invocation(for:)` | Issue the retained canonical predecessor material exactly once; physical result admission remains iii-b2a work. |
| new `InvestigationMachineSingleEpochPhysicalBridge.swift` | invocation and physical ownership/completion codecs | Provide strict bounded, canonical, non-`Codable` encode/decode values for the later supervisor protocol. |

`diff_context` is `null`. The scope comes from the approved iii-b0 contract and
the two interface conflicts above, not from a local patch.

## 3. Step 4 BUG_MAP

```json
{
  "BUG_MAP": [
    {
      "defect_type": "Business Gaps",
      "scenario": "[defect-probing] 物理 composer 接收当前 epoch 时必须同时拿到唯一 predecessor 的 canonical transcript 和 digest",
      "description": "现有 composition 只传 previousHelperIdentity，导致跨进程请求无法绑定真正被消费的 continuity",
      "file_path": "Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineSingleEpochComposition.swift",
      "target_func": "InvestigationMachineSingleEpochComposition.run",
      "bug_range": "lines 350-368",
      "evidence": "predecessor.consume(for:) 返回的 continuitySHA256 在当前调用路径被丢弃，composer.run 只收到 optional helper；iii-b0 明确要求 request 携带完整 predecessor transcript，因此 adapter 若自行重建会形成第二条状态链",
      "expect_outcome": "correct outcome: composer receives one immutable selection-bound invocation containing canonical predecessor bytes, digest and previous helper; current wrong outcome: only helper identity crosses the boundary; verification: a capturing physical composer must observe exact bytes and reject replay, foreign selection or digest drift",
      "severity": "P1"
    },
    {
      "defect_type": "Business Gaps",
      "scenario": "[defect-probing] outer 解码 inner 的 canonical completion 后必须能交给既有 outer join 且不能伪造本地 opaque proof",
      "description": "现有 result 只有进程内 opaque cases，跨进程结果无法合法进入 continuity join",
      "file_path": "Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineSingleEpoch.swift",
      "target_func": "InvestigationMachineSingleEpochResult",
      "bug_range": "lines 12-18",
      "evidence": "ownership/local completion 分别保留 private installed-L2、release、retirement 和 driver-observation 值，而 InvestigationMachineCompletionMaterial 仅接受完整 in-process result；outer 无法从 wire 重建这些私有对象，也不能跳过现有 join",
      "expect_outcome": "correct outcome: inner projects a strict canonical physical result DTO, while only the later physical adapter may combine exact request/response bytes with independently observed evidence into an opaque admitted result; current wrong outcome: no representable cross-process result exists; verification: the DTO round-trips but cannot enter the continuity join directly",
      "severity": "P1"
    }
  ]
}
```

Candidate filtering also examined the App `PGID == PID` assumption and immediate
TERM behavior. They are real iii-b2a physical-adapter obligations, but are not
included in this prerequisite BUG_MAP because their responsible methods are not
in the narrowed bridge scope.

## 4. Frozen Typed Contract

### 4.1 Invocation

`InvestigationMachineSingleEpochInvocation` is package-only, `Sendable`,
`Equatable` and non-`Codable`. It contains:

- the canonical predecessor transcript already used to derive continuity;
- its exact SHA-256; and
- the previous complete helper identity for successors, with a distinct genesis
  representation rather than an optional wire field.

The invocation is created only after the existing one-shot predecessor has been
consumed for the exact selection. Decode accepts the exact expected selection,
requires the genesis/successor domain, exact field count/order/length/EOF,
canonical re-encode, transcript hash equality, cohort identity, ordinal
continuity, non-reused epoch identity and complete previous-helper equality.

The composing protocol gains `run(invocation:)`. Its default implementation
forwards only the embedded previous helper to the existing in-process
`run(previousHelperIdentity:)`, preserving all existing fake and Darwin
implementations. The future physical proxy overrides the new requirement.

### 4.2 Physical result

The bridge defines two distinct canonical values:

- physical ownership material for the `parentCrash` transfer path; and
- physical local-completion material for the normal path.

Both bind outer attempt, whole capsule/input, epoch ordinal/UUID/scenario,
projection digest, complete App/helper identities, ownership binding, claim
evidence and installed-L2 proof digests, and the exact deadlines. Normal
completion additionally binds claim-release, driver-observation and local-
completion digests. Distinct transcript domains avoid optional or zero-length
fields. Every digest must be nonzero and local completion must embed the exact
canonical ownership bytes.

The existing in-process result can project this material, but the wire type
cannot reconstruct or expose the private local proof objects. The decoded value
is deliberately an untrusted DTO: it cannot enter
`InvestigationMachineSingleEpochResult`, `InvestigationMachineCompletionMaterial`
or the continuity join. iii-b2a must bind the exact request, ownership
acknowledgement, response bytes, observed child/peer identity, EOF and terminal
evidence before its unique private call site mints an opaque admitted result.

## 5. Exact Scope and Cost

Maximum: eight non-document paths and 2,200 changed lines. Exact planned set:

1. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineSingleEpochComposition.swift`;
2. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineHelperEpochContinuity.swift`;
3. new `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineSingleEpochPhysicalBridge.swift`;
4. new `Tests/StornautInvestigationTests/InvestigationMachineSingleEpochPhysicalBridgeTests.swift`;
5. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
6. `scripts/verify-contract`;
7. `scripts/verify-investigation-boundaries`; and
8. `scripts/verify-app-release-boundaries`.

No existing focused test file, Package/Xcode graph, public driver entry, Darwin
process source or product source changes. If the bridge cannot be completed in
this set, stop and split again before coding.

## 6. RED and Validation Matrix

The single new focused suite must first fail for missing bridge artifacts and
then cover:

- exact genesis and successor invocation round trips;
- default in-process forwarding and physical override receiving the full
  invocation exactly once;
- predecessor replay, foreign selection, wrong ordinal/helper, digest drift,
  truncated/nested-trailing/outer-trailing bytes and noncanonical fields;
- local ownership and local-completion projection followed by strict decode;
- each physical ownership/completion field and digest mutation;
- normal versus parent-crash scenario mismatch;
- decoded physical result cannot enter the outer containment join;
- sender-side concurrent/repeated invocation issuance has exactly one winner;
- receiver-side replay rejection remains an explicit iii-b2a state-machine
  obligation; and
- non-`Codable`, package-only, no path/descriptor/process/write/network/cleanup
  or readiness authority.

Validation order is structural/source/scope, exact focused tests, affected
Investigation tests, the three boundary gates, applicable SwiftPM/Xcode
Debug/Release projections, one clean staged-only serialized SwiftPM regression
and independent semantic/verifier review. This prerequisite does not run
`scripts/verify --full`.

## 7. iii-b2a Contract Clarification

The later iii-b2a physical fixture will prove real Darwin process, FD, EOF,
PGID, direct-child reap and group-containment behavior using disposable same-UID
children. It will not claim that a product NSXPC helper followed its
`connectionInvalidated -> status 71 -> L1 absence` path, because the split also
forbids launching the installed helper or real product XPC. That product-specific
absence proof remains mandatory in ii-c's one privileged no-model machine gate.
No generic fixture result can substitute for it.

## 8. Non-Claims and Next Step

This preflight changes documentation only. It does not launch a process, read FD
0, connect App/helper/XPC, use administrator privileges, read Codex
authentication, call a model, access the network or claim readiness. ADR 0018
remains Proposed, Task 39 remains incomplete and production Deep Dive remains
`.implementationUnavailable`. The next action is the iii-b2a0 RED focused test.

## 9. Implementation Outcome

The prerequisite is implemented in eight non-document paths with 2,198 changed
lines, below the 2,200-line ceiling. Tests-first evidence began with a focused
compile failure for the missing invocation/result bridge. After implementation,
the six top-level focused tests (ten parameterized cases) passed. A later
semantic review exposed an impossible predecessor UUID acceptance window and
then three P1 false-authority/replay/verifier gaps; all were repaired before the
final runs.

The final contract is narrower than the initial sketch: physical result bytes
are an untrusted canonical DTO and cannot enter `InvestigationMachineSingleEpochResult`
or the continuity join. The future iii-b2a adapter must mint a private admitted
result only after binding exact request/response bytes, ownership acknowledgement,
independently observed identities, EOF and terminal evidence. Sender-side
invocation issuance is one-shot and full-selection-bound; receiver-side replay
admission remains iii-b2a work.

Final validation evidence:

- focused bridge/continuity/cohort selection: 36 tests in 3 suites passed;
- affected Investigation selection: 580 tests in 43 suites passed;
- `scripts/verify-contract`: passed, including semantic and scope mutations;
- `scripts/verify-investigation-boundaries`: passed, including exact Debug and
  Release Machine Driver projections;
- `scripts/verify-app-release-boundaries`: passed, including Xcode/App boundary
  checks;
- clean staged-only serial: 1,462 tests in 76 suites passed, 94.420 seconds test
  time and 155.498 seconds for the complete step;
- targeted Xcode Debug diagnostic build: passed in 29.5 seconds; and
- independent semantic, verifier and cross-group post-fix review: no unresolved
  P0-P2 findings.

Coverage collection was skipped: the repository defines no unit-test coverage
threshold for this workflow and the configured `utree` coverage parser does not
support Swift. This does not replace the focused, affected and serialized
regression evidence above.

No authoritative full verifier or authenticated Codex App Server run was
performed. After the immutable completion seal, the next implementation
checkpoint is iii-b2a Darwin outer/inner physical adaptation.
