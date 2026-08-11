# Stornaut Documentation

本文档树是人类开发者和 Coding Agent 的共同知识入口。不要从文件名、概念图或旧研究结论自行推断产品行为；先按任务路由读取最小必要文档。

## Start Here

| 目的 | 入口 |
| --- | --- |
| 接手实现、确认硬约束 | [Coding Agent Handoff](agent/coding-agent-handoff.md) |
| 本地构建、运行与 UI 自动化 | [Development Automation](agent/development-tooling.md) |
| UI 测试、截图契约与排障 | [UI Testing Guide](agent/ui-testing-guide.md) |
| 当前开发自动化验证证据 | [Development Automation Validation](reports/development-automation-2026-08-09.md) |
| Epic 0–1 evidence gate | [Epic 0–1 Validation Report](reports/epic-0-1-validation-report.md) |
| Epic 2–4 gate evidence（Passed） | [Epic 2–4 Validation Report](reports/epic-2-4-validation-report.md) |
| Epic 1 最终代码审查 | [Epic 1 Final Code Review](reports/epic-1-code-review-2026-08-09.md) |
| Epic 2–4 Task 11 persistence review | [Task 11 Code Review](reports/epic-2-4-task-11-review.md) |
| Epic 2–4 Task 12 Quick Scan lifecycle review | [Task 12 Code Review](reports/epic-2-4-task-12-review.md) |
| Epic 2–4 Task 13 Space Ledger review | [Task 13 Code Review](reports/epic-2-4-task-13-review.md) |
| Epic 2–4 Task 14 Rule Compiler review | [Task 14 Code Review](reports/epic-2-4-task-14-review.md) |
| Epic 2–4 Task 15 Protected Catalog review | [Task 15 Code Review](reports/epic-2-4-task-15-review.md) |
| Epic 2–4 Task 16 Project Artifact review | [Task 16 Code Review](reports/epic-2-4-task-16-review.md) |
| Epic 2–4 Task 17 Package Cache review | [Task 17 Code Review](reports/epic-2-4-task-17-review.md) |
| Epic 2–4 Task 18 Complete Catalog review | [Task 18 Code Review](reports/epic-2-4-task-18-review.md) |
| Epic 2–4 Task 19 Activity/Knowledge review | [Task 19 Code Review](reports/epic-2-4-task-19-review.md) |
| Epic 2–4 Task 21 App state/fixtures review | [Task 21 Code Review](reports/epic-2-4-task-21-review.md) |
| Epic 2–4 Task 22 Snapshot-first Overview review | [Task 22 Code Review](reports/epic-2-4-task-22-review.md) |
| Epic 2–4 Task 23 Quick Scan UI review | [Task 23 Code Review](reports/epic-2-4-task-23-review.md) |
| Epic 2–4 Task 24 Scan-only History review | [Task 24 Code Review](reports/epic-2-4-task-24-review.md) |
| Epic 2–4 Task 25 Phase B Settings review | [Task 25 Code Review](reports/epic-2-4-task-25-review.md) |
| Epic 2–4 Task 26 Phase B gate review | [Task 26 Code Review](reports/epic-2-4-task-26-review.md) |
| 产品范围、术语、验收 | [PRD](product/PRD.md) |
| 进程边界、模块与安全架构 | [System Architecture](architecture/system-architecture.md) |
| Agent、双模式与治理设计 | [Agent Disk Governance](design/agent-disk-governance.md) |
| UI、品牌、状态与交互 | [UI/UX](design/ui-ux.md) |
| 宏观交付顺序与阶段 Gate | [Delivery Roadmap](plans/roadmap.md) |
| 当前计划状态 | [Active Plans](plans/active/README.md) — 当前无获批 executable plan |
| Phase C Epic 8 Proposed plan | [Safe Execution Vertical Slice](plans/active/epic-8-safe-execution-vertical-slice.md) — 仅供 review，批准前不得实施 |
| Epic 2–4 历史计划 | [Deterministic Product Core](plans/completed/epic-2-4-deterministic-product-core.md) — Tasks 9–26 已完成并归档 |
| 已完成计划 | [Completed Plans](plans/completed/README.md) — Epic 0–1 |
| 上游学习与许可证门禁 | [Upstream Reference Matrix](research/upstream-reference-matrix.md) |
| 当前 Codex Runtime 研究 Gate | [Epic 1 Codex Runtime Study](upstream-studies/epic-1-codex-runtime.md) |
| 当前 Swift Surveyor 研究 Gate | [Epic 1 Swift Surveyor Study](upstream-studies/epic-1-surveyor.md) |
| 当前 Trash / Registered Actions 研究 Gate | [Epic 1 Actions Study](upstream-studies/epic-1-actions.md) |
| Codex discovery/capability 决策 | [ADR 0002](adr/0002-codex-discovery-and-capabilities.md) |
| Codex structured process 决策 | [ADR 0003](adr/0003-codex-process-protocol.md) |
| Probe Broker 与 Codex 隔离决策 | [ADR 0004](adr/0004-codex-file-read-isolation.md) |
| Swift Surveyor 性能决策 | [ADR 0005](adr/0005-swift-surveyor-performance.md) |
| Trash 与 Registered Action 决策 | [ADR 0006](adr/0006-trash-and-registered-actions.md) |
| 领域持久化决策 | [ADR 0007](adr/0007-domain-persistence-boundary.md) — Accepted，Task 11 verified |

