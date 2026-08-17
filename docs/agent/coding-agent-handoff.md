# Stornaut Coding Agent Handoff

> 面向接手实现的 Coding Agent  
> 最近更新：2026-08-16
> 当前状态：产品、Agent、UI 功能交互与品牌基线完成；Epic 0–1 evidence
> gate 已完成；Epic 2–4 Tasks 9–26 通过最终 unified verifier 并归档；
> Phase C deterministic Epic 8 详尽 plan 已于 2026-08-11 获用户批准，
> Tasks 27–28 已完成；ADR 0004 回顾发现的旧 Broker-only Runtime 漂移已由
> capability-first Runtime R1–R6 gate 关闭；
> R1–R2 已完成；R2 结论为 `configurationReady`；R3 的原 process-group
> candidate 因 new-session descendant escape 被拒，用户批准的 audit-session
> lifecycle supervisor 随后通过 final privileged composition，R3 得出
> `behaviorReady` candidate；用户 review 后已继续。R4 已完成 strict
> Investigation Envelope v2、Swift identity binding、ProcessSupport/ProbeBridge
> module separation 与 structural no-Executor verifier，结论为
> `protocolReady`。用户明确当前只需个人本机运行，不要求分发；R5 已采用
> root-only `/Library/Application Support/Stornaut/` App + fixed plist 的
> local-only lifecycle candidate。provider/schema/raw-event compatibility、
> closed auth projection 与 machine verifier 已实现；官方 `openai` +
> ChatGPT subscription `gpt-5.6-luna` worker 已观察 9/9 capabilities，
> errno-only IPv4/IPv6/
> private/local/Unix denial 与 worker containment 6/6。2026-08-13 post-fix
> review 进一步关闭 command/image/subagent evidence forgery、random denial
> token 映射、privacy-preflight outer/inner launcher 漂移与漏 staged
> `codex-code-mode-host`；后续独立审查又修复 current-build binding、XPC
> one-shot continuation、external-state priority 与 subagent sender identity；
> final live fixes 关闭 vanished-process errno 分类、strict-schema `$ref`
> sibling、direct-read fixed command 漂移和 shell gate Codable shape。
> 最新 Codex 227 passed + 8 explicit opt-in skipped、Lifecycle 60/60、
> serial 537/537、headless selected
> 534/534、Xcode/Release/no-Executor gates 通过。历史
> TeamoRouter/`usageLimitExceeded`
> 仅为 superseded 调试证据。
> current-source signed App/helper machine report 已得出 `signedRuntimeReady`
>（9/9 capabilities、12/12 integrity，SHA-256
> `08ba7c30373d4736124f0e507fcc9aa972880235251b8bbf636a7b2fabb1d193`），
> 随后完成 fixed topology 零残留卸载并独立提交推送。R6 已完成 exact
> admitted receipt、five-dimensional Settings status、typed bilingual
> disclosure、actual-window evidence、final matrix 与 independent post-fix
> review，runtime foundation 结论为 `go`，无 unresolved P0–P2。Task 29 的
> closed execution profiles、one-snapshot Activity/Evidence、Quick Scan
> integration、完整 Store join、Cleanup Plan Builder、bounded Review
> projection、independent review 与 unified verifier 已完成。Task 30 的
> collector/pure-gate、memory-only selection、typed stale contract、
> actor-owned one-shot authorization、independent review 与 unified verifier
> 已完成。Task 31 的 serial injected fake-Trash coordinator、durable journal、
> per-item fresh Policy、Manifest/accounting、audit retry、no-replay recovery、
> independent review 与 unified verifier 已完成。Task 32 的 typed
> Scan→Review routing、Core-backed Plan/Policy、write-disabled execution seam、
> native UI、实际窗口验证、independent review 与 authoritative unified
> verifier 已完成；真实 App Trash 依赖仍保持关闭。
> Task 33 的 exact terminal Plan/Policy admission、typed Evidence enrichment、
> immutable Manifest/journal projection、Reversible First Cleanup Result、
> read-only Manifest detail、Open Trash/audit-only retry、真实
> Review→confirmation→terminal DEBUG fixtures、独立 review findings 修复、
> App tests/focused XCUITest、actual-App/Peekaboo 与 authoritative full
> verifier 已完成，后者单次 exit 0。production execution 继续
> `writeDisabled`。
> Task 34 的 Store v3 Manifest paging、独立 7/90-day retention、typed
> Quick Scan/Manifest History union、exact local-record deletion、
> privacy-bounded export、non-causal trend marker、实际窗口证据与独立 review
> 已完成；authoritative `scripts/verify --full` 单次 exit 0（826.52 秒）。
> Task 35 的 closed runtime facade、strict signed-App diagnostic、
> recovery-only runtime、Phase C product gate、benchmark 与 App/Core
> regressions 已实现。唯一授权的真实 Trash attempt 已消费：exact
> diagnostic-owned fixture 被移动且 journal durably 停在
> `actionOutcomeRecorded`；Manifest timeline 缺陷使原 report 正确保持
> `signedAppTrashBlocked` / `executionFailed`，未重试。随后独立 signed
> recovery-only App 以 Executor invocation `0` 完成 journal finalization、
> one-record Manifest、1 success / 0 failed/cancelled/unknown、permanent bytes
> `0`，并按 identity 恢复 fixture，证明原位置存在且 Trash destination
> 不存在。privacy-safe checked receipt 已绑定原始/恢复 reports、final Store
> 与安全关键源码。
> mutation scripts 现均 sealed；authoritative `scripts/verify --full` 最终只
> 验证 receipt/source/raw evidence，绝不再调用真实 Trash 或 recovery。
> 旧 global same-UID Node safe-window 已删除，contracts 禁止
> `pkill`/`killall`/`pgrep`/`ps -U` 全局进程协调；Chrome、Cursor、Claude、
> MCP 或其他 App 不得因 Task 35 被阻断或终止。focused product gate 74/74、
> SwiftPM 634/634、完整 App/UI、Debug/Release 与 receipt/raw-evidence gates
> 均通过；authoritative full verifier 22/22 stages 单次 exit 0（847.921 秒）。
> 最终 whole-diff 与 timestamp-focused review 均无 unresolved P0–P2，Phase C
> plans/briefs 已归档，admission 为 `go`。normal App execution 仍不得启用。
> Phase D Tasks 36–44 plan 已获批并直接绑定 authoritative pushed Task 35
> baseline `86ee2aa9428cfc71036e18dcb2c1349ec248ec73`。Task 36 deterministic
> Investigation domain/canonical source projection/Candidate Planner/budget/
> stop core 已完成：300,002-row / 256 MiB benchmark 连续最慢
> `22.540198084` 秒、kernel peak increment 最坏 `100,958,328` bytes；
> maximum benchmarks 已从普通 suites 隔离并在 full 中独立串行一次，
> Task 35 receipt/source seal 也已前移到所有昂贵步骤之前。independent
> review 无 unresolved P0–P2，authoritative `scripts/verify --full` 23/23
> stages 单次 exit 0（875.36 秒）。Task 37 Store v4/persistence/retention/
> source rejoin 已完成实现与 independent review；两轮完整 Release capacity
> gate 共 `30/30` 样本通过，最慢 `53.159062` 秒、最坏 kernel footprint
> increment `210,944,240` bytes。普通 suites 明确跳过该显式 opt-in
> benchmark，worker 直接运行已构建 test bundle、不嵌套 SwiftPM。
> authoritative `scripts/verify --full` 23/23 stages 单次 exit 0（893.65 秒）。
> Task 38 closed dependency-injected Investigation coordinator/fake runtime、
> Store-owned one-shot admission、strict event/lineage/token normalization、
> scientific loop、terminal/recovery barrier、versioned prompt 与 structural
> no-Executor gate 已完成。review 发现的 prose replay、actor reentrancy、
> Probe usage regression、spawn started/completed、completion-side tool
> classification 与 terminal deadline 六类 P1 问题均已 tests-first 修复；
> 811-test serialized regression、independent post-fix review 与 authoritative
> `scripts/verify --full` 23/23 stages 单次 exit 0（884.57 秒）。Task 39 已按
> 39A/39B checkpoint 拆分；39A strict signed-runtime contract、server-owned
> turn identity binding 与 package-closed diagnostic facade 已完成。11/11
> contract、5/5 facade、77/77 Investigation focused tests、829-test
> serialized regression、independent post-fix review 与 authoritative
> `scripts/verify --full` 23/23 stages 单次 exit 0（891.15 秒）。39B 已拆为
> 39B1a/39B1b/39B2；39B1a exact Evidence Store v4 path、directly async
> lifecycle、actor reentrancy/deadline preservation 与 structural
> no-blocking-bridge gate 已完成，83-test Investigation suite、833-test
> serialized regression、independent post-fix review 与 authoritative
> `scripts/verify --full` 23/23 stages 单次 exit 0（883.38 秒）。39B1b 已继续
> 拆为 39B1b-i transport/composition 与 39B1b-ii DEBUG App leaf。39B1b-i
> package-scoped stateful App Server client、non-product
> `StornautInvestigationRuntime` target、async root preopen/one-shot Store
> claim、canonical first-turn injection、server-owned identity mapping、
> pending reservation/active turn separation 与 transport fail-closed cleanup
> 已完成。92-test Investigation、240-test Codex、846-test serialized
> regression、independent post-fix review 与 authoritative
> `scripts/verify --full` 23/23 stages 单次 exit 0（900 秒）。39B1b-ii strict
> DEBUG App leaf implementation、11-test dedicated App target、
> pure-product Debug/Release boundary、846-test serialized regression 与
> independent post-fix review 已通过；authoritative `scripts/verify --full`
> 23/23 stages 单次 exit 0（972 秒）。39B2 已拆为 39B2a strict supervised
> interactive transport、39B2b signed production composition 与 39B2c
> machine admission。39B2a implementation、73-test Lifecycle、103-test
> Investigation、865-test serialized regression 与 independent post-fix
> review 已通过；authoritative full verifier 23/23 stages 单次 exit 0
> （932 秒）。39B2b 已继续拆为 39B2b-i helper-owned contained worker 与
> 39B2b-ii signed diagnostic-App/Task 38 composition。39B2b-i 的
> root-helper/UID-worker boundary、closed broker、fixed contained session、
> 37-test focused regression、889-test serialized regression 与 independent
> post-fix review 已完成；authoritative full verifier 23/23 stages 单次
> exit 0（933.21 秒）。39B2b-i 已完成。39B2b-ii preflight 随后发现
> diagnostic final Mach-O 因静态链接整个 Core 而携带 concrete cleanup 与
> Registered Action authority；dead stripping、关闭 Debug dylib、whole-module
> 与 `-Osize` 均不能移除。前置修复因此拆为 E1 Registered Action authority
> extraction 与 E2 Trash/Executor authority extraction。E1 已将 concrete
> `posix_spawn`/process-tree runner 迁入单向
> `StornautExecution → StornautCore + StornautProcessSupport` target，Core
> 只保留 typed contract；11-test focused、895-test serialized、
> independent review 与 authoritative full 23/23 stages 单次通过（timed
> stages 954.459 秒）。E1 已完成。E2 已继续拆为 E2a package-only seam
> 与 E2b concrete authority migration；E2a 的 47/47 focused cleanup、
> 8/8 headless stages（内含 893-test serialized regression）、targeted
> Debug App build、Task 35 historical source-snapshot correction 与
> independent review 均通过，未移动 concrete authority。E2a 已完成，
> E2b 已继续拆为 E2b-i authority relocation 与 E2b-ii strict
> final-Mach-O admission。E2b-i 已把 concrete Trash/Executor authority
> 迁入 `StornautExecution`，Core 只保留 typed seam/receipt/无权 runtime
> state machine；3/3 package、32/32 affected、73/73 Phase C、
> ordinary/diagnostic App builds 与单次 898-test serial regression 均通过，
> independent review 无 unresolved P0–P2。E2b-i complete；E2b-ii strict
> final-Mach-O verifier/review 已完成，built Execution authority 正控制、
> full diagnostic bundle Mach-O 负控制与六 target Xcode allowlist 均通过，
> 唯一一次 clean full 23/23 stages 单次通过（timed 1,046.300 秒），无
> restart 或 stage rerun。E2b-ii complete；
> 恢复后的 39B2b-ii signed diagnostic composition 已绑定 opaque Task 38
> facade、delayed auth projection、helper-reported random workspace、exact
> diagnostic Store 与 dedicated App/helper topology；focused Codex/
> Investigation/App tests、strict final-Mach-O gate 与 independent post-fix
> review 已通过；该 checkpoint 唯一一次 authoritative full verifier 以
> 23/23 stages、898-test serialized regression、981 秒 wall time 单次通过，
> 无 restart 或 stage retry。39B2b-ii 已完成；39B2c 的窄 attempt-binding
> prerequisite 已把 raw capability worker evidence 绑定到 exact nonce 与完整
> signed runtime binding，修复 component-hash review P2，并通过 903-test
> headless regression 与 post-fix review。随后独立 strict-decoding
> prerequisite 已关闭 capability report/outcome unknown-field 接受窗口，
> 255-test serial Codex suite 与 post-fix review 通过。L1 helper-sealed
> per-run residue observation 随后完成，949-test staged-only serial regression、
> targeted Debug helper build 与 post-fix review 通过。L2 exact root topology
> observer 随后完成 package-closed/non-Codable contract、fixed-node/signing/
> PID-version/audit-token identity 复查与 installed/post-teardown phase proof；
> root-helper signing review P1 已 tests-first 修复，117-test focused、exact
> source-boundaries、targeted Debug diagnostic App/helper build、981-test clean
> staged-only serial 与 post-fix review 通过。machine driver/failure matrix 尚未
> 实现；39B2c 才能作 readiness claim。
> 生产 Deep Dive 仍 unavailable。
> Task 5 的历史
> Broker-only no-go 已由 ADR 0004 capability-first 决策修订，Deep Dive 因
> 生产产品流程尚未实现而 unavailable；
> release signing/notarization 未评估

