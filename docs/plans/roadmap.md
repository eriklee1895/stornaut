# Stornaut Delivery Roadmap

> 状态：用户已批准
> 批准日期：2026-08-09
> 目的：定义 v1 的宏观交付顺序、阶段依赖和 go/no-go gate；具体文件、测试和命令由 [`active/`](active/) 中的实施计划负责。

## 1. Roadmap 规则

- Epic 编号表示长期能力归属，不表示必须严格按数字顺序交付。
- 每个阶段优先形成可运行、可验证的纵向切片，不长期堆积无法验收的基础设施。
- 安全、权限、隔离、性能和许可证主张必须由 ADR、测试、Benchmark 或本机证据支持。
- Quick Scan 与确定性安全执行链不依赖 Codex、Adapter 或 Deep Dive 成功。
- Deep Dive 是条件交付能力。ADR 0004 capability-first runtime gate 必须证明完整只读 Agent 工具与公共联网可用，同时进程树不可写且无 Executor 路径；旧 Broker-only 前提已废止。
- 任何 no-go 都可以作为成功的风险验证结果结束当前 Spike；不得为了维持原计划而降低产品不变量。
- 本 Roadmap 不取代 PRD、设计规格、architecture 或 active plan。

## 2. 宏观交付顺序

```text
Foundation & Risk Gates
→ Deterministic Product Core
→ Safe Execution Vertical Slice
→ Conditional Deep Dive
→ Adapters & Registered Actions
→ Product Completion & Release Readiness
```

对应 Epic：

```text
Epic 0–1
→ Epic 2–4
→ Epic 8 deterministic subset
→ Epic 5–6, only after the Deep Dive gate
→ Epic 7 + remaining Epic 8
→ Epic 9
```

## 3. 阶段与 Gate

### Phase A — Foundation & Risk Gates

**范围：** Epic 0–1。

**目标：**

- 建立真实、可本地签名的 macOS `.app` host 和可测试 Swift 模块；
- 验证 Codex 发现、结构化协议、取消与进程树终止；
- 测量 Broker-only 工具面、直接读取和 FDA/TCC 继承，并为后续用户边界决策提供证据；
- 验证 Swift Surveyor 性能、取消和部分结果；
- 验证 Trash 与 fake Registered Action 生命周期。

**退出证据：**

- ADR 0001–0006；
- 可重复的本地验证入口；
- Epic 0–1 validation report；
- Deep Dive gate 为 `go`、`conditional go` 或 `no-go`，不得保持模糊。

**历史分支（已由 ADR 0004 修订）：**

- Broker-only 通过：允许后续进入生产级 Epic 5–6。
- Broker-only 未通过：Deep Dive 继续 paused；可以继续确定性产品阶段，但不得声称完整 v1 已满足，也不得静默修改 Agent 权限边界。

2026-08-11 用户明确选择 capability-first：接受 direct read/model/public
internet 的保密风险，不再要求 Broker-only；当前 gate 改为强调查能力可用且
Codex 进程树不可写、no-Executor。

### Phase B — Deterministic Product Core

**范围：** Epic 2–4。

**目标：**

- 建立 Snapshot、Classification、Evidence、CleanupPlan、PolicyDecision、Manifest 和 Accounting 领域模型；
- 建立 SQLite schema、migration、TTL 与本地数据边界；
- 实现不调用模型的 Quick Scan、取消、流式部分结果和真实空间账本；
- 建立 Knowledge Base、provenance、overlay、Activity 与清理 protected-path policy/veto；
- 形成无 Codex、无 Adapter 也可独立使用的扫描产品。

**退出证据：**

- 匿名 fixture 和安全回归测试；
- 真实机器 Quick Scan Benchmark；
- Known、Unknown、Unmeasurable 与 Free 可解释；
- Quick Scan 不产生任何写操作，也不调用 Codex。

### Phase C — Safe Execution Vertical Slice

**范围：** 提前交付 Epic 8 的确定性部分。

**目标：**

- 从 Quick Scan 结果形成 Review Reclaim Plan；
- 实现纯函数式 Policy Gate、执行前重验证和 stale plan 阻断；
- 实现默认 `MoveToTrash`、immutable Cleanup Manifest 和结果计量；
- 打通 `Quick Scan → Review → Policy Gate → Trash → Cleanup Result → History`。

**退出证据：**

- 只有规则和 Policy 都支持的 Trash 项目默认选中；
- Protected/Unknown 不可执行；
- Trash 失败不回退永久删除；
- candidate、processed、Trash、permanent、free-space delta 不混算；
- 一条完整的确定性端到端安全闭环可以在没有 Codex 时运行。

**为什么提前：**

- 它是 Quick Scan 与 Deep Dive 共用的安全基础；
- Deep Dive runtime gate 未完成时产品仍有完整、可用的确定性价值；
- 后续 Agent 只能接入已经成熟的 CleanupPlan/Policy/Executor 契约。

