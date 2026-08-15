# Stornaut 产品需求文档

> 版本：2.3
> 状态：设计基线已批准；capability-first Runtime R1–R6 foundation `go`，生产 Deep Dive 等待 Phase D Tasks 36–44 与 Task 44 admission
> 初版日期：2026-08-06
> 最近更新：2026-08-15
> 产品策略：个人自用优先，GitHub Public 开源，不以付费独立产品为目标

配套文档：

- [真实案例](../research/case-study-2026-08-06.md)
- [竞品与开源生态报告](../research/competitive-analysis-2026-08-06.md)
- [技术架构](../architecture/system-architecture.md)
- [上游参考矩阵](../research/upstream-reference-matrix.md)
- [Coding Agent Handoff](../agent/coding-agent-handoff.md)
- [批准的 Agent 设计规格](../design/agent-disk-governance.md)
- [UI/UX 设计规格](../design/ui-ux.md)
- [Epic 0–1 实施计划](../plans/completed/epic-0-1-foundation-spikes.md)
- [Epic 0–1 验证报告](../reports/epic-0-1-validation-report.md)

## 0. 品牌与项目边界

- **正式名称**：Stornaut
- **读音**：`STORE-naut`（/ˈstɔːr.nɔːt/，两音节）
- **词源**：`storage + -naut`，即“存储空间探索者”
- **英文标语**：*Map the known. Investigate the unknown. Reclaim with evidence.*
- **中文描述**：面向 macOS 开发者的 AI 磁盘调查员
- **标识约定**：产品/App 使用 `Stornaut`；仓库、CLI 和配置前缀使用 `stornaut`；Swift 模块使用 `StornautApp`、`StornautCore`、`StornautCodex`
- **开源策略**：GitHub Public，MIT License
- **首发平台**：开发时最新稳定版 macOS、Apple Silicon；个人阶段不为 Intel 或旧 macOS 设置兼容性验收门槛

名称承载“探索未知空间”的产品隐喻；AI/Codex 是核心能力，但不写入名称，以免品牌绑定某一代模型或营销术语。

### 0.1 规范术语

- 用户界面的两种模式是 `Quick Scan` 与 `Deep Dive`；`Investigation` 只用于领域对象和 `Investigations` workspace，例如 `InvestigationSession`。
- 领域层与 UI 共用 `ReclaimDisposition`：`readyToReclaim`、`reviewRecommended`、`protected`、`unknown`，对应文案 `Ready to Reclaim`、`Review Recommended`、`Protected`、`Unknown`。
- 风险高低、证据置信度和回收处置是不同维度；不得用旧的 `safe/caution/no` 同时承载三者。
- `Registered Action` 指 Action Registry 中经过审核、类型化、固定 executable/参数模板的动作；它可能可逆或永久。只有永久 Registered Action 才使用独立的不可撤销确认。

## 1. 产品摘要

Stornaut 是面向 macOS 开发者的开源 AI 磁盘调查与治理工具。

它吸收现有清理工具在原生 UI、权限引导、全盘扫描、开发缓存目录、项目产物识别、活动保护和安全删除方面的成熟经验，再加入一个能力完整但没有写入/执行权的 Codex 调查指挥官：规则负责高效处理已知空间，Agent 负责按科学方法调查未知空间，Swift 安全策略和用户掌握最终执行权。

一句话定位：

> **不只告诉你什么占空间，还用证据调查它是什么、为什么能清、删除后如何恢复。**

核心公式：

```text
前人验证过的确定性能力
+ Codex 全盘调查指挥官
+ 不可绕过的 Swift 安全执行链
= Stornaut
```

## 2. 背景与问题

开发者电脑会持续产生通用清理器难以理解的空间占用：

- 多项目的 `node_modules`、`.venv`、`target`、DerivedData 和生成产物
- npm、pnpm、Bun、uv、Go、Cargo、Homebrew、Docker 等全局缓存
- 克隆后长期不用的开源仓库、重复 `.git` 对象和模型权重
- IDE、模拟器、虚拟机、AI 工具运行时和更新残留
- 位于非标准路径、无法被固定规则识别的陌生大目录
- APFS、swap、稀疏文件、TCC 权限造成的空间口径差异