## 1. 任务目标

构建一个原生 Swift macOS App，将确定性开发者磁盘扫描与 capability-first Codex 深度调查结合起来。产品必须在没有 Codex 和外部工具时完成 Quick Scan；Deep Dive 允许 Codex 使用直接只读 Agent 工具、Probe Broker 与公共互联网调查未知空间。所有写操作由 Swift Policy Gate 与 Executor 控制。

Coding Agent 可以实现已批准的导航、状态模型和原生组件骨架，但不得把任一视觉概念图当作逐像素终稿。Onboarding 使用 A 的三步单焦点结构 + C 的紧凑 Full/Limited 后果说明，并具有 Welcome、FDA、Connect Codex 的 Dark/Light 配对；Overview 的 A+B 融合构图及 Dark/Light 配对方向已经批准；Quick Scan 的 E 主体 + A 阶段 rail 已批准；Scan Results 的 A 默认表格 + D Inspector 已批准；Deep Dive 的 B 默认页 + C Inspector + A Probe 轨迹已经批准；Review 的 A 默认表格 + C Inspector + B 分组解释已经批准；Cleanup Result 使用 B 的可恢复优先层级 + A 计量契约，E 是 partial/error 状态，C/D 分别下沉为 Accounting Details 与 Manifest；History 使用 E master-detail + A 日期分组，C 是按需 Storage Trend；Settings 使用 A 的独立原生侧栏外壳 + C 的 General 状态汇总 + E 的结构化 Local Knowledge，并具有 General、Codex & Deep Dive、Local Knowledge 的 Dark/Light 配对。跨流程状态统一采用“保留有效结果 → 标出受影响范围 → 只提供安全恢复 → 技术细节按需展开”，五组 Light/Dark canonical 覆盖 limited coverage、Deep Dive safety blocked、stale plan、partial investigation 与 expired evidence/corrupt history。圆环只作为功能性存储图，不得实现星座/星图装饰。发现 Codex 不等于验证 capability-first runtime boundary；在“完整调查能力 + 公共联网 + 进程树不可写 + no-Executor”运行时检查通过前 Deep Dive 必须保持 paused。

