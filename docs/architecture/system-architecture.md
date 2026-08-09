# Stornaut 技术架构

> 版本：2.2  
> 状态：与 PRD 2.3 设计基线同步  
> 初版：2026-08-06；最近更新：2026-08-08

配套文档：[PRD](../product/PRD.md)、[Agent 设计规格](../design/agent-disk-governance.md)、[UI/UX 设计规格](../design/ui-ux.md)、[上游参考矩阵](../research/upstream-reference-matrix.md)、[Coding Agent Handoff](../agent/coding-agent-handoff.md)。

## 1. 架构目标

1. 使用原生 SwiftUI/AppKit 获得最佳 macOS 权限、Trash、单窗口交互和分发体验。
2. 快速扫描完全确定性化，不依赖模型或外部清理工具。
3. Codex 作为深度调查指挥官，自主选择只读探针，但不拥有写权限。
4. 所有证据、授权和执行通过类型化接口，可审计、可测试、可降级。
5. 系统化借鉴上游经验，同时保持许可证边界和核心独立性。

架构约束：v1 只验收开发时最新稳定版 macOS 与 Apple Silicon；项目采用 MIT License。具体 OS、Xcode、Swift 和 Codex 版本是 Spike 证据，不是永久产品常量。

## 2. 系统上下文

```text
┌──────────────────────────── macOS ─────────────────────────────┐
│                                                                │
│  ┌────────────────── Stornaut.app ─────────────────────────┐  │
│  │ SwiftUI / AppKit                                         │  │
│  │ Surveyor · Knowledge Base · Evidence Store               │  │
│  │ Probe Broker · Policy Gate · Action Registry · Executor  │  │
│  └───────────────┬──────────────────────┬────────────────────┘  │
│                  │ JSONL / JSON Schema  │ typed read-only calls │
│          ┌───────▼────────┐       ┌─────▼──────────────────┐    │
│          │ Codex subprocess│       │ Optional Adapters      │    │
│          │ investigation   │       │ Mole/kondo/brew/docker │    │
│          └─────────────────┘       └────────────────────────┘    │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

关键边界：

- Swift App 掌握磁盘扫描、规则、权限、证据、Policy 和所有写操作。
- Codex 只接收调查上下文并调用受控只读工具。
- 外部工具是可选探针，不是核心依赖，也不能直接清理。
- Executor 不接受自然语言或任意 Shell，只接受已验证的类型化动作。

## 3. 进程与权限边界

### 3.1 Stornaut 主进程

职责：

- SwiftUI/AppKit UI
- Full Disk Access 检测与用户引导
- Surveyor 和所有磁盘读写
- Probe Broker 与内容过滤
- Evidence Store、Policy Gate 和 Executor

主进程是唯一允许执行清理动作的组件。

### 3.2 Codex 子进程

使用用户已安装的 Codex。启动参数能力以运行时探测为准，目标配置包括：

```text
codex exec
  --ephemeral
  --json
  --output-schema <schema>
  --sandbox read-only
  --skip-git-repo-check
  -C <isolated-investigation-workspace>