### Phase D — Conditional Deep Dive

**范围：** Epic 5–6；仅在 ADR 0004 capability-first runtime gate 允许时进入。

**目标：**

- 将 Codex Runtime、完整只读 Agent 工具、公共联网和 Probe Broker Spike 收敛为生产实现；
- 实现 Candidate Planner、科学调查状态机、预算和停止条件；
- 生成 Evidence Report 与不可执行 CleanupPlan；
- 实现首次 capability/data disclosure、partial report 和 Investigation Details。

**退出证据：**

- shell/unified exec、live high-context search、browser/direct fetch、image、skills/subagents 与公共互联网均可用，无 Bash/executable/public destination-domain allowlist；
- Codex 与所有后代进程不可写、不可访问 localhost/私网/任意 Unix socket，且无 Trash/Policy bypass/Executor 路径；
- prompt injection、Schema 错误、预算耗尽和取消均 fail closed；
- Agent-only rule miss 最高为 `Review Recommended`；
- Deep Dive 输出复用 Phase C 的 Policy Gate 和 Executor，不创建第二条执行路径。

**No-go 分支：**

若“完整调查能力 + 公共联网 + 不可写/no-Executor”组合仍不能成立，继续推进确定性产品并研究外层 App Sandbox/XPC/seatbelt 方案；不得以 `danger-full-access` 或关闭调查工具绕过 gate。

### Phase E — Adapters & Registered Actions

**范围：** Epic 7 + Epic 8 剩余部分。

**目标：**

- 增加 macOS、Mole、kondo、Homebrew、Docker 等只读 Adapter；
- 增加经过审核的真实 Registered Actions；
- 为每个外部能力建立版本、许可证、固定参数、golden fixture 和降级路径。

**退出证据：**

- Adapter 缺失或解析失败只影响局部证据；
- 核心扫描、安全和 Trash 不依赖外部工具；
- 永久 Registered Action 独立确认，不能与普通 Trash 合并执行；
- Agent 不能提供 executable 或任意参数。

### Phase F — Product Completion & Release Readiness

**范围：** Epic 9，以及各阶段未完成的批准 UI、accessibility、本地化和分发工作。

**目标：**

- 完成批准的 Onboarding、Overview、Scan、Investigations、Review、Cleanup Result、History 与 Settings；
- 完成 English/`zh-Hans`、Light/Dark、VoiceOver、键盘与 Reduce Motion；
- 完成真实案例复现、跨状态恢复和空间归因；
- 完成 Developer ID、notarization、FDA 指引、隐私、安全和贡献文档。

**退出证据：**

- PRD v1 验收项全部有测试、Benchmark、人工验证或明确 waiver；
- `false Ready-to-Reclaim = 0`；
- 无遥测、远程规则服务、后台监控或未批准写路径；
- 第三方许可证、NOTICE 和 provenance 完整。

## 4. Gate 依赖

| Gate | 必须阻塞什么 | 不阻塞什么 |
| --- | --- | --- |
| App host identity | App-context FDA/TCC、签名和分发结论 | Core/Codex 库测试 |
| Swift Surveyor performance | 完整 Quick Scan 架构定型 | 领域模型与 fixture |
| Capability-first Codex containment | 生产级 Deep Dive | Quick Scan、Policy、Trash、History |
| Policy/Executor safety | 任何真实清理能力 | 只读扫描与调查 |
| License/provenance | 第三方代码、依赖、规则或 Adapter 合入 | 独立 fixture/Spike |
| Release readiness | 公共 release、签名和公证 | 本地开发迭代 |

## 5. 迭代与 Git 契约

- 每轮迭代只处理一个可说明、可验证的目标。
- 完成后运行该目标的 focused checks，再运行当前统一验证入口。
- 不把已知失败、私密数据、原始 Codex JSONL 或本机敏感路径提交到仓库。
- 每个完成的小迭代创建独立 commit，并及时 push 到 `origin/main`。
- Commit message 必须包含仓库要求的 TRAE co-author trailer。
- push 前若存在失效 `GITHUB_TOKEN`/`GH_TOKEN`，清除环境变量并使用 keyring/SSH 登录。
- force-push、历史重写、release、notarization、修改许可证和触发外部发布流程仍需用户单独确认。
- 若某轮只得到 no-go 证据，提交测试、ADR 和报告，不提交绕过安全边界的替代实现。

## 6. 当前状态

- 当前阶段：Phase A 与 Phase B evidence gates 已完成。Epic 2–4 Tasks
  9–26 通过最终统一 verifier 并归档至
  [`completed/`](completed/epic-2-4-deterministic-product-core.md)。
- Phase C deterministic Epic 8 safe-execution 详尽 plan 已于 2026-08-11
  获用户批准；Tasks 27–28 已完成。当前按用户要求暂停，先回顾 ADR 0004，
  Task 29 尚未启动。
