# Stornaut UI/UX 设计规格

> 日期：2026-08-07  
> 最近更新：2026-08-08
> 状态：功能、交互、品牌、安全、核心页面、Settings 与跨流程恢复状态均已批准；UI/UX 设计基线完成
> 适用范围：Stornaut v1 原生 macOS App  
> 上位约束：[PRD](../product/PRD.md)、[Agent 磁盘治理设计](agent-disk-governance.md)、[技术架构](../architecture/system-architecture.md)

本文件把产品讨论中确认的界面、交互、品牌和 Agent 表达方式固化为 Coding Agent 的实施输入。信息架构、状态、文案、安全规则、功能交互和核心页面构图已经批准；概念图用于记录已选方向与主题关系。视觉概念图只用于表达氛围与布局，不是逐像素终稿；发生冲突时，以本规格为准。

## 1. 体验目标

Stornaut 应像一台安静、可信、证据驱动的磁盘观测仪，而不是“垃圾猎杀器”或聊天机器人。

用户启动 App 后应能快速回答四个问题：

1. 空间主要去了哪里？
2. 当前有多少空间可以安全处理？
3. 哪些占用需要进一步调查？
4. 清理动作是否可恢复、会产生什么代价？

设计优先级依次为：安全与可理解性、信息层级、响应反馈、平台原生感、品牌表现。漂亮动画不能掩盖证据缺口，也不能早于安全核心实现。

## 2. v1 产品形态

- 原生 SwiftUI/AppKit 单窗口 macOS App。
- v1 只验收开发时最新稳定版 macOS 与 Apple Silicon；Intel 和旧 macOS 布局不是验收目标。
- 用户需要时主动启动、扫描和清理；退出后不驻留。
- v1 不提供 `MenuBarExtra`、后台监控、定时扫描、登录启动或空间告警。
- 顶层导航固定为 `Overview`、`Scan`、`Investigations`、`History` 四项。
- `Settings` 使用标准 macOS Settings 场景与 `⌘,`，不占用主侧边栏。
- 默认语言为 English，可在 Settings 切换 `zh-Hans`（Simplified Chinese）；切换后应用界面和 Agent 用户摘要同时更新。
- 外观默认 `System`，同时完整支持 `Light` 与 `Dark`，不把深色主题当作唯一正确体验。

## 3. 核心体验原则

### 3.1 Snapshot-first

首页优先展示最近一次可靠快照及采样时间，而不是每次启动自动全盘扫描。用户主动点击 `Quick Scan` 或 `Deep Dive`。过期数据必须明显标记，但仍可用于理解历史变化。

### 3.2 Visual-first, evidence-on-demand

- Overview 和扫描进度优先使用图形、数值和简短标签。
- 风险判断、Evidence、Recovery 和永久动作使用精确文字。
- 默认界面不展示终端、日志流、模型内部思维链或大段 Agent 对话。
- 复杂信息进入 Inspector、Disclosure Group 或独立详情页。

### 3.3 One primary action

每个页面只保留一个视觉主操作。取消、停止、重新扫描、查看详情和高级设置必须从属，避免多个高饱和按钮争抢注意力。

### 3.4 Evidence before confidence

不展示脱离证据的“AI 置信度分数”。用户先看到生产者、用途、活动状态、反证、恢复方式和重建成本，再看到结论。颜色不能成为风险等级的唯一表达。

### 3.5 Safe by structure

界面不暗示 Agent 可以执行删除。所有清理动作必须经过 Review、Policy Gate 和最终用户批准；被 veto 的项目不可通过 UI 强制选择。

## 4. 信息架构与窗口

### 4.1 主窗口

- 默认窗口建议尺寸：`1180 × 760 pt`。
- 最小窗口建议尺寸：`960 × 640 pt`。
- 使用原生 `NavigationSplitView` 或等价 AppKit split view。
- Sidebar 建议宽度 `210–240 pt`；主内容保持单一主滚动区域。
- Toolbar 只承载当前页面标题、状态摘要和一项主操作；不要复制页面内操作。
- Inspector 建议宽度 `320–400 pt`，用于证据和高级调查详情，可由 `⌥⌘I` 或页面按钮开关。

### 4.2 顶层导航

| Destination | 目的 | 主要内容 |
| --- | --- | --- |
| Overview | 回答“空间去哪了” | Space Ledger、关键指标、机会与入口 |
| Scan | 运行和检查确定性扫描 | Scope、进度、分类、项目产物与缓存 |
| Investigations | 调查未知或矛盾空间 | Deep Dive 会话、发现、证据和未完成目标 |
| History | 审计过去的扫描和动作 | Snapshot、Manifest、实际空间变化 |

Sidebar item 必须同时有 SF Symbol 和文字；当前项使用系统 selection material，不使用仅靠颜色的细线指示。

### 4.3 独立 Settings scene

Settings 由 `⌘,` 打开独立标准 macOS Settings scene，不复用主窗口四项 Sidebar，也不显示 Overview 指标、扫描图或清理 CTA。内部使用原生 Settings 侧栏，固定六项：

1. `General`
2. `Scanning`
3. `Permissions`
4. `Codex & Deep Dive`
5. `Privacy & Data`
6. `Local Knowledge`

Settings 必须视觉上区分三类内容：

- **Editable preference**：语言、外观、允许的扫描根/排除项、规则 overlay、可选 Adapter 和默认 Deep Dive 预算。
- **Runtime status + repair**：Full Disk Access、已授权目录、Codex 路径/版本/能力和 Deep Dive safety check；使用明确状态和 `Review`、`Open System Settings`、`Check Again`、`Run Safety Check` 等恢复动作，不伪装成普通 toggle。
- **Read-only policy fact**：永久敏感区 denylist、Policy Gate、执行边界、7 天 Evidence、90 天最小 Cleanup Manifest、JSONL 生命周期和本地存储边界。可解释、可立即清除对应本地记录，但不可延长或绕过。

