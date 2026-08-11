# Active Plans

当前获批 executable plan 仍为 Phase C deterministic Epic 8，但按用户要求在
Task 28 后暂停；当前没有 active implementation Task。

Epic 2–4 Tasks 9–26 已完成并归档；最终统一 verifier 单次 exit `0`。
Phase C deterministic Epic 8 的详尽 plan 已于 2026-08-11 获用户批准，见
[`epic-8-safe-execution-vertical-slice.md`](epic-8-safe-execution-vertical-slice.md)。
Tasks 27–28 的 study/ADR、domain v2、Evidence Store v3、crash journal、
code review 与 unified verifier 已完成。下一步先完整回顾更新后的 ADR 0004，
确认后续 Codex 调查应尽可能发挥 direct read、shell/unified exec、live search、
browser/direct fetch、skills/subagents 与公共联网能力，同时继续由 Swift 独占
用户数据写入和 Executor。回顾完成且用户对齐前，不得启动 Task 29。

即使计划获批，正常 App 也必须保持真实 Trash 依赖关闭，直到 Task 35 的
signed-App disposable Trash diagnostic 与最终 gate 通过。Task 32 的 Review
UI 只允许使用 fake/write-disabled coordinator 做产品验收。

Epic 0–1 evidence gate 已完成，历史计划见
[`../completed/epic-0-1-foundation-spikes.md`](../completed/epic-0-1-foundation-spikes.md)；
Epic 2–4 历史计划见
[`../completed/epic-2-4-deterministic-product-core.md`](../completed/epic-2-4-deterministic-product-core.md)；
不得从 completed plan 继续推断新任务。