```

要求：

- 复用用户认证，但使用 Stornaut 生成的隔离配置。
- 不默认加载目标目录的 `AGENTS.md`、项目指令、Hooks 或无关插件。
- stdout 仅按 JSONL 解析；stderr 单独收集并限制大小。
- 支持取消、超时、进程树终止和异常退出恢复。
- 最终输出必须通过 JSON Schema；失败保持 `Unknown` disposition。

### 3.3 隔离技术 Spike

`--sandbox read-only` 只能证明禁止写入，不能在未经验证时声称禁止读取所有敏感路径。实施前必须验证：

1. Codex 子进程是否继承 Stornaut 的 FDA/TCC 权限。
2. 是否能把 Codex 的直接文件访问限制在临时工作区。
3. 是否可以只通过本地 MCP/Probe Broker 提供目标磁盘证据。
4. 子进程、Shell 子进程和 Adapter 是否都受同一限制。

`--sandbox read-only` 只限制写入，仍可能允许模型生成 Shell 和直接读取，因此不能单独证明 Broker-only。若无法技术性限制 Codex 只暴露受控本地 Probe Broker 工具面，Deep Dive 必须暂停；先记录测量结果与可选设计，再由用户明确批准任何边界变化。不得用提示词或 UI 披露替代尚未实现的安全边界。

## 4. 模块设计

### 4.1 App Shell

- v1 是按需启动的单窗口 App；不创建 `MenuBarExtra`，不注册后台监控、定时任务或登录启动项
- 主窗口四个 workspace：Overview、Scan、Investigations、History
- Review 和 Cleanup Result 作为工作流页面，不进入顶层 Sidebar
- Settings 使用独立 macOS Settings scene，分为 General、Scanning、Permissions、Codex & Deep Dive、Privacy & Data、Local Knowledge；语言为 `English (default) | zh-Hans`，外观为 `System (default) | Light | Dark`
- Settings 将可编辑偏好、实时状态/修复入口和只读安全策略分开；denylist、Policy Gate、固定数据生命周期和 Agent 权限边界不提供绕过开关
- Inspector 承载 Evidence 和 Investigation Details；主视图默认不展示 chat、console 或原始 JSONL
- SwiftUI 为主；系统能力不足处桥接 AppKit
- UI 只消费 ViewModel/领域状态，不直接启动扫描、Codex 或 Executor

所有导航、状态、文案、品牌、Light/Dark、本地化、accessibility 和 motion 约束见 [UI/UX 设计规格](../design/ui-ux.md)。

### 4.2 Surveyor

纯 Swift/Foundation/POSIX 的只读扫描引擎。

输入：

```swift
struct ScanRequest {
    let roots: [URL]
    let exclusions: [PathRule]
    let crossVolume: Bool
    let collectGit: Bool
    let collectSpotlight: Bool
}
```

输出：

```swift
struct PathSnapshot: Codable, Sendable {
    let id: SnapshotID
    let url: URL
    let logicalBytes: UInt64
    let allocatedBytes: UInt64?
    let modifiedAt: Date?
    let fileIdentity: FileIdentity?
    let kind: PathKind
    let symlinkTarget: URL?
    let permissions: MeasurementStatus
    let activity: ActivitySignals
}
```

实现原则：

- 首选原生枚举和批量 metadata API；外部 `du/find` 只作可选校验探针。
- 并发按根目录和 I/O 预算控制，避免无界 Task。
- 默认不跟随 symlink；跨卷需要显式策略。
- 扫描事件增量写入临时 store，避免大树常驻内存。
- 支持取消和部分结果。

### 4.3 Knowledge Base

由版本化规则包和用户 overlay 组成。

规范处置类型与 UI 一致；风险与置信度使用独立字段，不能复用 disposition：

```swift
enum ReclaimDisposition: String, Codable, Sendable {
    case readyToReclaim
    case reviewRecommended
    case protected
    case unknown
}
```

建议规则 Schema：

```yaml
id: python-venv
match:
  basename: [.venv, venv]
  kind: directory
producer: Python environment
disposition: reviewRecommended
conditions:
  staleDays: 60
  requireProjectManifest: true
veto: false
rebuild:
  methods: ["uv sync", "pip install -r requirements.txt"]
  cost: medium
action:
  type: moveToTrash
provenance:
  sources:
    - url: https://github.com/example/project
      commit: abc123
      license: MIT
  independentlyVerified: true
  verifiedAt: 2026-08-06