General 只保留 `Language`、`Appearance` 和三行紧凑 `Setup Status`：Disk access、Codex installation、Deep Dive safety。`Codex Installed` 与 `Deep Dive safety Required/Verified` 独立显示；前者不得隐含后者。底部使用非交互信息行说明 `Runs only when you open Stornaut`，不得提供后台监控、定时扫描或自动清理开关。

Scanning 将用户可编辑的 scan roots/bookmarks 与 exclusions 分开，并把永久 protected locations 作为只读策略展示。工具生态使用动态规则/facet，不建立 Node、Python、Rust、Go、Xcode、Android、Next.js 或 Homebrew 的固定完整清单。规则 overlay 与 Adapter 只在实现和 provenance 可用时显示，缺失时给出局部降级说明。

Permissions 中 FDA 只显示 `Full`、`Limited` 或检查失败状态，不实现应用内权限 toggle。`Open System Settings` 后允许 `Check Again`；有限访问必须说明覆盖率影响和 Quick Scan 仍可用。用户选择的安全作用域目录可添加/移除；永久敏感区没有例外按钮。

Codex & Deep Dive 中默认预算使用 `10 min · Focused`、`30 min · Balanced`、`60 min · Thorough` 三个产品级预设，Balanced 默认。高级墙钟、轮次、Probe、字节和并发限制进入折叠 disclosure；v1 不提供模型供应商、任意 CLI flag、Shell、隔离绕过或“信任 Codex”开关。

Privacy & Data 以只读政策行展示 Evidence `7 days`、minimal Cleanup Manifest `90 days`、normal-end JSONL deletion 与 crash remnant `up to 24 hours`。`Clear Evidence Now…` 与 `Clear Manifests Now…` 分开确认，并明确只删除 Stornaut 本地记录，不删除用户文件、不改变 Trash、不撤销既有清理。

Local Knowledge 使用结构化列表展示 finding、scope、provenance、updated/stale 状态；支持 Review、Forget 和经确认的 Forget All。禁止自由文本记忆编辑、聊天历史、未经确认的模型结论、直接 disposition 覆盖或任何 policy 降级。所有设置即时生效，不提供全局 Save 按钮。

已批准候选评审、六个区域行为和 General/Codex/Local Knowledge 的 Dark/Light canonical 见 [Settings Internal Draw](../assets/ui-concepts/SETTINGS-ROUND-1.md)。

## 5. 首次启动与权限

首次启动采用无主侧边栏、不超过三步的轻量引导。每页只处理一个决策，顶部三步 rail 保持位置稳定；整套引导可跳过，且不在此阶段执行扫描或清理：

1. `Map your storage`：说明 Quick Scan 在本机执行且不调用 Codex，建立 `Local first`、`Evidence before action`、`Always reversible` 三项承诺；操作为 `Skip Setup` 与主操作 `Continue`。
2. `Full Disk Access`：解释 FDA 只改变可测量覆盖率，不开启自动清理；以一张收益卡配一条紧凑 `Limited Access` 后果说明，允许 `Continue with Limited Access`。
3. `Connect Codex`：分别检测用户已安装 Codex 与 Deep Dive safety check；缺失、版本不兼容或安全检查失败时 Quick Scan 仍完整可用，Deep Dive 保持 paused。

`Codex installation` 与 `Deep Dive safety check` 是两个独立状态。发现可执行文件不等于安全边界已验证。目标产品边界是 Codex 不能修改或直接浏览扫描根，只能通过 Stornaut 的受控本地桥接请求经过审计的只读 Probe Broker；该边界在技术 Spike 与运行时检查通过前必须显示为 `Required`/`Paused`，不得显示 `Verified`。若无法强制成立，暂停 Deep Dive 而不是用提示词或文案代替。

FDA 采用强引导但可跳过：

- 永远显示当前覆盖范围与不可测量空间，不把权限拒绝显示为 `0 B`。
- 初始操作提供 `Open System Settings`；从系统设置返回后提供 `Check Again`，检查失败仍允许有限模式，不形成授权循环。
- 不在普通扫描中反复弹出系统授权提示。
- L2 内容读取采用每次 Deep Dive 会话最多一次的聚合授权 sheet。
- 永久敏感区 denylist 不提供 UI 绕过开关。

首次启动 canonical 暗/亮参考及候选评审见 [Onboarding and Permissions Internal Draw](../assets/ui-concepts/ONBOARDING-ROUND-1.md)。

## 6. Overview

### 6.1 默认内容层级

1. 顶部：卷名称、最近扫描时间、权限覆盖状态。
2. 三个主指标：`Free`、`Explained`、`Ready to Reclaim`。
3. `Space Ledger`：Known、Unknown、Unmeasurable 与 Free 的一致账本。
4. 两个模式入口：主操作 `Quick Scan`，次操作 `Deep Dive`。
5. `Top Opportunities`：最多三项，展示类别、大小、活动状态和建议。
6. 可折叠的趋势或最近结果，不在首屏塞满历史图表。

### 6.2 Space Ledger

Space Ledger 是主可视化，优先采用分段横条或简化 Storage Orbit，而不是完整 DaisyDisk treemap。必须：

- 同时用标签、数值和形状表达，不能只靠颜色。
- 明确区分 `Unknown` 与 `Unmeasurable`。
- Tooltip/VoiceOver 提供精确字节与采样时间。
- 数字使用 tabular figures，空间单位统一由格式化器产生。
- 点击区段进入带对应 filter 的 Scan 或 Investigations。