2026-08-06 的真实案例中，一块 460GB 磁盘达到 98% 使用率。Claude Code 通过动态调查找出大量历史项目、虚拟环境、包缓存和 VM 镜像，随后 Mole 又通过成熟的 65 类规则补充清理约 7.88GB。两次结果共同证明：

1. Agent 擅长调查未知和跨目录关联，但会消耗更多时间与 Token。
2. 成熟规则擅长快速召回已知垃圾，但无法解释规则未覆盖的空间。
3. 最有效的产品不是二选一，而是由 Agent 编排确定性专业工具。

## 3. 目标与非目标

### 3.1 产品目标

1. 几分钟内完成低成本、可预测的开发者磁盘快速扫描。
2. 在磁盘告急时启动 Codex 深度调查，尽可能解释全盘空间分布和未知大目录。
3. 每个建议都提供可复核证据、风险、恢复方式和重建成本。
4. Agent 可以自主选择调查轨迹，但必须遵循固定科学方法和工具边界。
5. 任何模型结论都不能绕过确定性策略、用户批准和类型化 Executor。
6. 系统性学习 Mole、ClearDisk、kondo、devklean、Cluttered 等项目经验，而不是从零重造。
7. 核心能力在 Codex、Mole、kondo 等外部工具缺失时仍可使用。

### 3.2 非目标

- 不做通用杀毒、恶意软件检测或系统优化套件。
- 不支持 Windows/Linux；v1 专注 macOS。
- 不把 Agent 做成任意 Shell 清理器；调查允许直接只读 shell/unified exec、live web search、browser/direct fetch、image、skills/subagents 与公共互联网，但禁止本地写入和任何清理执行。
- 不承诺一次扫描解释所有受 TCC、APFS 或系统保护影响的空间。
- 不在 v1 自动定时清理或无确认后台删除。
- 不以复制某个上游项目或做“免费版 Mole/CleanMyMac”为目标。
- 不在没有性能证据时引入 Rust Scanner Core。

## 4. 目标用户与核心场景

目标用户是磁盘长期处于 80% 以上、同时使用多语言工具链、IDE、容器和 AI 编程工具的 macOS 开发者。

核心场景：

1. 日常快速体检：快速找出已知缓存和陈旧项目产物。
2. 磁盘告急：彻底调查“空间到底去哪了”。
3. 陌生目录判断：解释生产者、用途、活动状态、重建方式和删除影响。
4. 安全清理：普通文件进废纸篓；复杂缓存调用 Action Registry 中经过审核的 Registered Action。
5. 开源扩展：用户增加本地规则，并把验证过的规则贡献回项目。

## 5. 产品原则

### 5.1 Agent 是指挥官，不是删除器

Agent 有完整调查权和建议权，没有写权限和最终授权。它负责决定下一步调查什么、使用哪个只读工具或公共信息源、证据是否充分；Swift Policy Gate 和 Executor 负责所有执行。

### 5.2 轨迹动态，方法固定

深度调查不使用固定清理清单，但必须遵循：

```text
观察 → 建立假设 → 调用探针验证 → 寻找反证 → 量化影响 → 得出结论 → 明确不确定性
```

### 5.3 已知问题优先使用确定性工具

Agent 不应浪费 Token 重新发现已经被可靠规则解决的问题。快速扫描和 Knowledge Base 先覆盖已知空间，Agent 聚焦未知、异常和数字差额。

### 5.4 效果不以牺牲安全为代价

提示词不是安全边界。Codex 进程树不可写、清理 protected-path policy、Policy Gate、执行前重验证和用户确认必须由 Swift 代码强制执行；不得用逐文件读取批准或静态路径封锁替代这些完整性控制。

### 5.5 站在前人肩膀上

每个开发 Epic 必须执行 Reference Study Gate：先研究对应上游，再独立实现、Benchmark 和记录改进。

## 6. 产品模式

