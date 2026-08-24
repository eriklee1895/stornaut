# Phase D Task 39B2c L3c3c-ii-b5b-iii-b2a-i Supervisor Admission Preflight

> Status: complete / non-admitting; post-review closure and immutable seal
> recorded
>
> Date: 2026-08-24
>
> Baseline: `79cc78c5f1169faa0820a6377a0d512e2034b0ef`
>
> Implementation commit: `2f3a116be4644829fc513bcc2287c6bd2a1ea0ec`
>
> Accepted implementation tree: `62994279cc5a262dee3a490d845dc2f32a8fa4b6`
>
> Completion-seal commit: `30ee32e02fd1ce5fe45a55f64f083f9294c85695`
>
> Scope: package-closed canonical outer/inner protocol and opaque physical
> admission seam only; no process spawn, descriptor I/O, App/helper/XPC launch,
> install, sudo/root operation, model/authentication/network use, public driver
> entry, product admission or authoritative full verifier

## 1. Decision and split

The original iii-b2a ten-path maximum is no longer executable as frozen. The
completed iii-b2a0 prerequisite added
`InvestigationMachineSingleEpochPhysicalBridge.swift`, and iii-b2a must now
extend that bridge before any Darwin process adapter can safely consume it. The
current bridge deliberately exposes only an untrusted DTO: it has no receiver-
side replay state, no standalone normal-path ownership message and no legal
conversion into the existing opaque single-epoch result. Adding that source to
the original maximum would require either eleven non-document paths or removal
of a mandatory identity/process/verifier path.

The checkpoint is therefore split before coding:

```text
iii-b2a-i canonical supervisor protocol and opaque admission seam
-> iii-b2a-ii-a Darwin physical session composition
-> iii-b2b zero-argument entry and final artifact
-> ii-c0b -> ii-c -> L3c3d -> L3c4
```

iii-b2a-i is intentionally free of Darwin spawn, descriptor and signal calls.
It makes the wire order, one-shot receiver state and proof boundary testable
without conflating them with physical process lifecycle. iii-b2a-ii-a remains
responsible for supplying independently observed evidence from same-UID
disposable processes.

## 2. Step 3 TARGETS

The worktree is clean, so this is an explicit `non_diff` scope and
`diff_context` is `null`. The Swift minimum testable units are:

| Source | Symbol or method target | Reason |
| --- | --- | --- |
| `InvestigationMachineSingleEpochPhysicalBridge.swift` | standalone physical ownership projection and strict result accessors | Normal ownership must cross the process boundary before release while remaining an untrusted DTO. |
| `InvestigationMachineSingleEpoch.swift` | `InvestigationMachineSingleEpochResult` and fixed-deadline composer execution | The physical path needs an opaque admitted case and must use the outer-created absolute deadline rather than minting an inner deadline. |
| `InvestigationMachineSingleEpochComposition.swift` | result helper extraction | The composition must recognize the opaque admitted physical case without accepting a raw DTO. |
| `InvestigationMachineHelperEpochContinuity.swift` | `InvestigationMachineCompletionMaterial.init` | Only a validated admitted token may supply physical helper, binding and mode to the existing continuity join. |
| new `InvestigationMachineDarwinOuterInnerProtocol.swift` | canonical request/ownership/acknowledgement/decision/result values and one-shot outer admission actor | Freeze exact message bytes, ordering, replay rejection, independent-observation joins and the only admitted-token minting callsite. |

The focused test target is one new Swift Testing suite,
`InvestigationMachineDarwinOuterInnerProtocolTests.swift`. Structural ownership
is additionally pinned by `InvestigationMachineTargetBoundaryTests.swift` and
the three existing boundary verifiers.

## 3. Step 4 BUG_MAP

