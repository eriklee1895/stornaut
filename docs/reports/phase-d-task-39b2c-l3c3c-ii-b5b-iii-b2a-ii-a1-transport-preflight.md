# Phase D Task 39B2c L3c3c-ii-b5b-iii-b2a-ii-a1 Transport Preflight

> Status: a1-i source/test implementation complete / non-admitting; a1-v
> verifier/inner-role closure current
>
> Date: 2026-08-24
>
> Baseline: `9551c3de274df192b097c7021690dbccec8e976d`
>
> Scope: package-only fixed self-spawn, FD 2/8/9 transport and independently
> observed inner-child identity/PGID foundation. No App/helper/XPC launch,
> installation, sudo/root operation, protocol admission, continuity, public
> zero-argument entry, Codex authentication, model/network operation or
> authoritative full verifier.

## 1. Decision and split

The completed iii-b2a-i supervisor protocol is intentionally free of Darwin
authority. Its successor cannot safely compose physical process creation and
the complete App/helper terminal-evidence flow in one checkpoint. The existing
Darwin App session and identity observer model one directly spawned App that is
its own process-group leader, while the accepted outer/inner topology requires a
disposable driver child to lead the group and the App to inherit that group. The
existing retirement proof is also deliberately opaque and cannot by itself be
expanded into every terminal-evidence Boolean.

Therefore iii-b2a-ii-a is split before coding:

```text
iii-b2a-ii-a1 fixed self-spawn and supervisor transport foundation
-> iii-b2a-ii-a2 App inheritance, protocol and terminal-evidence composition
-> iii-b2b zero-argument entry and final artifact
-> ii-c0b -> ii-c -> L3c3d -> L3c4
```

ii-a1 owns only the first authority surface. It may return an opaque, one-shot
owned transport session and independently observed driver-child identity, but it
cannot construct `InvestigationMachineSingleEpochAdmittedPhysicalResult`,
`InvestigationMachineOuterContainmentProof`, helper continuity, machine
readiness or product admission.

The a1 implementation reached the mandatory 2,300-line review point at three
new source/test files. To preserve the 2,600-line hard ceiling, a1 is itself
closed as two consecutive checkpoints rather than adding verifier code to the
same review surface:

```text
iii-b2a-ii-a1-i self-spawn/transport/identity source and focused tests
-> iii-b2a-ii-a1-v inner-role/source/Mach-O verifier and immutable seal
-> iii-b2a-ii-a2
```

The a1-v closure may add the existing boundary test and three verifier paths.
It also owns the Swift inner-role validator for fixed FD provenance; the a1-i
same-UID physical child is a production-spawn/file-action positive control, not
a substitute for that future production entry validation.

## 2. Step 3 TARGETS

`scope_type` is `non_diff`: baseline and `origin/main` are both the clean commit
above, and the user-authorized next checkpoint has no local business diff.
`diff_context` is `null`.

```json
{
  "scope_type": "non_diff",
  "TARGETS": [
    {
      "file_path": "Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinOuterInnerSession.swift",
      "target_type": "actor",
      "symbol": "InvestigationMachineDarwinOuterInnerSessionFactory / InvestigationMachineDarwinOuterInnerSession",
      "locator": "new package-only source",
      "source": "explicit",
      "reason": "Own fixed self-spawn, descriptor provenance, bounded framing and one-shot endpoint lifecycle without modifying the sealed protocol",
      "hunks": []
    },
    {
      "file_path": "Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinDriverChildObservation.swift",
      "target_type": "struct",
      "symbol": "InvestigationMachineDarwinDriverChildObserver",
      "locator": "new package-only source",
      "source": "explicit",
      "reason": "Produce the canonical driver-child identity only from an independent PID/version/PPID/PGID/audit-token sandwich",
      "hunks": []
    }
  ],
  "diff_context": null
}
```

The generated test target is one new serialized Swift Testing suite:
`Tests/StornautInvestigationTests/InvestigationMachineDarwinOuterInnerSessionTests.swift`.
Existing boundary tests and verifier scripts are validation owners, not extra
business targets.

## 3. Step 4 BUG_MAP