任意实现任务默认读取顺序：

1. 本索引；
2. [Coding Agent Handoff](agent/coding-agent-handoff.md)；
3. 与任务直接相关的一份规范；
4. 涉及跨 Epic 顺序或 gate 时读取 [Delivery Roadmap](plans/roadmap.md)；
5. 当前 active plan 中对应 Task；
6. 对应 upstream study、ADR、report 或 fixture。

不要为了“了解全部背景”每次重读整个 `docs/`。研究和概念资产只在任务需要时读取。
涉及 App/UI 运行时验证时，读取 [Development Automation](agent/development-tooling.md) 和 [UI Testing Guide](agent/ui-testing-guide.md)；其中的 MCP 只属于 Coding Agent，不属于产品 Deep Dive。

## Structure

| 目录 | 角色 | 内容规则 |
| --- | --- | --- |
| [`product/`](product/) | 产品规范 | 稳定产品范围、术语、需求与验收；改变范围需用户批准 |
| [`architecture/`](architecture/) | 技术架构 | 进程边界、模块责任、安全不变量与数据流 |
| [`design/`](design/) | 已批准设计 | Agent 治理、UI/UX、品牌和交互规范 |
| [`plans/`](plans/) | 路线图与可执行计划 | `roadmap.md` 管阶段；`active/` 管当前 Task；完成后移入 `completed/` |
| [`agent/`](agent/) | Coding Agent 路由 | handoff、工作循环和最小阅读入口 |
| [`research/`](research/) | 研究与时间切片 | 案例、竞品、上游矩阵；不能覆盖规范 |
| [`upstream-studies/`](upstream-studies/) | 实施前研究证据 | 每个 Epic/技术主题的 Reference Study Gate |
| [`adr/`](adr/) | 架构决策记录 | 测量、取舍、决定和后果；文件一经接受不重写历史 |
| [`reports/`](reports/) | 验证与里程碑证据 | Benchmark、release gate、审计与阶段报告 |
| [`assets/`](assets/) | 视觉研究资产 | 概念稿、prompt 和 canonical 参考；不是像素或运行时数据规范 |

## Authority

发生冲突时按以下顺序处理：

1. 用户明确批准的最新 v1 约束；
2. [`product/PRD.md`](product/PRD.md) 与 [`design/`](design/) 中已批准规格；
3. [`architecture/system-architecture.md`](architecture/system-architecture.md)；
4. [`plans/roadmap.md`](plans/roadmap.md) 与 [`plans/active/`](plans/active/) 中当前计划；
5. 已接受 ADR 和当前机器测量证据；
6. upstream studies、research、案例和视觉概念。

历史研究中的命令、旧术语和当时判断仅作证据上下文。它们不是当前执行授权，也不能绕过 Policy Gate、denylist 或 Executor。

## Lifecycle

- **Normative docs**：使用稳定文件名，不在文件名中携带日期；正文顶部记录版本、状态和最近更新时间。
- **Research/reports**：保留日期，因为它们是事实时间切片。
- **Plans**：新计划先进入 `plans/active/`；完成后移动到 `plans/completed/`，不继续把完成计划当当前指令。
- **ADRs**：采用 `NNNN-short-title.md`；状态至少为 Proposed、Accepted、Superseded 或 Rejected。
- **Upstream studies**：在对应实现前创建，记录 URL、commit/version、license、阅读文件、复用边界和 Benchmark。
- **Assets**：Markdown 说明与图片同目录；生产实现不得硬编码生成图中的示例路径、数字或状态。

## Change Rules

- 修改产品范围、安全边界、权限、隐私、默认选择或 Executor 能力前，先提出精确变更并取得用户批准。
- 测量事实与规范冲突时，先写 ADR/report；不得静默降低规范。
- 新增第三方依赖或复制代码前，先记录许可证、commit、attribution 和必要性。
- 移动或重命名文档时，同一变更必须更新 `AGENTS.md`、根 `README.md`、本索引及所有相对链接。
- 文档修改后至少运行 `scripts/check-doc-links` 和 `git diff --check`。