```json
{
  "BUG_MAP": [
    {
      "defect_type": "Business Gaps",
      "scenario": "[defect-probing] 同一 canonical request、ownership 或 result 被接收端重复提交时必须永久拒绝",
      "description": "当前 physical codec 是无状态解码器，发送端 one-shot 不能阻止接收端重放同一合法字节",
      "file_path": "Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineSingleEpochPhysicalBridge.swift",
      "target_func": "InvestigationMachineSingleEpochInvocation.decode / InvestigationMachineSingleEpochPhysicalResult.decode",
      "bug_range": "lines 73-132 and 293-358",
      "evidence": "两处 decode 对同一 canonical Data 可无限次成功；iii-b2a0 completion audit 明确保留 receiver-side replay rejection 给 iii-b2a，重复物理 epoch 可在没有状态消费的情况下再次进入流程",
      "expect_outcome": "correct outcome: one actor-owned receiver accepts the exact selection-bound message once and every duplicate or reordered call consumes the epoch as terminal uncertainty; current wrong outcome: repeated bytes decode successfully; verification: concurrent/repeated request, ownership and result calls have exactly one winner",
      "severity": "P1"
    },
    {
      "defect_type": "Business Gaps",
      "scenario": "[defect-probing] normal epoch 必须在 helper release 前发送 ownership，再在 continue 后发送 completion",
      "description": "当前 normal physical ownership 只能嵌套在已经完成 release 的 completion DTO 中，无法表达冻结的 ownership-first 顺序",
      "file_path": "Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineSingleEpochPhysicalBridge.swift",
      "target_func": "InvestigationMachineSingleEpochPhysicalResult.init(projecting:)",
      "bug_range": "lines 230-290",
      "evidence": "ownership candidate 在 suspender 时已存在，但 normal scenario 只有 localCompletion 分支可编码，而 localCompletion 要等 claim release、App EXIT 和 local retirement 后才能形成；这与 b0 的 ownership -> acknowledgement -> continue -> release 顺序直接矛盾",
      "expect_outcome": "correct outcome: every scenario has a strict standalone physical ownership projection and normal completion later embeds that exact ownership bytes; current wrong outcome: normal ownership cannot be serialized at the arm point; verification: normal ownership round-trips before completion and completion rejects any different ownership",
      "severity": "P1"
    },
    {
      "defect_type": "Business Gaps",
      "scenario": "[defect-probing] outer 只能在绑定请求、ack、响应、独立身份、EOF 与终止证据后把物理结果交给 continuity join",
      "description": "现有 single-epoch result 只有不可从 wire 重建的本地 opaque cases，而 raw physical DTO 又不能进入 join，跨进程完成路径没有安全表示",
      "file_path": "Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineSingleEpoch.swift",
      "target_func": "InvestigationMachineSingleEpochResult",
      "bug_range": "lines 12-19",
      "evidence": "localCompletion 和 ownershipTransferred 都保留 fileprivate in-process proof；physical DTO 只暴露 helper/mode/binding，直接转换会伪造这些 proof，而不转换则 physical composer 无法满足 run() 返回类型并进入 OuterCompletionJoin",
      "expect_outcome": "correct outcome: a fileprivate-init opaque admitted token is minted at one state-machine callsite only after all exact bindings and external terminal evidence pass, and raw DTO remains inadmissible; current wrong outcome: no legal physical return value exists; verification: valid ordered evidence seals once, raw/replayed/foreign evidence never mints a result",
      "severity": "P1"
    },
    {
      "defect_type": "Business Gaps",
      "scenario": "[defect-probing] inner composer 必须使用 outer request 中已经承诺的绝对 monotonic deadline",
      "description": "当前 composer 总是从 inner 自己的 clock 重新创建 deadline，导致 wire request 与 ownership/result 可能绑定两个不同截止时间",
      "file_path": "Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineSingleEpoch.swift",
      "target_func": "InvestigationMachineSingleEpochComposer.run / execute",
      "bug_range": "lines 196-245",
      "evidence": "execute 无外部 deadline 参数并固定计算 now + 140 seconds；b0 要求 request 携带由 outer 创建的 absolute epoch deadline，ownership candidate 又保存 composer 的 deadline，因此当前跨进程实现会产生第二时钟来源",
      "expect_outcome": "correct outcome: an internal physical execution entry validates and uses the exact outer deadline while legacy in-process run keeps bounded derivation; current wrong outcome: inner silently replaces the committed deadline; verification: injected outer deadline appears unchanged in ownership and expired/over-window deadlines fail before session start",
      "severity": "P1"
    }
  ]
}
```

The direct-App process-group shape, App `PGID == PID` assumption, missing FD
8/9 ABI and immediate group TERM are separately confirmed iii-b2a-ii-a defects.
They are excluded from this BUG_MAP because their responsible Darwin methods
are outside this narrowed checkpoint.

## 4. Frozen protocol and authority boundary

The protocol is package-closed, non-public and non-`Codable`. Every wire value
uses `HandoffBinaryTranscript`, a distinct version-1 domain, exact ordered
fields, fixed length bounds, canonical nested decode/re-encode and exact EOF.

- The request embeds the exact `InvestigationMachineSingleEpochInvocation`, its
  SHA-256, the outer-created absolute monotonic deadline and the internally
  derived `normal` or `parentCrash` mode. It contains no path, descriptor, PID,
  PGID, UID, signal, endpoint, model or cleanup command.
- Standalone physical ownership is available for all eight scenarios and binds
  the exact selection, App/helper identities, claim/L2 proof, release deadline
  and epoch deadline. It remains an untrusted DTO.
- The ownership record binds the request digest, complete self-reported inner
  identity, App PPID/PGID topology and exact physical ownership bytes. The
  outer accepts it only when separately observed inner and App facts equal the
  record and satisfy inner `PID == PGID`, inner direct-child PPID, App
  `PPID == inner PID` and App `PGID == inner PGID`.