### 6.1 快速扫描 Quick Scan

目标：低成本、高频、可预测，默认不调用 Codex。

流程：

```text
磁盘基线 → Swift Surveyor → Knowledge Base → 活动保护 → 空间报告
```

必须支持：

- 卷级 `df`/APFS 基线和真实可用空间
- 已知 developer cache 路径
- 项目产物扫描和陈旧度信号
- App/进程活动保护
- 风险分类、人话模板和恢复方法
- 扫描覆盖率、权限缺口和不可测量空间
- 结果持久化，供深度调查复用

性能目标：460GB 真实磁盘小于 5 分钟。

### 6.2 深度调查 Deep Dive

目标：由 Codex 调查指挥官尽可能解释未知大目录、空间差额和复杂工作链。

流程：

```text
复用 Quick Scan 快照
→ 计算未解释空间与候选目标
→ Swift Candidate Planner 生成并准入 InvestigationPlan
→ Codex 使用直接只读工具、Probe Broker 与 live public internet 调查
→ Agent 在 Swift 准入的目标与预算内动态调整调查策略
→ 达到覆盖率、时间或 Token 预算
→ 生成 EvidenceReport 与 CleanupPlan
```

Agent 可以决定：

- 优先调查哪些目录和空间差额
- 是否继续下钻某个目录
- 是否检查关联 App、运行进程、Git、manifest 或 lockfile
- 是否调用 Mole、kondo、Homebrew、Docker 等可选探针
- 当前假设是否有足够证据或反证
- 何时停止并将目标标记为 `Unknown`

Agent 不可以：

- 删除、移动、压缩或修改文件
- 调用任何清理命令
- 通过 shell、browser、skills、subagents 或网络绕过进程树写入禁令
- 主动采集凭据、绕过 TCC，或访问 localhost、私网与任意 Unix socket
- 调用或绕过 Policy Gate、Executor、预算或用户授权
- 把低置信度推断提升为 `Ready to Reclaim`

## 7. 功能需求

### FR-1 Swift Surveyor

- 使用原生 Swift/Foundation/POSIX API 建立目录与卷级快照。
- 输出路径、逻辑/物理大小、mtime、文件类型、所有者、符号链接和权限状态。
- 为 Git 仓库采集 last commit、dirty、untracked、remote 和活动信息。
- 采集 Spotlight 最近使用、运行进程、已安装 App、Bundle ID 等信号。
- 避免跟随危险符号链接和跨卷递归。
- 能取消、恢复进度并标记未完成范围。
- v1 不使用 Rust；只有 Benchmark 证明 Swift 不达标时才提出替换 ADR。

### FR-2 Knowledge Base 与规则

内置规则至少覆盖：

- Node.js、Python、Rust、Go、Java、Ruby、PHP、Flutter、Xcode 等项目产物
- npm、pnpm、Yarn、Bun、uv、pip、Conda、Cargo、Go、Gradle、Maven、Homebrew 缓存
- Docker/Colima/Lima、Xcode、JetBrains、VS Code/Cursor、AI 工具运行时
- Electron ShipIt、更新残留和常见可重建缓存
- 照片库、浏览器用户数据、凭据和系统目录等否决规则

每条规则必须记录：

- 唯一 ID、匹配条件、生产者和类别
- 风险等级与 veto
- 前置条件和活动保护
- 恢复/重建方法与成本
- 推荐类型化动作
- 来源 URL、commit/版本、许可证、验证日期
- fixture 和安全回归测试

支持内置规则和本地 overlay；overlay 可以更保守，默认不得降低内置 deny/veto。

### FR-3 Codex Runtime

