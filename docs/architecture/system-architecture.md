# Stornaut 技术架构

> 版本：2.2
> 状态：与 PRD 2.3 / ADR 0004 capability-first 设计基线同步；runtime foundation `go`，生产 Deep Dive 等待 Phase D Tasks 36–44
> 初版：2026-08-06；最近更新：2026-08-15

配套文档：[PRD](../product/PRD.md)、[Agent 设计规格](../design/agent-disk-governance.md)、[UI/UX 设计规格](../design/ui-ux.md)、[上游参考矩阵](../research/upstream-reference-matrix.md)、[Coding Agent Handoff](../agent/coding-agent-handoff.md)、[Epic 0–1 验证报告](../reports/epic-0-1-validation-report.md)。

## 1. 架构目标

1. 使用原生 SwiftUI/AppKit 获得最佳 macOS 权限、Trash、单窗口交互和分发体验。
2. 快速扫描完全确定性化，不依赖模型或外部清理工具。
3. Codex 作为深度调查指挥官，自主使用完整只读 Agent 工具与公共互联网，但不拥有写入或清理执行权限。
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
│          │ direct read +   │       │ Mole/kondo/brew/docker │    │
│          │ shell/web/agent │       └────────────────────────┘    │
│          └─────────────────┘                                     │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

关键边界：

- Swift App 掌握确定性扫描、规则、权限、Policy 和所有写/清理操作。
- Codex 可直接读取授权扫描范围，使用 shell/unified exec、live search、
  browser/direct fetch、image、skills/subagents、公共互联网和 Probe Broker；
  所有这些工具共享外层不可写、no-Executor 边界。
- 外部工具是可选探针，不是核心依赖，也不能直接清理。
- Executor 不接受自然语言或任意 Shell，只接受已验证的类型化动作。

## 3. 进程与权限边界

### 3.1 Stornaut 主进程

职责：

- SwiftUI/AppKit UI
- Full Disk Access 检测与用户引导
- Surveyor 确定性读取和所有磁盘写入
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
- 目标目录的 `AGENTS.md`/项目指令只作为调查数据读取，不加载为 Agent
  指令；不继承会产生外部副作用的用户 Hooks/Apps。
- 显式启用 shell/unified exec、`web_search = "live"` high context、
  browser/direct fetch、image inspection 与运行时支持的 skills/subagents。
- 命令、子进程与 browser/direct fetch 可访问公共互联网，不设置
  Bash/executable/public destination-domain allowlist 或逐命令批准；cached/indexed search
  只能作为显式 degraded coverage。
- stdout 仅按 JSONL 解析；stderr 单独收集并限制大小。
- 支持取消、超时、进程树终止和异常退出恢复。
- 使用 `posix_spawn` 原子创建独立进程组；`POSIX_SPAWN_CLOEXEC_DEFAULT`
  默认关闭未显式映射的描述符，避免与 Registered Action 并发 spawn 时
  互相继承 pipe。
- 最终输出必须通过 JSON Schema；失败保持 `Unknown` disposition。

### 3.3 Capability-first 隔离技术 Gate

ADR 0004 明确把读取/联网能力与写入/执行权分开。实施前必须验证：

1. Codex 子进程继承哪些 Stornaut FDA/TCC 读取权限，并如实展示覆盖率。
2. Codex、Shell 子进程、skills/subagents 与调查 Adapter 能直接读取授权
   扫描范围，但不能创建、修改、移动、重命名或删除用户数据。
3. built-in search 确实运行在 live/high-context 模式，公共命令网络与
   browser/direct fetch 可用，且没有 public destination-domain allowlist。
4. localhost、link-local/private network 与任意 Unix socket 保持隔离。
5. Codex 输出、命令与工具调用均不存在直达 Trash、Registered Action、
   Policy Gate bypass 或 Executor 的路径。

`--sandbox read-only` 单独不是完整结论。R1–R6 已通过外层 OS containment、
signed-App identity、完整工具观察、adversarial denial、no-Executor 与零残留
证据，runtime foundation 结论为 `go`。不得使用 `danger-full-access`，也不得
通过关闭 shell/browser/search/skills 伪造后续 gate。生产 Deep Dive 仍保持
unavailable，唯一原因是 Phase D Tasks 36–44 产品流程尚未完成并通过 Task 44
admission；runtime receipt 或 Codex discovery 不能单独启用它。

## 4. 模块设计

### 4.1 App Shell

- v1 是按需启动的单窗口 App；不创建 `MenuBarExtra`，不注册后台监控、定时任务或登录启动项
- 主窗口四个 workspace：Overview、Scan、Investigations、History
- Review 和 Cleanup Result 作为工作流页面，不进入顶层 Sidebar
- Settings 使用独立 macOS Settings scene，分为 General、Scanning、Permissions、Codex & Deep Dive、Privacy & Data、Local Knowledge；语言为 `English (default) | zh-Hans`，外观为 `System (default) | Light | Dark`
- Settings 将可编辑偏好、实时状态/修复入口和只读安全策略分开；清理 protected-path policy、Policy Gate、固定数据生命周期和 Agent 写/执行边界不提供绕过开关
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

