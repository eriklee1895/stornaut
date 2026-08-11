# Stornaut Agent 磁盘治理设计规格

> 初版：2026-08-06；最近更新：2026-08-11
> 状态：用户已批准  
> 目的：记录产品头脑风暴中确认的设计基线；详细需求见 [PRD](../product/PRD.md)，实现边界见 [技术架构](../architecture/system-architecture.md)，完整界面规范见 [UI/UX 设计规格](ui-ux.md)。

## 0. 命名决策（2026-08-07）

- 正式名称：**Stornaut**
- 读音：`STORE-naut`（/ˈstɔːr.nɔːt/）
- 构词：`storage + -naut`，表达“深入存储空间、调查未知占用的探索者”
- 英文标语：*Map the known. Investigate the unknown. Reclaim with evidence.*
- 产品/App 使用 `Stornaut`；仓库、CLI、配置前缀使用 `stornaut`
- Swift 模块使用 `StornautApp`、`StornautCore`、`StornautCodex`

名称不直接包含 AI/Codex。智能调查由定位、标语和 Deep Dive 能力表达，使项目未来可以升级模型与运行时而不必再次改名。

## 1. 设计问题

现有 macOS 清理工具已经积累了大量有价值的工程经验：原生 UI、权限引导、developer cache 路径、项目 artifact taxonomy、进程保护、Trash 和官方清理命令。Stornaut 不应从零重造这些能力。

但固定规则也有结构性盲区：它们无法现场理解非标准目录、跨工具工作链、空间统计差额和用户个人项目状态。真实案例表明，通用 Agent 可以通过动态调查释放固定工具遗漏的大量空间；随后 Mole 又补充发现 Agent 未覆盖的已知类别。

因此设计目标是把两者组合，而不是互相替代。

## 2. 已批准方案

### 2.1 产品形态

- 原生 Swift 全栈 macOS App
- SwiftUI 为主，必要处使用 AppKit/Foundation/POSIX
- 不在没有性能证据时引入 Rust Scanner
- GitHub Public 开源，个人自用优先
- MIT License
- 首发只面向开发时最新稳定版 macOS 与 Apple Silicon，不承担 Intel/旧系统兼容成本

### 2.2 Agent Runtime

- v1 只支持 Codex
- 使用用户已安装版本，不捆绑、不自动下载
- Codex 作为独立子进程，通过 JSONL 和 JSON Schema 通信
- Codex 是调查指挥官，不拥有执行权

### 2.3 双模式

快速扫描：Swift 确定性扫描和规则分类，不调用模型。

深度调查：复用快速扫描快照，由 Codex 按科学方法动态编排只读探针。

### 2.4 工具策略

采用“内置核心 + 可选工具 Adapter”：

- 核心扫描、规则、安全和执行不依赖 Mole/kondo 等工具
- Agent 可使用直接只读文件系统、shell/unified exec、live search、browser/direct fetch、image、skills/subagents 与公共互联网；Probe Broker 继续提供类型化、可预算、可审计的优先证据能力
- 外部工具不能直接执行清理
- Stornaut 不设置 Bash/executable/public destination-domain allowlist，也不因无法形成完整 Codex tool allowlist 而关闭调查能力；强制边界只约束本地写入、私网/Unix socket 和清理执行权

### 2.5 安全与隐私

- 元数据优先
- Codex 可直接读取调查所需的 README/manifest/lockfile 等文件；文件内容可能进入模型上下文，UI 明确披露这一点
- 主动采集凭据、绕过 TCC、访问 localhost/私网或任意 Unix socket 仍不属于调查范围
- Agent 只生成结构化 CleanupPlan
- Swift Policy Gate 可以否决任何 Agent 结论
- Executor 仅接受 Trash 或 Action Registry 中审核过的 Registered Action
- Evidence Store 默认保留 7 天；原始内容片段不落盘
- 原始 Codex JSONL 正常结束即删除，崩溃残留最长 24 小时
- Cleanup Manifest 默认保留 90 天且不包含原始读取内容

### 2.6 上游学习

每个 Epic 强制执行 Reference Study Gate。Coding Agent 必须在实现前研究对应上游、记录许可证边界、独立实现并完成行为 Benchmark。

## 3. 科学调查协议

Agent 没有固定清理轨迹，但必须遵循固定状态机：

```text
OBSERVE
  建立全盘和候选事实
HYPOTHESIZE
  提出生产者、用途、活动状态和可重建性假设
PROBE
  选择成本最低、信息增益最高的只读工具
FALSIFY
  主动寻找反证、活动引用和危险子路径
QUANTIFY
  估算可回收空间、重建成本和副作用
CLASSIFY
  输出 Ready to Reclaim / Review Recommended / Protected / Unknown disposition，并独立标注风险、置信度与证据缺口
STOP
  达到覆盖率或预算；剩余目标保持 Unknown
```

方法固定使调查可测试；轨迹动态使 Agent 能处理规则未知的真实机器。

## 4. 核心数据流

```text
Quick Scan
  Surveyor → Knowledge Base → Activity Protection → Evidence Store → UI

Deep Dive
  Evidence Store → Candidate Planner → Codex Commander
  Codex Commander ↔ Direct Read / Shell / Live Web / Browser / Agent Tools
  Codex Commander ↔ Probe Broker ↔ Built-in Probes / Optional Adapters
  Codex Commander → EvidenceReport + CleanupPlan

Execution
  CleanupPlan → Policy Gate → User Approval → Executor → Manifest/Accounting
```

Quick 和 Deep 共用同一 Snapshot、Evidence Store、分类 Schema、Policy Gate 和 Executor，避免两套系统产生不一致。

