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
→ Safe Execution Foundations
→ Capability-First Codex Runtime Evidence Gate
→ Complete Safe Execution Vertical Slice
→ Conditional Deep Dive
→ Adapters & Registered Actions
→ Product Completion & Release Readiness
```

对应 Epic：

```text
Epic 0–1
→ Epic 2–4
→ Epic 8 Tasks 27–28
→ Epic 5 runtime R1–R6 evidence gate
→ Epic 8 Tasks 29–35
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

**2026-08-11 interlock：**

Tasks 27–28 已先建立 cleanup domain/persistence/journal foundations。用户批准
在 Task 29 前插入 ADR 0004 capability-first Runtime R1–R6 evidence gate，
详见 [completed plan](completed/capability-first-codex-runtime-gate.md)。该 gate
解决现有旧 Broker-only runtime 与最新产品边界的漂移；它不启用 Deep Dive，
也不改变 Task 29–35 的确定性职责。

R1–R6 通过后恢复 Task 29；若 gate 为 no-go，先记录证据并 review 路线调整，
不得用 `danger-full-access`、命令/公共域名 allowlist、逐命令审批或关闭所需调查
能力绕过。Task 35 完成后，Phase D 才可基于已验证的 runtime foundation
实现完整 Deep Dive 产品流程。

R3 已于 2026-08-12 得出 `behaviorReady` candidate。用户 review 后已继续；
R4 strict v2 advisory protocol 与 structural no-Executor seam 已通过并得出
`protocolReady`。用户随后明确只需个人本机运行，R5 采用 local-only
lifecycle candidate；provider/schema/raw-event compatibility 修复后，真实
`openai` + ChatGPT subscription `gpt-5.6-luna` worker 已观察 9/9
capabilities 与 errno-only IPv4/IPv6/private/local/Unix denial。post-fix review
已补齐 anti-forgery evidence、random denial-token translation、outer/inner
privacy preflight、bundled `codex-code-mode-host`、current-build binding、XPC
one-shot reply 与 exact subagent sender identity。final live fixes 关闭
vanished-process errno 分类、strict-schema `$ref` sibling、direct-read fixed
command 与 shell outcome shape。current-source signed App/helper 已得出
`signedRuntimeReady`（9/9 capability、12/12 integrity），随后卸载并证明
零残留。R6 已完成 final matrix、product status 与 independent review，并得出
	runtime foundation `go`。Tasks 29–35 已完成并通过 independent
review/unified verifier。Task 35 唯一授权的 signed-App real Trash attempt 已
消费：exact diagnostic fixture 被移动且 journal durably 记录
`actionOutcomeRecorded`；原 report 因 Manifest timeline 缺陷正确保持
blocked，未重试。独立 signed recovery-only App 随后以零 Executor replay
完成 finalized journal、one-record Manifest、truthful accounting 与
identity-checked restore。privacy-safe checked receipt 已绑定原始/恢复
reports、final Store 和安全关键源码，mutation scripts 已 sealed。旧 global
same-UID Node safe-window 已删除；verifier 不得阻断或终止 Chrome、Cursor、
Claude、MCP 等其他 App。最终 whole-diff 与 timestamp-focused review 均无
unresolved P0–P2；authoritative full verifier 22/22 stages 单次 exit 0，
Phase C plans/briefs 已归档，admission 为 `go`。production Deep Dive 仍须
等待 Phase D 自己的实现与 gate。

### Phase D — Conditional Deep Dive