正式产品名为 `Stornaut`：App/Swift 类型使用该大小写，仓库、CLI 和配置前缀使用 `stornaut`。项目采用 MIT License；首发仅面向开发时最新稳定版 macOS 与 Apple Silicon，不为 Intel 或旧系统牺牲实现简洁度。

不要把项目实现成：

- 一组 Shell 清理脚本的 GUI
- 把扫描结果发给模型生成文案的“AI 标签”
- 允许 Agent 任意 `rm` 或执行清理命令的包装器
- ClearDisk、Mole 或其他项目的简单 Fork

## 2. 必读顺序

1. [文档地图](../README.md)
2. [PRD](../product/PRD.md)
3. [技术架构](../architecture/system-architecture.md)
4. [批准的 Agent 设计规格](../design/agent-disk-governance.md)
5. [UI/UX 设计规格](../design/ui-ux.md)
6. [跨流程恢复状态与概念图](../assets/ui-concepts/RESILIENCE-STATES-ROUND-1.md)
7. [已批准的 Epic 0–1 实施计划](../plans/completed/epic-0-1-foundation-spikes.md)
8. [上游参考矩阵](../research/upstream-reference-matrix.md)
9. [竞品报告](../research/competitive-analysis-2026-08-06.md)
10. [真实案例](../research/case-study-2026-08-06.md)