- v1 只支持 Codex，不抽象其他 Agent Runtime。
- 使用用户已安装的 Codex，不捆绑或自动下载。
- 探测常见安装位置、登录 Shell 和用户手动配置路径。
- 运行 `codex --version` 和能力检查，记录兼容范围。
- 复用现有登录凭据；调查进程使用 Stornaut 隔离配置。目标磁盘中的项目指令可作为证据读取，但不作为 Codex 指令加载；不继承会产生外部副作用的用户 Hooks/Apps。
- 非交互运行，使用 JSONL 事件和最终 JSON Schema。
- 会话使用 ephemeral 模式，并提供取消、超时和预算。
- 显式启用正常 shell/unified exec、`web_search = "live"` high context、browser/direct fetch、image inspection 以及运行时支持的 skills/subagents；不得因缺少完整工具 allowlist 而关闭这些调查能力。
- 允许命令、子进程和 browser/direct fetch 访问公共互联网，不设置 Bash/可执行文件或公共域名 allowlist，也不逐命令请求批准；cached/indexed search 只能作为显式 degraded coverage，不能静默替代 live search。
- Codex 与所有后代进程必须处于有效的 OS 写入隔离中；不得以 `danger-full-access` 换取联网。localhost、link-local/private network 与任意 Unix socket 默认不开放。
- Codex 不可用时深度调查禁用，但快速扫描保持完整。

### FR-4 Probe Broker

Probe Broker 是 Agent 的优先结构化证据接口，提供类型化、只读、可审计工具；它不是 Codex 的唯一调查接口：

- `getDiskSnapshot`
- `summarizeDirectory`
- `listLargestChildren`
- `inspectFileMetadata`
- `readSafeTextSnippet`
- `inspectBundleProducer`
- `inspectRunningProcesses`
- `inspectGitState`
- `inspectPackageManifest`
- `measurePath`
- `runReadOnlyAdapter`

每次 Broker 调用记录输入、输出摘要、耗时、读取字节、错误和预算消耗。Broker 对路径做规范化、范围验证、符号链接检查和敏感区检查。Codex 的直接读取、shell 和联网证据必须带来源/覆盖率，但不伪装成 Broker 审计记录。

Codex 可以直接浏览用户选择的扫描范围、使用本地只读 shell/文件系统工具，并直接运行不会写入或清理的调查命令；也可以通过 Broker 获取更稳定、可复用的结构化证据。隔离 gate 验证的是“完整调查能力与公共联网可用，同时所有后代进程不可写且没有 Executor 调用路径”，不再验证 Broker-only。若 installed Codex 自身无法组合公共联网与只读 sandbox，必须增加外层 OS containment，而不是关闭 shell/browser/search 或改用 `danger-full-access`。

### FR-5 外部工具 Adapters

内置核心必须独立工作。检测到外部工具时，可提供只读增强：

- Mole：分类与扫描结果交叉验证，不调用清理动作
- kondo：项目类型和 artifact 发现
- Homebrew：缓存、Cellar 和 cleanup dry-run/信息接口
- Docker/Colima：只读 disk usage 和对象关系
- 系统工具：`diskutil`、`df`、`mdls`、`lsof` 等

Adapter 必须声明版本范围、能力、只读保证、超时和解析器测试。缺失、版本不兼容或输出异常时自动降级。

### FR-6 Evidence Store

对每个候选项保存：

- 空间与路径事实
- 生产者证据
- 活动与进程证据
- Git/项目状态
- 可重建性与重建成本
- Agent 假设、支持证据、反证和不确定性
- 使用过的规则与工具
- 最终分类和 Policy Gate 结果

用户界面展示证据摘要和工具活动，不展示模型隐藏推理过程。

默认数据生命周期：

- Quick Scan 快照、Agent 证据记录和调查报告保留 7 天，支持立即手动清除。
- 受控读取的内容片段仅在内存中处理，不写入 Evidence Store。
- 原始 Codex JSONL 在会话正常结束时删除；崩溃残留在下次启动清理，最长保留 24 小时。
- Cleanup Manifest 默认保留 90 天，只保留最小审计元数据：Action ID、Policy disposition、清理前后计量、结果和错误；不延长 Evidence payload、probe 记录或内容派生摘要的 7 天生命周期。
- 路径只保存在本机；导出报告时将用户主目录规范化为 `~`。

### FR-7 调查数据边界