### 6.3 无快照与过期快照

- 无快照：使用品牌插画、两句以内说明和唯一主操作 `Run Quick Scan`。
- 快照过期：继续展示内容，在顶部加 `Scanned N days ago` 和 `Scan Again`。
- 扫描进行中：首页显示持续更新的摘要，但导航后仍能恢复原进度。

### 6.4 已批准的 Overview 构图

Overview 采用 `Orbit Ledger` 融合方向：以第二轮 A 的信息架构和内容层级为主体，吸收 B 的环形类别直标与功能性 Nautilus Probe。

- 首屏阅读顺序固定为：卷与三个主指标 → Storage Orbit 与 Space Ledger → Quick Scan / Deep Dive → Top Opportunities。
- Storage Orbit 保持中等尺寸，不抢占整页；Developer、Apps、Personal、System、Unknown 可通过短引导线直接标注，精确数据仍由 Ledger 和 accessibility summary 提供。
- Nautilus Probe 只定位在 `Explained` 与 `Unknown` 的调查边界，并可用短虚线轨迹表达当前调查方向；它不是装饰性吉祥物。
- 圆环是功能性的分层磁盘占用图，不采用“星座图”叙事；禁止星空背景、星座连线、散布星点和纯天文装饰。历史候选名 `Constellation` 不进入产品文案或设计语言。
- `Space Ledger` 继续承担完整账本职责，不能因环形直标而删除 `Unknown`、`Unmeasurable`、Free 或 reclaimability 维度。
- C 的高密度表格语言不用于 Overview 主体，保留给 Scan Results 和 Review。
- Dark 与 Light 必须共享同一构图和层级；Light 使用独立 semantic surface/text/border token，不做颜色反相。

## 7. Scan

### 7.1 双模式入口

`Quick Scan` 是默认主入口：确定性、无 Token、目标小于 5 分钟。`Deep Dive` 是可见但从属的二级入口：复用 Quick Scan 快照，耗时更长并使用 Codex。

若没有有效快照而用户直接选择 Deep Dive，系统先运行同一套 Quick Scan baseline，并在一个连续流程中说明当前阶段，不要求用户返回重新操作。

### 7.2 Quick Scan 进度

默认显示：

- 当前阶段，例如 `Mapping projects`；
- 已扫描范围和已发现候选；
- elapsed time 与可取消的 `Stop Scan`；
- 持续出现的分类摘要，避免长时间只显示 spinner。

停止后保留 partial snapshot，明确标注覆盖率和未完成范围。

### 7.3 动态分类

主分组按 artifact lifecycle，而不是写死工具列表：

- Package & Build Caches
- Rebuildable Project Artifacts
- Tool Runtimes & Images
- Updates & Temporary Files
- Large Repositories & History
- Unknown Large Consumers
- Protected

Node.js、Python、Rust、Go、Java、Android、Xcode、Next.js、Homebrew、Docker 等作为 ecosystem/tool/framework/project facets 与子项。规则库可以扩展，Agent 也可以发现未预置生产者；UI 不应为每种工具增加顶层导航。

### 7.4 结果行

每行至少包含：名称、路径摘要、allocated size、最近活动、来源/生产者、分类、恢复或重建提示。默认折叠路径和技术细节；支持 Reveal in Finder、Copy Path、View Evidence。

Known-rule 项目不显示 AI 装饰。规则 miss、生产者未知、证据冲突或体积异常的项目显示安静的 `Investigate with Codex` 次操作。

### 7.5 已批准的 Quick Scan 进度构图

Quick Scan 采用“Results Taking Shape + Stage Rail”：以渐进填充的 grouped outline/table 为主体，加入紧凑的五阶段过程说明。

- 阶段固定为 `Index Volumes`、`Map Projects`、`Classify Artifacts`、`Check Activity`、`Finalize Snapshot`；完成、当前、待执行必须同时用图标、文案和状态表达。
- 顶部只保留 Scope scanned、Candidates found、Measured、Elapsed 四个互不混淆的动态指标。
- 当前扫描范围使用单行 status strip，路径缩写并展示当前 facet；不输出滚动日志。
- 已完成分组显示稳定行和总量；当前分组显示 inline progress；未开始分组显示 `Pending` 和破折号，不构造假数据。
- `Stop Scan` 是中性次操作；旁边明确说明停止会保存 partial snapshot。停止不使用危险红色，也不触发清理。
- 扫描完成时复用同一表格位置和滚动模型进入 Scan Results，避免整页重排。
- Quick Scan 中不出现 Codex、Nautilus Probe、AI 徽标或 Agent 动效。

### 7.6 已批准的 Scan Results 构图

Scan Results 采用 grouped lifecycle outline 作为默认页，并提供按需右侧 Evidence Inspector。

- 默认列固定为 `Item / Path Summary`、`Last Active`、`Producer`、`Recovery`、`Allocated Size`、`Disposition`；Recovery 与 Disposition 不得混用。
- Results 不显示 checkbox，也不直接执行 Trash 或 Registered Action；用户进入 `Review Reclaim Plan` 后才进行执行选择。
- 顶部提供搜索和 All、Ready、Review、Unknown、Protected 过滤；`Scan Again` 为次操作。
- Unknown/rule-miss 项目可显示安静的 `Investigate with Codex`；known-rule 项目不带 Agent 装饰。
- Inspector 只读展示 producer、lifecycle、activity、recovery、supporting/missing evidence 和 exact path；允许 Reveal、Copy、View Evidence，以及证据不足时的 Investigate，不允许清理或改变 disposition。
- 底部保持 Ready、Review、Unknown 数字分离，唯一 filled CTA 为 `Review Reclaim Plan`。
- 双轴 Space Ledger 仅可作为折叠的 `Snapshot Summary`，不常驻占用默认首屏。
- Dark 与 Light 共享相同布局和安全边界，分别调校 semantic tokens。

