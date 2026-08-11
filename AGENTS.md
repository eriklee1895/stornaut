# AGENTS.md

Stornaut 是证据驱动的 macOS 开发者磁盘调查与治理工具：Swift 确定性扫描处理已知空间，用户已安装的 Codex 使用直接只读 Agent 工具、Probe Broker 与公共互联网调查未知空间，Swift Policy Gate / Executor 掌握全部写权限。

本文件只保留高频规则与文档路由。文档总入口为 [`docs/README.md`](docs/README.md)，完整实施约束以 [`docs/agent/coding-agent-handoff.md`](docs/agent/coding-agent-handoff.md) 为准。

> 注意：本文件指导的是**实现 Stornaut 的 Coding Agent**。产品内 Deep Dive 启动的 Codex 子进程必须使用隔离配置，**不得**加载本仓库或目标磁盘上的 `AGENTS.md` / 项目指令。

## Always

- 先读 handoff，再按任务读取最小必要文档；不要从 UI 概念图推断规格外功能，也不要把概念图当逐像素终稿。
- 遵守全部产品不变量（见 handoff §3）。尤其：Quick Scan 不调模型；Codex 可直接读取并使用 shell/unified exec、live search、browser/direct fetch、image、skills/subagents 与公共互联网，但无写权限或清理执行权；Probe Broker 是优先结构化证据源而非唯一接口；Executor 只接受 `MoveToTrash` 或 Registered Action；Trash 失败绝不永久删除；失败保持 `Unknown`。
- Epic 0–1 与 Epic 2–4 Tasks 9–26 已完成；Phase B 最终 unified verifier
  单次 exit 0，计划与 Task 21–26 briefs 已归档；
  Phase C deterministic Epic 8 详尽 plan 已于 2026-08-11 获用户批准，
  Tasks 27–28 已完成并通过 unified verifier。ADR 0004 回顾后，用户已批准在
  Task 29 前插入 capability-first Runtime R1–R6 evidence gate；R1 已完成并
  transport 例外已获批准；R2 已完成并得出 `configurationReady`；R3 已因
  new-session descendant lifecycle escape 得出 `behaviorBlocked/no-go`，
  R4–R6 与 Task 29 均未启动。逐 Task 完成 Upstream Study、
  实现、code review、focused/full verify、独立 commit/push；不得提前混入
  生产 Deep Dive、Adapter、真实 Registered Action 或 release 工作。
- 新的 capability-first runtime/safety check 通过前，Deep Dive 必须保持
  paused；发现 Codex 或 feature flag ≠ 已证明“公共联网 + 完整调查能力 +
  全进程树不可写 + 私网/Unix socket 阻断 + no-Executor”边界。
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
- 先向用户确认：扩大 Codex 本地写入/执行权、开放本机私网或 Unix socket、改产品范围、新增付费/远程服务、force-push、改许可证、发布/公证流程、把未经 runtime gate 的 Deep Dive 从 paused 放开。ADR 0004 已批准的直接只读工具与公共互联网能力不再重复请求授权。
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
| 当前 active plan 状态 | [docs/plans/active/README.md](docs/plans/active/README.md) |
| Capability-first Codex Runtime Gate | [docs/plans/active/capability-first-codex-runtime-gate.md](docs/plans/active/capability-first-codex-runtime-gate.md) |
| R1 Runtime Study / conditional decision | [docs/upstream-studies/epic-5-capability-first-runtime.md](docs/upstream-studies/epic-5-capability-first-runtime.md) / [ADR 0013](docs/adr/0013-capability-first-runtime-containment.md) |
| R3 Runtime lifecycle no-go | [docs/reports/capability-first-runtime-r3-review.md](docs/reports/capability-first-runtime-r3-review.md) |
| Phase C Epic 8 获批计划 | [docs/plans/active/epic-8-safe-execution-vertical-slice.md](docs/plans/active/epic-8-safe-execution-vertical-slice.md) |
| Epic 2–4 历史计划 | [docs/plans/completed/epic-2-4-deterministic-product-core.md](docs/plans/completed/epic-2-4-deterministic-product-core.md) |
| Epic 2–4 最终 Gate | [docs/reports/epic-2-4-validation-report.md](docs/reports/epic-2-4-validation-report.md) |
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