- Epic 0 Foundation Upstream Study：已完成，选择 checked-in Xcode App/Test host + local Swift packages。
- Epic 0 Task 1：SwiftPM Core/Codex、smoke tests、`scripts/verify`、manual-only CI 与 ThirdPartyNotices 骨架已完成。
- Bundle identifier：已确认 `com.eriklee.stornaut`。
- Epic 0 Task 2：原生 App/Test/UI Test host、Sidebar 左下 Settings、Light/Dark/Settings 窗口截图、本地签名、LaunchServices 和 bundle 审计已完成；见 ADR 0001。
- 开发自动化：仓库固定的 XcodeBuildMCP `2.7.0`、Peekaboo `3.10.0` 五工具只读 MCP、UI Testing Guide 与真实 App PID 窗口截图 smoke 已完成；见 [Development Automation Validation](../reports/development-automation-2026-08-09.md)。
- Epic 1 Codex Runtime Upstream Study Gate：已完成；历史研究确认 installed `0.147.0` 的 process flags 与 Broker-only 不可证明，后由 ADR 0004 接受 direct read 与公共联网并改用 capability-first gate；见 [study](../upstream-studies/epic-1-codex-runtime.md)。
- Epic 1 Task 3：无 shell Codex discovery、bounded process seam、evidence-bearing capability report、generated fixtures 与 installed no-model diagnostic 已完成；所有 behavior/isolation verdict 仍为 unverified，见 [ADR 0002](../adr/0002-codex-discovery-and-capabilities.md)。
- Epic 1 Task 4：固定参数 structured process、bounded JSONL、Swift final-envelope validation、原子 process-group 与 timeout/cancellation descendant cleanup 已完成；真实 `0.147.0` static-envelope probe 通过；当时的 Broker-only/read isolation 结论是历史证据，不是当前能力限制，见 [ADR 0003](../adr/0003-codex-process-protocol.md)。
- Epic 1 Task 5：四个 bounded read-only Probe、canonical path/immutable denylist、budget/redacted audit、fake Codex typed Bridge 与 signed App-context canary 已完成；历史结论为 protocol-only/no-go。ADR 0004 已在 2026-08-11 修订为 capability-first，Deep Dive 现在因新实现/evidence gate 未交付而 paused。
- Epic 1 Task 6：bounded Swift/POSIX Surveyor、no-follow/same-device、logical/allocated bytes、partial errors、synthetic/real benchmark 已完成；460GiB-class root 中位约 96.2s、peak RSS <28MB、producer cancellation <1ms，继续 Swift、不评估 Rust，见 [ADR 0005](../adr/0005-swift-surveyor-performance.md)。
- Epic 1 Task 7：identity/activity revalidation、Foundation Trash、无 permanent-delete fallback、fixed fake Registered Action、process-group timeout 与真实 CLI/APFS Trash probes 已完成；App-context FDA/TCC 仍为 residual risk，见 [ADR 0006](../adr/0006-trash-and-registered-actions.md)。
- Epic 1 Task 8：六项 spike evidence gate 与约束审计已完成；报告中的 Deep Dive no-go/paused 是当时 Broker-only 口径，已由 ADR 0004 修订；历史证据见 [Epic 0–1 Validation Report](../reports/epic-0-1-validation-report.md)。
- Epic 1 最终 code review：denylist、secret redaction、signed device identity、bounded directory probes、Registered Action descendant cleanup 等 5 个确认缺陷已修复，统一验证通过，见 [review report](../reports/epic-1-code-review-2026-08-09.md)。
- Phase B Task 9：四份 Upstream Study、SQLite feasibility、ADR 0007 与
  code review 已完成；两项 P1 设计问题已修复。
- Phase B Task 10：domain contracts、anonymous fixtures、Surveyor transport
  migration、code review 与 139-test unified verifier 已完成。
- Phase B Tasks 11–25：SQLite/retention、production Surveyor、Space Ledger、
  67-rule Knowledge catalog、Activity/Local Knowledge、deterministic
  orchestration、Overview、Scan、History 与 Settings 已完成逐 Task gate。
- Phase B Task 26：最终源码 product path 在 3,107,607-entry Home 范围内
  247.24 秒完成，peak RSS 73,220,096 bytes，132 个 permission gaps 保持
  Partial/Unmeasurable；Codex marker absent。完整结论见
  [Epic 2–4 Validation Report](../reports/epic-2-4-validation-report.md)。
- 下一项对齐：回顾更新后的 capability-first ADR 0004，确认个人工具应尽可能
  发挥 Codex direct read、shell/unified exec、live search、browser/direct
  fetch、skills/subagents 与公共联网能力，同时保持 Swift-only 用户数据写入
  和 Executor 边界。完成回顾前不启动 Phase C Task 29。
