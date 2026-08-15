# Completed Plans

完成 evidence gate 的计划从 `../active/` 移入本目录，保留原始 Task、结果链接和最终状态，作为历史证据而非当前执行指令。

- [Epic 0–1 Foundation & Risk Spikes](epic-0-1-foundation-spikes.md)：已完成；当时的 Broker-only Deep Dive no-go/paused 是历史证据，已由 2026-08-11 修订的 [ADR 0004](../../adr/0004-codex-file-read-isolation.md) 取代。最终阶段证据见 [Epic 0–1 Validation Report](../../reports/epic-0-1-validation-report.md)。
- [Epic 2–4 Deterministic Product Core](epic-2-4-deterministic-product-core.md)：Tasks 9–26 已完成；one-root deterministic Quick Scan、Space Ledger、Knowledge/Activity、Overview/Scan/History/Settings 与 Phase B evidence gate 通过。最终结论见 [Epic 2–4 Validation Report](../../reports/epic-2-4-validation-report.md)。
- [Epic 8 Safe Execution Vertical Slice](epic-8-safe-execution-vertical-slice.md)：Tasks 27–35 与 capability-first Runtime R1–R6 interlock 已完成；唯一 signed-App diagnostic Trash attempt、zero-replay recovery、source-bound receipt、独立审查和 authoritative full verifier 全部通过。最终结论见 [Phase C Validation Report](../../reports/epic-8-safe-execution-validation-report.md)。

Task 21–26 implementation briefs 与 parent plan 一同归档，保留当时的文件
范围、测试优先顺序和证据，不构成后续 Phase 的实现授权。

Phase C 的 Task 27–35 briefs、Runtime R1–R6 plan/briefs 与归档时的
[阶段索引](phase-c-plan-index.md) 同样只作为历史证据。普通 App execution
保持 `writeDisabled`，production Deep Dive 必须等待新的获批 active plan。
