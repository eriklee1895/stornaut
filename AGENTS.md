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
  transport 例外已获批准；R2 已完成并得出 `configurationReady`；原 R3
  process-group candidate 的 new-session descendant escape 已由用户批准的
  audit-session lifecycle supervisor 精确关闭，R3 得出 `behaviorReady`
  candidate。用户 review 后已继续；R4 的 strict Investigation Envelope v2、
  Swift identity binding、ProcessSupport/ProbeBridge module separation 与
  structural no-Executor verifier 已完成并得出 `protocolReady`。用户明确当前
  只需个人本机运行，不要求分发；R5 已采用 root-only
  `/Library/Application Support/Stornaut/` App + 固定 plist 的 local-only
  lifecycle candidate，原 notarization blocker 已转为未来 distribution gate。
  provider/schema/raw-event 漂移已修复；官方 `openai` + ChatGPT subscription
  的真实 `gpt-5.6-luna` worker 已观察 9/9 capabilities，errno-only probe
  已观察 IPv4/IPv6/local/private/Unix denial，worker containment 6/6。
  2026-08-13 post-fix review 又修复了
  command/image/subagent 证据伪造窗口、随机 denial token 映射、synthetic
  outer/inner launcher 漂移与漏 staged 官方 `codex-code-mode-host`；最新
  focused/Codex/Lifecycle/Xcode/no-Executor/headless gates 通过。后续审查
  进一步修复 current-build/installed-App 绑定、XPC continuation one-shot、
  external-state outcome 优先级与 subagent sender identity。历史 TeamoRouter
  与 `usageLimitExceeded` 只保留为 superseded 调试证据，不是当前 blocker，
  也不得重新混入产品 profile。
  最终 current-source signed App/helper machine report 已得出
  `signedRuntimeReady`：9/9 capabilities observed、12/12 integrity
  contained；machine report SHA-256 为
  `08ba7c30373d4736124f0e507fcc9aa972880235251b8bbf636a7b2fabb1d193`。
  fixed App/plist/service/lease/runtime 与匹配进程随后全部卸载并证明零残留。
  R5 已独立提交推送。R6 已完成 exact evidence receipt、五维 Settings 状态、
  bilingual first-use disclosure、actual-window UI evidence、final matrix 与
  independent review，runtime foundation 结论为 `go`，无 unresolved P0–P2。
  Task 29 的 closed execution profiles、one-snapshot Activity/Evidence、
  Quick Scan integration、完整 Store join、Cleanup Plan Builder、bounded
  Review projection、independent review 与 unified verifier 已完成；Task 30
  的 memory-only selection、pure Policy、fresh context collector、typed stale
  contract、one-shot authorization、independent review 与 unified verifier 已
  完成；Task 31 的 serial injected fake-Trash coordinator、durable journal、
  per-item fresh Policy、Manifest/accounting、no-replay recovery、independent
  review 与 unified verifier 已完成；Task 32 的 typed Scan→Review routing、
  Core-backed Plan/Policy、write-disabled execution seam、原生 UI、实际窗口验证
  与独立 review 已完成，authoritative unified verifier 单次 exit 0。
  Task 33 的 exact terminal Plan/Policy admission、typed Evidence enrichment、
  immutable Manifest/journal projection、Reversible First Cleanup Result、
  read-only Manifest detail、真实 Review→confirmation→terminal DEBUG fixtures、
  独立 review findings 修复、App tests/focused XCUITest 与
  actual-App/Peekaboo 已完成；authoritative full verifier 单次 exit 0。
  Task 34 的 Store v3 Manifest paging、独立 7/90-day retention、typed
  Quick Scan/Manifest History union、exact local-record deletion、
  privacy-bounded export、non-causal trend marker、actual-App/Peekaboo 与
  independent review 已完成；authoritative full verifier 单次 exit 0。
  Task 35 的 closed real-Trash composition、strict signed-App disposable
  diagnostic、recovery-only runtime、Phase C product gate、benchmark 与
  Core/App regressions 已实现。唯一授权的真实 Trash attempt 已消费：
  exact diagnostic-owned fixture 被移动且 journal durably 停在
  `actionOutcomeRecorded`；Manifest timeline 缺陷使原 report 正确保持
  `signedAppTrashBlocked` / `executionFailed`，没有重试。随后独立 signed
  recovery-only App 以 Executor invocation `0` 完成 journal
  `actionOutcomeRecorded → finalized`、one-record Manifest、1 success /
  0 failed/cancelled/unknown、permanent bytes `0`，并按 identity 恢复 fixture，
  原位置存在且 Trash destination 不存在。privacy-safe checked receipt 已绑定
  原始/恢复 report、final Store 与安全关键源码。
  diagnostic/recovery mutation scripts 现均 sealed；`scripts/verify --full`
  最终只运行 receipt/source/raw-evidence read-only gate，绝不得再次调用真实
  Trash 或 recovery。旧 global same-UID Node safe-window 已删除，contracts
  禁止 `pkill`/`killall`/`pgrep`/`ps -U` 全局进程协调；Chrome、Cursor、
  Claude、MCP 或其他 App 的进程不得因此被阻断或终止。focused product gate
  74/74、SwiftPM 634/634、完整 App/UI、receipt/raw evidence 与
  Debug/Release gates 已通过；authoritative `scripts/verify --full` 22/22
  stages 单次 exit 0（847.921 秒）。最终 whole-diff 与 timestamp-focused
  independent review 均无 unresolved P0–P2，Phase C 计划已归档，admission
  为 `go`。
  Phase D Task 36 的 strict Investigation domain、canonical binary/source
  projection、Candidate Planner、budget ledger、stop semantics 与 structural
  no-Executor gate 已完成。300,002-row / 256 MiB source benchmark 连续三次
  最慢 `22.540198084` 秒、kernel peak increment 最坏 `100,958,328` bytes；
  maximum benchmarks 已从普通 suites 精确隔离并只在 full 中独立串行一次。
  Task 35 receipt/source seal 已前移到所有昂贵步骤之前，未来 verifier 漂移
  fail-fast。independent review 无 unresolved P0–P2，authoritative
  `scripts/verify --full` 23/23 stages 单次 exit 0（875.36 秒）。Task 36 已
  完成。Task 37 Store v4/persistence/retention/source rejoin 已完成实现与
  independent review；两轮完整 Release capacity gate 共 `30/30` 样本通过，
  最慢 `53.159062` 秒，最坏 kernel footprint increment `210,944,240` bytes。
  普通 suites 明确跳过该显式 opt-in benchmark，worker 直接运行已构建 test
  bundle 而不嵌套 SwiftPM；authoritative `scripts/verify --full` 23/23 stages
  单次 exit 0（893.65 秒）。Task 38 的 closed dependency-injected
  Investigation coordinator/fake runtime、Store-owned one-shot admission、
  strict event/lineage/token normalization、scientific loop、
  terminal/recovery barrier、versioned prompt 与 structural no-Executor gate
  已完成。六类 review P1 均已 tests-first 修复；811-test serialized
  regression、independent post-fix review 与 authoritative
  `scripts/verify --full` 23/23 stages 单次 exit 0（884.57 秒）。Task 39 已按
  39A/39B checkpoint 拆分；39A strict signed-runtime contract、
  server-owned turn identity binding 与 package-closed diagnostic facade 已
  完成，11/11 contract、5/5 facade、77/77 Investigation focused tests、
  829-test serialized regression、independent post-fix review 与
  `scripts/verify --full` 23/23 stages 单次 exit 0（891.15 秒）。39B 已继续
  拆为 39B1a/39B1b/39B2；39B1a exact Evidence Store v4 path、directly
  async lifecycle、actor reentrancy/deadline preservation 与 structural
  no-blocking-bridge gate 已完成，83-test Investigation suite、833-test
  serialized regression、independent post-fix review 与
  `scripts/verify --full` 23/23 stages 单次 exit 0（883.38 秒）。39B1b 已继续
  拆为 39B1b-i transport/composition 与 39B1b-ii DEBUG App leaf。39B1b-i
  package-scoped stateful App Server client、non-product
  `StornautInvestigationRuntime` target、async root preopen/one-shot Store
  claim、canonical first-turn injection、server-owned identity mapping、
  pending reservation/active turn separation 与 transport fail-closed cleanup
  已完成。92-test Investigation、240-test Codex、846-test serialized
  regression、independent post-fix review 与 authoritative
  `scripts/verify --full` 23/23 stages 单次 exit 0（900 秒）。39B1b-ii strict
  DEBUG App leaf implementation、11-test dedicated App target、
  pure-product Debug/Release boundary、846-test serialized regression 与
  independent post-fix review 已通过；authoritative `scripts/verify --full`
  23/23 stages 单次 exit 0（972 秒）。39B2 已按 preflight 拆为
  39B2a strict supervised interactive transport、39B2b signed production
  composition 与 39B2c machine admission。39B2a implementation、73-test
  Lifecycle、103-test Investigation、865-test serialized regression 与
  independent post-fix review 已通过；authoritative full verifier 23/23
  stages 单次 exit 0（932 秒）。39B2b 已进一步拆为 39B2b-i
  helper-owned contained worker 与 39B2b-ii signed diagnostic-App/Task 38
  composition。39B2b-i 的 root-helper/UID-worker boundary、closed broker、
  fixed contained session、37-test focused regression、889-test serialized
  regression 与 independent post-fix review 已完成；authoritative full
  verifier 23/23 stages 单次 exit 0（933.21 秒）。39B2b-i 已完成。
  39B2b-ii preflight 发现 diagnostic final Mach-O 静态携带 Core concrete
  cleanup/Registered Action authority，且 dead stripping/优化不能移除；
  前置修复拆为 E1/E2。E1 已把 concrete Registered Action
  `posix_spawn`/process-tree runner 迁入单向
  `StornautExecution → StornautCore + StornautProcessSupport` target；
  11-test focused、895-test serialized、independent review 与 authoritative
  full 23/23 stages 单次通过。E1 已完成，E2 Trash/Executor authority
  extraction 已继续拆为 E2a package-only seam 与 E2b concrete authority
  migration。E2a 已完成：47/47 focused cleanup、8/8 headless stages（内含
  893-test serialized regression）、targeted Debug App build、historical
  Task 35 source-snapshot correction 与 independent review 均通过，且未移动
  concrete authority。E2b 已按第 15 个必要 verifier 路径继续拆为 E2b-i
  authority relocation 与 E2b-ii strict final-Mach-O admission。E2b-i 已把
  concrete Trash/Executor authority 迁入 `StornautExecution`，Core 只保留
  typed seam/receipt/无权 state machine；3/3 package、32/32 affected、
  73/73 Phase C、ordinary/diagnostic App builds 与单次 898-test serial
  regression 通过，independent review 无 unresolved P0–P2。E2b-i 已完成，
  E2b-ii strict final-Mach-O verifier implementation/review 已完成：
  built `StornautExecution.o` authority positive control、完整 diagnostic bundle
  Mach-O negative control 与六 target Xcode allowlist 均通过；E2 checkpoint
  唯一一次 clean full 23/23 stages 单次通过（timed 1,046.300 秒），无 restart
  或 stage rerun。E2b-ii 已完成；
  恢复后的 39B2b-ii signed diagnostic composition 已绑定 opaque Task 38
  facade、delayed auth projection、helper-reported random workspace、exact
  diagnostic Store 与 dedicated App/helper topology；focused Codex/
  Investigation/App tests、strict final-Mach-O gate 与 independent post-fix
  review 已通过；该 checkpoint 唯一一次 authoritative full verifier 以
  23/23 stages、898-test serialized regression、981 秒 wall time 单次通过，
  无 restart 或 stage retry。39B2b-ii 已完成；39B2c 的窄 attempt-binding
  prerequisite 也已 tests-first 完成：raw capability worker evidence 现绑定
  exact nonce 与完整 signed runtime binding，component-hash review P2 已修复，
  903-test headless regression 与 post-fix review 通过。随后独立拆出的
  strict-decoding prerequisite 已关闭 capability report/outcome unknown-field
  接受窗口，255-test serial Codex suite 与 post-fix review 通过。L1
  helper-sealed per-run residue observation 已完成，949-test staged-only serial
  regression、targeted Debug helper build 与 post-fix review 通过。L2 exact
  root topology observer 随后完成 package-closed/non-Codable evidence、
  fixed-node/signing/process identity 复查与 installed/post-teardown phase
  contract；review 发现的 root-helper signing P1 已 tests-first 修复，117-test
  Lifecycle focused、exact source-boundaries、targeted Debug diagnostic
  App/helper build、981-test clean staged-only serial regression 与 post-fix
  review 均通过。39B2c machine driver/failure matrix 仍未实现；只有它可以作
  machine readiness claim，
  随后的 L3 preflight 已拆为 L3a trusted target extraction、L3b root
  driver/L1+L2 collection 与 L3c failure matrix/final admission。L3a 已把
  2,509-line machine-only contract/assembler 以 99% rename 迁入非产品
  `StornautInvestigationMachine` target；58-test machine focused、151-test
  Investigation suite、exact source-boundaries、targeted Debug diagnostic
  build、982-test clean staged-only serial 与 independent review 均通过。L3b/
  L3c 继续拆分；L3b1 exact connected-helper attestation、non-reconnectable
  XPC epoch、operation-bound L1/helper handoff 与 irreversible one-shot Store
  已完成，987-test clean staged-only serial、targeted helper/diagnostic builds
  与 independent post-fix review 均通过。L3b2 trusted L1/L2 collection 与 L3c
  final admission 随后继续拆分；L3b2 root-only one-shot L1/L2 collector、
  non-activating exact service/PID observation 与 synthetic transition contract
  已完成，1001-test clean staged-only serial、targeted helper/diagnostic builds
  与 independent post-fix review 均通过。L3c mandatory scope/trust preflight
  识别出 App-local handoff 无法跨 App exit 与 managed-proxy/probe retirement
  仍为推断两个真实缺口，因此继续拆为 L3c1 helper-owned opaque retirement
  escrow、L3c2 deterministic machine driver、L3c3 current-source real-success
  three-plane composition 与 L3c4 sealed final admission。L3c1 路径 preflight
  又拆为 L3c1a typed owner retirement 与 L3c1b helper-owned opaque escrow。
  L3c1a 已完成 typed none/prepared/owned truth、strict response v3、suspended
  start join、exact PGID zero、strict worker reply、86-test focused、11-test App、
  1012-test clean staged-only serial 与 post-fix review。L3c1b 又拆为 i/ii；
  L3c1b-i configuration-bound strict v2/v4 transport、memory-only helper escrow、
  58-test clean staged focused、136-test Lifecycle、168-test Investigation、
  11-test App、1025-test clean staged-only serial 与 independent post-fix review
  已通过；L3c1b-ii synthetic non-Codable Machine claim/collector join、20-test
  focused、139-test Lifecycle、178-test Investigation、targeted Debug build、
  1035-test clean staged-only serial 与 independent grouped/cross-group review
  已通过。L3c1 已关闭；L3c2 mandatory scope/trust/cost preflight 已把 strict
  claim transport、non-product root host/topology 与 eight-scenario driving
  拆为 L3c2a-i/L3c2a-ii/L3c2b。L3c2a-i strict Machine-claim transport、
  36-test focused、144-test Lifecycle、178-test Investigation、targeted
  build/release boundaries、1041-test clean staged-only serial 与 independent
  post-fix review 已完成；L3c2a-ii non-product root host/topology、strict
  XPC/signing adapters、resolved package/source authority gate、20-test affected、
  187-test Investigation、targeted driver/diagnostic builds、release boundary、
  1046-test clean staged-only serial 与 independent post-fix review 也已完成；
  L3c2b preflight 发现的 fresh plan/matrix contradiction 已由 3-path
  plan-freshness prerequisite 关闭：actual plan fingerprints 全唯一、exact
  target-set fingerprint 全相同，59-test affected、189-test Investigation、
  structural gate 与 independent review 已通过；L3c2b driving next。只有 L3c4
  可作 readiness claim，
  final full 尚未消耗。
  Task 39 尚未完成。
  真实 App Trash 依赖仍保持关闭，生产 Deep Dive 仍为 implementation unavailable。
  逐 Task 完成 Upstream Study、
  实现、code review、分层验证、独立 commit/push；`scripts/verify --full`
  只作产品/安全 checkpoint 的单次最终验收，绝不作为调试循环。先按
  structural → focused → one serial SwiftPM → applicable headless/App/binary
  gate → independent review 排除问题，再运行一次 clean full；失败后只复跑
  精确失败 stage/case，修复并恢复绿色后才重新开始最终 full。获批 brief
  明确记录的 package-only seam 可用 headless + targeted App build 替代
  full/XCUITest；此时 headless 自带的 `swiftpm-tests-serialized` 就是唯一
  serial regression，不得再独立重复一遍。enclosing product/security
  checkpoint 仍必须执行最终 full。不得提前混入
  生产 Deep Dive、Adapter、真实 Registered Action 或 release 工作。