首次启用 Deep Dive 时一次性说明：授权扫描范围中的文件内容可能进入模型上下文，调查查询、URL 和必要片段可能发送到公共互联网服务。用户接受后，Codex 可在该范围内自主选择元数据、README、manifest、lockfile、配置、日志以及理解未知目录所需的其他只读证据；不逐文件、逐命令、逐工具或逐域名再次确认，也不设置 Agent 读取路径 denylist。

这不是凭据采集功能：Codex 不应把 Keychain、密码管理器、私钥、token 或 secret value 当作调查目标，也不得绕过 TCC。偶然遇到的 secret value 不写入 Evidence Store、Local Knowledge、日志或报告。Probe Broker 可继续对自身输出做限字节与脱敏，但其过滤策略不限制 Codex 的其他只读调查工具。

清理 protected-path policy 与调查读取是两个边界。Keychain、凭据目录、用户通信/照片库、HOME/卷根和系统关键路径仍可被 Swift Policy Gate 永久拒绝成为清理目标；该执行保护不得被 Agent 或 Settings 绕过。

### FR-8 CleanupPlan 与 Policy Gate

Agent 只能输出 versioned、不可执行的 advisory report，且只能引用 Swift
预先提供的 investigation/run/target/candidate IDs。Agent 不能提供路径、
CleanupAction、authorization、PolicyDecision、Trash、Registered Action、
journal 或 Executor 字段。Swift coordinator 必须从 retained IDs 重新查找
当前路径、canonicalize/revalidate，并显式构造结构化 CleanupPlan。
Policy Gate 必须：

- 重新规范化路径并检查 symlink/mount boundary
- 重查大小、mtime、inode/文件标识和活动状态
- 应用清理 protected-path policy、veto、风险和证据完整性要求
- 规则 miss 且只有 Agent 建议的项目必须保持 `Review Recommended`，绝不能成为 `Ready to Reclaim`
- 检查计划是否过期或扫描后发生变化
- 对多个动作检查依赖和执行顺序

任何失败都应拒绝动作，而不是猜测通过。

### FR-9 类型化 Executor

支持两类执行动作：

1. `MoveToTrash(path)`：普通目录和文件的默认动作，可通过 Finder 恢复。
2. `Registered Action`：例如经审核后注册的 Homebrew、uv、pnpm、Docker 固定动作模板。

Registered Action 要求：

- 固定二进制与参数，不接受 Agent 原始 Shell
- 明确前置条件、dry-run 能力、风险和可撤销性
- 永久 Registered Action 单独确认，不能和普通 Trash 批量静默执行
- 执行后重新测量和验证
- 失败停止当前动作并记录，不级联猜测处理

所有执行写入 Manifest，包括计划证据摘要、动作、结果、清理前后空间和错误。

### FR-10 原生 macOS UI

技术栈：SwiftUI 为主，必要处桥接 AppKit。

v1 是用户按需启动的单窗口 App，不提供 MenuBarExtra、后台检测、定时扫描、登录启动或空间告警。主窗口固定为四个 workspace：

- Overview：卷级 Space Ledger、已解释/未知/不可测量空间、最近快照和主要入口
- Scan：Quick Scan 进度、动态 artifact 分类、活动状态和恢复方式
- Investigations：Deep Dive 会话、阶段、预算、覆盖率、新发现和部分结果
- History：Snapshot、Cleanup Manifest、实际空间变化和审计

Review Plan 与 Cleanup Result 是工作流页面，不增加顶层导航；Settings 使用标准 macOS Settings 场景与 `⌘,`。

Settings 固定使用六个区域：General、Scanning、Permissions、Codex & Deep Dive、Privacy & Data、Local Knowledge。语言、外观、允许的扫描范围/排除项、规则 overlay、可选 Adapter 和默认调查预算属于可编辑偏好；FDA、Codex 发现、Deep Dive safety check、数据生命周期和清理 protected-path policy 属于实时状态或只读事实。普通 Settings 不得提供 Policy Gate、Executor、写隔离或清理 protected-path 绕过。

界面必须：