规范优先级：用户明确批准的 v1 约束 → PRD 2.3 与两份批准规格 → architecture 2.2 → Epic 0–1 实施计划 → 研究/案例/视觉概念。发现冲突时先报告并提出精确修正文案；未经用户批准不得降低安全边界、扩大权限或修改已批准产品范围。

涉及 App build/run、UI 改动或实际截图验证时，额外读取 [Development Automation](development-tooling.md) 与 [UI Testing Guide](ui-testing-guide.md)。仓库 XcodeBuildMCP/Peekaboo 是 Coding Agent harness，不得进入产品 Deep Dive Codex 的配置或工具面。

## 3. 不可违反的产品不变量

1. Quick Scan 不调用模型。
2. Codex 只有调查和建议权。
3. Codex 可直接读取授权扫描范围，并使用 shell/unified exec、live high-context search、browser/direct fetch、image、skills/subagents 与公共互联网；不得设置 Bash/executable/public destination-domain allowlist 或逐命令批准来削弱调查质量。
4. Probe Broker 是优先的类型化、可预算、可审计证据接口，不是 Agent 磁盘调查的唯一入口。
5. Codex 与所有后代进程不可写用户数据、不可访问 localhost/私网/任意 Unix socket、不可调用清理链；不得以 `danger-full-access` 换取联网。
6. Policy Gate 可以否决 Agent，不能反向被 Agent 覆盖。
7. Executor 只接受 `MoveToTrash` 或 Action Registry 中的类型化动作。
8. Trash 失败绝不回退为永久删除。
9. 执行前必须重验证路径与活动状态。
10. Adapter 可缺失，核心必须独立工作。
11. Swift Scanner 性能未被证明不足前，不引入 Rust。
12. 失败保持 `Unknown`/拒绝，不能猜测为 `Ready to Reclaim`。
13. Evidence Store 默认 7 天；原始受控读取内容不落盘；原始 Codex JSONL 正常结束即删除。
14. v1 不创建 MenuBarExtra、后台监控、定时扫描或登录启动项。
15. 顶层导航固定为 Overview、Scan、Investigations、History；Settings 独立。
16. UI 默认不展示 chat、console、原始 JSONL 或模型思维链。
17. Agent-only 规则 miss 不能进入默认选中的 Ready to Reclaim。
18. Local Knowledge 只能保存经确认的结构化事实，不能降低清理 protected-path policy、veto 或 Policy Gate。
19. `ReclaimDisposition` 只有 Ready to Reclaim、Review Recommended、Protected、Unknown；风险与置信度独立建模。
20. 权限缺口不得显示为 `0 B`；已经完成且仍有效的结果不得被局部失败抹掉。
21. stale preflight 没有 `Proceed Anyway`；刷新受影响项之前不得执行任何动作。
22. safety check 阻断时不得显示尚未发生的 explained gain、finding count 或阶段进度。
23. linked Evidence 到期不得提前删除最小 Cleanup Manifest；损坏记录只隔离自身。

## 4. 开发方法

每个 Epic 使用以下循环：

```text
Upstream Study
→ Implementation Brief
→ 小型技术设计/ADR
→ Tests/Fixtures first
→ 实现
→ 安全与行为 Benchmark
→ 文档和 provenance 更新
```

### Upstream Study Gate

开始编码前，从 [上游参考矩阵](../research/upstream-reference-matrix.md) 选择必读项目，记录：

- URL、commit/version、license
- 阅读的具体文件和文档
- 值得借鉴的行为/算法/UX
- 反面案例
- 是否复用代码及 attribution
- Stornaut 的独立方案和预期改进

没有完成 Gate，不进入编码。

## 5. Epic 能力地图与批准交付顺序

Epic 编号用于能力归属，不再被解释为严格的时间顺序。批准的宏观交付顺序见 [Delivery Roadmap](../plans/roadmap.md)：

```text
Epic 0–1
→ Epic 2–4
→ Epic 8 Tasks 27–28
→ Epic 5 Runtime R1–R6 evidence gate
→ Epic 8 Tasks 29–35
→ Epic 5–6（仅在 ADR 0004 capability-first runtime gate 允许时）
→ Epic 7 + Epic 8 remaining
→ Epic 9
```

这样先形成无 Codex 也可工作的 `Quick Scan → Review → Policy Gate → Trash → Manifest` 安全闭环，再条件接入 Deep Dive。以下各 Epic 保留其能力范围。

### Epic 0：仓库与验证骨架