- 每个实现 checkpoint 编码前做 scope/cost preflight；若预计超过 14 个
  non-document source/test/script 路径或约 4,000 新增 non-document 行，必须
  先拆分再编码。不得重现 Tasks 36–38 的超大 review surface。
- Capability-first runtime foundation 已通过；这不等于生产 Deep Dive 已实现。
  Deep Dive 必须保持 unavailable，直到 Phase D 完整产品流程自己的实现与 gate
  通过；发现 Codex、runtime receipt 或 feature flag 都不能单独启用它。
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
| Capability-first Codex Runtime Gate（历史） | [docs/plans/completed/capability-first-codex-runtime-gate.md](docs/plans/completed/capability-first-codex-runtime-gate.md) |
| R1 Runtime Study / conditional decision | [docs/upstream-studies/epic-5-capability-first-runtime.md](docs/upstream-studies/epic-5-capability-first-runtime.md) / [ADR 0013](docs/adr/0013-capability-first-runtime-containment.md) |
| R3 Runtime behavior gate | [docs/reports/capability-first-runtime-r3-review.md](docs/reports/capability-first-runtime-r3-review.md) |
| R4 Protocol / no-Executor gate | [docs/reports/capability-first-runtime-r4-review.md](docs/reports/capability-first-runtime-r4-review.md) |
| R5 local-only topology decision | [docs/reports/capability-first-runtime-r5-blocker.md](docs/reports/capability-first-runtime-r5-blocker.md) |
| R5 historical App Server blocker | [docs/reports/capability-first-runtime-r5-api-key-blocker.md](docs/reports/capability-first-runtime-r5-api-key-blocker.md) |
| R5 historical usage-limit blocker | [docs/reports/capability-first-runtime-r5-usage-limit-blocker.md](docs/reports/capability-first-runtime-r5-usage-limit-blocker.md) |
| R5 current review | [docs/reports/capability-first-runtime-r5-review.md](docs/reports/capability-first-runtime-r5-review.md) |
| Runtime final validation / R6 review | [docs/reports/capability-first-runtime-validation-report.md](docs/reports/capability-first-runtime-validation-report.md) / [docs/reports/capability-first-runtime-r6-review.md](docs/reports/capability-first-runtime-r6-review.md) |
| Runtime R2–R6 progress audit | [docs/reports/capability-first-runtime-progress-audit-2026-08-13.md](docs/reports/capability-first-runtime-progress-audit-2026-08-13.md) |
| Phase C Epic 8 已完成计划 | [docs/plans/completed/epic-8-safe-execution-vertical-slice.md](docs/plans/completed/epic-8-safe-execution-vertical-slice.md) |
| Epic 8 Task 29 tests-first brief | [docs/plans/completed/task-29-implementation-brief.md](docs/plans/completed/task-29-implementation-brief.md) |
| Epic 8 Task 29 review / completion audit | [docs/reports/epic-8-task-29-review.md](docs/reports/epic-8-task-29-review.md) |
| Epic 8 Task 30 tests-first brief | [docs/plans/completed/task-30-implementation-brief.md](docs/plans/completed/task-30-implementation-brief.md) |
| Epic 8 Task 30 review / completion audit | [docs/reports/epic-8-task-30-review.md](docs/reports/epic-8-task-30-review.md) |
| Epic 8 Task 31 tests-first brief | [docs/plans/completed/task-31-implementation-brief.md](docs/plans/completed/task-31-implementation-brief.md) |
| Epic 8 Task 31 review / completion audit | [docs/reports/epic-8-task-31-review.md](docs/reports/epic-8-task-31-review.md) |
| Epic 8 Task 32 tests-first brief | [docs/plans/completed/task-32-implementation-brief.md](docs/plans/completed/task-32-implementation-brief.md) |
| Epic 8 Task 32 review / completion audit | [docs/reports/epic-8-task-32-review.md](docs/reports/epic-8-task-32-review.md) |
| Epic 8 Task 33 tests-first brief | [docs/plans/completed/task-33-implementation-brief.md](docs/plans/completed/task-33-implementation-brief.md) |
| Epic 8 Task 33 review / completion audit | [docs/reports/epic-8-task-33-review.md](docs/reports/epic-8-task-33-review.md) |
| Epic 8 Task 34 tests-first brief | [docs/plans/completed/task-34-implementation-brief.md](docs/plans/completed/task-34-implementation-brief.md) |
| Epic 8 Task 34 review / completion audit | [docs/reports/epic-8-task-34-review.md](docs/reports/epic-8-task-34-review.md) |
| Epic 8 Task 35 tests-first brief | [docs/plans/completed/task-35-implementation-brief.md](docs/plans/completed/task-35-implementation-brief.md) |
| Epic 8 Task 35 review / completion audit | [docs/reports/epic-8-task-35-review.md](docs/reports/epic-8-task-35-review.md) |
| Phase C final validation | [docs/reports/epic-8-safe-execution-validation-report.md](docs/reports/epic-8-safe-execution-validation-report.md) |
| Phase D 获批计划 | [docs/plans/active/phase-d-conditional-deep-dive.md](docs/plans/active/phase-d-conditional-deep-dive.md) |
| Investigation Canonical v1 | [docs/specs/investigation-canonical-v1.md](docs/specs/investigation-canonical-v1.md) |
| Epic 6 Investigation Study / ADR | [docs/upstream-studies/epic-6-investigation-planning.md](docs/upstream-studies/epic-6-investigation-planning.md) / [ADR 0017](docs/adr/0017-investigation-planning-and-stop-semantics.md) |
| Phase D Task 36 tests-first brief | [docs/plans/active/task-36-implementation-brief.md](docs/plans/active/task-36-implementation-brief.md) |
| Phase D Task 36 review / completion audit | [docs/reports/phase-d-task-36-review.md](docs/reports/phase-d-task-36-review.md) |
| Phase D Task 37 tests-first brief | [docs/plans/active/task-37-implementation-brief.md](docs/plans/active/task-37-implementation-brief.md) |
| Phase D Task 37 review / completion audit | [docs/reports/phase-d-task-37-review.md](docs/reports/phase-d-task-37-review.md) |
| Phase D Task 38 tests-first brief | [docs/plans/active/task-38-implementation-brief.md](docs/plans/active/task-38-implementation-brief.md) |
| Phase D Task 38 review / completion audit | [docs/reports/phase-d-task-38-review.md](docs/reports/phase-d-task-38-review.md) |
| Phase D Task 39 tests-first brief | [docs/plans/active/task-39-implementation-brief.md](docs/plans/active/task-39-implementation-brief.md) |
| Phase D Task 39A review / completion audit | [docs/reports/phase-d-task-39a-review.md](docs/reports/phase-d-task-39a-review.md) |
| Phase D Task 39B1a review / completion audit | [docs/reports/phase-d-task-39b1a-review.md](docs/reports/phase-d-task-39b1a-review.md) |
| Phase D Task 39B1b-i review / completion audit | [docs/reports/phase-d-task-39b1b-i-review.md](docs/reports/phase-d-task-39b1b-i-review.md) |
| Phase D Task 39B1b-ii review / completion audit | [docs/reports/phase-d-task-39b1b-ii-review.md](docs/reports/phase-d-task-39b1b-ii-review.md) |
| Phase D Task 39B2a review / completion audit | [docs/reports/phase-d-task-39b2a-review.md](docs/reports/phase-d-task-39b2a-review.md) |
| Phase D Task 39B2b-i review / completion audit | [docs/reports/phase-d-task-39b2b-i-review.md](docs/reports/phase-d-task-39b2b-i-review.md) |
| Phase D Task 39B2b-ii-E1 review / completion audit | [docs/reports/phase-d-task-39b2b-ii-e1-review.md](docs/reports/phase-d-task-39b2b-ii-e1-review.md) |
| Phase D Task 39B2b-ii-E2a review / completion audit | [docs/reports/phase-d-task-39b2b-ii-e2a-review.md](docs/reports/phase-d-task-39b2b-ii-e2a-review.md) |
| Phase D Task 39B2b-ii-E2b-i review / completion audit | [docs/reports/phase-d-task-39b2b-ii-e2b-i-review.md](docs/reports/phase-d-task-39b2b-ii-e2b-i-review.md) |
| Phase D Task 39B2b-ii-E2b-ii review / completion audit | [docs/reports/phase-d-task-39b2b-ii-e2b-ii-review.md](docs/reports/phase-d-task-39b2b-ii-e2b-ii-review.md) |
| Phase D Task 39B2b-ii review / completion audit | [docs/reports/phase-d-task-39b2b-ii-review.md](docs/reports/phase-d-task-39b2b-ii-review.md) |
| Phase D Task 39B2c attempt-binding prerequisite review | [docs/reports/phase-d-task-39b2c-attempt-binding-prerequisite-review.md](docs/reports/phase-d-task-39b2c-attempt-binding-prerequisite-review.md) |
| Phase D Task 39B2c strict-decoding prerequisite review | [docs/reports/phase-d-task-39b2c-strict-capability-decoding-prerequisite-review.md](docs/reports/phase-d-task-39b2c-strict-capability-decoding-prerequisite-review.md) |
| Phase D Task 39B2c-L1 residue observation review | [docs/reports/phase-d-task-39b2c-l1-residue-observation-review.md](docs/reports/phase-d-task-39b2c-l1-residue-observation-review.md) |
| Phase D Task 39B2c-L2 root topology observation review | [docs/reports/phase-d-task-39b2c-l2-root-topology-observation-review.md](docs/reports/phase-d-task-39b2c-l2-root-topology-observation-review.md) |
| Phase D Task 39B2c-L3a trusted machine target review | [docs/reports/phase-d-task-39b2c-l3a-trusted-machine-target-review.md](docs/reports/phase-d-task-39b2c-l3a-trusted-machine-target-review.md) |
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
已获批准；Tasks 27–28 已完成。ADR 0004 回顾发现的旧 Broker-only runtime/
UI 漂移已由 capability-first Runtime R1–R6 gate 关闭；R1 证明 read-only
writes 隔离与 managed proxy 候选；用户已批准
same-investigation parent-owned random-loopback managed proxy 例外；R2 已完成
并得出 `configurationReady`，
允许 Codex descendants 仅连接 same-investigation、父进程拥有、随机端口的
loopback managed proxy；其他 localhost/private/link-local 和所有 Unix sockets
仍须阻断。R3 首先证明 direct `setsid()`、`POSIX_SPAWN_SETSID` 与 launchd
user-job cleanup 不能保证整个调查进程树回收；用户随后批准 ADR 0016 的窄
audit-session lifecycle supervisor。最终 privileged composition 已观察到
identity drop、outer Seatbelt ordering、audit-session inheritance、managed
proxy owner drain 与 stale-lease recovery，live/combined/recovery 均完成且
residue 为 0；R3 结论为 `behaviorReady` candidate。R4 已完成 strict v2
advisory protocol、Swift-owned context binding 与 structural no-Executor
module seam，结论为 `protocolReady`。R5 的 local-only lifecycle candidate
已完成 root-only topology、closed ChatGPT projection、App Server
  provider/schema/raw-event compatibility、signed evidence contract 与 machine
  verifier。官方 `openai` + ChatGPT subscription worker 已观察 9/9 capabilities；
  errno-only IPv4/IPv6/private/local/Unix probe 与 write/auth/runtime cleanup 均
  contained。post-fix source 已补齐 official code-mode host、anti-forgery
  evidence、current-build binding、one-shot XPC reply、vanished-process
  classification、provider-compatible group schema 与 fixed direct-read command
  identity。current-source signed App/helper 已得出 `signedRuntimeReady`，并在
  gate 后完成 fixed topology 零残留卸载。R6 final admission 已完成并得出
  runtime foundation `go`；Tasks 29–35 与完整 Phase C gate 已完成，
  authoritative full verifier 单次 exit 0，计划已归档，Phase C admission
  为 `go`。Phase D Tasks 36–44 plan 已获批；Task 36 deterministic
  Investigation domain/planner/budget/stop core 已完成并通过 independent
  review 与 authoritative full verifier。Task 37 Store v4/persistence/
  retention/source rejoin 已完成实现、independent review 与两轮完整 capacity
  gate，authoritative full verifier 23/23 stages 单次 exit 0。Task 38 closed
  coordinator/fake runtime、strict event/lineage/token normalization、
  terminal/recovery barrier 与 structural no-Executor gate 已完成并通过
  independent review 与 authoritative full verifier。Task 39 的 39A strict
  signed-runtime contract、server-owned turn identity binding 与
  package-closed diagnostic facade 已完成并通过 independent review 与
  authoritative full verifier；39B1a exact Store binding、directly async
  lifecycle、actor reentrancy/deadline preservation 与 no-blocking-bridge gate
  也已完成并通过 independent review 与 authoritative full verifier。39B1b-i
  package-closed transport/non-product composition 也已完成并通过 independent
  review 与 authoritative full verifier。39B1b-ii strict DEBUG App leaf
  implementation、11-test dedicated App target、pure-product Debug/Release
  boundary、846-test serialized regression、independent post-fix review 与
  authoritative full verifier 已通过。39B2a strict lifecycle contract、
  signed-peer XPC client、cancellation/dispatch linearization 与 package-closed
  transport implementation 已完成；73-test Lifecycle、103-test
  Investigation、865-test serialized regression 与 independent post-fix
  review 已通过，authoritative full verifier 23/23 stages 单次 exit 0
  （932 秒）。39B2a 已完成。39B2b 已拆为 39B2b-i helper-owned contained
  worker 与 39B2b-ii signed diagnostic-App/Task 38 composition；39B2b-i
  implementation、37-test focused regression、889-test serialized regression
  与 independent post-fix review 已完成，authoritative full verifier 23/23
  stages 单次 exit 0（933.21 秒）。39B2b-i 已完成。39B2c 才是 machine admission，
  39B2b-ii-E1 Registered Action authority extraction 与 E2a package-only
  cleanup seam 已完成；E2a 的 47-test focused、893-test headless regression、
  targeted Debug App build、independent review 与 Task 35 historical
  source-snapshot verifier 均通过。E2b-i concrete Trash/Executor authority
  relocation、authorized ordinary-App linkage、3/3 package、32/32 affected、
  73/73 Phase C、ordinary/diagnostic App builds 与 898-test serial regression
  已通过。E2b-i complete；E2b-ii strict final-Mach-O verifier/review 已通过，
  built authority 正控制、full-bundle Mach-O 负控制与 exact Xcode allowlist
  均绿色，唯一一次 clean full 23/23 stages 单次通过（1,046.300 秒）。
  E2b-ii complete；恢复后的 signed composition 已完成实现、focused tests、
  strict final-Mach-O gate 与 independent post-fix review；唯一一次
  authoritative full verifier 以 23/23 stages、898-test serialized
  regression、981 秒 wall time 单次通过，无 restart 或 stage retry。
  39B2b-ii 已完成。39B2c attempt-binding prerequisite 已关闭跨-attempt
  capability evidence replay，903-test headless regression 与 post-fix review
  通过；L1 helper-sealed residue observation 与 949-test staged-only serial
  regression 已通过；L2 exact root topology observer、117-test focused、
  targeted Debug diagnostic build、981-test clean staged-only serial 与
  post-fix review 已通过；L3a non-product trusted machine target extraction、
  151-test focused、982-test clean staged-only serial 与 independent review
  已通过；L3b1 peer/L1 handoff、987-test clean staged-only serial 与 post-fix
  review 已通过；L3b2 trusted root collection 与 L3c failure matrix/final
  admission 随后继续推进；L3b2 lifecycle collector、1001-test clean
  staged-only serial 与 post-fix review 已通过；L3c 已按 trust/cost preflight
  拆成 L3c1–L3c4，L3c1 又拆为 L3c1a/L3c1b；L3c1a 已完成 typed owner
  retirement、1012-test serial 与 post-fix review；L3c1b 又拆为 i/ii，L3c1b-i
  configuration-bound helper escrow、1025-test clean staged-only serial 与
  independent post-fix review 已完成；L3c1b-ii synthetic Machine claim/collector
  join、1035-test clean staged-only serial 与 independent review 也已完成。L3c1
  已关闭；L3c2 已拆为 a-i/a-ii/b；L3c2a-i strict claim transport、1041-test
  clean staged-only serial 与 independent post-fix review 已完成；L3c2a-ii
  non-product root host/topology、1046-test clean staged-only serial 与
  independent post-fix review 也已完成，L3c2b next；L3c4
  独占 final admission 与剩余 full。
  Task 39 尚未完成。