## 8. Deep Dive / Investigations

### 8.1 预算选择

开始前提供三个清晰预算：

- `10 min · Focused`
- `30 min · Balanced`（默认）
- `60 min · Thorough`

同时说明这是上限而非必然耗时。高级 Token、探针次数和字节预算放入 disclosure，不进入主流程。

### 8.2 默认调查进度

默认界面保持简单，显示四阶段：

1. `Prioritize`
2. `Identify`
3. `Verify`
4. `Build Plan`

主区域显示调查覆盖率、已解释空间、剩余 `Unknown`、当前关注目标和最近发现。提供 `Pause`/`Resume`、`Stop` 和 `Investigation Details`，不提供聊天输入框或默认控制台。

已批准的构图以第二轮 B `Guided Journey` 为默认 Deep Dive：四阶段流程是主叙事，功能性圆环说明当前调查范围，当前目标卡解释正在核验什么。点击 `Investigation Details` 后进入 C 的右侧 Inspector 状态，并借用 A 更明确的 Probe 轨迹和当前目标强调。Inspector 关闭时不占据默认画布。

### 8.3 Investigation Details

Inspector 才展示：

- 当前目标及选择原因；
- 调用过的类型化探针及状态；
- 读取级别、读取字节和剩余预算；
- supporting evidence 与 counter-evidence；
- 尚未解决的问题；
- Adapter/Codex 降级信息。

工具活动使用用户可理解的摘要，例如 `Checked Git activity`，而非实时刷屏的原始 JSONL。

### 8.4 Agent 的可见表达

Agent 价值通过调查状态和证据变化体现，不通过全局聊天机器人或遍布界面的 sparkle：

- 调查前：未知候选提供 `Investigate with Codex`。
- 调查中：Nautilus Probe/轨道 locator 只出现在当前目标和整体进度上。
- 调查后：新识别项显示 `Discovered by Codex` 小徽标和证据摘要。
- 已确认规则项目不加 Codex 徽标。
- 用户可选择 `Remember This Finding`，将结构化事实写入 Local Knowledge；不会保存自由文本人格记忆。

Agent 对目录的解释固定回答：

1. What is it?
2. What created it and why is it here?
3. Is it active or referenced?
4. How much can actually be reclaimed?
5. What breaks, and how is it rebuilt or restored?
6. What evidence is missing?

### 8.5 停止与部分结果

预算耗尽、用户停止或证据无法增加时，仍生成部分报告。未完成项保持 `Unknown`，并提供 `Continue Investigation`，不得通过乐观文案暗示已经覆盖全盘。

## 9. Review Reclaim Plan

### 9.1 分组和默认选择

| Group | 默认选择 | 行为 |
| --- | --- | --- |
| Ready to Reclaim | 选中 | 仅审核规则支持、Policy 允许且默认进 Trash 的项目 |
| Review Recommended | 不选中 | 用户逐项理解证据后选择 |
| Protected | 禁用 | 活跃、veto 或明确应保留；活动状态作为原因/facet 展示 |
| Unknown | 禁用 | 证据不足，不允许执行 |
| Registered Actions | 不选中、独立分区 | 显示每个动作是 Reversible 还是 Permanent；永久动作单独明确确认 |

Agent-only rule miss 即使证据偏向可回收，也至少进入 `Review Recommended`，不能进入默认选中的 `Ready to Reclaim`。

### 9.2 Review row 与 Inspector

列表行优先简洁：checkbox、项目、最近活动、恢复方式、动作类型、大小。选中项目后 Inspector 展示：

- Why this recommendation
- Evidence and counter-evidence
- Activity and dependencies
- Recovery/rebuild instructions and cost
- Exact path and Reveal in Finder
- Policy decision and blocked reasons

### 9.3 已批准的 Review 构图

Review 采用第二轮 A `Decision Table` 作为默认页面，C `Evidence Inspector` 作为按需审核状态，并吸收 B 的分组一句话解释。

- 默认页保持原生高密度 grouped outline/table；列固定为 Item、Last Active、Recovery、Action、Size，便于快速横向比较。
- 五个组必须保持独立，不合并 `Protected` 与 `Unknown`，也不把 `Registered Actions` 混入普通 Trash 项目。
- 分组标题使用简短辅助说明：`Reviewed rules · Moves to Trash`、`Check evidence before selecting`、`Active or policy blocked`、`Insufficient evidence · Will not be processed`、`Separate confirmation`。
- 默认画布不常驻 Inspector；聚焦行或使用 `⌥⌘I` 后在右侧打开。Inspector 只提供证据、反证、活动、恢复、Policy 与 Reveal/Copy 等只读能力，不提供清理、删除或勾选动作。
- 行的 focus/highlight 与执行 selection 是两种独立状态。即使 Inspector 正在显示 `Review Recommended` 项目，该行仍保持未勾选。
- `Discovered by Codex` 只表示证据来源，不改变分组、风险、置信度或默认选择。
- Dark 与 Light 使用完全相同的结构和安全状态；分别调校 surface、text、border 和 semantic color，不做简单反相。

### 9.4 最终确认

- 底部固定 bar 展示选中数量、预计处理、Trash 量与永久 Registered Action 预计释放，不能合并成一个“释放空间”数字。
- 普通项目主操作使用 `Move N Items to Trash`。
- Registered Action 在独立 sheet 中按 action type 聚合确认；永久动作使用明确危险语义和不可撤销说明，可逆动作显示恢复方式。
- v1 不自动清空 Trash，也不提供“失败后永久删除”。