- 验证现有 GitHub/`main`/`origin` 基线；确认并保留现有、已批准的 MIT `LICENSE`
- 按已接受的 Epic 0 Upstream Study 建立 checked-in Xcode App/Test host 与 Swift Packages；ADR 0001 固化最终 bundle/signing 证据
- CI、SwiftLint/format、单元测试和 fixture 目录
- ADR 与 ThirdPartyNotices 机制
- 建立最小原生单窗口 shell：四个 placeholder workspace 与独立 Settings；不实现品牌化完整 UI

交付：空 App 可启动，Core tests 可在命令行运行。

### Epic 1：高风险技术 Spikes

必须先验证：

1. GUI App 如何可靠发现用户 Codex。
2. `codex exec --json --output-schema --ephemeral` 的协议。
3. 超时、取消和子进程树终止。
4. Codex 是否继承 FDA，以及 direct read/shell/live web/browser 可用时如何强制整个进程树不可写。
5. 本地 MCP/Probe Broker 或等价桥接作为优先结构化证据接口。
6. Swift 扫描真实性能。
7. Trash 和 Registered Action 生命周期。

每项写 ADR。任何安全假设无法成立时，暂停功能开发并更新设计。

### Epic 2：StornautCore 数据模型

- Snapshot、Evidence、Classification、InvestigationTarget
- CleanupPlan、PolicyDecision、CleanupAction、Manifest
- SQLite schema/migrations
- 无 UI 的 fixture tests

### Epic 3：Quick Scan

- Surveyor
- 扫描取消和流式结果
- 基础 space accounting
- Quick Scan UI
- Overview 的 snapshot-first Space Ledger 与 Scan 动态分类
- 460GB Benchmark harness

### Epic 4：Knowledge Base 与 Activity

- YAML compiler、provenance、overlay
- 首批 developer cache 和 artifact 规则
- Git/IDE/process 信号
- 清理 protected-path policy 与 veto
- 与 Mole/ClearDisk/kondo 的 fixture 对照

### Epic 5：Codex Runtime 与 Probe Broker

- Codex detection/capability check
- JSONL event parser 和 output Schema
- direct read、shell/unified exec、live search、browser/direct fetch、image、skills/subagents 与公共网络 profile
- Broker 工具、预算、审计和内容过滤
- fake Codex integration tests
- Prompt injection、写入尝试与凭据非持久化测试

### Epic 6：Deep Dive

- Candidate Planner
- 科学调查状态机和停止条件
- Evidence Report
- Deep Dive UI、覆盖率和预算
- 首次启用时聚合披露 direct read/model context/public network 数据边界
- Agent 调查 affordance、Investigation Details Inspector 和 `Discovered by Codex` 证据摘要

### Epic 7：Adapters

- macOS 系统探针
- Mole、kondo、Homebrew、Docker
- detection/version/capability
- golden output fixtures 和降级

### Epic 8：Policy、Executor 与结果计量

- Policy Gate 不变量
- Trash
- 首批 Registered Actions
- preflight/dry-run/revalidate/postflight
- Manifest 和 Cleanup Result UI
- Review 默认选择策略、永久动作独立确认和 History 审计体验

其中 Policy Gate、Review、MoveToTrash、Manifest 与基础结果计量在 Epic 2–4 后提前交付；真实 Registered Actions 与 Adapter 相关能力在 Epic 7 后补齐。

### Epic 9：真实机器验证与开源准备

- 匿名案例端到端复现
- 性能、内存、取消、权限和清理归因
- Developer ID/notarization/FDA 流程
- 贡献指南、规则 Schema、隐私和安全说明

## 6. 第一份实施计划的范围

第一份 coding plan 只覆盖 Epic 0–1：工程骨架和高风险 Spikes，目前已经完成。

