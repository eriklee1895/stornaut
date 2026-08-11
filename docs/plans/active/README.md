# Active Plans

当前获批 executable plan 仍为 Phase C deterministic Epic 8，但按用户要求在
Task 28 后暂停。ADR 0004 capability-first 宏观插队顺序已获用户批准；详细
R1–R6 计划见
[`capability-first-codex-runtime-gate.md`](capability-first-codex-runtime-gate.md)，
当前等待用户 review 该详尽计划，尚未启动 R1 或 Task 29。

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
通过。详细计划 review 完成前不得启动 R1；R1–R6 gate 完成前不得启动 Task 29。

即使计划获批，正常 App 也必须保持真实 Trash 依赖关闭，直到 Task 35 的
signed-App disposable Trash diagnostic 与最终 gate 通过。Task 32 的 Review
UI 只允许使用 fake/write-disabled coordinator 做产品验收。

Epic 0–1 evidence gate 已完成，历史计划见
[`../completed/epic-0-1-foundation-spikes.md`](../completed/epic-0-1-foundation-spikes.md)；
Epic 2–4 历史计划见
[`../completed/epic-2-4-deterministic-product-core.md`](../completed/epic-2-4-deterministic-product-core.md)；
不得从 completed plan 继续推断新任务。