- The acknowledgement echoes exact request and ownership digests. The decision
  binds request, ownership and acknowledgement and can only be `continue` for
  normal or `crashNow` for parent crash.
- A normal result embeds the exact physical completion plus all prior message
  digests. A parent crash admits only zero result bytes.
- The actor state is strictly one-shot: request -> ownership -> acknowledgement
  -> decision -> terminal evidence -> one containment proof. Any duplicate,
  replay, wrong order, foreign selection/digest/identity or cancellation makes
  the state terminally uncertain.
- The actor mints the only
  `InvestigationMachineSingleEpochAdmittedPhysicalResult` after exact protocol
  bytes, independent identities, control/result EOF, expected exit class, App
  absence, group reap-last/post-reap emptiness, helper/L1 absence where
  required and unchanged driver observation are joined. Its initializer is
  file-private. A decoded DTO has no conversion API.
- The shared actor is also the injected containment prover. It returns a proof
  only once for the exact admitted result, selection and predecessor digest.
  `InvestigationMachineOuterCompletionJoin` remains the sole continuity mint.

The internal physical composer entry must accept the outer deadline exactly,
require it to be future and no more than the existing 140-second ceiling from
the inner observation point, and use it for bootstrap, claim and ownership. The
legacy in-process `run(previousHelperIdentity:)` behavior remains unchanged.

## 5. Exact scope and cost

Maximum: ten non-document paths and 3,600 changed non-document lines. Exact
planned set:

1. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinOuterInnerProtocol.swift` (new);
2. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineSingleEpochPhysicalBridge.swift`;
3. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineSingleEpoch.swift`;
4. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineSingleEpochComposition.swift`;
5. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineHelperEpochContinuity.swift`;
6. `Tests/StornautInvestigationTests/InvestigationMachineDarwinOuterInnerProtocolTests.swift` (new);
7. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
8. `scripts/verify-contract`;
9. `scripts/verify-investigation-boundaries`; and
10. `scripts/verify-app-release-boundaries`.

No Package/Xcode graph, C shim, second focused test file, Darwin spawn/session/
identity/retirement source, public zero-argument driver, App, helper, Lifecycle,
Core or product source may change. If the implementation needs any such path or
would exceed 3,600 changed non-document lines, stop and split again before that
edit.

## 6. RED and validation matrix

The single focused suite must first fail to compile because the supervisor and
admitted-token symbols do not exist. It must then cover:

- strict request, standalone ownership, acknowledgement, decision and normal
  result round trips plus field/domain/tag/length/order/EOF mutations;
- exact normal and parent-crash mode mapping without a ninth scenario;
- ownership-before-acknowledgement, acknowledgement-before-decision and
  decision-before-terminal ordering;
- concurrent/repeated receiver calls with exactly one winner and permanent
  terminal uncertainty after any invalid transition;
- exact independent inner/App identity and PPID/PGID joins;
- request-bound deadline preservation and expired/over-window rejection;
- normal result plus exact EOF and expected successful inner termination;
- parent crash plus zero result bytes and expected non-success termination;
- missing EOF, wrong exit class, live App, non-empty/reused group, helper/L1
  residue, driver drift and result/containment asymmetry;
- raw DTO cannot enter `InvestigationMachineSingleEpochResult` or continuity;
- admitted result can be consumed only by the same actor/prover and only once;
  and
- non-`Codable`, package/source closure and absence of spawn, descriptor,
  signal, root, XPC, write, network, cleanup or readiness authority.

Validation order is structural/source/scope RED, exact focused tests, affected
Investigation tests, the three boundary gates, applicable Debug/Release symbol
projections, one clean staged-only serialized SwiftPM regression and independent
semantic/verifier/cross-boundary review. This prerequisite does not run
`scripts/verify --full`.

## 7. iii-b2a-ii-a retained work and non-claims

iii-b2a-ii-a exclusively owns fixed-path self-spawn, FD 2/7/8/9 inheritance and
direction checks, collision-safe relocation to `>= 10`, inner/App process
observation, App group inheritance, normal direct-child reap, bounded natural
drain before exact-group TERM/KILL, exit-status observation, reap-last and
post-reap-empty proof. It may use only same-UID disposable fixtures.

This preflight performs no build, test, process launch, FD I/O, App/helper/XPC,
install, sudo/root, Codex authentication, model or network operation. ADR 0018
remains Proposed, Task 39 remains incomplete and production Deep Dive remains
`.implementationUnavailable`. Only ii-c may accept ADR 0018; only L3c4 may
claim readiness and consume Task 39's remaining authoritative full verifier.