## 10. Cleanup Result 与 History

Cleanup Result 是 `Scan` 工作流页面，保持 Sidebar 中 `Scan` 选中，不新增 destination。默认完成页采用 `Reversible First` 层级：第一眼先说明实际动作、可恢复性和恢复入口，再按需展开计量与审计。

结果页面必须区分：

- Candidate logical/allocated bytes
- Executor processed bytes
- Moved to Trash
- Permanently released by registered actions
- Free-space delta
- Unexplained delta

已批准的默认构图：

- Header 显示 `Cleanup Result`、终态和 Manifest 保存状态，不使用超大成功图标。
- Hero 使用字面动作 `N GB moved to Trash`，同时显示 item count 与 `Recoverable until Trash is emptied`；`Open Trash` 只在此出现一次。
- `Processed`、`Permanently Released` 与 `System Observation` 使用三个独立摘要区域，不求和、不组成 `Reclaimed` 总数。
- `Free Space Changed` 与 `Unexplained Delta` 同属 `System Observation`，必须显示采样来源/时间，并注明 `Not attributed to a single action`。
- Execution Results 展示 Item、Action、Result、Size、Recovery；行与所有汇总必须来自同一 immutable Cleanup Manifest，不允许 View 独立拼接或重算出另一套总数。
- `Accounting Details` 默认折叠，展开后显示 Selected、Processed、Trash、Permanent 与 Observed 的 plan/actual ledger。
- `View Manifest` 打开审计时间线和按需 Inspector；默认结果页不展示原始日志或 JSON。
- Footer 只保留 `View Manifest` 次操作与一个主操作 `Done`。

部分失败沿用同一页面骨架：

- `Completed with issues` 使用中性 amber，并同时展示 succeeded 与 failed group；不把整个页面染红。
- 已成功的 Trash 动作保持有效和可恢复，不因其他行失败而暗示自动回滚。
- Trash 失败行明确 `Original remains in place`，只进入 failure details；绝不提供永久删除 fallback。
- Retry 只有在重新验证仍可执行后才出现，否则返回 Review。
- 即使执行完全失败，也尽可能保存 Manifest；Manifest 持久化本身失败必须单独报告。

提供 `Open Trash`、`View Manifest`、`Done`。不要用彩带或夸张庆祝；完成态只使用一次 200–300 ms 的克制 opacity/scale 过渡，Reduce Motion 下直接更新。

已批准候选评审、partial 状态与 Dark/Light canonical 见 [Cleanup Result Internal Draw](../assets/ui-concepts/CLEANUP-RESULT-ROUND-1.md)。

History 按 session 展示 Quick Scan、Deep Dive、snapshot/report 和 Cleanup Manifest，采用原生 master-detail 构图：App Sidebar 继续选中 `History`；主区域左侧使用 350–400 pt session navigator，右侧显示所选记录详情。

已批准的默认构图与行为：

- Header 提供 search、type filter、date range 与次操作 `Storage Trend`；History 默认没有 filled primary action。
- Navigator 按 `Today`、`Yesterday`、`Earlier` 分组。每行显示 type、timestamp、terminal status、一个关键指标和 retention countdown；默认选中最新记录。
- Detail 是选中 immutable record 的类型化投影。Cleanup Manifest 详情继续区分 succeeded、failed、Moved to Trash、Permanently Released、Free Space Changed 与 Unexplained Delta。
- `Related Records` 只表示证据 lineage，不表达扫描、调查、清理与空间变化之间的因果。
- `Export Record…` 与 `Delete Record…` 位于 detail footer。Delete 必须确认，并明确删除记录不会改变磁盘文件、Trash 或既有清理结果。
- v1 不提供 `Adjust Retention`；只展示默认 TTL、精确 expiry 和立即删除能力。

`Storage Trend` 是按需 History substate，不常驻默认页面：

- 至少四个可比较 snapshot 才使用 line chart；不足时改用带日期的 metric rows。
- Used/Free 除颜色外还使用不同 line style 与直接标签，并提供 keyboard tooltip、VoiceOver summary 和 `Show Data Table`。
- Quick Scan、Deep Dive、Cleanup Manifest 只作为时间轴 marker；固定显示 `Events mark when records were created. They do not prove what caused a storage change.`。
- v1 不显示 forecast、anomaly alarm、实时 streaming 或暗示后台采集的动画。

Evidence、scan session、snapshot、investigation 与报告默认 7 天，Cleanup Manifest 默认 90 天；用户可以立即删除。Manifest 的 linked evidence 可以先到期，届时详情显示 `Evidence expired`，但最小 Manifest 的 Action ID、Policy disposition、计量、结果和错误继续保留到自身 expiry。记录损坏或过期只影响对应行，不阻断整个 History。

路径仅本机保存；导出时将 canonical home 前缀替换为 `~`，并提醒剩余项目名/子目录仍可能具有识别性。空 History 显示 `No history yet` 与单一 `Start Quick Scan`，不暗示后台会自动产生记录。

已批准候选评审、Storage Trend、retention/degraded 状态与 Dark/Light canonical 见 [History Internal Draw](../assets/ui-concepts/HISTORY-ROUND-1.md)。

## 11. Local Knowledge，而非自由记忆

Stornaut 需要本地结构化知识，但不需要会自由联想的 Agent Memory。