Epic 0–1 与 Epic 2–4 evidence gates 已完成。Phase B 的
domain/persistence、product Quick Scan、Space Ledger、Knowledge/Activity
与 App/UI 产品证据通过最终统一验证。Phase C deterministic Epic 8 plan
已获批准；Tasks 27–28 已完成。ADR 0004 回顾确认当前 `CodexProcess`、
capability report、Investigation Envelope 与 UI copy 仍漂移在旧 Broker-only
模型；用户已批准在 Task 29 前插入 capability-first Runtime R1–R6 gate，
R1 已完成并证明 read-only writes 隔离与 managed proxy 候选；用户已批准
same-investigation parent-owned random-loopback managed proxy 例外；R2 已完成
并得出 `configurationReady`，
允许 Codex descendants 仅连接 same-investigation、父进程拥有、随机端口的
loopback managed proxy；其他 localhost/private/link-local 和所有 Unix sockets
仍须阻断。R3 已证明 direct `setsid()`、`POSIX_SPAWN_SETSID` 与 launchd
job cleanup 均不能保证整个调查进程树回收，结论为
`behaviorBlocked/no-go`；R4–R6 与 Task 29 均未启动。
Deep Dive 的旧 Broker-only no-go 已被 ADR 0004 的 capability-first 边界取代；
当前仍 paused 的原因是新运行时实现/evidence gate 尚未交付，而非 Codex 工具
能力过强。release signing/notarization 仍未评估。Overview、Scan、Scan-only
History 与六区 Settings 已是真实 typed projection/生命周期，Investigations 仍是 placeholder，
Review/Trash 仍未启用。

当前已验证的包布局：

```text
Sources/StornautCore/    领域类型与安全接口
Sources/StornautCodex/   Codex 发现、启动、JSONL/schema
Sources/StornautCore/Settings/
                        closed preferences、bookmark 与 exclusions
Stornaut.xcodeproj/      原生 macOS App/Test host
StornautApp/             最小原生 .app shell
StornautAppTests/        App contract tests
StornautAppUITests/      Light/Dark、Settings 与截图验收
Tests/                   XCTest / Swift Testing + fixtures
docs/adr/                架构假设证据
docs/upstream-studies/   Reference Study Gate 记录
scripts/verify           默认/full 本机验收；--headless 为普通 CI 构建测试入口
scripts/verify-ui-automation-mode
                         完整 verifier 的只读 Automation Mode fail-fast gate
scripts/bootstrap-dev-tools / doctor-dev-tools
                         固定版本 XcodeBuildMCP + Peekaboo 开发 harness
scripts/verify-ui-runtime
                         awake 本机会话的真实 .app 窗口截图 smoke
scripts/check-doc-links  文档本地链接检查
```

App host 拓扑已由 [`docs/upstream-studies/epic-0-foundation.md`](docs/upstream-studies/epic-0-foundation.md) 选定，bundle identifier 已确认为 `com.eriklee.stornaut`；ADR 0001 记录最终 build/signing 证据。

宏观交付顺序以 [`docs/plans/roadmap.md`](docs/plans/roadmap.md) 为准。Epic
编号表示能力归属，不要求严格按数字顺序交付；Phase C 新 plan 必须明确复用
现有 Policy/Trash foundations，并保持所有真实执行能力关闭直到自己的 gate。

## Working loop

```text
Upstream Study → Implementation Brief → ADR → Tests/Fixtures first → Implement → Benchmark → Docs/provenance
```

涉及 App/UI 的小迭代，在 `Implement` 与最终验收之间执行实际窗口验证：

```text
Narrow build/test → Launch actual .app → Peekaboo read-only capture/inspect → XCUITest/verify
```

每个完成且验证通过的小迭代都创建独立 commit 并及时 push `origin/main`。不得 push 已知失败、敏感数据或未完成的安全绕过；force-push、release、公证与许可证变更仍先确认。
