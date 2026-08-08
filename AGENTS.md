# AGENTS.md

Stornaut 是证据驱动的 macOS 开发者磁盘调查与治理工具：Swift 确定性扫描处理已知空间，用户已安装的 Codex 经 Probe Broker 调查未知空间，Swift Policy Gate / Executor 掌握全部写权限。

本文件只保留高频规则与文档路由。完整实施约束以 [`docs/coding-agent-handoff.md`](docs/coding-agent-handoff.md) 为准。

> 注意：本文件指导的是**实现 Stornaut 的 Coding Agent**。产品内 Deep Dive 启动的 Codex 子进程必须使用隔离配置，**不得**加载本仓库或目标磁盘上的 `AGENTS.md` / 项目指令。

## Always

- 先读 handoff，再按任务读取最小必要文档；不要从 UI 概念图推断规格外功能，也不要把概念图当逐像素终稿。
- 遵守全部产品不变量（见 handoff §3）。尤其：Quick Scan 不调模型；Codex 无写权限；磁盘调查只能走 Probe Broker；Executor 只接受 `MoveToTrash` 或 Registered Action；Trash 失败绝不永久删除；失败保持 `Unknown`。
- 当前实现范围默认是 Epic 0–1。按已批准计划逐 Task 执行；开始每个技术主题前完成 Upstream Study Gate。不得另起替代大计划或提前实现完整产品。
- Spike / safety check 通过前，Deep Dive 必须保持 paused；发现 Codex ≠ 验证安全边界。
- 权限、隔离、许可证、性能主张必须有本机证据（`--help`、测试、Benchmark、ADR）。不确定时先 Spike/ADR，不用大段代码掩盖。
- 保留现有 MIT `LICENSE`；新增依赖前记录许可证与理由。不要复制 Mole GPL 代码。
- 不创建遥测、远程规则服务、MenuBarExtra、后台监控、定时扫描或登录启动项（v1）。
- 目标平台：开发时最新稳定 macOS + Apple Silicon only。
- 模块命名：App/类型用 `Stornaut*`；仓库、CLI、配置前缀用 `stornaut`。
- 推送 GitHub 前若环境存在失效 `GITHUB_TOKEN`，先 `unset GITHUB_TOKEN GH_TOKEN`，以免覆盖 keyring 登录。

## Never build

- Shell 清理脚本的 GUI 包装
- 把扫描结果发给模型生成文案的“AI 标签”
- 允许 Agent 任意 `rm` / Shell / 直接文件系统清理的包装器
- ClearDisk、Mole 或其他上游的简单 Fork
- 在 Swift Scanner 性能未被证明不足前引入 Rust

## Decision Autonomy

- 可逆、低风险工作可主动推进：文档修正建议、测试、fixture、本地 verify、ADR 草稿、计划内 Task。
- 先向用户确认：扩大安全/权限边界、改产品范围、新增付费/远程服务、force-push、改许可证、发布/公证流程、把 Deep Dive 从 paused 放开。
- 设计/PRD/architecture 冲突时先报告并提出精确修正文案，不得自行放宽边界。

## Docs Router

| 任务 | 先读 |
| --- | --- |
| 任意实现任务的总入口 | [docs/coding-agent-handoff.md](docs/coding-agent-handoff.md) |
| 产品需求与验收 | [docs/PRD.md](docs/PRD.md) |
| 进程边界、模块、安全架构 | [docs/architecture.md](docs/architecture.md) |
| Agent / 双模式 / 安全基线 | [docs/superpowers/specs/2026-08-06-stornaut-agent-disk-governance-design.md](docs/superpowers/specs/2026-08-06-stornaut-agent-disk-governance-design.md) |
| 导航、文案、品牌、Light/Dark | [docs/superpowers/specs/2026-08-07-stornaut-ui-ux-design.md](docs/superpowers/specs/2026-08-07-stornaut-ui-ux-design.md) |
| Epic 0–1 逐 Task 执行 | [docs/superpowers/plans/2026-08-07-stornaut-epic-0-1-foundation-spikes.md](docs/superpowers/plans/2026-08-07-stornaut-epic-0-1-foundation-spikes.md) |
| 上游学习与许可证边界 | [docs/upstream-reference-matrix.md](docs/upstream-reference-matrix.md) |
| 竞品与可借鉴点 | [docs/competitive-analysis-2026-08-06.md](docs/competitive-analysis-2026-08-06.md) |
| 真实清理案例上下文 | [docs/case-study-2026-08-06.md](docs/case-study-2026-08-06.md) |
| UI 概念图（氛围/构图参考） | [docs/assets/ui-concepts/](docs/assets/ui-concepts/) |
| 品牌概念图 | [docs/assets/brand-concepts/](docs/assets/brand-concepts/) |

规范优先级：用户明确批准的 v1 约束 → PRD 与两份批准规格 → architecture → Epic 0–1 计划 → 研究/案例/视觉概念。

## Current milestone

Epic 0–1：仓库与验证骨架 + 高风险技术 Spike（Codex 发现/协议/取消、FDA 与读取隔离、Probe Broker 桥接、Swift 扫描 Benchmark、Trash / Registered Action 生命周期）。每项写 ADR；假设不成立则暂停并更新设计。

计划中的包布局（尚未全部落地）：

```text
Sources/StornautApp/     最小原生 shell
Sources/StornautCore/    领域类型与安全接口
Sources/StornautCodex/   Codex 发现、启动、JSONL/schema
Tests/                   XCTest / Swift Testing + fixtures
docs/adr/                架构假设证据
docs/upstream-studies/   Reference Study Gate 记录
scripts/verify           本地验收入口
```

## Working loop

```text
Upstream Study → Implementation Brief → ADR → Tests/Fixtures first → Implement → Benchmark → Docs/provenance
```