Deep Dive 的旧 Broker-only no-go 已被 ADR 0004 的 capability-first 边界取代；
当前仍不可用的原因是生产 Deep Dive 尚未实现，而非 R6 或 Codex 工具能力。
R6 不证明 release distribution、FDA/TCC 或 production Deep Dive；
release signing/notarization 仍未评估。Overview、Scan、Scan-only
History、六区 Settings 与 Scan-owned Review 已是真实 typed
projection/生命周期，Investigations 仍是 placeholder；真实 Trash 仍未启用。

当前已验证的包布局：

```text
Sources/StornautCore/    领域类型与安全接口
Sources/StornautCodex/   Codex 发现、启动、JSONL/schema
Sources/StornautProcessSupport/
                        无 Core 权限的通用进程组终止支持
Sources/StornautCodex/ProbeBridge/
                        独立 StornautProbeBridge host target
Sources/StornautLifecycle/
                        closed audit-session lifecycle foundation
Sources/StornautCore/Settings/
                        closed preferences、bookmark 与 exclusions
Sources/StornautCore/Review/
                        deterministic execution Evidence、Plan Builder 与 projection
Sources/StornautCore/Actions/
                        closed action types、durable execution journal 与 serial coordinator
Sources/StornautExecution/
                        concrete Registered Action process/OS authority
Sources/StornautCore/Accounting/
                        cleanup Manifest/accounting 与 read-only volume sampling
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
编号表示能力归属，不要求严格按数字顺序交付；获批 Phase D plan 明确复用
现有 Runtime、Policy/Trash foundations，并保持 production Deep Dive 和普通
App 执行能力关闭直到各自 gate。

## Working loop

```text
Upstream Study → Implementation Brief → ADR → Tests/Fixtures first → Implement → Benchmark → Docs/provenance
```

涉及 App/UI 的小迭代，在 `Implement` 与最终验收之间执行实际窗口验证：

```text
Narrow build/test → Launch actual .app → Peekaboo read-only capture/inspect → XCUITest/verify
```

每个完成且验证通过的小迭代都创建独立 commit 并及时 push `origin/main`。不得 push 已知失败、敏感数据或未完成的安全绕过；force-push、release、公证与许可证变更仍先确认。