编译阶段把 YAML 转为内部不可变结构并校验：重复 ID、非法 glob、覆盖清理 protected-path policy、未知动作和缺少 provenance 都应失败。

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

应用另设结构化 `LocalKnowledgeStore`，保存用户确认的 producer 映射、路径范围偏好、保留决定和已验证恢复方式。持久化数据只位于应用拥有的 Application Support 目录；Caches 只保存可丢弃衍生物，不创建 `~/.stornaut` workspace。它不能保存原始读取片段、自由文本 Agent 记忆，也不能降低清理 protected-path policy、veto 或 Policy Gate。

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

Codex 根据候选、预算和已有证据，自主选择直接只读文件/元数据调查、shell
命令、live web、browser/direct fetch、受支持的 Agent 能力或 Broker 类型化
Probe。Codex 最终只返回 versioned `InvestigationAdvisoryReport`：模型回显
Swift 提供的 investigation/run/target/candidate IDs，不能提供路径、动作、
authorization、Policy、Trash 或 Executor 字段。Swift 绑定身份、规范化并将
可信结构化结果写入 Evidence Store，再把压缩状态提供给 Codex；直接工具结果
始终作为不受 Broker 审计保证的 advisory evidence 标记来源。未来 coordinator
必须从 retained IDs 重新查找路径并执行 canonicalization/current identity/
Policy，才能形成确定性 CleanupPlan。

### 4.7 Probe Broker

Broker 是 Agent 获取稳定、类型化、可预算磁盘证据的优先策略层，不是 Agent
与磁盘之间的唯一接口。

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
5. Broker 自身的敏感路径、限字节与内容策略检查
6. 单次和会话预算检查
7. 执行、限时、限输出
8. 脱敏与证据落盘

禁止将 Agent 输出拼接到 Shell。需要外部进程时，Adapter 使用固定 executable 和参数数组。

### 4.8 内容读取策略

- 首次启用 Deep Dive 时一次性披露模型上下文、直接读取和公共联网的数据边界。
- 在用户选择的扫描范围内，Codex 可自主读取理解未知目录所需的文件类型和片段；不做逐文件/逐命令授权，也不设置 Agent 读取路径 denylist。
- Codex 不主动采集凭据或绕过 TCC；偶然遇到的 secret value 不进入持久化证据、Local Knowledge 或报告。
- Probe Broker 仍对自己的调用执行路径策略、限字节、脱敏和审计，但这些控制不伪装成 Codex 全工具面的限制。
- direct/shell/web/browser 证据记录来源和覆盖率摘要，不持久化原始内容或原始 Codex JSONL。

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

- 清理 protected-path policy 永远拒绝
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
Codex → Files/Shell/Web/Browser: direct read-only investigation
Codex ↔ Probe Broker: optional typed read-only requests
Probe Broker/Normalizer → Evidence Store: typed evidence + source labels
Evidence Store → Codex: compressed updated state
Codex → App: versioned advisory report with Swift-bound IDs
App → Swift Coordinator: lookup IDs, canonicalize, revalidate, build CleanupPlan
Swift Coordinator → Policy Gate: validate
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

- path canonicalization、symlink、mount、清理 protected-path policy
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
│   ├── StornautCodex/
│       ├── Runtime/
│       ├── Protocol/
│       ├── Schemas/
│       └── ProbeBridge/     # source path of separate host-side target
│   ├── StornautProcessSupport/
│   ├── StornautLifecycle/
│   └── CLifecycleSupport/
├── Rules/
├── Tests/
│   ├── Fixtures/
│   ├── GoldenOutputs/
│   ├── Safety/
│   └── Benchmarks/
└── ThirdPartyNotices/
```

Swift Package Manager 的当前安全边界为：

```text
StornautCodex → StornautProcessSupport
StornautCore → StornautProcessSupport
StornautProbeBridge → StornautCodex + StornautCore
StornautProcessSupport → no target dependency
```

`StornautCodex` 不得直接或间接依赖 Executor-bearing `StornautCore`。
`StornautProbeBridge` 是 host-side typed bridge target，不是 Codex child 的
通用 IPC/cleanup endpoint。已接受的 Epic 0 Upstream Study 选择 checked-in
`Stornaut.xcodeproj` 作为真实 App/Test host，并通过 local package products
接入所需库。最终 bundle identifier 与本地签名证据由 Task 2/ADR 0001 固化。
规则、Policy 和 Probe 必须在不启动 GUI 时可测试。不要在 v1 为形式上的
“微服务”拆多进程；Codex 隔离和获批的 lifecycle supervisor/XPC 技术边界除外。

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