已完成的历史输入：[Epic 0–1 Foundation & Risk Spikes Implementation Plan](../plans/completed/epic-0-1-foundation-spikes.md)。
[Epic 2–4 Deterministic Product Core Plan](../plans/completed/epic-2-4-deterministic-product-core.md)
已完成并归档，不再构成当前执行授权。Phase B 最终证据见
[Epic 2–4 Validation Report](../reports/epic-2-4-validation-report.md)。
Phase C 详尽计划见已归档的
[Epic 8 Safe Execution Vertical Slice](../plans/completed/epic-8-safe-execution-vertical-slice.md)，
已于 2026-08-11 获用户批准并于 2026-08-15 完成。用户在 Task 29 前插入的
[Capability-First Codex Runtime Evidence Gate](../plans/completed/capability-first-codex-runtime-gate.md)
也已完成并归档。
R1–R6 全部通过后才恢复 Tasks 29–35；R4 已完成并得出
`protocolReady`。R5 的 local-only topology、runtime worker 与 verifier 已
实现；provider/schema/raw-event 漂移及 post-review closed-protocol findings
已关闭。官方 `openai` worker 已观察 9/9 capabilities 与 6/6 worker
containment；post-fix source 已补齐 official code-mode host、
anti-forgery evidence、current-build binding 与 one-shot XPC reply。历史
TeamoRouter/usage-limit 报告只作 superseded evidence。current-source signed
App/helper 已得出 `signedRuntimeReady`，并完成 fixed App/plist/service/
lease/runtime/process 零残留卸载。R6 final admission 已完成并得出 runtime
foundation `go`；Task 29 已完成并通过 review/verify。实现与完成证据见
[Task 29 Implementation Brief](../plans/completed/task-29-implementation-brief.md)
与 [Task 29 Review](../reports/epic-8-task-29-review.md)。Task 30 详细边界见
[Task 30 Implementation Brief](../plans/completed/task-30-implementation-brief.md)；
完成证据见
[Task 30 Review](../reports/epic-8-task-30-review.md)。Task 31 详细边界见
[Task 31 Implementation Brief](../plans/completed/task-31-implementation-brief.md)；
完成证据见
[Task 31 Review](../reports/epic-8-task-31-review.md)。Task 32 只可接入 fake
或 write-disabled coordinator，不得启用真实 App Trash。Task 32 详细边界见
[Task 32 Implementation Brief](../plans/completed/task-32-implementation-brief.md)，
当前 completion audit 见
[Task 32 Review](../reports/epic-8-task-32-review.md)。
Task 33 详细边界见
[Task 33 Implementation Brief](../plans/completed/task-33-implementation-brief.md)；
completion audit 见
[Task 33 Review](../reports/epic-8-task-33-review.md)。Task 33 只展示已接受的
Core terminal Manifest；它不启用真实 App Trash、Task 34 History 或 Task 35
signed-App admission。
Task 34 详细边界见
[Task 34 Implementation Brief](../plans/completed/task-34-implementation-brief.md)；
完成证据见
[Task 34 Review](../reports/epic-8-task-34-review.md)。Task 34 将 Manifest
加入 typed History，但仍未执行或启用真实 App Trash。
逐项 artifact/command/gate 缺口与恢复顺序见
[R2–R6 Progress Audit](../reports/capability-first-runtime-progress-audit-2026-08-13.md)。
R1 当前证据见
[study](../upstream-studies/epic-5-capability-first-runtime.md) 与
[ADR 0013](../adr/0013-capability-first-runtime-containment.md)：唯一候选需要
same-session parent-owned random loopback managed proxy transport。该精确例外
已获用户批准用于 R2 configuration candidate；R3 behavior evidence 因
process-tree lifecycle escape 拒绝原 process-group design，随后由用户批准的
[ADR 0016](../adr/0016-investigation-lifecycle-supervisor.md) audit-session
supervisor 关闭 hard gate。R3 final verdict 为 `behaviorReady` candidate。
R4 随后用 strict v2 advisory protocol 与 package graph separation 关闭
no-Executor protocol seam；R5 signed-App helper 与 R6 final admission 已
完成。FDA/TCC product flow 与 production Deep Dive 仍不在当前 admission。

Phase D 当前实现入口为
[Conditional Deep Dive Plan](../plans/active/phase-d-conditional-deep-dive.md)、
[Investigation Canonical v1](../specs/investigation-canonical-v1.md) 与
[Task 39 Brief](../plans/active/task-39-implementation-brief.md)；Task 36 的
完成证据见 [Task 36 Review](../reports/phase-d-task-36-review.md)，Task 37
完成证据见 [Task 37 Review](../reports/phase-d-task-37-review.md)，Task 38
完成证据见 [Task 38 Review](../reports/phase-d-task-38-review.md)。Task 39
的 39A contract/composition foundation 已完成，证据见
[Task 39A Review](../reports/phase-d-task-39a-review.md)。39B1a prerequisite
closure 也已完成，证据见
[Task 39B1a Review](../reports/phase-d-task-39b1a-review.md)。39B1b-i
transport/composition 也已完成，证据见
[Task 39B1b-i Review](../reports/phase-d-task-39b1b-i-review.md)；39B1b-ii/
39B2 只按 signed-App diagnostic
[Implementation Brief](../plans/active/task-39-implementation-brief.md) 实施。
39B1b-ii implementation/review evidence 见
[Task 39B1b-ii Review](../reports/phase-d-task-39b1b-ii-review.md)；其
authoritative full verifier 已通过。39B2a implementation/review evidence 见
[Task 39B2a Review](../reports/phase-d-task-39b2a-review.md)；其
authoritative full verifier 23/23 stages 单次 exit 0。39B2b-i
implementation/focused review evidence 见
[Task 39B2b-i Review](../reports/phase-d-task-39b2b-i-review.md)；
889-test serialized regression 与 authoritative full verifier 23/23 stages
单次 exit 0（933.21 秒）已通过。39B2b-ii authority-extraction prerequisites
与 resumed signed composition evidence 见
[Task 39B2b-ii Review](../reports/phase-d-task-39b2b-ii-review.md)；focused
acceptance、independent post-fix review 与唯一一次 authoritative full
23/23 stages 已通过；该 run 包含 898-test serialized regression，wall time
981 秒，无 restart 或 stage retry。39B2b-ii 已完成。39B2c attempt-binding
prerequisite evidence 见
[review](../reports/phase-d-task-39b2c-attempt-binding-prerequisite-review.md)；
其 903-test headless regression 与 independent post-fix review 已通过，
strict-decoding prerequisite evidence 见
[review](../reports/phase-d-task-39b2c-strict-capability-decoding-prerequisite-review.md)；
其 255-test serial Codex suite 与 independent post-fix review 已通过，
L1 helper-sealed residue evidence 见
[review](../reports/phase-d-task-39b2c-l1-residue-observation-review.md)；
其 949-test staged-only serial regression、targeted helper build 与 independent
post-fix review 已通过。L2 root topology evidence 见
[review](../reports/phase-d-task-39b2c-l2-root-topology-observation-review.md)；
其 117-test Lifecycle focused、exact source-boundaries、targeted Debug
diagnostic build、981-test clean staged-only serial 与 independent post-fix
review 已通过。machine driver/failure matrix 仍待实现。
生产 Deep Dive 继续 unavailable，直到 Task 44 final admission。