- 持久化 Local Knowledge 只位于应用拥有的 `Application Support`；`Caches` 只保存可丢弃的扫描衍生物，不建立 `~/.stornaut` Global Workspace。
- 可保存：用户确认的 producer 映射、路径范围偏好、保留决定、忽略规则、已验证恢复方法和 provenance。
- 不保存：模型思维链、原始敏感片段、聊天人格记忆、未经用户确认的永久 `Ready to Reclaim` 结论。
- 新文件事实、活动变化和规则版本更新必须使旧结论 stale。
- `Remember This Finding` 默认只创建保守映射；不能降低 denylist/veto 或跳过 Policy Gate。

## 12. 视觉系统：Native Observatory

### 12.1 风格

整体采用原生 macOS 的清晰层级、system materials、SF Symbols 和 restrained depth，辅以“深海观测站”品牌气质。避免整屏玻璃拟态、霓虹赛博朋克、卡通清理器、营销型渐变和大量圆角卡片套卡片。

### 12.2 品牌色：Deep Ocean Evidence

| Token | Hex | 用途 |
| --- | --- | --- |
| Abyss Background | `#07152E` | App icon、暗色品牌展示面 |
| Deep Indigo | `#3F469A` | 亮色界面品牌结构、暗部层次 |
| Observatory Indigo | `#6573E6` | 主品牌和 selection accent |
| Probe Cyan | `#32D6F4` | 当前调查、新发现、活动 locator |
| Evidence Amber | `#FFB547` | 极少量证据 beacon |
| Signal White | `#EAFBFF` | 暗色前景和高光 |

规则：

- 组件代码使用 semantic tokens，不直接散落 raw hex。
- Cyan 只表示正在调查或新发现，不表示 `Ready to Reclaim`。
- Amber 证据点不能与 warning 混用；warning 使用系统语义色并带图标/文字。
- Risk、success、error 使用系统动态色，且必须有非颜色表达。
- Light/Dark 分别调校对比度，不采用简单颜色反转。

### 12.3 排版、间距与图标

- 使用系统字体与 Dynamic Type；数据使用 monospaced/tabular digits。
- 正文默认不小于 13pt；关键正文与按钮优先 14–16pt。
- 基于 4pt 网格，常用间距 8/12/16/24/32pt。
- 可交互目标至少 44×44pt，紧凑表格行也必须提供足够点击区域。
- 使用一致的 SF Symbols 线条语言；品牌 Nautilus Probe 不替代普通功能图标。

## 13. Logo 与品牌图形

正式方向为 `H — Nautilus Probe`。它表达储存层、调查探针和被证据照亮的未知区域，而不是自动删除。

- App Icon 使用稳定深色 tile 与适度材质。
- Light UI 使用 Deep/Observatory Indigo 平面标记。
- Dark UI 使用 Pale Indigo/Cyan 标记，不能依赖 glow 才可辨认。
- 微尺寸从单色 silhouette 派生。
- 最终生产资产必须矢量重绘并测试 16–1024px。
- G — Abyssal Beacon 可作为 Deep Dive 的功能插画语言，但不是第二个 Logo。

概念资产与生产要求见 [Brand Concept Prompt Set](../assets/brand-concepts/PROMPTS.md)。

## 14. Motion 与状态反馈

- 动效只表达扫描、调查推进、层级展开和状态变化。
- 常规微交互 150–250ms；复杂转场不超过 400ms。
- 同一视图同时运动的关键元素不超过两个。
- 扫描超过 300ms 显示确定或不确定进度，不用无限装饰性动画代替反馈。
- Orbit/Probe 动画可表达当前调查目标，但必须可中断。
- 完整支持 Reduce Motion：用 crossfade、静态阶段和数值更新替代轨道移动。

## 15. Accessibility 与键盘

- 正常文字对比至少 4.5:1，大字号至少 3:1。
- 支持 VoiceOver、Increase Contrast、Reduce Transparency、Reduce Motion 和系统字号。
- 图表提供可访问摘要；风险和状态不只靠颜色。
- 键盘顺序与视觉顺序一致，所有关键动作可由键盘完成。
- 建议快捷键：`⌘R` Quick Scan、`⇧⌘R` Deep Dive、`⌥⌘I` Inspector、`⌘,` Settings、`Esc` 取消 sheet/停止确认。
- 取消长任务必须二次确认任务影响，但不能制造无法退出的 modal trap。

## 16. 核心文案规则

- 默认英文，使用普通开发者能理解的短句。
- 避免 `junk`、`magic clean`、`100% safe`、`AI says`。
- 使用 `Ready to Reclaim`、`Review Recommended`、`Protected`、`Unknown`。
- 区分 `Move to Trash`、`Permanently Clean` 和 `Free Space Changed`。
- 所有错误说明“发生了什么 + 当前影响 + 如何恢复”。
- Agent 摘要使用本地化模板包裹结构化证据，避免把未经处理的模型 prose 直接放进 UI。

## 17. 关键状态与降级

每个主要页面必须设计：empty、loading、partial、success、cancelled、permission-limited、Codex-unavailable、Adapter-degraded、stale、error。

所有页面采用统一的 **page-preserving recovery**：保留已完成且仍有效的结果，精确标记未完成/不可测/阻断/stale 范围，用一句短文案说明影响，只给出安全恢复动作，技术细节放在 disclosure 或 Inspector。除 stale execution preflight 这类必须阻断写操作的决策外，不用全屏 modal 或独立 Recovery Center 替换原页面。

状态语义：limited、partial、budget exhausted 与 stale 使用 neutral/amber；只有具体操作失败才局部使用 red；Policy/safety 阻断使用 lock/shield 与 neutral/indigo。图标、状态词与影响说明必须同时存在，不能只依赖颜色。不可测量范围显示 `Unknown` 或 em dash，绝不显示 `0 B`。

特别要求：

