# Active Plans

当前获批 executable plan 仍为 Phase C deterministic Epic 8，但按用户要求在
Task 28 后暂停。ADR 0004 capability-first 宏观插队顺序已获用户批准；详细
R1–R6 计划见
[`capability-first-codex-runtime-gate.md`](capability-first-codex-runtime-gate.md)，
详尽计划已获批准。R1 study/ADR/probe/review 已完成，结论为
`conditional-go`；R2 与 Task 29 均未启动。

Epic 2–4 Tasks 9–26 已完成并归档；最终统一 verifier 单次 exit `0`。
Phase C deterministic Epic 8 的详尽 plan 已于 2026-08-11 获用户批准，见
[`epic-8-safe-execution-vertical-slice.md`](epic-8-safe-execution-vertical-slice.md)。
Tasks 27–28 的 study/ADR、domain v2、Evidence Store v3、crash journal、
code review 与 unified verifier 已完成。ADR 0004 回顾确认现有
`CodexProcess`、capability report、Investigation Envelope 和 UI copy 仍漂移在
旧 Broker-only 模型。获批的新顺序为：

```text
Task 28 complete
→ R1–R6 capability-first runtime evidence gate
→ resume deterministic Task 29–35
→ production Deep Dive still requires its Phase D implementation plan
```

R1–R6 必须证明 direct read、shell/unified exec、live search、browser/direct
fetch、image、skills/subagents 与公共联网可用，同时 Codex 全进程树不可写用户
数据、不可访问 localhost/私网/任意 Unix socket 且无 Executor 路径。不得用
`danger-full-access`、关闭调查能力、命令/公共域名 allowlist 或逐命令审批制造
通过。R1 已完成；ADR 0013 pending decision 前不得启动 R2，R1–R6 gate
完成前不得启动 Task 29。

R1 证明 read-only Seatbelt 能阻断 user-data writes，且 Codex experimental
managed proxy 能让公网请求成功并阻断 direct bypass、任意
localhost/private/link-local 目标与 Unix socket。但是该机制必须允许 Codex
descendants 连接到**同一调查会话、父进程拥有、随机端口**的一个 loopback
proxy listener。当前产品边界字面上拒绝全部 localhost，因此
[ADR 0013](../../adr/0013-capability-first-runtime-containment.md) 保持
Proposed，等待用户明确批准或拒绝这个唯一的内部 transport 例外：

```text
只允许连接 same-session managed proxy；
其他 localhost/private/link-local 和所有 Unix sockets 继续 OS-blocked。
```

批准后才可启动 R2；若拒绝，当前 Codex `0.147.0` candidate 为 no-go。
R2 的 tests-first implementation brief 已预先收敛在
[`task-r2-implementation-brief.md`](task-r2-implementation-brief.md)，但它只
是 decision-support 文档，不构成实现授权。

即使计划获批，正常 App 也必须保持真实 Trash 依赖关闭，直到 Task 35 的
signed-App disposable Trash diagnostic 与最终 gate 通过。Task 32 的 Review
UI 只允许使用 fake/write-disabled coordinator 做产品验收。

Epic 0–1 evidence gate 已完成，历史计划见
[`../completed/epic-0-1-foundation-spikes.md`](../completed/epic-0-1-foundation-spikes.md)；
Epic 2–4 历史计划见
[`../completed/epic-2-4-deterministic-product-core.md`](../completed/epic-2-4-deterministic-product-core.md)；
不得从 completed plan 继续推断新任务。