跨 Epic 的阶段依赖、no-go 分支和交付顺序由 [Delivery Roadmap](../plans/roadmap.md) 管理；新 active plan 不得另起一套宏观路线。

原因：Codex capability-first 写隔离、FDA 继承、公共联网、Probe Broker 和 Swift 扫描性能是架构成立的前提。在这些结果出来前批量实现 UI、规则或 Agent 流程会造成返工。

第一里程碑 evidence gate（已完成，见 [验证报告](../reports/epic-0-1-validation-report.md)）：

- 真实、可本地签名的 `.app` host 能定位并启动用户 Codex；SwiftPM/CLI 进程不能替代 App-context 证据
- Codex 通过受控本地桥接调用一个 fake/真实只读 Probe，并对任意 Shell、直接文件系统工具和未注册能力形成明确的 go/no-go 证据
- 可以取消并确认进程树退出
- 已记录实际文件读取隔离边界
- Swift Scanner 在受控目录上有可重复 Benchmark
- `trashItem` 和一个 fake registered action 通过生命周期测试

以上是 Epic 0–1 的历史验收口径。ADR 0004 已接受 Broker-only 无法成立并改为 capability-first；历史 no-go 证据保留，但不再作为当前产品限制。新的 Deep Dive gate 验证完整调查能力与公共联网可用时，进程树仍不可写且没有 Executor 路径。

## 7. 测试优先级

最高优先：

- 清理 protected-path policy
- path canonicalization、symlink、mount/root protection
- Agent 建议 Ready to Reclaim vs rule veto
- 执行前 stale evidence
- Shell/skills/subagents 尝试写入、调用清理链或访问本机私网/Unix socket
- prompt injection in README/path
- Codex/Adapter 崩溃和取消

其次：

- taxonomy 覆盖
- UI 状态和进度
- 性能与空间计量

漂亮动画、品牌材质和完整可视化不能早于安全核心；v1 不实现菜单栏体验。

## 8. 外部代码与许可证

- 不要复制 Mole GPL 代码；只做行为参考或调用用户安装的只读命令。
- MIT 代码复用必须记录源文件、commit、版权和许可证文本。
- Pearcleaner 按 source-available 对待。
- Spaci 无 LICENSE，不复制。
- CodeCleaner/CleanMyMac CLI 只做黑盒 Benchmark。
- 新增依赖前记录许可证、维护状态和为什么需要。

## 9. Coding Agent 工作纪律

- 不假设文档中的命令在当前 Codex 版本一定存在；运行 `--help` 验证。
- 不假设 README 的安全声明等于真实执行路径；阅读代码和测试。
- UI 改动不能只通过 SwiftUI 源码审查验收；必须构建并启动真实 `.app`，用仓库 `scripts/peekaboo-readonly` 截取/检查实际窗口，再以 XCUITest 和 `scripts/verify` 固化可重复契约。
- 开发 MCP 必须通过 `scripts/bootstrap-dev-tools` / `scripts/doctor-dev-tools` 使用固定版本。Peekaboo 仅允许 `image`、`see`、`inspect_ui`、`list`、`permissions`，不得为自动化方便授予 Accessibility/Event Synthesizing 或扩大写能力。
- 不把“可重建”写成“可恢复”。
- 不把 Trash 大小写成已经释放空间。
- 不把扫描权限失败写成零占用。
- 不在未授权情况下创建远程服务、遥测或规则下载。
- 遇到架构级不确定性先写 Spike/ADR，不用大段代码掩盖。

## 10. 当前工作区注意事项

截至 2026-08-09，仓库已经初始化并发布到 GitHub，默认分支为 `main`，远端为 `origin`，`main` 跟踪 `origin/main`。MIT `LICENSE` 已由用户批准并提交。Epic 0 不再执行 `git init`、创建远端或首次文档提交。仓库开发 harness 由 `.trae/.mcp.json`、`.xcodebuildmcp/config.yaml`、`scripts/*dev-tools*`、`scripts/xcodebuildmcp` 和 `scripts/peekaboo-readonly` 管理；工具产物保持 ignored。每个完成且验证通过的小迭代创建独立 commit 并及时 push `origin/main`；force-push、发布、公证和 CI 外部运行仍需单独授权。

## 11. Handoff Prompt

可以把下面内容交给 Coding Agent：