- Codex 缺失时 Deep Dive 显示诊断与修复入口，Quick Scan 不受影响。
- FDA 缺失时显示 limited coverage，不显示失败或零占用。
- Adapter 缺失只影响对应证据，不阻断报告。
- Agent Schema 错误使项目保持 Unknown。
- 执行前 stale 使 checkbox 失效并要求重新验证。
- Trash 失败显示原文件仍在原处，绝不提供自动永久删除 fallback。
- Deep Dive safety check 失败时四个调查阶段保持 `Not started`，不得显示 explained gain、finding count 或 Ready 结论；只提供检查诊断和 Quick Scan fallback，不提供 bypass。
- Quick Scan 停止后保存带覆盖率与 unfinished roots 的 partial snapshot；Deep Dive 停止/预算耗尽后保存 verified partial report，未完成目标保持 Unknown。
- stale preflight 使用原生 sheet 冻结 Review context，只列变化项；`Refresh Affected Items` 或 `Cancel`，没有 `Proceed Anyway`。Cancel 后计划仍为 stale 且不可执行。
- Cleanup Result 的行级失败保留成功行与恢复信息。Manifest 持久化失败必须与 action 失败分开报告，成功保存/导出前不能显示普通完成态。
- linked Evidence 过期后保留最小 Cleanup Manifest；单条损坏 History 只隔离自身，不阻断其他记录。
- Cleanup 只允许在动作开始前或类型化动作之间取消；单个动作开始后显示 `Stop After Current Action`，具体原子性以 Trash/Action lifecycle Spike 与 ADR 为准。

五组批准的 Dark/Light 状态构图、行为矩阵、取消与无障碍契约见 [Resilience States — Cross-flow Round 1](../assets/ui-concepts/RESILIENCE-STATES-ROUND-1.md)。

## 18. 组件清单

实现时优先形成可复用原生组件：

- `SpaceLedgerView`
- `MetricTile`
- `ScanModeCard`
- `CoverageBadge`
- `ArtifactGroupRow`
- `EvidenceSummaryView`
- `InvestigationStageView`
- `ProbeActivityRow`
- `ReclaimDispositionLabel`
- `ReclaimPlanRow`
- `SpaceAccountingSummary`
- `CleanupResultHero`
- `ExecutionResultRow`
- `AccountingDetailsDisclosure`
- `HistorySessionRow`
- `HistoryRecordDetail`
- `RetentionBadge`
- `StorageTrendView`
- `PermissionStatusCard`
- `EmptyStateView`

组件只消费 ViewModel/领域模型，不直接启动 Codex、扫描文件或执行动作。

## 19. 设计资产的使用边界

UI 概念图位于 `docs/assets/ui-concepts/`，包括 Onboarding、Overview（早期资产名 Dashboard）、Quick Scan、Scan Results、Deep Dive（早期资产名 Deep Investigation）和 Review 的暗色/亮色候选。它们用于：

- 理解 Native Observatory 的密度与气质；
- 比较平衡型、视觉型和 inspector 型布局；
- 为 SwiftUI 原型提供视觉参考。

`overview-round2-a-orbit-ledger-dark.png`、`overview-round2-b-constellation-dark.png` 和 `overview-round2-c-native-console-dark.png` 是第二轮 Overview 构图抽卡稿。用户已在 2026-08-08 批准 A+B 融合：A 为主体，只吸收 B 的环形直标与 Probe；C 的高密度表格保留给 Scan Results 和 Review。B 的历史名 `Constellation` 仅用于追溯资产，星座/星图视觉明确不采用。

`overview-canonical-dark.png` 与 `overview-canonical-light.png` 是该已批准方向的配对视觉参考。它们确定构图、密度、主题关系与 Agent 表达边界，但仍不是逐像素实施规格；图像模型产生的示例数字、换行、图标和细微对齐漂移不得直接固化到代码。

`deep-round2-a-probe-focus-dark.png`、`deep-round2-b-guided-journey-dark.png` 与 `deep-round2-c-evidence-inspector-dark.png` 是基于 canonical Overview 语法生成的第二轮 Deep Dive 抽卡稿。用户已批准 B 作为默认构图、C 作为按需 Inspector，并借用 A 的 Probe 轨迹；图像仍只作为非逐像素视觉参考。

`review-round2-a-decision-table-dark.png`、`review-round2-b-decision-cards-dark.png` 与 `review-round2-c-evidence-inspector-dark.png` 是第二轮 Review 抽卡稿。用户已批准 A 作为默认高密度分组表、C 作为按需 Evidence Inspector，并只吸收 B 的分组一句话解释；B 的卡片布局、合并分组和错误侧栏选中状态不采用。

`review-canonical-dark.png` 与 `review-canonical-light.png` 是已批准默认 Review 页的主题配对参考。`review-round2-c-evidence-inspector-dark.png` 暂作已批准 Inspector 行为参考。它们确定层级、信息密度、默认选择与安全动作分离，但仍不是逐像素实现规格；示例条目、数字、图标、换行和细微对齐漂移不得固化到代码。

`quick-scan-round1-a-stage-rail-dark.png` 至 `quick-scan-round1-e-results-taking-shape-dark.png` 是 Quick Scan 的五张内部抽卡稿。已批准 E 为主体并吸收 A 的五阶段 rail；`quick-scan-canonical-dark.png` 与 `quick-scan-canonical-light.png` 是主题配对参考。B 的红色 Stop、D 的错误 lifecycle 均属明确拒绝的图像漂移。