- 默认 English，支持切换 `zh-Hans`（Simplified Chinese）；Agent 用户摘要跟随应用语言
- 默认跟随 System 外观，同时完整支持 Light 与 Dark
- 首页 visual-first，证据与最终决策 text-first
- 默认不显示聊天、终端、原始 JSONL 或模型隐藏思维链
- Agent 只在未知候选调查、当前 Deep Dive 和新发现中可见；known-rule 项目不添加 AI 装饰
- 将开发者工具作为动态分类的 facets/子项，而不是为 Node、Python、Rust、Go、Android、Xcode 等建立固定顶层页面
- 使用本地结构化 Local Knowledge 保存经用户确认的映射与偏好，不保存自由文本 Agent Memory；持久化 `LocalKnowledgeStore` 只位于 Stornaut 自有 Application Support 目录，衍生缓存才进入 Caches，不创建 `~/.stornaut`

Deep Dive 只在首次启用时聚合披露调查数据边界，不逐文件、逐命令、逐工具或逐域名弹出授权。Registered Action 按动作类型聚合，永久动作必须逐类明确确认。

完整信息架构、状态、文案、品牌、accessibility 和 motion 规范见 [UI/UX 设计规格](../design/ui-ux.md)。

### FR-11 空间计量

至少区分：

- 候选逻辑大小
- 执行器实际处理大小
- 移入废纸篓但尚未永久释放的大小
- 永久清理动作预计/实际释放
- 系统可用空间变化
- APFS purgeable、clone、sparse file、swap 等解释项
- 权限导致的不可测量空间

不能把“选中大小”“移动到 Trash”和“系统可用空间增加”混为一个数字。无法归因的差额必须明确标注。

## 8. 调查预算与停止条件

深度调查必须支持可配置预算：

- 最大墙钟时间
- 最大 Agent 轮次和探针调用数
- 可由用户提高的总读取/模型上下文预算
- 最大并发探针数
- 用户随时取消

默认优先级使用：

```text
priority = expectedReclaimableBytes × uncertainty × relevance / investigationCost
```

满足以下任一条件应停止：

- 达到用户设定覆盖率
- 剩余未知项低于体积阈值
- 时间/Token/工具预算耗尽
- 连续调查无法增加有效证据
- 用户取消

停止时仍输出部分报告、未完成清单和继续调查入口。

## 9. 权限与分发

- 非 App Store 沙盒产品，使用 Developer ID 签名和 notarization 分发。
- 首发构建只要求当前最新稳定版 macOS 与 Apple Silicon；不为 Intel/旧系统增加兼容层。
- 首次启动解释 Full Disk Access 的目的；未授权时降级并展示覆盖缺口。
- Swift App 是磁盘访问和写操作主体。
- Codex 子进程隔离必须进行技术验证，确保 direct read、shell/browser、skills/subagents 与公共网络可用时，Codex 及其后代仍不能写用户数据或调用清理执行链。
- 不得把 `danger-full-access`、提示词或人工确认标记为技术写隔离；runtime gate 失败时暂停 Deep Dive，但不得把“关闭强调查能力”作为默认修复。

## 10. 失败与降级

| 失败 | 行为 |
|---|---|
| Codex 未安装/未登录/崩溃 | Quick Scan 可用；Deep Dive 说明原因并提供修复入口 |
| Adapter 缺失或版本不兼容 | 跳过，记录覆盖差距 |
| FDA/TCC 拒绝 | 标记不可测量，不误报为零占用 |
| Agent 输出不符合 Schema | 丢弃结论，目标保持 Unknown |
| 预算耗尽 | 输出部分结果和未完成目标 |
| 调查期间目录变化 | 证据失效，重新扫描目标 |
| 执行前目录变化 | 拒绝执行并要求重新确认 |
| Registered Action 失败 | 停止该动作，保留日志和恢复建议 |
| Trash 失败 | 不回退到永久删除 |
| Cleanup Manifest 持久化失败 | 与执行结果分开报告；在成功重试保存或导出前不得显示正常完成 |
| linked Evidence 到期 | 保留最小 Cleanup Manifest；证据区明确标记过期，不猜测重建 |
| 单条 History 损坏 | 只隔离该记录，其他历史仍可查看、导出和删除 |