```text
你正在实现 Stornaut。先从 docs/README.md 进入文档地图，再完整阅读 docs/agent/coding-agent-handoff.md 指定的文档，尤其是产品/Agent/UI 三份批准规格，遵守所有产品不变量和 Reference Study Gate。不要直接实现整个产品，也不要从概念图推断规格外功能。

Epic 0–1 evidence gate 已完成。Phase B 已实现 closed domain/persistence、
bounded product Quick Scan、incremental Space Ledger、67-rule
Knowledge/Activity、structured Local Knowledge、snapshot-first Overview、Scan、
Scan-only History 与六区 Settings。Task 26 的 focused gate、真实 Home
benchmark、scope audit、actual-window inspection、review 和最终 unified
verifier 均通过；Epic 2–4 计划与 Task 21–26 briefs 已归档。

Phase C deterministic Epic 8 plan 已于 2026-08-11 获批、于 2026-08-15
完成并归档至
docs/plans/completed/epic-8-safe-execution-vertical-slice.md，范围从 Quick
Scan terminal projection 形成 Review Reclaim Plan，经 pure Policy Gate、
fresh revalidation、用户确认与默认 MoveToTrash，最后写 immutable Cleanup
Manifest 和 truthful Cleanup Result/History。Tasks 27–28 已完成。ADR 0004
回顾发现的旧 Broker-only runtime/UI 漂移已由
docs/plans/completed/capability-first-codex-runtime-gate.md 的 R1–R6 关闭。
R1 得出 conditional-go：read-only Seatbelt 阻断 user-data
writes，managed proxy 可让公网访问成功并阻断 direct/local/private/Unix
targets，但需要一个 same-session、父进程拥有、随机端口的 loopback proxy
transport。该精确例外已获用户批准用于 R2 configuration candidate；R2 已
完成并得出 `configurationReady`；R3 证明 direct `setsid()`、
`POSIX_SPAWN_SETSID` 与 launchd user-job cleanup 均不能保证整个调查进程树
回收，随后通过用户批准的 audit-session lifecycle supervisor 取得
`behaviorReady` candidate：identity drop、outer Seatbelt、ASID inheritance、
managed-proxy-owner drain 与 stale-lease recovery 均 observed，residue 为 0。
R4 已完成并得出 `protocolReady`；R5 official `openai` worker gate 已通过
9/9 capability 与 errno-only IPv4/IPv6/private/local/Unix containment；
current-source signed App/helper report 进一步通过 9/9 capability、12/12
integrity 与零残留卸载。R6 已完成 final matrix、five-dimensional status、
typed disclosure、actual-window evidence 与 post-fix review，runtime
foundation 结论为 `go`。Tasks 29–35 与完整 Phase C gate 已完成；
authoritative full verifier 单次 exit 0，计划已归档，Phase C admission 为
`go`。Task 36 deterministic Investigation foundation 已完成。Task 37 Store
v4/persistence/retention/source rejoin 已完成实现、independent review 和两轮
完整容量 gate，authoritative full verifier 23/23 stages 单次 exit 0；Task 37
已完成。Task 38 closed coordinator/fake runtime、strict normalization、
terminal/recovery barrier 与 structural no-Executor gate 已完成，
authoritative full verifier 23/23 stages 单次 exit 0。Task 39 的 39A
strict contract、server-owned turn binding 与 package-closed diagnostic
facade 已完成并通过 authoritative full verifier；39B1a exact Store binding、
directly async lifecycle、actor reentrancy/deadline preservation 与
no-blocking-bridge gate 也已完成并通过 authoritative full verifier。39B1b-i
package-closed transport/non-product composition 也已完成并通过 authoritative
full verifier。39B1b-ii strict DEBUG App leaf implementation、11-test
dedicated App target、pure-product Debug/Release boundary、846-test serialized
regression、independent post-fix review 与 authoritative full verifier 已
通过。39B2a strict lifecycle contract、signed-peer XPC client、
cancellation/dispatch linearization 与 package-closed transport
implementation 已完成；73-test Lifecycle、103-test Investigation、865-test
serialized regression 与 independent post-fix review 已通过，authoritative
full verifier 23/23 stages 单次 exit 0（932 秒）。39B2a 已完成。39B2b 已
拆为 39B2b-i helper-owned contained worker 与 39B2b-ii signed
diagnostic-App/Task 38 composition；39B2b-i implementation、37-test focused
regression、889-test serialized regression 与 independent post-fix review
已完成，authoritative full verifier 23/23 stages 单次 exit 0（933.21 秒）。
39B2b-i 已完成。39B2b-ii preflight 发现 final Mach-O 的静态 Core
dependency closure 携带 concrete cleanup/Registered Action authority；
dead stripping 与优化实验均不能移除。前置修复拆为 E1/E2，E1 已把
concrete Registered Action process runner 迁入单向 `StornautExecution`
target，并通过 11-test focused、895-test serialized、independent review
与 authoritative full 23/23 stages。E2a package-only cleanup seam 随后
通过 47-test focused、893-test headless regression、targeted Debug App
build、historical Task 35 source-snapshot gate 与 independent review；
E2b-i concrete Trash/Executor authority relocation 与 authorized ordinary-App
linkage 已完成，3/3 package、32/32 affected、73/73 Phase C、
ordinary/diagnostic App builds 与 898-test serial regression 均通过；
E2b-ii strict final-Mach-O verifier/review 已完成，built authority 正控制、
full-bundle Mach-O 负控制与 exact Xcode allowlist 均通过，唯一一次 clean
full 23/23 stages 单次通过（1,046.300 秒）。E2b-ii complete；原 signed
composition 已恢复并完成 implementation、focused tests、strict binary
gate 与 independent post-fix review；该 checkpoint 唯一一次 authoritative
full 以 23/23 stages、898-test serialized regression、981 秒 wall time
单次通过，无 restart 或 stage retry。39B2b-ii 已完成；39B2c 的 exact
attempt-binding prerequisite、L1 helper residue 与 L2 root topology observer
均已完成，L2 通过 981-test clean staged-only serial regression；machine
driver/failure matrix 仍待实现。39B2c 才是 machine admission。该最终 gate
要求证明完整调查能力和公共联网可用时，
Codex 全进程树不可写用户数据、不可
访问 localhost/私网/任意 Unix socket 且无 Executor 路径；不得用
`danger-full-access`、命令/公共域名
allowlist、逐命令审批或关闭调查能力绕过。生产 Deep Dive、Adapter、真实
destructive Registered Action、release/notarization 仍不在当前授权范围。

任何权限、安全或许可证假设都必须有实际证据。设计或 PRD 如有冲突，先报告并修正文档。ADR 0004 已批准的直接只读 Agent 工具与公共联网无需再次缩减或请求授权；不得自行扩大本地写入、私网或 Executor 权限。
```