`scan-results-round1-a-lifecycle-outline-dark.png` 至 `scan-results-round1-e-ledger-results-dark.png` 是 Scan Results 的五张内部抽卡稿。已批准 A 作为默认页、D 作为按需 Inspector，并只允许 E 的 ledger 进入折叠 Summary。`scan-results-canonical-dark.png` 与 `scan-results-canonical-light.png` 是默认页主题配对参考。D 中的 `AI` badge、红色 missing-evidence 以及任何生成图里的 Recovery/Disposition 混用均不得实现。

`onboarding-round1-a-guided-focus-dark.png` 至 `onboarding-round1-e-native-sheet-dark.png` 是首次启动与权限的五张内部抽卡稿。已批准 A 的三步单焦点结构，并把 C 的 Full/Limited 后果对比压缩进第二步；B 只可借鉴为 Settings 的状态汇总，D 只可借鉴为明确标注的帮助示意，E 不作为首次启动结构。`onboarding-welcome-canonical-*`、`onboarding-full-disk-access-canonical-*` 与 `onboarding-connect-codex-canonical-*` 是三步暗/亮主题配对参考。生成图里的 Codex 路径、版本和能力状态都只是示例，必须由实时检测与技术证据驱动。

`cleanup-result-round1-a-accounting-ledger-dark.png` 至 `cleanup-result-round1-e-partial-outcome-dark.png` 是 Cleanup Result 的五张内部抽卡稿。已批准 B 作为默认完成页、A 作为计量契约、E 作为 partial/error 状态；C 下沉为折叠 `Accounting Details`，D 下沉为 `View Manifest`。`cleanup-result-canonical-dark.png` 与 `cleanup-result-canonical-light.png` 是默认成功态主题配对参考。所有图中的数字只能作为布局 fixture，生产汇总与行必须来自同一 Cleanup Manifest。

`history-round1-a-unified-timeline-dark.png` 至 `history-round1-e-master-detail-dark.png` 是 History 的五张内部抽卡稿。已批准 E 作为默认 master-detail、A 的日期分组进入 navigator、C 作为按需 `Storage Trend`；B 仅贡献筛选/排序思路，D 卡片流不采用。`history-canonical-dark.png` 与 `history-canonical-light.png` 是默认所选 Cleanup Manifest 的主题配对参考。生成图里的 TTL 数字、日期和记录内容只是 fixture；生产状态必须来自持久化时间戳与 immutable record。

`settings-round1-a-sidebar-privacy-dark.png` 至 `settings-round1-e-local-knowledge-dark.png` 是独立 Settings 的五张内部抽卡稿。已批准 A 作为原生六项 Settings 侧栏外壳、C 的 Setup Status 进入 General、E 的结构化列表用于 Local Knowledge；B 的工具栏仅作为 Permissions 内容参考，D 单页折叠结构不采用。`settings-general-canonical-*`、`settings-codex-deep-dive-canonical-*` 与 `settings-local-knowledge-canonical-*` 是三组暗/亮主题参考。生成图中的路径、版本、日期、数量和 finding 都是 fixture；尤其不得把 `Codex Installed` 当作安全验证，也不得从概念图推导通用目录“safe to remove”。

`resilience-*-canonical-dark.png` 与 `resilience-*-canonical-light.png` 是跨流程恢复状态的五组主题配对参考，覆盖 limited coverage、Deep Dive safety blocked、stale plan、partial investigation 与 expired evidence/corrupt history。它们共同定义 page-preserving recovery。`resilience-deep-dive-safety-blocked-draft-dark.png` 是明确拒绝的审计稿：它把 stale 成功指标留在未开始的调查上，不得实现。完整选择依据和状态矩阵见 [Resilience States](../assets/ui-concepts/RESILIENCE-STATES-ROUND-1.md)。

它们不用于：

- 直接逐像素照抄；
- 增加规格之外的 sidebar destination；
- 引入 paywall、chat、terminal 或多余 feature；
- 覆盖本规格的文案、状态、安全和 selection 默认值。

## 20. v1 验收标准

1. App 不创建 MenuBarExtra，不后台驻留，不定时扫描。
2. 四个顶层 workspace 与独立 Settings 符合 macOS 导航习惯。
3. 无 Codex/FDA/Adapter 时均有清晰降级路径。
4. Overview 能在 10 秒内被用户读懂：Free、Explained、Ready to Reclaim、Unknown。
5. Quick Scan 不调用模型，并持续呈现进度和部分结果。
6. Deep Dive 默认界面无聊天/控制台，但可在 Inspector 审核工具和证据。
7. Agent 只在未知调查和新发现上可见，不污染 known-rule 项目。
8. Review 默认只选择规则与 Policy 都允许的 Trash 项目。
9. Registered Actions 独立、未预选；永久动作明确不可撤销性，可逆动作明确恢复方式。
10. 空间数字不混淆候选、处理、Trash、永久释放和 free-space delta。
11. Light/Dark、English/`zh-Hans`、VoiceOver、键盘和 Reduce Motion 均可用。
12. 所有取消、失败与 stale 状态 fail closed，不产生隐式写操作。
13. 局部失败保留仍有效的结果；不可测量范围不显示为零，stale 与 safety-blocked 状态没有 bypass。
14. Evidence 过期与单条 History 损坏不破坏仍在保留期内的最小 Manifest 或健康记录。

## 21. 明确不做

- 菜单栏伴侣、后台监测、通知和自动清理。
- 聊天式 Agent 主界面或调查控制台。
- 完整 treemap/disk map 编辑器。
- 远程账号、云同步、遥测和在线规则市场。
- 自由文本 Agent Memory 或 `~/.stornaut` 工作区。
- 通过高频弹窗逐文件授权。
- 用动画、吉祥物或 AI 徽标替代证据。

任何改变信息架构、默认选择、安全确认、Agent 可见边界、Local Knowledge 或后台行为的实现，都必须先更新本规格并获得用户确认。