```

编译阶段把 YAML 转为内部不可变结构并校验：重复 ID、非法 glob、覆盖 denylist、未知动作和缺少 provenance 都应失败。

### 4.4 Staleness 与 Activity

信号包括：

- Git last commit、dirty、untracked、ahead/remote
- 目录和相关源码 mtime
- Spotlight last used
- IDE/App 是否打开
- 进程 open files
- Stornaut 自身历史动作造成的 mtime 污染

`readyToReclaim` 不能仅由时间阈值产生。活动信号冲突时取更保守结果，并保留每个原始信号。

### 4.5 Evidence Store

建议使用 SQLite 保存一次扫描/调查会话：

- `scan_sessions`
- `path_snapshots`
- `classifications`
- `evidence`
- `probe_calls`
- `investigation_targets`
- `cleanup_plans`
- `action_results`

证据记录：

```swift
struct EvidenceRecord: Codable, Sendable {
    let targetID: SnapshotID
    let kind: EvidenceKind
    let source: EvidenceSource
    let summary: String
    let observedAt: Date
    let freshness: EvidenceFreshness
    let supports: HypothesisID?
    let contradicts: HypothesisID?
}
```

Store 保存事实和可展示摘要，不保存模型隐藏思维链。

默认 TTL：`scan_sessions`、snapshot、classification/disposition、evidence、probe call、investigation target、CleanupPlan 和报告保留 7 天并支持立即手动删除；受控读取片段只存在内存。原始 Codex JSONL 正常结束即删除，崩溃残留最长 24 小时。90 天 Cleanup Manifest 只保留 Action ID、Policy disposition、计量、结果和错误，不保留 Evidence payload、probe 记录或内容派生摘要。

应用另设结构化 `LocalKnowledgeStore`，保存用户确认的 producer 映射、路径范围偏好、保留决定和已验证恢复方式。持久化数据只位于应用拥有的 Application Support 目录；Caches 只保存可丢弃衍生物，不创建 `~/.stornaut` workspace。它不能保存原始受控读取片段、自由文本 Agent 记忆，也不能降低 denylist、veto 或 Policy Gate。

### 4.6 Investigation Planner

Swift 先从 Quick Scan 结果构造候选集合：

- 大体积规则 miss
- `df` 与可测量目录总和的差额
- 风险/分类冲突
- 生产者未知
- 规则已过期或证据不足

候选优先级：

```text
expectedBytes × uncertainty × userRelevance / estimatedProbeCost
```

Codex 根据候选、预算和已有证据，通过受控本地桥接返回下一批类型化 Probe 请求。每轮后 Swift 更新 Evidence Store，再把压缩后的状态提供给 Codex。Codex 不直接启动内置探针、Adapter、Shell 或文件系统工具。

### 4.7 Probe Broker

Broker 是 Agent 与磁盘之间的策略执行层。

```swift
protocol ReadOnlyProbe: Sendable {
    associatedtype Input: Codable & Sendable
    associatedtype Output: Codable & Sendable
    static var capability: ProbeCapability { get }
    func run(_ input: Input, context: ProbeContext) async throws -> Output
}
```

每次调用依次执行：

1. Schema 解码
2. canonical path 解析
3. root scope 检查
4. symlink/mount 检查
5. denylist 与读取等级检查
6. 单次和会话预算检查
7. 执行、限时、限输出
8. 脱敏与证据落盘

禁止将 Agent 输出拼接到 Shell。需要外部进程时，Adapter 使用固定 executable 和参数数组。

### 4.8 内容读取策略

- L0 元数据自动允许。
- L1 仅允许审核过的文件类型和最大字节；读取前运行 secret/path policy，输出再脱敏。
- L2 把多个目标聚合成一次 UI 授权，权限仅在当前 investigation session 有效。
- 永久 denylist 在 v1 无例外。
- 任何内容读取都记录目标、字节数和用途摘要。

### 4.9 Adapters

```swift
protocol ToolAdapter: Sendable {
    var id: String { get }
    func detect() async -> AdapterAvailability
    func capabilities() -> Set<ProbeCapability>
    func run(_ request: AdapterRequest) async throws -> AdapterResult
}
```

首批 Adapter：

- Mole read-only analysis
- kondo artifact discovery
- Homebrew cache/cellar inspection
- Docker system `df` 类只读信息
- macOS `diskutil`/`df`/`mdls`/`lsof`

每个 Adapter 需要 golden output fixture，防止上游格式变化导致错误解析。

### 4.10 Policy Gate

Policy Gate 是纯函数式判定核心，输入 CleanupPlan、最新 PathSnapshot、规则和用户授权，输出允许/拒绝及原因。

关键不变量：

- denylist 永远拒绝
- rule veto 永远优先于 Agent
- 规则 miss 且只有 Agent 建议时保持 `reviewRecommended`；只有规则支持、Policy 允许且默认 MoveToTrash 的项目才可为 `readyToReclaim`
- inode/mtime/size/activity 变化导致计划失效
- symlink、根目录、HOME、卷根和系统路径拒绝
- Registered Action 必须有 Action Registry 中的 `RegisteredActionDefinition`
- 不完整证据不能默认通过

### 4.11 Action Registry 与 Executor

```swift
enum CleanupAction: Codable, Sendable {
    case moveToTrash(PathAction)
    case runRegisteredAction(RegisteredActionRequest)
}
```

`RegisteredActionDefinition` 固定声明：

- executable
- 参数模板和允许的变量
- 风险等级
- preflight/dry-run/execute/postflight
- 是否可撤销
- App/进程前置条件
- 超时和输出限制

Executor 顺序：preflight → 用户最终确认 → revalidate → execute → measure → manifest。Trash 失败不得降级为 `rm`。

### 4.12 Space Accounting

统一账本区分：

- logical candidate bytes
- allocated candidate bytes
- executor processed bytes
- trashed bytes
- permanent action bytes
- free-space delta
- unexplained delta
- unmeasurable bytes

所有数值带采样时间和来源。`free-space delta` 只能作为系统观测，不自动归因给某个动作。

## 5. 两种模式的时序

### 5.1 Quick Scan

```text
User → App: Start Quick Scan
App → Surveyor: scan roots
Surveyor → Evidence Store: snapshots
App → Knowledge Base: classify snapshots
App → Activity: enrich risky candidates
App → UI: stream categorized results
```

### 5.2 Deep Dive

```text
User → App: Start Deep Dive
App → Evidence Store: load Quick Scan snapshot
App → Planner: build targets and budgets
App → Codex: investigation context
Codex → Probe Broker: typed read-only request
Probe Broker → Evidence Store: audited evidence
Evidence Store → Codex: compressed updated state
Codex → App: EvidenceReport + CleanupPlan
App → Policy Gate: validate
Policy Gate → UI: approved/rejected items and reasons
```

### 5.3 Execution

```text
User → UI: approve selected actions
UI → Policy Gate: final revalidation
Policy Gate → Executor: typed approved actions
Executor → Trash/Registered Action: execute
Executor → Space Accounting: remeasure
Executor → Manifest: append results
```

## 6. 错误处理

- 错误类型化：permission、timeout、cancelled、stale evidence、schema、adapter、execution。
- 部分失败不丢失已完成扫描和证据。
- 所有失败都有用户可理解的下一步，不展示未经处理的 Agent 文本。
- Agent 或 Adapter 异常永远不能把 `Unknown` 变为 `Ready to Reclaim`。
- 进程取消必须终止子进程树并关闭 pipes，避免孤儿进程继续扫描。
- UI 消费类型化恢复状态，而不是原始错误字符串：`limited(scope)`、`blocked(reason)`、`partial(completed, unresolved)`、`stale(affected)`、`failed(operation)`、`expired(recordPart)` 与 `corrupt(recordID)`。
- 恢复 reducer 必须保留仍有效的 snapshot/evidence/manifest，只有依赖失败证据的结论与动作失效；任何局部失败都不能清空整个页面状态。
- stale execution preflight 只能产生 refresh/cancel transition，不能产生 bypass transition。Safety check 阻断不能进入 investigation started 状态。
- Manifest 写入失败与 Cleanup Action 失败是两个独立事件；前者不得伪装成正常完成。Linked Evidence expiry 不级联删除仍在保留期内的最小 Manifest。
- 视觉与交互契约见 [Resilience States](../assets/ui-concepts/RESILIENCE-STATES-ROUND-1.md)。

## 7. 性能与资源预算

| 操作 | v1 目标 |
|---|---|
| 460GB Quick Scan | < 5 分钟 |
| 规则匹配 | 不成为扫描瓶颈 |
| 首屏结果 | 扫描开始后持续流式出现 |
| Deep Dive | 用户可配置 10/30/60 分钟预算 |
| 安全文本读取 | 单文件和会话双重字节上限 |
| Adapter | 各自超时，不阻塞整体报告 |
| 内存 | PathSnapshot 分页/持久化，不保留完整目录树对象图 |

## 8. 测试架构

### 单元测试

- path canonicalization、symlink、mount、denylist
- rule compiler 和 overlay
- staleness/activity 融合
- priority 和停止条件
- Policy Gate 不变量
- Action Registry 参数模板

### 集成测试

- 临时目录树 Quick Scan
- fake Codex JSONL 和 Schema 错误
- fake Probe Broker 调用和预算
- fake Adapter golden outputs
- Trash 和 registered action dry-run
- 执行前路径变化

### 安全测试

- Prompt injection 位于 README/目录名
- Agent 请求读取 `.env`/SSH/浏览器 Profile
- Agent 提交原始 Shell 或未注册动作
- symlink 指向 HOME/卷根/敏感区
- Agent 建议 Ready to Reclaim 与规则 veto 冲突

### 真实 Benchmark

- 匿名化复现 2026-08-06 案例
- 与 Mole、ClearDisk、kondo 的覆盖和性能对照
- 清理前后四种空间口径
- Codex 不可用和 Adapter 全部缺失模式

## 9. 逻辑模块与物理布局

```text
stornaut/
├── README.md
├── docs/
├── Stornaut.xcodeproj/
├── StornautApp/
│   ├── AppShell/
│   ├── Overview/
│   ├── Scan/
│   ├── Investigations/
│   ├── Review/
│   ├── History/
│   ├── DesignSystem/
│   └── Settings/
├── StornautAppTests/
├── StornautAppUITests/
├── Sources/
│   ├── StornautCore/
│   │   ├── Surveyor/
│   │   ├── KnowledgeBase/
│   │   ├── Activity/
│   │   ├── Evidence/
│   │   ├── LocalKnowledge/
│   │   ├── Investigation/
│   │   ├── ProbeBroker/
│   │   ├── Adapters/
│   │   ├── Policy/
│   │   ├── Actions/
│   │   └── Accounting/
│   └── StornautCodex/
│       ├── Runtime/
│       ├── Protocol/
│       └── Schemas/
├── Rules/
├── Tests/
│   ├── Fixtures/
│   ├── GoldenOutputs/
│   ├── Safety/
│   └── Benchmarks/
└── ThirdPartyNotices/
```

`StornautCore` 与 `StornautCodex` 使用 Swift Package Manager；已接受的 Epic 0 Upstream Study 选择 checked-in `Stornaut.xcodeproj` 作为真实 App/Test host，并通过 local package products 接入两个库。最终 bundle identifier 与本地签名证据由 Task 2/ADR 0001 固化。规则、Policy 和 Probe 必须在不启动 GUI 时可测试。不要在 v1 为形式上的“微服务”拆多进程；Codex 隔离和必要的 XPC 技术 Spike 除外。

## 10. 实施前技术 Spike

在构建完整 UI 前必须完成：

1. Swift 扫描 460GB 机器的性能和取消行为。
2. GUI App 定位并调用用户已安装 Codex。
3. Codex JSONL、Schema、超时和进程树取消。
4. Codex 子进程与 FDA/文件读取隔离。
5. Probe Broker 的本地 MCP 或等价协议可行性。
6. `FileManager.trashItem` 在跨卷、权限不足和大目录上的行为。
7. 至少一个 Registered Action 的 preflight/dry-run/execute/postflight。

Spike 结果必须写 ADR；如果关键隔离不可实现，应先调整 PRD 安全声明，而不是继续堆 UI。
