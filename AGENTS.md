# AGENTS.md

Stornaut 是证据驱动的 macOS 开发者磁盘调查与治理工具：Swift 确定性扫描处理已知空间，用户已安装的 Codex 经 Probe Broker 调查未知空间，Swift Policy Gate / Executor 掌握全部写权限。

本文件只保留高频规则与文档路由。文档总入口为 [`docs/README.md`](docs/README.md)，完整实施约束以 [`docs/agent/coding-agent-handoff.md`](docs/agent/coding-agent-handoff.md) 为准。

> 注意：本文件指导的是**实现 Stornaut 的 Coding Agent**。产品内 Deep Dive 启动的 Codex 子进程必须使用隔离配置，**不得**加载本仓库或目标磁盘上的 `AGENTS.md` / 项目指令。

## Always

- 先读 handoff，再按任务读取最小必要文档；不要从 UI 概念图推断规格外功能，也不要把概念图当逐像素终稿。
- 遵守全部产品不变量（见 handoff §3）。尤其：Quick Scan 不调模型；Codex 无写权限；磁盘调查只能走 Probe Broker；Executor 只接受 `MoveToTrash` 或 Registered Action；Trash 失败绝不永久删除；失败保持 `Unknown`。
- Epic 0–1 已完成；Epic 2–4 deterministic active plan 已批准，Task 9 已完成，下一项为 Task 10。逐 Task 完成 Upstream Study、实现、code review、focused/full verify、独立 commit/push；不得把后续 Task 提前混入。
- Spike / safety check 通过前，Deep Dive 必须保持 paused；发现 Codex ≠ 验证安全边界。
- 权限、隔离、许可证、性能主张必须有本机证据（`--help`、测试、Benchmark、ADR）。不确定时先 Spike/ADR，不用大段代码掩盖。
- 保留现有 MIT `LICENSE`；新增依赖前记录许可证与理由。不要复制 Mole GPL 代码。
- 视觉素材可通过 Web 搜索或 `$erik-gpt-image-2` 生成。Web 素材必须记录来源 URL、作者/版权、许可证和允许用途；AI 生成素材必须保留 prompt/metadata，不提交凭据。现有 UI/UX 与品牌概念图由 `$erik-gpt-image-2` 生成，仍只作非逐像素参考。
- 不创建遥测、远程规则服务、MenuBarExtra、后台监控、定时扫描或登录启动项（v1）。
- 目标平台：开发时最新稳定 macOS + Apple Silicon only。
- 模块命名：App/类型用 `Stornaut*`；仓库、CLI、配置前缀用 `stornaut`。
- 开发期 Xcode/App 自动化只使用仓库固定的 XcodeBuildMCP + Peekaboo harness（见 `docs/agent/development-tooling.md`）；UI 验收按 `docs/agent/ui-testing-guide.md`。它们是 Coding Agent 工具，不得链接、复制或暴露给产品内 Deep Dive Codex。
- UI 变更必须形成 `build/test → 启动真实 .app → Peekaboo 截取实际窗口 → 检查截图/AX 结果 → 必要时补 XCUITest` 的闭环；不能只读 SwiftUI 源码就宣称 UI 正确。`scripts/verify` 与 XCUITest 仍是可重复验收真相，Peekaboo 只补充本机运行时视觉证据。
- Peekaboo 默认只能暴露 `image`、`see`、`inspect_ui`、`list`、`permissions`；不得绕过 `scripts/peekaboo-readonly` 或扩大白名单。Screen Recording 可读权限足够时不要求 Accessibility/Event Synthesizing；不得自动申请、授予、重置或引导点击系统权限。
- XcodeBuildMCP 必须从 `.xcodebuildmcp/config.yaml` 读取本项目、scheme、Debug 和 workflow 默认值，并保持 Sentry disabled。MCP 结果不能替代 `scripts/verify`，版本/目录升级先更新 checksum、doctor 与开发文档。
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
| 文档地图与规范优先级 | [docs/README.md](docs/README.md) |
| 任意实现任务的总入口 | [docs/agent/coding-agent-handoff.md](docs/agent/coding-agent-handoff.md) |
| 本地构建与 UI 自动化工具 | [docs/agent/development-tooling.md](docs/agent/development-tooling.md) |
| UI 测试、截图与故障判定 | [docs/agent/ui-testing-guide.md](docs/agent/ui-testing-guide.md) |
| 产品需求与验收 | [docs/product/PRD.md](docs/product/PRD.md) |
| 进程边界、模块、安全架构 | [docs/architecture/system-architecture.md](docs/architecture/system-architecture.md) |
| Agent / 双模式 / 安全基线 | [docs/design/agent-disk-governance.md](docs/design/agent-disk-governance.md) |
| 导航、文案、品牌、Light/Dark | [docs/design/ui-ux.md](docs/design/ui-ux.md) |
| 跨 Epic 交付顺序与 Gate | [docs/plans/roadmap.md](docs/plans/roadmap.md) |
| Epic 2–4 当前计划 | [docs/plans/active/epic-2-4-deterministic-product-core.md](docs/plans/active/epic-2-4-deterministic-product-core.md) |
| Epic 0–1 历史计划与证据 | [docs/plans/completed/epic-0-1-foundation-spikes.md](docs/plans/completed/epic-0-1-foundation-spikes.md) |
| Epic 0–1 最终 Gate | [docs/reports/epic-0-1-validation-report.md](docs/reports/epic-0-1-validation-report.md) |
| Codex discovery/进程/隔离研究 Gate | [docs/upstream-studies/epic-1-codex-runtime.md](docs/upstream-studies/epic-1-codex-runtime.md) |
| 上游学习与许可证边界 | [docs/research/upstream-reference-matrix.md](docs/research/upstream-reference-matrix.md) |
| 竞品与可借鉴点 | [docs/research/competitive-analysis-2026-08-06.md](docs/research/competitive-analysis-2026-08-06.md) |
| 真实清理案例上下文 | [docs/research/case-study-2026-08-06.md](docs/research/case-study-2026-08-06.md) |
| UI 概念图（氛围/构图参考） | [docs/assets/ui-concepts/](docs/assets/ui-concepts/) |
| 品牌概念图 | [docs/assets/brand-concepts/](docs/assets/brand-concepts/) |