所有降级界面遵循同一恢复契约：保留仍然有效的结果，精确标记受影响范围，说明当前影响，只提供安全恢复动作，并将技术细节按需展开。局部权限失败不得写成 `0 B`；Deep Dive safety check 阻断时不得保留虚假的 investigation 成功指标；执行前 stale 没有 bypass，刷新前不执行任何动作。完整状态矩阵与 Light/Dark 参考见 [Resilience States](../assets/ui-concepts/RESILIENCE-STATES-ROUND-1.md)。

## 11. 成功指标与发布门槛

### 11.1 个人阶段

- 460GB 真实磁盘 Quick Scan 小于 5 分钟
- Quick Scan 不调用模型
- 本人机器已知规则覆盖率大于 85%
- Deep Dive 能解释案例中的未知 VM、历史项目和空间差额
- `false Ready-to-Reclaim = 0`
- 预计释放与实际归因误差在可解释范围内；目标 ±10%
- 全程可以取消，失败不产生隐式写操作

### 11.2 开源阶段

- 规则 Schema、来源和贡献流程文档化
- 每条新规则有 fixture、安全测试和来源
- 核心在没有 Codex/外部工具时仍通过测试
- 至少完成 Mole、ClearDisk、kondo 的行为 Benchmark
- 完成签名、公证、FDA 和 Codex 隔离技术验证

## 12. 测试与 Benchmark

必须覆盖：

- 来自真实案例的匿名目录 fixture
- 规则匹配、路径规范化、symlink 和 mount 边界
- Agent 建议 `Ready to Reclaim`、规则 veto 的对抗测试
- Codex 写入隔离、secret 非持久化和清理 protected-path policy
- Codex 超时、崩溃、格式错误和取消
- Adapter 输出变更和版本不兼容
- Git dirty、未推送、IDE/App 正在运行
- Trash、Registered Action dry-run、部分失败和执行前变化
- APFS 空间计量和清理前后归因
- 460GB 真实机器性能 Benchmark

竞品 Benchmark 分层：

- 产品体验与覆盖：Mole、ClearDisk、CodeCleaner、CleanMyMac CLI
- taxonomy：kondo
- 安全设计：devklean
- 活动保护：Cluttered
- Agent 工作流：Claude Code disk cleanup、daymade macos-cleaner

## 13. Reference Study Gate

Coding Agent 开始每个 Epic 前必须：

1. 阅读 [上游参考矩阵](../research/upstream-reference-matrix.md) 中对应项目。
2. 获取上游当前 commit、许可证和相关源码/文档。
3. 写简短 Implementation Brief：可借鉴点、反面案例、许可证边界、拟采用方案。
4. 优先复用公开事实、协议和测试思想；复制代码必须满足许可证和 attribution。
5. 实现后运行上游行为 Benchmark，记录 Stornaut 的差异和改进。

Definition of Done：

- 已完成模块级上游学习记录
- 已说明采用/不采用理由
- 已通过许可证检查
- 已增加 fixture、测试或 Benchmark
- 已记录相对上游的改进
- 未引入未经审核的 Shell、路径规则或第三方代码

## 14. MVP 范围与路线图

v1 的宏观交付顺序与阶段 gate 见 [Delivery Roadmap](../plans/roadmap.md)。Epic 编号表示能力归属，不要求按数字严格顺序实现。已批准先在 Epic 2–4 后交付 Epic 8 的确定性安全执行子集，再按 ADR 0004 的 capability-first runtime gate 生产化 Epic 5–6 Deep Dive。

### v1

- 原生 SwiftUI/AppKit macOS App
- Quick Scan 与 Deep Dive 双模式
- Swift Surveyor、Knowledge Base、Evidence Store
- 用户已安装 Codex 的子进程集成
- Probe Broker 与首批内置探针
- Mole/kondo/Homebrew/Docker 首批只读 Adapter
- capability-first 只读调查、一次性数据边界披露、预算和调查日志
- Policy Gate、Trash 和少量 Registered Action
- 清理前后空间计量
- Reference Study Gate 和核心 Benchmark