**当前计划：** [Phase D Tasks 36–44](active/phase-d-conditional-deep-dive.md)；
Task 36 deterministic planning core 已完成并通过独立审查、连续最大规模
benchmark 与 authoritative full verifier；Task 37 Store v4/persistence/
retention/source rejoin 已完成，两轮正式容量 gate 共 `30/30` 样本通过，
最慢 `53.159062` 秒，authoritative full verifier 23/23 stages 单次 exit 0。
Task 38 closed fake-runtime coordinator、event normalization、terminal/recovery
barrier 与 structural no-Executor gate 已完成，811-test serialized regression
与 authoritative full verifier 23/23 stages 单次 exit 0。Task 39 正在按
39A/39B1a/39B1b-i/39B1b-ii/39B2 小 checkpoint 实施；39A strict signed-runtime
contract、server-owned turn identity binding 与 package-closed diagnostic
facade 已完成，829-test serialized regression、independent post-fix review
与 authoritative full verifier 23/23 stages 单次 exit 0；39B1a exact Store
binding 与 directly async lifecycle prerequisites 也已完成，83-test
Investigation suite、833-test serialized regression、independent post-fix
review 与 authoritative full verifier 23/23 stages 单次 exit 0；39B1b-i
package-closed transport/non-product composition 也已完成，92-test
Investigation suite、240-test Codex suite、846-test serialized regression、
independent post-fix review 与 authoritative full verifier 23/23 stages
单次 exit 0。39B1b-ii strict DEBUG App leaf implementation、11-test dedicated
App target、pure-product Debug/Release boundary、846-test serialized regression
与 independent post-fix review 已通过，authoritative full verifier 23/23
stages 单次 exit 0。39B2 已拆为 39B2a strict supervised transport、39B2b
signed production composition 与 39B2c machine admission；39B2a
implementation、73-test Lifecycle、103-test Investigation、865-test
serialized regression 与 independent post-fix review 已通过，authoritative
full verifier 23/23 stages 单次 exit 0（932 秒）。39B2a 已完成。39B2b-i
helper-owned contained worker 与 39B2b-ii 的 E1/E2 authority extraction
prerequisites 均已完成并通过各自 gate；恢复后的 39B2b-ii signed diagnostic
composition 已完成实现、focused tests、strict final-Mach-O gate 与
independent post-fix review；该 checkpoint 唯一一次 authoritative full
verifier 以 23/23 stages、898-test serialized regression、981 秒 wall time
单次通过，无 restart 或 stage retry。39B2b-ii 已完成。39B2c 的窄
attempt-binding prerequisite 已绑定 raw capability evidence 到 exact nonce
与完整 signed runtime binding，修复 component-hash review P2，并通过
903-test headless regression 与 post-fix review；L1 helper residue 与 L2 exact
root topology observer 也已完成，L2 通过 981-test clean staged-only serial
regression 与 post-fix review；L3c2 deterministic machine driver/failure
matrix、L3c3a driver-bound attempt 与 L3c3b native packaging/installer admission
均已完成。L3c3c-i transport/root-launch audit 已完成并拒绝 external root
branch；i-b2b-0b/i-b2b-1 在执行前 superseded，B4 root execution count 为 0。
ADR 0018 仍 Proposed；L3c3c-ii-a 已完成，ii-b 已拆为 ii-b0a/ii-b0b 与
ii-b1–ii-b5 并插入 ii-c0；ii-b0a frame/capsule、ii-b0b claim/release wire 与
ii-b0c bootstrap 已完成；ii-b1 authority-free leaf 也已在 post-RED
Debug-only diagnostic/dependency-free Release-shell topology correction 后通过
9/9 leaf、13/13 App、277 affected、exact artifact gates、1,138-test staged-only
serial 与 independent post-fix review。ii-b2 ASID prerequisite 也已完成
semantic-only correction、structural mutation controls、1,142-test
implementation serial 与独立 1,143-test decoder-negative supplement；ii-b2a
typed escrow/deadline state、19 focused、167 Lifecycle affected、唯一 1,162-
test combined serial 与 final review 也已完成。ii-b2b-i sealed/non-connected
server、59 focused、唯一 1,194-test staged-only serial、source/package/mutation
gates 与 post-fix reviews 已完成；ii-b2b-ii legacy-client quarantine / Machine
production block 也已通过 helper-private legacy server correction、完整
App/main-Mach-O gate、1,196-test staged-only serial 与 grouped/cross-group
review；ii-b2b-iii 已拆为 iii-a/iii-b，iii-a handle-v3/single-quantized
transfer 已通过 91 focused、181 Lifecycle、309 Investigation、唯一
1,208-test staged-only serial 与 post-fix/cross-group review；iii-b 又拆为
iii-b-i/iii-b-ii，iii-b-i 已通过 83 focused、499 affected、唯一 1,212-test
staged-only serial、helper/final-Mach-O gates 与 fresh cross-group review，
iii-b-ii 也已通过 51 focused、504 affected、唯一 1,223-test staged-only
serial、physical/five-symbol final-Mach-O gates 与 post-fix review；iii-b/
ii-b2b 已关闭；ii-b3a 已通过 35 focused、521 affected、唯一 1,234-test
staged-only serial、exact contract/structural/artifact gates 与 final review；
ii-b3b、独立 fixture prerequisite、ii-b3c 与 ii-b4 已完成并保持
non-admitting；ii-b5 已拆为 b5a0/b5a/b5b-i/b5b-ii/b5b-iii，b5a 与 b5b-i
through aggregate i-c2 已完成并保持 non-admitting；b5b-ii-a fixed FD-0
capsule intake、b5b-ii-b independent Darwin App identity observation 与
b5b-ii-c fixed FD-7 session 已完成并保持 non-admitting，b5b-ii-d exact
owned-PGID retirement 是当前 frontier。
39B2c 仍未作 machine readiness claim。
L3 preflight 已把余下范围拆为 L3a trusted target extraction、L3b root
collection 与 L3c failure matrix/final admission。L3a 已把 machine-only
contract/assembler 迁入非产品 target，并通过 151-test focused、targeted Debug
build、982-test clean staged-only serial 与 independent review。
L3b1 exact helper-peer/opaque L1 handoff 随后完成，并通过 987-test clean
staged-only serial、targeted helper/diagnostic builds 与 post-fix review；L3b2
trusted lifecycle collector 随后完成，并通过 1001-test clean staged-only
serial、targeted builds 与 post-fix review。强制 scope/trust preflight 将 L3c
继续拆为 L3c1 helper-owned opaque retirement escrow、L3c2 deterministic
machine driver、L3c3 current-source real-success three-plane composition 与
L3c4 sealed final admission；L3c1a typed owner retirement、L3c1b-i
configuration-bound helper escrow 与 L3c1b-ii synthetic Machine claim/collector
join 均已完成；后者通过 20-test focused、139-test Lifecycle、178-test
Investigation、1035-test clean staged-only serial 与独立 review。L3c1 已关闭；
L3c2 mandatory preflight 已将 claim transport、root-host/topology 与八场景
driving 拆为 L3c2a-i/L3c2a-ii/L3c2b；L3c2a-i strict Machine-claim transport
已完成，并通过 36-test focused、144-test Lifecycle、178-test Investigation、
targeted build/release boundaries、1041-test clean staged-only serial 与
independent post-fix review；L3c2a-ii non-product root host/topology、resolved
authority gates、targeted builds/release boundary、1046-test clean staged-only
serial 与 independent post-fix review 也已完成；L3c2b eight-scenario driver
已完成并通过 1055-test clean staged-only serial 与 independent review，L3c2
已关闭；L3c3a/L3c3b 与 L3c3c-i root-launch audit 也已完成，external branch
为 NO-GO，ADR 0018 仍 Proposed；L3c3c-ii-a 已完成，ii-b 已进一步拆分，
ii-b0a/ii-b0b/ii-b0c/ii-b1、ii-b2 ASID prerequisite、ii-b2a、ii-b2b-i 与
ii-b2b-ii、iii-a、iii-b-i 与 iii-b-ii 均已完成；iii-b/ii-b2b 已关闭；ii-b3
已拆为 b3a/b3b/b3c，ii-b3a fixed-channel/root-peer/drop adapter 与 ii-b3b
start-to-retire-only Lifecycle seam 与 ii-b3c concrete leaf/native entry
已完成；ii-b4 fixed helper-claim client 也已完成并保持 non-admitting；
ii-b5 已拆为 b5a0 claim-abort、b5a typed composer、b5b-i L2/projection、
b5b-ii Darwin runtime 与 b5b-iii production/artifact；b5a 与 b5b-i through
aggregate i-c2 已完成并保持 non-admitting；b5b-ii-a/b/c 已完成并保持
non-admitting，b5b-ii-d 是当前 frontier。
L3c2b preflight 的 real-plan matrix contradiction 已由 3-path plan-freshness
prerequisite 关闭，affected/Investigation/structural/review gates 通过；
只有 L3c4 可作 readiness claim 并运行
Task 39 剩余唯一 full。
Task 44 是唯一
normal-product admission gate。completion evidence 见
Task 36 [review](../reports/phase-d-task-36-review.md)、Task 37
[review](../reports/phase-d-task-37-review.md) 与 Task 38
[review](../reports/phase-d-task-38-review.md)；39A checkpoint evidence 见
[review](../reports/phase-d-task-39a-review.md)，39B1a checkpoint evidence 见
[review](../reports/phase-d-task-39b1a-review.md)，39B1b-i/ii evidence 见
[transport review](../reports/phase-d-task-39b1b-i-review.md) 与
[App leaf review](../reports/phase-d-task-39b1b-ii-review.md)，39B2a evidence
见 [supervised transport review](../reports/phase-d-task-39b2a-review.md)。
L3c3c 当前证据见
[parent-owned handoff study](../upstream-studies/phase-d-task-39b2c-l3c3c-parent-owned-handoff.md)、
[Proposed ADR 0018](../adr/0018-parent-owned-investigation-handoff.md)、
[final review](../reports/phase-d-task-39b2c-l3c3c-i-handoff-launcher-spike-review.md)
、[i-b2a reproducibility review](../reports/phase-d-task-39b2c-l3c3c-i-b2a-reproducibility-contract-review.md)
、[i-b2b-0a root-launch audit](../reports/phase-d-task-39b2c-l3c3c-i-b2b-0a-root-provenance-review.md)
、[installed-driver preflight](../reports/phase-d-task-39b2c-l3c3c-ii-installed-driver-path-cost-preflight.md)
、[ii-b0a frame/capsule review](../reports/phase-d-task-39b2c-l3c3c-ii-b0a-review.md)
、[ii-b0b claim/release review](../reports/phase-d-task-39b2c-l3c3c-ii-b0b-review.md)
、[ii-b0c bootstrap review](../reports/phase-d-task-39b2c-l3c3c-ii-b0c-review.md)
、[ii-b1 App leaf review](../reports/phase-d-task-39b2c-l3c3c-ii-b1-review.md)
、[ii-b3c concrete entry review](../reports/phase-d-task-39b2c-l3c3c-ii-b3c-review.md)
与 [ii-b4 fixed claim client review](../reports/phase-d-task-39b2c-l3c3c-ii-b4-review.md)。

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
- Commit message 不添加 Coding Agent co-author trailer。
- push 前若存在失效 `GITHUB_TOKEN`/`GH_TOKEN`，清除环境变量并使用 keyring/SSH 登录。
- force-push、历史重写、release、notarization、修改许可证和触发外部发布流程仍需用户单独确认。
- 若某轮只得到 no-go 证据，提交测试、ADR 和报告，不提交绕过安全边界的替代实现。