规范优先级：用户明确批准的 v1 约束 → PRD 与两份批准规格 → architecture → roadmap 与获批 active plan → 已接受 ADR/report → 研究/案例/视觉概念。

## Current milestone

Epic 0–1 evidence gate 与最终跨模块 code review 已完成；5 个确认缺陷已修复并通过统一验证。deterministic path conditional go，Deep Dive 因 Broker-only 未被技术性证明而 no-go/paused。Epic 2–4 Task 9 已完成，下一项为 Task 10；release signing/notarization 仍未评估。

当前已验证的包布局：

```text
Sources/StornautCore/    领域类型与安全接口
Sources/StornautCodex/   Codex 发现、启动、JSONL/schema
Stornaut.xcodeproj/      原生 macOS App/Test host
StornautApp/             最小原生 .app shell
StornautAppTests/        App contract tests
StornautAppUITests/      Light/Dark、Settings 与截图验收
Tests/                   XCTest / Swift Testing + fixtures
docs/adr/                架构假设证据
docs/upstream-studies/   Reference Study Gate 记录
scripts/verify           本地验收入口
scripts/bootstrap-dev-tools / doctor-dev-tools
                         固定版本 XcodeBuildMCP + Peekaboo 开发 harness
scripts/verify-ui-runtime
                         awake 本机会话的真实 .app 窗口截图 smoke
scripts/check-doc-links  文档本地链接检查
```

App host 拓扑已由 [`docs/upstream-studies/epic-0-foundation.md`](docs/upstream-studies/epic-0-foundation.md) 选定，bundle identifier 已确认为 `com.eriklee.stornaut`；ADR 0001 记录最终 build/signing 证据。

宏观交付顺序以 [`docs/plans/roadmap.md`](docs/plans/roadmap.md) 为准。Epic 编号表示能力归属，不要求严格按数字顺序交付；当前按已批准 active plan 的 Task 9–26 顺序执行。

## Working loop

```text
Upstream Study → Implementation Brief → ADR → Tests/Fixtures first → Implement → Benchmark → Docs/provenance
```

涉及 App/UI 的小迭代，在 `Implement` 与最终验收之间执行实际窗口验证：

```text
Narrow build/test → Launch actual .app → Peekaboo read-only capture/inspect → XCUITest/verify
```

每个完成且验证通过的小迭代都创建独立 commit 并及时 push `origin/main`。不得 push 已知失败、敏感数据或未完成的安全绕过；force-push、release、公证与许可证变更仍先确认。