### v1 明确不做

- 其他 Agent Runtime
- Rust Scanner Core
- 自动下载或捆绑 Codex
- 自动后台清理
- MenuBarExtra、后台监控、定时扫描、登录启动和空间告警
- Agent 通过 Shell 写入、清理或直连 Executor；调查性只读 Shell 属于 v1 核心能力
- 清理 protected-path policy 绕过
- 跨平台
- DaisyDisk 式完整 treemap
- 聊天式 Agent 主界面、调查控制台和自由文本 Agent Memory

### 后续

- 增量扫描和 FSEvents
- 社区规则远程更新与签名
- 更多 Registered Action 和 Adapter
- 可选磁盘地图
- 只有在性能证据充分时评估 Rust Scanner

## 15. 已批准决策

1. 个人自用优先，GitHub Public 开源。
2. 原生 Swift 全栈 + Codex 子进程。
3. v1 只支持 Codex，并使用用户已安装版本。
4. Quick Scan + Deep Dive 双模式。
5. Deep Dive 是全盘调查指挥官，不是固定清理轨迹。
6. Agent 遵循科学调查方法；Codex 可直接读取扫描范围并使用 shell/unified exec、live search、browser/direct fetch、image、skills/subagents、公共互联网和 Probe Broker，但不能写入或执行清理。
7. 内置核心 + 可选外部只读 Adapter。
8. Deep Dive 首次启用时一次性披露模型上下文与公共联网数据边界；调查中不做逐文件、逐命令、逐工具或逐域名批准。
9. 不设置 Agent 读取路径 denylist；Swift Policy Gate 永久保护敏感路径不成为清理目标，Codex 不主动采集或持久化凭据。
10. Trash + Action Registry 中经过审核的 Registered Action；永久动作独立确认。
11. Agent 没有删除权，Swift Executor 是唯一写路径。
12. 每个 Epic 强制执行 Reference Study Gate。
13. Rust Scanner 只有在 Benchmark 证明需要时再评估。
14. v1 只做按需启动的单窗口 App，不做菜单栏伴侣或后台检测。
15. 主导航为 Overview、Scan、Investigations、History；Settings 独立。
16. 默认 English，支持 `zh-Hans`；System/Light/Dark 均为一等外观。
17. UI visual-first、evidence-on-demand；默认不展示聊天、控制台或模型思维链。
18. 使用应用拥有的结构化 Local Knowledge；持久化数据仅在 Application Support，不创建 `~/.stornaut` 自由记忆工作区。
19. 正式品牌方向为 Nautilus Probe 与 Deep Ocean Evidence 配色。
20. `ReclaimDisposition` 统一为 Ready to Reclaim、Review Recommended、Protected、Unknown；风险与置信度分别建模。
21. Evidence 默认 7 天；90 天 Manifest 不保留 Evidence payload 或内容派生摘要。
22. ADR 0004 的 capability-first 边界是 Deep Dive 必验条件：完整调查工具与公共联网可用，Codex 进程树仍不可写且无 Executor 路径；旧 Broker-only 前提已废止。

## 16. Coding Agent 交接入口

Coding Agent 开始开发前必须按顺序阅读：

1. [本 PRD](PRD.md)
2. [技术架构](../architecture/system-architecture.md)
3. [批准的 Agent 设计规格](../design/agent-disk-governance.md)
4. [UI/UX 设计规格](../design/ui-ux.md)
5. [Epic 0–1 实施计划](../plans/completed/epic-0-1-foundation-spikes.md)
6. [上游参考矩阵](../research/upstream-reference-matrix.md)
7. [Coding Agent Handoff](../agent/coding-agent-handoff.md)
8. [竞品报告](../research/competitive-analysis-2026-08-06.md)
9. [真实案例](../research/case-study-2026-08-06.md)

Coding Agent 不应重新发明计划或直接批量编码；第一步是按已批准的 Epic 0–1 计划逐 Task 执行技术风险 Spike。