## 6. 当前状态

- 当前阶段：Phase A、Phase B 与 Phase C evidence gates 已完成。Epic 2–4 Tasks
  9–26 通过最终统一 verifier 并归档至
  [`completed/`](completed/epic-2-4-deterministic-product-core.md)。
- Phase C deterministic Epic 8 safe-execution 详尽 plan 已于 2026-08-11
  获用户批准并于 2026-08-15 完成归档。ADR 0004 回顾确认实现仍有旧
  Broker-only 漂移；用户已批准在 Task 29 前插入
  [capability-first Codex runtime R1–R6 gate](completed/capability-first-codex-runtime-gate.md)。
  R1 已完成并得出 conditional-go：managed proxy 是唯一观察到能同时满足
  公网访问与任意 local/private/Unix target 阻断的候选，但需要 same-session、
  parent-owned random loopback proxy transport；该例外已获批准用于 R2
  configuration candidate；R2 已完成并得出 `configurationReady`。R3 原
  process-group candidate 因 direct `setsid()` /
  `POSIX_SPAWN_SETSID` new-session descendants 逃逸而被拒；用户批准的
  audit-session lifecycle supervisor 随后通过 live/combined/recovery
  privileged composition，R3 得出 `behaviorReady` candidate。R4 已完成
  Investigation Envelope v2、Swift identity binding 与 structural no-Executor
  module seam，结论为 `protocolReady`。R5 local-only candidate 已完成 worker
  9/9 capability、errno-only IPv4/IPv6/private/local/Unix denial、focused/
  serial/headless contracts/build 与 review findings 修复；官方 `openai`
  subscription worker 已通过，历史 TeamoRouter/usage-limit evidence 已
  superseded。signed App/helper machine gate 已得出 `signedRuntimeReady`，
	  并完成零残留卸载；R6 已得出 runtime foundation `go`。Tasks 29–35 与
	  Phase C final gate 已完成：receipt/source/raw-evidence、SwiftPM 634/634、
	  Phase C 74/74、完整 App/UI 和 authoritative full verifier 均通过，计划已
	  归档。旧 global process safe-window 已删除；production Deep Dive 仍不可用。
	  Phase D Tasks 36–44 plan 已获批；Task 36 deterministic
	  domain/planner/budget/stop contracts 已完成，300,002-row / 256 MiB
	  source benchmark 连续最慢 `22.540198084` 秒且 authoritative full
	  verifier 单次 exit 0；Task 37 Store v4/persistence/retention/source
	  rejoin 已完成实现与独立审查，两轮正式 `3 × 5` capacity runs 共
	  `30/30` 通过，最慢 `53.159062` 秒、最坏 kernel footprint increment
	  `210,944,240` bytes；authoritative full verifier 23/23 stages 单次 exit 0。
	  Task 38 closed Investigation coordinator/fake runtime、strict event
	  normalization、terminal/recovery barrier 与 structural no-Executor gate 已
	  完成，811-test serialized regression 与 authoritative full verifier
	  23/23 stages 单次 exit 0。Task 39 的 39A strict signed-runtime contract、
	  server-owned turn identity binding 与 package-closed diagnostic facade 已
	  完成并通过 829-test serialized regression、independent post-fix review
	  与 authoritative full verifier 23/23 stages；39B1a exact Store binding、
	  directly async lifecycle、actor reentrancy/deadline preservation 与
	  no-blocking-bridge gate 也已完成，通过 83-test Investigation suite、
	  833-test serialized regression、independent post-fix review 与
	  authoritative full verifier 23/23 stages。39B1b-i package-closed
	  transport/non-product composition 已完成并通过 92-test Investigation、
	  240-test Codex、846-test serialized regression、independent post-fix
	  review 与 authoritative full verifier。39B1b-ii strict DEBUG App leaf
	  implementation、11-test App target、pure-product Debug/Release boundary、
	  846-test serialized regression、independent post-fix review 与
	  authoritative full verifier 已通过。39B2a strict lifecycle contract、
	  signed-peer XPC client、cancellation/dispatch linearization 与
	  package-closed transport implementation 已完成；73-test Lifecycle、
	  103-test Investigation、865-test serialized regression 与 independent
	  post-fix review 已通过，authoritative full verifier 23/23 stages 单次
	  exit 0（932 秒）。39B2a 已完成；39B2b-i helper-owned contained worker
	  与 39B2b-ii E1/E2 authority extraction 已完成。恢复后的 39B2b-ii
	  signed diagnostic composition 已绑定 opaque Task 38 facade、delayed
	  auth projection、helper-reported random workspace、exact diagnostic
	  Store 与 dedicated App/helper topology；focused tests、strict
	  final-Mach-O gate 与 independent post-fix review 已通过；唯一一次
	  authoritative full verifier 以 23/23 stages、898-test serialized
	  regression、981 秒 wall time 单次通过，无 restart 或 stage retry。
	  39B2b-ii 已完成；39B2c attempt-binding、L1 helper residue 与 L2 root
	  topology prerequisites 已完成；L2 通过 981-test clean staged-only serial
	  regression；L3a trusted target extraction 也已通过 151-test focused、
	  982-test clean staged-only serial 与 independent review；L3b1 peer/L1
	  handoff 也已通过 987-test clean staged-only serial 与 post-fix review。L3b2
	  lifecycle collector 也已通过 1001-test clean staged-only serial、targeted
	  builds 与 post-fix review。L3c 已按 trust/cost preflight 拆为 L3c1–L3c4；
	  L3c1a typed owner retirement、L3c1b-i configuration-bound helper escrow 与
	  L3c1b-ii synthetic Machine claim/collector join 已完成，L3c1 已关闭；L3c2
	  已按强制 preflight 拆为 a-i claim transport、a-ii root host/topology 与 b
	  eight-scenario driving；L3c2a-i 已通过 1041-test clean staged-only serial
	  与 independent post-fix review；L3c2a-ii root host/topology 也已通过
	  1046-test clean staged-only serial 与 independent post-fix review；L3c2b
	  eight-scenario driver 也已完成，L3c2 已关闭。L3c3a/L3c3b 与
	  L3c3c-i root-launch audit 已完成并拒绝 external branch；i-b2b-0b/
	  i-b2b-1 在执行前 superseded，B4 root execution count 为 0。ADR 0018 仍
	  Proposed；L3c3c-ii-a、ii-b0a/ii-b0b/ii-b0c/ii-b1 与 ii-b2 ASID
  prerequisite、ii-b2a、ii-b2b-i、ii-b2b-ii、iii-a 与 iii-b 已完成；ii-b3
  已拆为 b3a/b3b/b3c，ii-b3a/ii-b3b/ii-b3c/ii-b4 已完成并保持
  non-admitting；ii-b5 已拆为 b5a0/b5a/b5b-i/b5b-ii/b5b-iii，b5a 与 b5b-i
  through aggregate i-c2 已完成并保持 non-admitting；b5b-ii-a/b/c 已完成并
  保持 non-admitting，b5b-ii-d exact owned-PGID retirement 是当前 frontier。
	  L3c4 才拥有
	  final admission/full。
	  39B2c 才是 machine admission，Task 39 尚未完成。
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
- 当前状态：ADR 0013 的精确 same-session managed proxy loopback transport
  例外已获批准；R2 已完成并得出 `configurationReady`；R3 behavioral gate
  已得出 `behaviorReady` candidate；R4 已得出 `protocolReady`；R5 已得出
  `signedRuntimeReady` 并证明 zero residue；R6 final admission 已得出 runtime
	  foundation `go`。Phase C Tasks 29–35、exact signed mutation +
	  zero-replay recovery evidence、最终 review/full verifier 与归档均完成，
	  admission 为 `go`。normal App execution 仍 write-disabled；生产 Deep
	  Dive 保持 unavailable。