```json
{
  "BUG_MAP": [
    {
      "defect_type": "Business Gaps",
      "scenario": "[defect-probing] outer 必须以固定 installed-driver 路径、单元素 argv、空环境和新 PGID 自启动 disposable inner",
      "description": "当前唯一 Darwin spawn 路径固定启动 App 并只映射 FD 7，无法创建接受的 outer 到 inner driver 拓扑",
      "file_path": "Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinOuterInnerSession.swift",
      "target_func": "InvestigationMachineDarwinOuterInnerSessionFactory.start",
      "bug_range": "absent at baseline; existing incompatible path is InvestigationMachineDarwinEpochSession.swift lines 185-270",
      "evidence": "现有 factory 把 fixed App executable 映射到 FD 7 并要求 spawned App 自己成为 PGID leader；冻结拓扑要求同一 machine driver 成为 outer 的 direct child 和 group leader",
      "expect_outcome": "correct outcome: one fixed-path driver child is atomically spawned with POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT; current wrong outcome: no such production path exists; verification: injected request and same-UID physical child prove exact path-independent primitive shape, argc/env and PID=PGID",
      "severity": "P1"
    },
    {
      "defect_type": "Security",
      "scenario": "[defect-probing] child 只能继承 FD 2、双向 FD 8 和 write-only FD 9，outer endpoints 必须搬移到大于等于 10",
      "description": "当前没有 outer/inner descriptor role contract，复用 FD 7 adapter 会产生错误 alias、方向或泄漏",
      "file_path": "Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinOuterInnerSession.swift",
      "target_func": "InvestigationMachineDarwinOuterInnerSpawnPrimitive.spawn / role validation",
      "bug_range": "absent at baseline",
      "evidence": "现有 spawn primitive 只有一次 adddup2 到 FD 7，没有 FD 2 addinherit、独立 FD 8/9、outer >=10 relocation 或 bounded 0...9 provenance validation",
      "expect_outcome": "correct outcome: collision-safe sources are CLOEXEC, only FD 2/8/9 survive in the inner with exact direction and no aliases; current wrong outcome: topology is unrepresentable; verification: injected collision matrix and real same-UID child inspect every FD 0...31",
      "severity": "P1"
    },
    {
      "defect_type": "Business Gaps",
      "scenario": "[defect-probing] outer 必须从独立双读内核与 audit evidence 绑定 inner PID/version/PPID/PGID/root identity",
      "description": "当前没有 driver-child observer，spawn 返回的 PID 与一次 getpgid 不能证明 canonical child identity",
      "file_path": "Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinDriverChildObservation.swift",
      "target_func": "InvestigationMachineDarwinDriverChildObserver.observe",
      "bug_range": "absent at baseline",
      "evidence": "b2a-i admission requires complete DriverChildIdentity and exact outer PPID/PID=PGID relation；现有 session only checks spawned PID and getpgid once",
      "expect_outcome": "correct outcome: two matching narrow identities and process snapshots bind PID/version/PPID/PGID/ASID/root EUID/audit token before ownership; current wrong outcome: no producer exists; verification: every identity/race mutation fails and a physical same-UID observation proves the syscall path without claiming root",
      "severity": "P1"
    },
    {
      "defect_type": "Resource",
      "scenario": "[defect-probing] supervisor control/result messages 必须有硬上限、精确 framing/EOF，并在失败取消或重复调用后只清理一次",
      "description": "canonical transcript 自身没有可先读的总长度，FD 8 长连接若依赖 EOF 分隔会死锁，且当前没有 owner 管理四端点和 spawned child 的一次性失败清理",
      "file_path": "Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinOuterInnerSession.swift",
      "target_func": "InvestigationMachineDarwinOuterInnerSession framed I/O and closeAndRetire",
      "bug_range": "absent at baseline; HandoffBinaryTranscript.swift lines 135-242 has no outer total-length prefix",
      "evidence": "FD 8 carries multiple request/ownership/ack/decision messages and FD 9 carries one result followed by EOF；without a 4-byte bounded envelope and one-shot owner, partial/trailing data or cancellation cannot be classified without leaks or hangs",
      "expect_outcome": "correct outcome: exact big-endian length framing rejects zero/oversized/truncated/trailing/duplicate data and every failure closes owned descriptors then retires only the validated child once; current wrong outcome: no transport owner exists; verification: deterministic injected I/O failures plus physical EOF/no-residue fixture",
      "severity": "P1"
    }
  ]
}
```

## 4. Frozen physical contract

- The public production entry remains unchanged. The package factory selects the
  fixed installed machine-driver executable internally; it accepts no caller
  path, argv, environment, descriptor number, UID, PGID or signal.
- The outer creates one Unix stream socketpair and one pipe. Every returned
  descriptor is unique, nonnegative and moved to `>= 10` with
  `F_DUPFD_CLOEXEC` before spawn. Originals are closed exactly once.
- `posix_spawn` uses the fixed executable, one-element argv, empty environment,
  `POSIX_SPAWN_SETPGROUP | POSIX_SPAWN_CLOEXEC_DEFAULT`, pgroup zero, two exact
  `dup2` mappings to FD 8/9, explicit FD 2 inheritance and exact source/outer
  endpoint closes. `fork`, `vfork`, `exec*`, `posix_spawnp`, `setsid` and
  `setpgid` remain forbidden.
- FD 8 is a connected duplex Unix stream. FD 9 is a write-only pipe in the
  inner. FD 0/1/7 are closed in the inner and no other FD in `0...9` is open.
  The outer retains only the control peer and result read end at `>= 10`, both
  CLOEXEC.
- Every supervisor message uses an additional four-byte big-endian nonzero
  length envelope. Control payloads are capped at 128 KiB; the terminal result
  is capped at 16 KiB. Reads are exact and deadline-bounded. EOF is observed
  separately; truncation, trailing data and a second result fail closed.