## 5. UI 设计原则

- 两个明确入口：Quick Scan、Deep Dive
- v1 是按需启动的单窗口 App，不做 MenuBarExtra、后台监控或定时扫描
- 主导航固定为 Overview、Scan、Investigations、History；Settings 独立
- 深度调查默认只显示阶段、覆盖率、预算、当前目标和发现；工具活动按需进入 Inspector
- 不提供聊天式主界面或默认调查控制台
- 不展示模型隐藏思维链，只展示可复核证据摘要
- Agent 只在未知候选、当前调查和新发现中可见；known-rule 项目不显示 AI 装饰
- 直接只读调查不逐文件弹窗；启动 Deep Dive 时一次性说明模型上下文与公共联网的数据边界
- Ready to Reclaim / Review Recommended / Protected / Unknown 清晰区分；风险与置信度独立表达
- 同时展示逻辑大小、实际处理、Trash、永久释放和 free-space delta
- Codex 或 Adapter 缺失时说明降级，不阻断 Quick Scan
- 默认 English，支持 `zh-Hans`；System/Light/Dark 均完整支持
- 使用应用拥有的结构化 Local Knowledge，持久化数据只在 Application Support，衍生缓存才进入 Caches；不建立自由文本 Agent Memory 或 `~/.stornaut` workspace
- Nautilus Probe 是批准的 Agent/调查品牌表达，只用于当前 Deep Dive 目标和证据进展，不装饰已知规则结果

## 6. 错误与安全原则

- fail closed：错误保持 Unknown 或拒绝执行
- Trash 失败不回退永久删除
- Agent 输出格式错误不自动修正为 Ready to Reclaim
- 执行前变化使 CleanupPlan 失效
- 清理 protected-path policy、veto 和 Action Registry 不能被用户提示词或 Agent 绕过
- Stornaut Executor/Registered Action 保持固定 executable/args；Codex 调查 shell 不做命令 allowlist，但整个进程树限时、限输出、可取消且不可写
- Broker 调用与所有执行写审计记录；direct/web 证据标记来源和覆盖率，不冒充 Broker 审计

## 7. 验证策略

1. 匿名化真实案例作为端到端 fixture。
2. 对 Mole、ClearDisk、kondo 做覆盖和行为 Benchmark。
3. 对 devklean/Cluttered 的安全与活动保护场景做回归测试。
4. 对 Agent 进行 prompt injection、写入尝试、凭据非持久化和 Ready-to-Reclaim/veto 对抗测试。
5. 在真实 460GB Mac 上测量扫描性能、内存和取消。
6. 验证 Codex 完整调查工具与公共联网可用时，整个进程树仍不可写且没有 Executor 路径。

## 8. 主要取舍

### 为什么允许 Agent 直接只读 Shell 与公共互联网

未知目录、长尾工程类型和动态工具链无法由固定 Probe schema 或域名白名单
充分覆盖。个人自用场景将调查质量置于数据保密之上，因此保留 Codex 的完整
Agent 工具面；风险控制放在 OS 强制不可写、no-Executor、Swift Policy Gate 与
人工选择，而不是削弱读取、搜索和推理能力。Probe Broker 仍用于需要稳定
结构、预算和审计的证据。

### 为什么不只做固定规则

这会退化成另一个开发者 Cleaner，无法复现真实案例中调查未知目录的核心价值。

### 为什么不默认每次 Deep Dive

日常场景不值得支付时间和 Token。双模式让用户在速度与彻底性之间明确选择。

### 为什么 v1 不使用 Rust Scanner

Swift 足以先验证需求和 macOS 集成。只有真实性能 Benchmark 失败，才值得承担 FFI、签名、打包和调试复杂度。

## 9. 实施前置条件

- 完成 Codex 路径、版本、JSONL 和 Schema Spike
- 完成 capability-first runtime Spike：direct read/shell/live web/browser 可用，进程树不可写且无 Executor 路径
- 完成 Swift Surveyor 性能 Spike
- 完成 Probe Broker 协议 Spike
- 完成 Trash 和首个 Registered Action Spike
- 产出分阶段实施计划后再进入完整功能开发

## 10. 批准记录

完整、规范化的批准决策以 [PRD 第 15 节](../product/PRD.md#15-已批准决策) 为唯一登记表。本节仅保留讨论过程中的里程碑，不作为第二份独立规范。

用户已逐项确认：

- 全盘调查指挥官
- Quick Scan + Deep Dive
- 内置核心 + 可选只读 Adapter
- 仅支持 Codex
- 原生 Swift 全栈 + Codex 子进程
- 使用用户已安装 Codex
- Codex capability-first：完整只读 Agent 工具与公共联网，Swift 独占所有写与清理执行权
- Trash + Action Registry 中审核过的 Registered Action
- capability-first 直接只读调查 + 首次数据边界披露 + 清理 protected-path policy
- 每个 Epic 强制学习上游项目
- 按需启动的原生单窗口 App，v1 无菜单栏伴侣或后台检测
- 四 workspace 信息架构、English + `zh-Hans`、System/Light/Dark 和 evidence-on-demand UI
- 结构化 Local Knowledge，不使用自由文本 Agent Memory

本规格构成 Coding Agent 的设计边界。ADR 0004 已批准的直接只读与公共联网能力不得被实现计划重新缩减；任何扩大 Agent 写入/执行权、本机私网访问、清理 protected-path policy、Executor 动作范围或双模式产品结构的实施方案，都必须先更新 PRD/ADR 并获得用户确认。