- Driver-child observation reads narrow audit identity and full process snapshot
  twice around validation. The two reads must match exactly and bind the spawned
  PID, outer PID as PPID, PID as PGID, root EUID, nonzero PID version/ASID and all
  eight audit-token words.
- The factory and returned session are one-shot. Before PGID ownership is
  validated, cleanup may target only the positive direct-child PID. Afterwards,
  cleanup delegates only the exact owned PID=PGID and owned descriptors to the
  existing retirement owner. No broad same-UID scan or global signal is allowed.
- The same-UID physical fixture proves Darwin spawn/file-action behavior, FD
  inheritance/direction, PID=PGID/direct-child relation, framing/EOF, direct reap
  and no fixture residue. It does not prove root EUID, installed identity, App or
  helper behavior.

## 5. Exact scope and budget

The original a1 maximum is seven non-document paths and 2,600 changed
non-document lines. The mandatory midpoint split fixes a1-i to exactly the first
three paths below and at most 2,600 lines; the accepted a1-i tree contains
2,588 added non-document lines. a1-v owns only paths 4-7 plus any
strictly necessary package-private inner-role validator in the existing session
source, under its own fresh budget.

1. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinOuterInnerSession.swift` (new);
2. `Sources/StornautInvestigationMachineDriverSupport/InvestigationMachineDarwinDriverChildObservation.swift` (new);
3. `Tests/StornautInvestigationTests/InvestigationMachineDarwinOuterInnerSessionTests.swift` (new);
4. `Tests/StornautInvestigationTests/InvestigationMachineTargetBoundaryTests.swift`;
5. `scripts/verify-contract`;
6. `scripts/verify-investigation-boundaries`; and
7. `scripts/verify-app-release-boundaries`.

Production/test/verifier allocations were planning estimates; the aggregate
2,600-line and path ceilings are hard. a1-i closed its exact three non-document
paths at 2,588 added lines. No existing session, App identity, retirement, protocol,
single-epoch/composition, Package/Xcode graph, tool entry, App/helper/Lifecycle/
Core or product source may change. A C shim, new target, Xcode membership, eighth
non-document path or more than 2,600 changed lines requires another pre-coding
split.

## 6. RED and validation matrix

The single new serialized suite must first fail to compile because the two
target types do not exist. It then covers exactly these top-level behaviors:

1. fixed self-spawn request, one-element argv, empty environment and spawn flags;
2. FD 2/8/9 mapping, directions, aliases, CLOEXEC and `>= 10` relocation;
3. independent child identity sandwich and every PID/version/PPID/PGID/UID/ASID/
   audit-token mismatch;
4. four-byte bounded control framing, fragmentation and deadline behavior;
5. one-result framing plus exact EOF, truncation, trailing and duplicate rejection;
6. one-shot factory/session behavior and exact cleanup ownership before/after
   PGID validation;
7. cancellation and I/O/spawn/observation failures remain terminally uncertain;
8. a disposable same-UID compiled child proves the actual FD map, direct-child
   PID=PGID topology, EOF/reap and zero fixture residue without claiming root.

Validation order is source/scope RED, exact focused suite, adjacent iii-b2a-i +
old FD-7 session + retirement suites, affected Investigation tests,
`scripts/verify-contract`, `scripts/verify-investigation-boundaries`,
`scripts/verify-app-release-boundaries`, applicable Debug/Release Machine Driver
projections, one clean staged-only serialized SwiftPM regression and independent
implementation/verifier/cross-boundary review. No authoritative full is run.

## 7. Non-claims and next step

ii-a1 does not launch the installed App/helper/XPC, change App PGID semantics,
drive the canonical request/ownership/acknowledgement/decision/result exchange,
observe helper/L1 disappearance, mint admitted results or continuity, install,
use sudo/root, call Codex, authenticate, use a model/network or claim readiness.

ii-a2 remains responsible for App inheritance, complete protocol driving and
outer terminal-evidence composition. ADR 0018 remains Proposed; Task 39 remains
incomplete; production Deep Dive remains `.implementationUnavailable`; and only
L3c4 may claim readiness or consume the remaining authoritative full verifier.

The a1-i source/test slice passed its 8-test focused suite (including 21
parameterized identity mutations), the adjacent 59-test / 4-suite Darwin
selection, Debug/Release Machine Driver builds and independent source review
with no unresolved P0-P2. The physical same-UID fixture observed exact FD
2/8/9 shape, direct-child `PID == PGID`, bounded framing and EOF without
claiming the root-only audit identity. The 601-test / 45-suite affected
Investigation selection was intentionally non-green only in the existing
target-boundary source-name/import map (2 assertions); the other 599 tests
passed. a1-v must now add the production inner-
role validator, exact authority/source/Mach-O gates and immutable completion
seal before a1 as a whole can be called complete.
