# Active Plans

## 三天完整收尾冲刺（2026-09-18 至 2026-09-20）

**状态：计划调整已获用户要求；实施和验收尚未完成。** 目标在 2026-09-20
23:59（Asia/Shanghai）前交付功能完整、在个人本机验真的 v1。本节是当前排期、
开发依赖和验证频率的唯一权威入口，覆盖旧 brief 中逐 Task 严格串行和逐 Task full
要求；PRD 产品范围、安全不变量、真实运行证据和操作授权边界不变。

三天是冲刺目标，不是已保证的结果。任何必需能力未通过验收，都必须报告未完成，
不得把演示、fake runtime、no-go 或后续待办记作完整交付；不自动延期或缩减 v1。
公开分发、Developer ID、公证和发布沿用已批准的独立授权 gate，不混同本机功能完成。

### 起点与完成口径

- 真实基线：`6d0d589d8d0b24d44b5c381b9e030fcf42f3f5fa`；其父提交
  `7054cedc401075cde97658f87511db105be14483` 已完成 persistent-evidence P2。
- Tasks 36–38 已验收；Task 39 不完整。v18 有一次明确授权但尚未启动；
  [授权记录](../../reports/phase-d-task-39b2c-iic-v18-replacement-campaign-authorization.md)
  只允许该固定 campaign，不授权新的真实清理、模型步骤或另一轮 campaign。
- 所谓 P3 已完成及 `60c3c08...` 提交没有 Git 证据，不列入交付或前置任务。
- 普通 App 的真实清理仍为 write-disabled，Investigations 仍是占位页；必须补齐
  产品装配与验收，不能用 Phase C 诊断完成替代用户功能完成。
- 完整功能范围包括 Tasks 39–44、Phase E 首批只读 Adapters/少量真实 Registered
  Actions，以及 Phase F 的本机安装、权限说明、恢复、无障碍、本地化和交付文档。

### 固定工作包与依赖

| 工作包 | 范围与开发准入 | 完成证据 | 初始状态 |
| --- | --- | --- | --- |
| R：运行时验收 | 冻结 Task 39 实现范围；campaign → L3c3d → L3c4。仅修可复现且阻止安全或必需行为的缺陷 | 无模型 cohort、真实认证调查、三类证据、取消/失败/零残留、Task 39 final full | v18 pending；后续 gate 未通过 |
| P：产品流程 | Tasks 40/41 基于现有 36–38 协议可立即开发；42/43 消费可编译的共享接口，采用闭合 fixture；44 的正常产品工厂提前在 42 装配 | 报告/Review、披露、工作流/恢复、真实 Investigations 窗口、History；Task 44 最终真实端到端 | 未实施 |
| A：确定性执行与 Adapters | 不依赖 R 通过；复用 Phase C Policy/Executor。外部探针仅由受控 Swift 侧调用，不能向 Codex 开放私网/Unix socket | 普通 App Trash 闭环；系统/Mole/kondo/Homebrew/Docker/Colima 只读适配与缺失降级；首批固定动作及审计 | 普通执行关闭；集成未验收 |
| Q：交付与验证 | 先隔离测试中的特权启动，再持续补 UI、隐私、许可证、安装与验收矩阵 | 当前 source/build/test 对应证据、真实 App 验收、最终 full、干净提交与交付清单 | 待收口 |

这里的并行指工作依赖解耦，不承诺同时运行多个重型构建，也不自动启动新的
sub-agent。主 Coding Agent 负责集成与状态，已有 reviewer 按有界 diff 复核；
同一时刻最多一个 SwiftPM/Xcode/full/特权 campaign。等待人工输入时推进互不冲突的
低风险工作；不得在 campaign 持有源码或产物时修改它们。

**开发就绪不等于生产准入：** 40–43 可形成 reviewed/scoped-tested 提交，不需要
先拿到 Task 39 Ready；Task 44 启用真实 Deep Dive 仍必须具备当前 Task 39 准入、
有效 source、披露、预算、Store、无冲突工作流和最终产品证据。所有假数据只用于
隔离测试，不得进入正常 App admission。Task 39/44 不允许用 fixture 替代真实模型。

### 三天安排与每日出口

| 日期 | 交付工作 | 当天必须看到的结果 |
| --- | --- | --- |
| 第一天：09-18 | 前 2 小时完成 R 的固定 launcher/sidecar/preflight 核对和 Q 的测试职责检查；已有授权可用才执行一次 v18。同期完成 40 报告投影、41 披露/状态及 A 的工具/许可证/只读能力盘点 | R 有真实运行结果或精确 blocker，不再停在找历史命令；App 可展示持久化报告与披露；每个 Adapter 和首批动作的范围已冻结 |
| 第二天：09-19 | 完成 42 工作流/恢复与正常产品工厂、43 UI；R 通过前置后完成 L3c3d/L3c4。A 接入普通 App Trash、只读适配和已审核固定动作 | 可走通 Scan → Investigation → Report → Review → Result/History；真实路径有对应授权和证据，未准入路径明确 disabled；所有功能代码在当天结束前齐备 |
| 第三天：09-20 | 仅做必要缺陷修复、Task 44 真实 signed-App 端到端、A 的真实动作验收、English/zh-Hans/Light/Dark/键盘/VoiceOver/Reduce Motion、性能/隐私/许可证与安装文档；最终 full、提交推送与交付 | 全部完成矩阵有证据，普通 App 不再用 placeholder/write-disabled 冒充完整功能；无 unresolved P0–P2；完整本机 v1 或明确的未完成结论 |

首批 Registered Actions 在第一天从已安装工具和 PRD 示例中冻结至少两个有独立
价值的动作 ID，优先 Homebrew 缓存治理与一个包管理器缓存动作；具体 executable、
参数、版本与 dry-run 语义须先实测并审查。不能因工具缺失静默取消动作范围；发现
不可安全实现即报告。Docker v1 保留只读用量/对象关系，不为赶工引入未批准的
volume/container 永久清理。真实动作测试使用明确获批的 disposable 目标。

### 时间盒与阻塞处置

- 单个 lookup/环境诊断最多 30 分钟；到点给出命令、错误、证据与下一步，不再
  全文滚动搜索超大历史会话。工作包内修复不递归创建新的 Task 编号。
- 第一天中午前核对 Codex 认证、固定 runtime/历史 Gate 状态、可用外部工具、
  本机签名条件及需要用户配合的凭据/真实动作；需要时立即提出一次精确请求。
- 第一天结束仍无 green cohort：报告三天目标风险、具体失败和最小修复，继续 P/A
  的非生产工作；不得等待或重跑 campaign 占满全部开发时间。
- 第二天中午评估完整功能是否能在当天冻结；缺口必须明确到工作包、验收项和
  时间影响。第二天结束冻结功能，第三天不新增抽象、框架或装饰性优化。
- 第三天中午前完成真实路径首轮验收并开始最终验证；若失败，只修实际失败项，
  恢复绿色后再进行必要的最终完整运行。截止时仍有 blocker，交付现有成果和精确
  缺口，不得宣称完整完成，也不擅自移到“下一版”。

### 验证分层与证据复用

1. 纯计划/文案：链接、diff、精确文档绑定与语义检查，不启动 App/campaign/full。
2. 每个实现切片：structural → 合并选择的 focused tests → 受影响组件/App gate →
   有界 independent review。P0–P2 修复留在原工作包；其他建议不扩大冲刺范围。
3. Tasks 40–43 不再各自运行 serial 加 full；每个稳定集成树最多一次必要 serial，
   若同树 final full 已覆盖则不重复。测试命令使用 `swift test --no-parallel`，
   不沿用旧 `--parallel false` 写法。
4. UI 必须完成 build/test → 真实 .app → Peekaboo 截图/AX → focused XCUITest；
   首次披露、running、partial、blocked、cancel/recovery 和最终状态均有证据。
5. Task 39 L3c4 保留最终安全 checkpoint；Task 44 与 Phase E/F 在同一最终集成树
   验收时共享一次 full。安全关键源码变化必须重验证受影响边界，不能复用旧结论。
6. 日常 gate 不得触发 sudo/install/campaign；当前 component gate 的 Debug 运行
   问题在 Q 中先隔离，非 TTY 不能作为长期修复。历史 receipt/hash 校验保留；
   历史重建/完整 replay 改为显式按需项目，改 verifier 须保留正负控和独立审查。
7. 为每次运行记录 source tree、构建/测试选择、exit、耗时和证据位置；不同树或
   条件跳过的结果不可拼成“全绿”。部分 serial 失败保持失败，不用 focused 通过
   覆盖原记录。长命令使用完成通知而非短间隔空轮询。
8. 保留现有 14 个非文档路径/约 4,000 行的编码前 preflight 上限，但分割按用户
   可验证行为组织；超限时只拆提交，不为每个提交复制整套历史文档和验收。

### 授权、历史证据与交付判定

- 本次计划修改不消费、不撤销、不转移 v18 授权。若使用其冻结运行基线，必须先
  证明 exact commit/build 与外部状态仍匹配；不能直接在本轮变更后的树启动。
  若必须修改授权绑定源码，先停止并请求一次绑定真实新提交的授权，不反复空请求。
- v8–v13/v16 consumed/non-retryable，v14/v15/v17 superseded；v13/v16 Gate 与
  历史 evidence 不可补写或删除。Task 35 原真实 Trash/recovery 授权不可复用。
- 真实清理、永久动作、额外 privileged campaign 和发布操作仍需各自精确授权；
  管理员凭据只由用户本人在固定 Terminal prompt 输入，Coding Agent 不读、不记、
  不代输。本冲刺不添加权限例外、遥测、后台进程或第二条 Executor。
- 每个工作包每日至少两次简短更新：已交付行为、实际运行结果、下一步和 blocker。
  只报告 Git/产物可证实的提交与结果，不使用推测的百分比或不存在的提交。

| 完成项 | 必须具备的证据 | 初始状态 |
| --- | --- | --- |
| Quick Scan/规则/Store | 当前产品回归、真实扫描性能、权限缺口不记零 | 有历史证据；待当前集成回归 |
| Task 39 runtime | green cohort + L3c3d + L3c4 三类证据和零残留 | 未完成 |
| Tasks 40–44 产品流程 | 正常产品工厂、真实 Deep Dive/报告/History/Review、披露及恢复 | 未完成 |
| 普通 App 清理 | 显式确认、fresh Policy、真实 Trash、Manifest/计量/恢复；不复用旧诊断授权 | 未完成 |
| 首批 Adapters/Actions | 所有首批只读适配、版本/许可证/golden fixture/降级；冻结动作逐项验收 | 未完成 |
| 产品质量 | 核心状态真实窗口、双语/主题/无障碍、隐私/性能/安装与贡献说明 | 部分已有；待整体验收 |
| 最终交付 | 无 unresolved P0–P2、同树 full exit 0、干净提交、推送及可运行 .app | 未完成 |
| 公开分发 | Developer ID/公证/发布的独立授权与验证 | 沿用本机阶段之外的 gate；不声称发行完成 |

只要前七项任一未完成，完整本机 v1 就未完成。公开发行必须另行满足最后一项，
不能把“本机功能完成”表述为“已公证发布”。

## 历史检查点说明（不再决定当前排期）

以下段落保留原始诊断、历史审查和失败上下文；其中过时的当前状态、立即前置
Task 阻塞和逐 Task full 叙述由上面的冲刺规则及各 brief 顶部修订取代，不代表
新的运行授权或验收通过。

The original executable plan is
[Phase D — Conditional Deep Dive](phase-d-conditional-deep-dive.md).
Tasks 36–38 are complete. Task 38's closed fake-runtime coordinator,
independent review, 811-test serialized regression and 23/23-stage
authoritative full verifier passed. Task 39 remains incomplete. v8, v9, v10 and v11
are consumed/no-go records. The first v9 launcher invocation was cancelled
before arm; the repaired invocation reached `armedConsumed` and then failed
`spawnUncertain → terminal` because AMFI rejected the ad-hoc MachineDriver's
restricted application-identifier entitlement. The root-cause repair has passed
non-privileged focused, structural and Debug/Release binary gates. A later
serial validation exposed that the historical physical fixture could invoke
production stale-recovery and remove the preserved v9 Gate capsule. The exact
bytes were not recoverable; the original v2 receipt, v3 predecessor and current
v5 receipt are retained, and the fixture is now explicit opt-in with
discovery/entry guards. v10 later ran from source `b9ade5e`, reached durable
arm, and exhausted the 1,200-second outer deadline before a coordinator receipt.
Its failure disposition is checked, and the machine-only 1,400-second
deadline-budget repair is complete and non-admitting. v11 then ran from
`8a286ea`, reached durable arm and recorded `spawnUncertain → terminal`
about 16.259 seconds later. An external launcher recorded exit status 70, but
the retained campaign artifacts do not bind that value. Because its legacy schema-v1
reason was only `campaign-incomplete`, the checked disposition is
`consumedPostArmFailureUnclassified`. The successor source closes that
diagnostic gap with a bounded schema-v2 reason and remains non-admitting. The
preservation repair is complete. The rebound v12 campaign ran once from
`212320f`, exceeded the 1,400-second horizon in the post-arm authorization path
and is consumed/non-admitting/non-retryable. Its checked disposition preserves
the eight durable artifacts and the later loss of the purgeable Gate cache. A
bounded credential repair and persistent Gate P1/P2 are complete/non-admitting.
The authorized v13 campaign ran once from descendant `8885161`, recorded a
closed post-arm `receiptInvalid/exited-82` failure near the shared deadline, and
is consumed/non-admitting/non-retryable. Its persistent Gate residue is intact;
the v13 disposition and 120-second authorization-window/single-attempt EOF
repair are complete/non-admitting.
The v14 authorization based on `d5a7df3` was stopped before launch when the
pre-arm inspection found the exact v13 preservation P0. It remains unconsumed
but is superseded; the preservation prerequisite is complete/non-admitting and
a fresh v15 campaign based on `facf3ea` was authorized. Pre-arm review found
aggregate scope and xattr no-mutation evidence gaps; v15 is superseded/
unconsumed. The fixes are pushed at `103a4836` and verified/non-admitting. One
fresh v16 then ran exactly once and closed as
`receiptInvalid/exited-82/cleanup-02`; it is consumed/non-admitting/non-retryable.
Its schema-v9 disposition binds the nine raw artifacts, both persistent Gate
attempts/capsules and zero fixed-runtime live residue. The tests-first
status-82/cleanup-02 repair is complete/non-admitting. Fresh v17 was authorized
from `a69bd33`, but a pre-launch check found v13 raw evidence missing from
TMPDIR concurrently with a macOS low-disk purge; the exact deleting actor is
not independently bound. v17 is superseded-before-launch and
unconsumed. The v13 purge disposition and future evidence persistent-path repair
are now prerequisites.
Checkpoints 39A,
39B1a, 39B1b-i and 39B1b-ii are complete and independently verified. 39B1a
closed the exact Evidence Store v4 path and directly async lifecycle prerequisites;
39B1b-i closed the package-scoped transport/non-product composition seam.
39B1b-ii closed the strict DEBUG App leaf, exclusive preflight receipt and
ordinary Debug/Release activation boundaries; its independent post-fix review
and 23-stage authoritative full verifier passed. 39B2a strict supervised
interactive transport implementation, 73-test Lifecycle suite, 103-test
Investigation suite, 865-test serialized regression and independent post-fix
review passed; its authoritative full verifier passed 23/23 stages in 932
seconds. 39B2a is complete. 39B2b is split into 39B2b-i helper-owned
contained worker and 39B2b-ii signed diagnostic-App/Task 38 composition.
39B2b-i implementation, 37-test focused regression, 889-test serialized
regression and independent post-fix review are complete; its authoritative
full verifier passed 23/23 stages in 933.21 seconds. 39B2b-i is complete.
39B2b-ii preflight found a pre-existing static-link authority defect and split
two prerequisite repairs before signed composition resumes.
39B2b-ii-E1 moved the concrete Registered Action process runner from Core into
the one-way `StornautExecution` target; its focused/serialized regression,
independent review and 23/23-stage authoritative full verifier passed. E1 is
complete. E2a then established the minimum package-only cleanup injection seam,
corrected the historical Task 35 source-snapshot verifier and passed 47/47
focused cleanup tests, all 8 headless stages including 893 serialized tests,
a targeted Debug App build and independent review. E2a is complete; E2b
was split before its fifteenth required verifier path. E2b-i moved concrete
Trash/Executor authority into `StornautExecution`, retained only typed
injection/state-machine surfaces in Core, explicitly linked only the ordinary
App and passed 3/3 package, 32/32 affected cleanup, 73/73 Phase C, targeted App
builds and one 898-test serialized regression. E2b-i is complete; E2b-ii
strict final-Mach-O gate implementation and isolated review are complete. Its
built execution-object positive controls, full diagnostic-bundle Mach-O
negative controls and six-target Xcode allowlist passed; the E2 checkpoint's
single final full verifier passed 23/23 stages in 1,046.300 timed seconds.
E2b-ii is complete.
The resumed 39B2b-ii signed diagnostic composition now binds the opaque Task
38 facade, delayed auth projection, helper-reported random workspace, exact
diagnostic Store and dedicated App/helper installation topology. Its focused
tests, strict final-Mach-O gate and independent post-fix review passed. Its
single authoritative full verifier passed 23/23 stages in 981 wall-clock
seconds, including the 898-test serialized regression, with no restart or
stage retry. 39B2b-ii is complete. See the
[39B2b-ii review](../../reports/phase-d-task-39b2b-ii-review.md).
The narrow 39B2c attempt-binding prerequisite then bound reused R5 raw
capability evidence to the exact Task 39 nonce and complete signed runtime
binding, fixed the independently found component-hash validation P2 and passed
the 903-test headless regression plus post-fix review. See the
[attempt-binding review](../../reports/phase-d-task-39b2c-attempt-binding-prerequisite-review.md).
The separate strict-decoding prerequisite then closed unknown-field acceptance
in the reused capability report and its derived outcome. Its tests-first
regression, 255-test serialized Codex suite and independent post-fix review
passed. See the
[strict-decoding review](../../reports/phase-d-task-39b2c-strict-capability-decoding-prerequisite-review.md).
The helper-sealed L1 residue prerequisite then replaced inner-worker
`drained: true` promotion with an exact nonce/UID/same-retire observation of
the audit session, lease root and per-run runtime root. Its 949-test staged-only
serialized regression, targeted Debug helper build and independent post-fix
review passed. See the
[L1 review](../../reports/phase-d-task-39b2c-l1-residue-observation-review.md).
The L2 prerequisite then added exact package-closed, non-serializable installed
and post-teardown observation of the fixed App/helper/plist/service/process/
runtime/lease topology. Its 117-test focused suite, exact source-boundaries,
targeted Debug diagnostic build, 981-test clean staged-only regression and
independent post-fix review passed. See the
[L2 review](../../reports/phase-d-task-39b2c-l2-root-topology-observation-review.md).
L3 preflight then split the remaining gate into trusted target extraction, root
collection and final matrix/admission. L3a moved the existing machine-only
contract/assembler into the non-product `StornautInvestigationMachine` target;
its 151-test focused suite, targeted Debug build, 982-test clean staged-only
serial and independent review passed. See the
[L3a review](../../reports/phase-d-task-39b2c-l3a-trusted-machine-target-review.md).
L3b1 exact helper-peer/opaque L1 retirement handoff and L3b2 root-only
one-shot L1/L2 collector are complete. The mandatory cost/trust preflight split
L3c into L3c1 helper-owned opaque retirement escrow, L3c2 deterministic machine
driver, L3c3 real-success three-plane composition and L3c4 final admission.
L3c1a typed owner retirement,
[L3c1b-i configuration-bound helper escrow](../../reports/phase-d-task-39b2c-l3c1b-i-configuration-bound-helper-escrow-review.md)
and
[L3c1b-ii synthetic Machine claim](../../reports/phase-d-task-39b2c-l3c1b-ii-synthetic-machine-claim-review.md)
are complete; L3c1 is closed. The mandatory L3c2 preflight split the remaining
driver work into L3c2a-i strict claim transport, L3c2a-ii non-product root host/
topology composition and L3c2b eight-scenario driving. L3c2a-i is complete; its
36-test focused gate, 144-test Lifecycle suite, 178-test Investigation suite,
targeted build, release boundaries, 1041-test clean staged-only serial and
independent post-fix review passed. See the
[L3c2a-i review](../../reports/phase-d-task-39b2c-l3c2a-i-machine-claim-transport-review.md).
L3c2a-ii is also complete; its seven-path root host, strict adapters, resolved
authority gate, targeted builds/release boundary, 1046-test clean staged-only
serial and independent post-fix review passed. See the
[L3c2a-ii review](../../reports/phase-d-task-39b2c-l3c2a-ii-machine-driver-host-review.md).
L3c2b is complete; its deterministic eight-scenario Task 38 driver, exact
cohort preflight, structural no-authority gate, targeted builds, 1,055-test
clean staged-only serial and final independent review passed. See the
[L3c2b review](../../reports/phase-d-task-39b2c-l3c2b-eight-scenario-driver-review.md).
The mandatory L3c3 preflight split current-source composition into L3c3a exact
driver binding schema, L3c3b native packaging/topology admission, L3c3c-i
handoff/launcher spike and ADR, L3c3c-ii fixed live handoff, and L3c3d one real
success pending candidate. See the
[L3c3 preflight](../../reports/phase-d-task-39b2c-l3c3-scope-trust-preflight.md).
L3c3a is complete: its strict driver-bound attempt schema, App-leaf decoder,
installed identity join, structural/release gates, 199-test Investigation suite,
11-test App target, one 1,057-test clean staged-only serial and independent
post-fix review passed. See the
[L3c3a review](../../reports/phase-d-task-39b2c-l3c3a-driver-binding-review.md).
The fresh
[L3c3b preflight](../../reports/phase-d-task-39b2c-l3c3b-scope-trust-preflight.md)
split native diagnostic-only packaging from root installer/L2 admission before
coding. A final-Mach-O spike then exposed forbidden Cleanup/Policy typed surfaces
through the full Machine/Core graph, so the
[L3c3b-0 preflight](../../reports/phase-d-task-39b2c-l3c3b-driver-runtime-authority-preflight.md)
inserted an authority-closed driver runtime extraction. Its zero-dependency
DriverSupport target, Debug/Release final-Mach-O authority gate, one 1,059-test
clean staged-only serial and independent post-fix review passed. See the
[L3c3b-0 review](../../reports/phase-d-task-39b2c-l3c3b-driver-runtime-authority-review.md).
L3c3b-i is also complete: its diagnostic-only native target, separate
CodeSignOnCopy membership, ordinary-App absence, final-artifact identity and
authority gates, one 1,060-test clean staged-only serial and independent
post-fix/cross-group review passed. See the
[L3c3b-i review](../../reports/phase-d-task-39b2c-l3c3b-i-native-driver-packaging-review.md).
L3c3b-ii is also complete: its exact installer/L2 driver admission, ACL
fail-closed trust transition, whole-installer source seal, six-case disposable
matrix, one 1,067-test clean staged-only serial and grouped/post-fix/cross-group
review passed. See the
[L3c3b-ii review](../../reports/phase-d-task-39b2c-l3c3b-ii-installer-l2-admission-review.md).
L3c3c-i study/root-launch audit is complete. Its i-a/i-b1/i-b2a evidence retains
the socketpair/root-to-UID algorithm and historical reproducibility, while
i-b2b-0a rejects both `sudo -v` and UID-staged no-cache external root launch.
i-b2b-0b/i-b2b-1 were superseded before execution; B4 root count is zero.
[ADR 0018](../../adr/0018-parent-owned-investigation-handoff.md) remains
Proposed. L3c3c-ii-a is complete after authority-closed installed-driver and
manifest observation, exact source/final-Mach-O admission and independent
post-fix review; ii-b is frozen as ii-b0a, ii-b0b and ii-b1 through ii-b5 with
ii-c0 before the privileged gate. ii-b0a frame/capsule and ii-b0b claim/release
wire implementations are complete after their focused/affected/structural gates,
single staged-only serials and independent reviews. ii-b1 preflight then exposed
the first-frame epoch-origin contradiction; ii-b0c bootstrap is complete. ii-b1
is also complete after its post-RED topology correction split one Debug-only
diagnostic target from one dependency-free Release-shell target, with 9/9 leaf,
13/13 App, 277 affected, exact structural/final-artifact gates, one 1,138-test
staged-only serial and independent post-fix review. The ii-b2 ASID prerequisite
and ii-b2a are complete. ii-b2b-i sealed/non-connected server integration and
ii-b2b-ii legacy-client quarantine / Machine production block, iii-a strict
handle-v3/single-quantized transfer, iii-b-i semantic/live integration,
iii-b-ii executable physical-adapter closure and ii-b3a/ii-b3b are complete;
iii-b/ii-b2b are closed; ii-b3c, ii-b4, ii-b5a0, ii-b5a, ii-b5b-i-a and
i-b1, i-b2a, i-b2b-a, i-b2b-b, i-b3, i-c1 and i-c2a are
complete/non-admitting; aggregate i-c2 and ii-b5b-ii-a/ii-b/ii-c are
complete/non-admitting, including ii-b5b-ii-d exact owned-PGID retirement and
ii-c0a projection-in-capsule input/intake. ii-c0a closed at implementation tree
`6064cccce400cd07f7ebdc4653a2496c67c83434`: exact 8 paths / 1,863 changed
lines, 90 focused tests, 536 affected tests, a clean 1,418-test / 73-suite
staged-only serial, all three boundary gates and no unresolved P0-P2 review
findings. It ran no root, App/XPC, model/auth, network or authoritative full
gate. A fresh source/topology audit split ii-b5b-iii before coding into b0
protocol, a per-epoch continuity, b1 injected cohort, b2a0 typed physical bridge,
b2a-i canonical supervisor admission, b2a-ii-a Darwin physical session and b2b
entry/artifact. b0 is frozen/non-admitting; iii-a per-epoch continuity, iii-b1
injected cohort, iii-b2a0 and iii-b2a-i are complete/non-admitting;
iii-b2a-ii-a1 is complete/non-admitting. The a2 scope/trust preflight split its
remaining work into a2-0 untrusted decode, a2-i inherited-PGID App session and
a2-ii terminal/admission composition; a2-0, a2-i and a2-ii are complete/non-admitting.
iii-b2b-0 Release graph closure, iii-b2b-1a-0 canonical helper-provenance
carriage and iii-b2b-1a-1 concrete outer observation are complete/non-admitting;
iii-b2b-1b zero-argument entry/artifact is also complete/non-admitting after its
1b-i/1b-ii implementation split. The fresh ii-c0b preflight split the work into
c0b-i semantic producer, c0b-ii owner-only capsule node, c0b-iii fixed launcher/
stub and c0b-iv zero-argument final composition. c0b-i is complete/non-admitting
after its exact 7-path / 1,900-line implementation, 95 tests / 5 suites, three
green gates and independent final review. The c0b-ii fresh preflight split it
into ii-c0b-ii-a kernel ownership and ii-c0b-ii-b capsule owner. A budget
trigger then split ii-a into exact 3-path / 2,000-line ii-c0b-ii-a1 behavior and
exact 4-path / 1,200-line ii-c0b-ii-a2 verifier closure. a1 is complete at
`d18354b` / tree `d6a4b0e`, exact 3 paths / 1,981 lines, with 132 concrete
cases, target/object/APFS evidence and no unresolved P0-P2. a2 is also
complete/non-admitting at implementation
`f11eea42ef295f49b20e1c0f3912d4b32448b968` / tree
`d0683495ea37d0692677c98f491f3037eaedba4c`, exact 4 non-document paths /
889 changed lines; the a1+a2 aggregate is 7 paths / 2,870 lines. Its bare
verify-contract, component and App-Release gates exited 0, and two independent
reviews found no unresolved P0-P2. It ran no serial/full/root/App/XPC/model/
network gate. The corrected retained-base/publication/settlement/verifier
sequence and c0b-iii fixed gate are complete/non-admitting at accepted checkpoint
`ced4da2`. The mandatory c0b-iv preflight freezes iv-a0 authoritative binding/
configuration/source inputs and iv-a-r provenance/App admission closure, then
dynamically splits the former iv-b1 into iv-b1a typed outcome/injected semantic
closure, iv-b1b-i injected Darwin lifecycle/adapter, and iv-b1b-ii dedicated
outer-adapter physical/verifier closure before iv-b2's zero-
argument executable/verifier closure. iv-a0 and iv-a-r are complete/non-
admitting. iv-b1a is complete/non-admitting at clean index-only snapshot
`db4e936` / tree `412da586d13fae7fd53937231217778b5d9ffd52`: exactly 6
non-document paths / +2,113/-3, staged-
only 48/48 focused and 785/785 affected tests, Debug via tests, Release target
build exit 0, tests-first closure of four initial-review P1 findings, and three
independent post-fix groups with no unresolved P0-P2. It ran no global serial,
full, root, real App/XPC, model or network gate. iv-b1b design review now freezes
iv-b1b-i at exact 3 paths with <=1,180 production changed lines (Darwin adapter,
injected lifecycle and deterministic tests), followed by iv-b1b-ii exact 5 paths
(dedicated physical fixture and tests, boundary test, and two verifiers). The
iv-b1 aggregate is exactly 14 non-document paths. iv-b1b-i closed at
implementation `41d34f26` / tree `8ab58932`, exact three paths / 1,173
production changed lines, 806/806 affected tests, a clean staged-only Release
target build and two final review groups with no unresolved P0-P2. It is
complete/non-admitting. iv-b1b-ii then closed at implementation `373431d4` /
tree `b08342e5`, exact five paths / 2,193 changed lines, a passing seven-scenario
physical matrix, 808/808 clean staged-only serial, three dedicated gates and
physical/verifier/cross-group reviews with no unresolved P0-P2. The accepted
c0b-iii PTY evidence cannot substitute for exercising the new outer adapter;
iv-b1b-ii therefore owns the now-complete dedicated non-product physical
evidence. The former
`ii-c0b-ii-a3 current` text is superseded.
a2-i closed at
implementation commit `158f500` and tree
`c7a42ffd`: exact 10 non-document paths / 1,965 changed lines, 66 focused
tests, a clean 1,500-test / 78-suite staged-only serial, exact SwiftPM/Xcode
Debug/Release projections, complete contract replay and no unresolved P0-P2.
a2-ii closed at implementation commit `8eac2c4f` / tree `9e3bdefd`, sealed by
`70603a0`: exact 12 non-document paths / 3,673 changed lines, 55 focused tests,
a clean 1,516-test / 79-suite staged-only serial, global source boundary,
complete contract/final-Mach-O gates and no unresolved P0-P2.
iii-b2b-0 closed at implementation commit `c8cc514` / tree `d615795`, sealed by
`6474016`: exact 7 non-document paths / 1,096 changed lines, 20 focused, 37
target-boundary and 1,517 serial tests, Debug/Release graph gates, immutable
8-path replay and no unresolved P0-P2. See the
[iii-b2b-0 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2b-0-review.md).
iii-b2b-1a-0 closed at implementation commit `53c5594` / tree `f9322fa`, with
test-only prerequisite `59d3bb7` and immutable seal `8361168`: exact 8
non-document implementation paths / 1,336 changed lines, 38 target-boundary
tests, 1,525-test / 79-suite staged serial, complete contract/App-Release gates
and no unresolved P0-P2. See the
[iii-b2b-1a-0 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2b-1a0-review.md).
iii-b2b-1a-1 closed at implementation commit `fe4f6ad` / tree `6bd6d384`,
sealed by `2c31a7c`: exact 8 non-document paths / 2,800 changed lines, a
1,535-test / 80-suite staged serial, complete App/Release and contract gates
and no unresolved P0-P2. See the
[iii-b2b-1a-1 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2b-1a1-review.md).
iii-b2b-1b-i closed the production entry at commit `6b26082` / tree `462d40b`:
exact 5 non-document paths / 2,434 changed lines, a 1,550-test / 81-suite
staged serial and four tests-first review P1 closures. iii-b2b-1b-ii then
closed exact SwiftPM/Xcode projections and verifier admission at commit
`1c8ab1d` / tree `d7b6c05`, sealed by `a314b85` / tree `aac9d81`; the complete
contract and App/Release gates, 1/1 seal marker and independent reviews passed
with no unresolved P0-P2. See the
[iii-b2b-1b review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2b-1b-review.md).
iii-a closed at
implementation
commit `4538e52a4ceafded60df302903aec1877e66bc40` and tree
`2eeb307cfb2cf67a1b169e0a510c92ea2dc9dbb2`: exact 10 paths / 3,147
changed lines, 40 focused tests, 559 affected tests, a clean 1,446-test /
74-suite staged-only serial, all three boundary gates and no unresolved P0-P2.
iii-b1 closed at implementation commit
`5e2365d0c5f3fbeef8e015f5e9ad4252c484217e` and tree
`b46d39bfcb4a24cee80b4be9562e281519450cb8`: exact 7 paths / 2,438
changed lines, 13 focused tests, 573 affected tests, a clean 1,455-test /
75-suite staged-only serial, all three boundary gates, immutable replay seal and
no unresolved P0-P2. See the
[iii-b1 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b1-review.md).
iii-b2a0 closed at implementation commit
`65f85c5adbb01b41b1bf9a5f787951f9feb4660d`, parent
`7c114e09c915e2685545872101e7c5854ce2cffd` and tree
`7df0d5597f498e3588823885d226bdd02befc058`: exact eight non-document paths /
2,198 changed lines, 36 combined tests / 3 suites, 580 affected tests / 43
suites, a clean 1,462-test / 76-suite staged-only serial, all three boundary
gates, Debug diagnostic and Release driver builds, immutable seal
`3f62678306d982edf986acf8a2ef12c3c4081741` and no unresolved P0-P2. Its
physical result is an untrusted DTO and cannot enter the single-epoch result or
continuity join. See the
[iii-b2a0 preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2a0-typed-physical-bridge-preflight.md)
and
[iii-b2a0 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2a0-review.md).
iii-b2a-i closed the package-closed canonical supervisor protocol, one-shot
receiver, private admitted token and same-owner containment proof. Its original
implementation changed 10 non-document paths / 3,236 lines; its tests-first r1
closure changed 8 paths / 977 lines and closed six review findings. Twelve
focused, 593 affected and one 1,475-test / 77-suite frozen-tree serial passed,
along with all three boundary gates, Debug/Release Machine Driver builds, the
immutable seal and independent no-unresolved-P0-P2 review. See the
[iii-b2a-i review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2a-i-review.md).
See the
[study](../../upstream-studies/phase-d-task-39b2c-l3c3c-parent-owned-handoff.md),
[final review](../../reports/phase-d-task-39b2c-l3c3c-i-handoff-launcher-spike-review.md)
and [i-b2a review](../../reports/phase-d-task-39b2c-l3c3c-i-b2a-reproducibility-contract-review.md),
plus the [i-b2b-0a audit](../../reports/phase-d-task-39b2c-l3c3c-i-b2b-0a-root-provenance-review.md)
and [installed-driver preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-installed-driver-path-cost-preflight.md),
plus the [ii-a completion review](../../reports/phase-d-task-39b2c-l3c3c-ii-a-installed-driver-observation-review.md).
The narrower budgets and protocol/topology corrections are frozen in the
[ii-b split preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b-split-preflight.md)
and [ii-b0 wire preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b0-wire-contract-preflight.md).
Completion evidence is in the
[ii-b0a review](../../reports/phase-d-task-39b2c-l3c3c-ii-b0a-review.md) and
[ii-b0b review](../../reports/phase-d-task-39b2c-l3c3c-ii-b0b-review.md).
The inserted bootstrap contract is frozen in the
[ii-b0c preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b0c-epoch-bootstrap-preflight.md).
Completion evidence is in the
[ii-b0c review](../../reports/phase-d-task-39b2c-l3c3c-ii-b0c-review.md).
The authority-free leaf contract and completion evidence are in the
[ii-b1 preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b1-app-leaf-preflight.md)
and
[ii-b1 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b1-review.md).
The ii-b2 ASID prerequisite is complete. It corrected the false App/helper
same-ASID join while preserving complete independent identities and binding L1
residue to the helper. Its implementation/verifier tree passed 1,142 serialized
tests; the completion-audit decoder-negative supplement independently passed
1,143 serialized tests and final review found no unresolved P0-P2. See the
[ASID prerequisite review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2-asid-prerequisite-review.md).
ii-b2a typed escrow/deadline state is complete after its focused/affected/
coverage/structural gates, sole 1,162-test combined staged serial and final
independent audit. See the
[ii-b2a review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2a-review.md).
ii-b2b-i is complete after sealed Lifecycle transfer, non-actor shared-wire
translation, 59 focused tests, one 1,194-test staged-only serial, exact
source/package/mutation gates and independent post-fix reviews. See the
[ii-b2b-i review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2b-i-review.md).
ii-b2 remains split; ii-b2b-ii legacy-client quarantine / Machine production
block, ii-b2b-iii-a handle-v3/single-quantized transfer and iii-b public live
façade/helper integration are complete.
See the
[ii-b2b-ii review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2b-ii-review.md).
Completion evidence for iii-a is in the
[handle v3 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2b-iii-a-review.md).
Completion evidence for iii-b-i is in the
[live integration review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2b-iii-b-i-review.md).
Completion evidence for iii-b-ii is in the
[physical adapter review](../../reports/phase-d-task-39b2c-l3c3c-ii-b2b-iii-b-ii-review.md).
The current b3a/b3b/b3c order, trust classification and budgets are frozen in the
[ii-b3 preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b3-split-preflight.md).
ii-b3 completion evidence is in the
[ii-b3a review](../../reports/phase-d-task-39b2c-l3c3c-ii-b3a-review.md),
[ii-b3b fixture review](../../reports/phase-d-task-39b2c-l3c3c-ii-b3b-fixture-prerequisite-review.md),
[ii-b3b seam review](../../reports/phase-d-task-39b2c-l3c3c-ii-b3b-review.md)
and [ii-b3c review](../../reports/phase-d-task-39b2c-l3c3c-ii-b3c-review.md).
The fixed-client contract and completion evidence are in the
[ii-b4 preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b4-preflight.md)
and [ii-b4 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b4-review.md).
The current ii-b5 contract is split by the
[ii-b5 preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b5-split-preflight.md)
into ii-b5a0 claim-abort, ii-b5a typed composition, ii-b5b-i L2/projection,
ii-b5b-ii fixed Darwin runtime and ii-b5b-iii production/artifact composition;
ii-b5a0, ii-b5a, ii-b5b-i-a, i-b1 and i-b2a are complete/non-admitting.
ii-b5b-i-b is complete through i-b3; i-c1 join/proof and i-c2a semantic-owner
closure are complete/non-admitting; aggregate i-c2, ii-b5b-ii-a fixed FD-0
capsule intake, ii-b5b-ii-b independent Darwin App identity observation and
ii-b5b-ii-c fixed FD-7 session and ii-b5b-ii-d exact owned-PGID retirement are
complete/non-admitting. ii-c0a is complete/non-admitting; ii-b5b-iii-b0 is
frozen/non-admitting; iii-a, iii-b1, iii-b2a0, iii-b2a-i,
iii-b2a-ii-a1, a2-0, a2-i, a2-ii, iii-b2b-0, iii-b2b-1a-0,
iii-b2b-1a-1, iii-b2b-1b, c0b-i, c0b-ii and c0b-iii are complete/non-admitting.
iv-a0, iv-a-r, iv-b1a, iv-b1b-i, iv-b1b-ii and iv-b2 are
complete/non-admitting.
iv-b1b-i closed at implementation `41d34f26` / tree `8ab58932`, exact three
paths / 1,173 production changed lines, 806/806 affected tests, a clean
staged-only Release target build and two final review groups with no unresolved
P0-P2. iv-b1b-ii closed at implementation `373431d4` / tree `b08342e5`, exact
five paths / 2,193 changed lines, seven physical scenarios, 808/808 serial and
three no-unresolved-P0-P2 review groups. iv-b2 closed at implementation
`4e8d672d35e4416b0114c5c4dbebb1cb6a4d5089` / tree
`e02a515283225b0b19443a47fad0b90fe3d0ddfd` and remains non-admitting.
The shared-deadline repair at `c144c1e`, fixed-gate deadline cleanup repair at
`bc42fbc`, interactive-native identity binding repair `531f79f` / consumer seal
`26e785a`, and fixed-gate historical replay `aa8a7f1` are complete/non-admitting.
ii-c-a is complete/non-admitting at implementation `81f185c` / tree
`7cf4db75`. ii-c-b1 is complete/non-admitting at implementation `77cde61` /
tree `9c59f241`; ii-c-b2a1 is complete/non-admitting at implementation
`e3555ec` / tree `f38783f`; ii-c-b2a2 is complete/non-admitting at implementation
`294bdb2` / tree `dbbffbba`. Resolved root-driver lineage L1 is complete at
implementation `83f6271` / tree `98289e2`; L2 implementation `474f634`,
cross-UID/PID-reuse corrections and final verifier closure `849e454` are also
complete/non-admitting; the final post-fix review returned no finding. The
historical pre-v8 order was ii-c-c -> L3c3d -> L3c4, but v8 is now consumed,
failed, and non-retryable. No live machine frontier exists without explicit user
approval for a replacement privileged campaign and plan amendment. These
repairs are machine-campaign prerequisite checkpoints, not recursively named
new Tasks. Review findings and
local repairs stay within their owning checkpoint. L3c4 alone owns the remaining
authoritative full.
See the
[ii-b5a review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5a-review.md) and
[ii-b5b-i-a review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-i-a-review.md) and
[ii-b5b-i-b1 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-i-b1-review.md) and
[ii-b5b-i-b2a review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-i-b2a-review.md) and
[ii-b5b-i-b2b split preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-i-b2b-split-preflight.md) and
[ii-b5b-i-b2b-a review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-i-b2b-a-review.md) and
[ii-b5b-i-b2b-b review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-i-b2b-b-review.md) and
[ii-b5b-i-b3 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-i-b3-review.md) and
[ii-b5b-i-c1 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-i-c1-review.md),
[ii-b5b-i-c2a review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-i-c2a-review.md) and
[ii-b5b-i-c2b preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-i-c2b-preflight.md) and
[ii-b5b-i-c2b review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-i-c2b-review.md) and
[ii-b5b-ii preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-ii-preflight.md),
[ii-b5b-ii-a review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-ii-a-review.md),
[ii-b5b-ii-b review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-ii-b-review.md),
[ii-b5b-ii-c review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-ii-c-review.md),
[ii-b5b-ii-d review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-ii-d-review.md),
[ii-c0a preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-c0a-projection-capsule-preflight.md),
[ii-c0a review](../../reports/phase-d-task-39b2c-l3c3c-ii-c0a-review.md),
[ii-c0b-i review](../../reports/phase-d-task-39b2c-l3c3c-ii-c0b-i-review.md),
[ii-c0b-ii ownership preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-c0b-ii-ownership-preflight.md) and
[ii-c0b-ii-a2 review](../../reports/phase-d-task-39b2c-l3c3c-ii-c0b-ii-a2-review.md) and
[ii-c0b-iv preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-c0b-iv-preflight.md),
[ii-c0b-iv-a0 review](../../reports/phase-d-task-39b2c-l3c3c-ii-c0b-iv-a0-review.md),
[ii-c0b-iv-a-r review](../../reports/phase-d-task-39b2c-l3c3c-ii-c0b-iv-a-r-review.md),
[ii-c0b-iv-b1a review](../../reports/phase-d-task-39b2c-l3c3c-ii-c0b-iv-b1a-review.md),
[ii-c0b-iv-b1b-i review](../../reports/phase-d-task-39b2c-l3c3c-ii-c0b-iv-b1b-i-review.md),
[ii-c0b-iv-b1b-ii review](../../reports/phase-d-task-39b2c-l3c3c-ii-c0b-iv-b1b-ii-review.md),
[ii-c0b-iv-b2 review](../../reports/phase-d-task-39b2c-l3c3c-ii-c0b-iv-b2-review.md),
[shared-deadline completion audit](../../reports/phase-d-task-39b2c-shared-deadline-repair-review.md) and
[fixed-gate deadline cleanup completion audit](../../reports/phase-d-task-39b2c-fixed-gate-deadline-cleanup-repair-review.md), and
[ii-c machine campaign preflight](../../reports/phase-d-task-39b2c-iic-machine-campaign-preflight.md) and
[ii-c-a static installed topology review](../../reports/phase-d-task-39b2c-iic-a-static-installed-topology-review.md), and
[ii-c-b1 root-owned Gate review](../../reports/phase-d-task-39b2c-iic-b1-root-owned-gate-review.md), and
[ii-c-b2 split preflight](../../reports/phase-d-task-39b2c-iic-b2-split-preflight.md), and
[ii-c-b2a1 evidence producer review](../../reports/phase-d-task-39b2c-iic-b2a1-evidence-producer-review.md), and
[ii-c-b2a2 independent verifier review](../../reports/phase-d-task-39b2c-iic-b2a2-independent-verifier-review.md),
[ii-c-b2b transport preflight](../../reports/phase-d-task-39b2c-iic-b2b-transport-preflight.md), and
[resolved root-driver lineage preflight](../../reports/phase-d-task-39b2c-iic-resolved-root-driver-lineage-preflight.md), and
[resolved root-driver lineage L1 review](../../reports/phase-d-task-39b2c-iic-resolved-root-driver-lineage-l1-review.md), and
[resolved root-driver lineage L2 review](../../reports/phase-d-task-39b2c-iic-resolved-root-driver-lineage-l2-review.md), and
[ii-b5b-iii-b0 preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b0-outer-inner-protocol-preflight.md) and
[ii-b5b-iii-a review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-a-review.md) and
[ii-b5b-iii-b1 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b1-review.md) and
[ii-b5b-iii-b2a0 preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2a0-typed-physical-bridge-preflight.md) and
[ii-b5b-iii-b2a0 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2a0-review.md) and
[ii-b5b-iii-b2a-i review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2a-i-review.md) and
[ii-b5b-iii-b2a-ii-a1-v review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2a-ii-a1-v-review.md) and
[ii-b5b-iii-b2a-ii-a2-0 review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2a-ii-a2-0-review.md) and
[ii-b5b-iii-b2a-ii-a2-i review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2a-ii-a2-i-review.md) and
[ii-b5b-iii-b2a-ii-a2-ii review](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2a-ii-a2-ii-review.md) and
[ii-b5b-i preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b5b-i-exact-path-preflight.md).
The preceding ii-b2b-iii split is frozen by the
[ii-b2b-iii preflight](../../reports/phase-d-task-39b2c-l3c3c-ii-b2b-iii-split-preflight.md).
Only L3c4 owns machine readiness and the remaining full verifier.
The L3c2b preflight's
[plan-freshness prerequisite](../../reports/phase-d-task-39b2c-l3c2b-plan-freshness-prerequisite-review.md)
is complete: real fresh plan fingerprints are unique, one target-set fingerprint
binds the cohort, and 59-test affected plus 189-test Investigation gates passed.
The former immediate-predecessor scheduling rule for Tasks 40–44 is superseded
by the sprint above. Task 44 production admission still requires all integrated
runtime and product evidence; Task 39 failure never becomes a Ready receipt.

The normative low-level contract is
[Investigation Canonical v1](../../specs/investigation-canonical-v1.md).
Task 36 is deterministic and non-executing: it added the canonical codec,
source projection, v2 Investigation domain, Candidate Planner, budget ledger
and stop evaluator. It did not launch Codex, call a model, migrate the Store,
change App availability or create cleanup authority.

Production Deep Dive remains `.implementationUnavailable` until Task 44 is
the sole normal-product admission gate.

| Task | Scope | Status |
| --- | --- | --- |
| [36](task-36-implementation-brief.md) | Domain, canonical projection, planner, budget and stop contracts | complete; [review](../../reports/phase-d-task-36-review.md) |
| [37](task-37-implementation-brief.md) | Store v4, retention and source rejoin | complete; [review](../../reports/phase-d-task-37-review.md) |
| [38](task-38-implementation-brief.md) | Closed coordinator with fake runtime | complete; [review](../../reports/phase-d-task-38-review.md) |
| [39](task-39-implementation-brief.md) | Signed-App production-runtime admission | active/incomplete; P2 at 7054ced complete; v18 pending; L3c3d/L3c4 unproven |
| [40](task-40-implementation-brief.md) | Evidence report and conservative Review projection | complete in closed-fixture scope; [review](../../reports/phase-d-task-40-review.md); production admission remains closed |
| [41](task-41-implementation-brief.md) | First-use disclosure and typed availability | active next; consumes Task 40 public projection |
| [42](task-42-implementation-brief.md) | App workflow, recovery and closed normal factory | develop incrementally on Task 40/41 interfaces; not implemented |
| [43](task-43-implementation-brief.md) | Investigations UI and navigation | develop against Task 42 state/fixtures; not implemented |
| [44](task-44-implementation-brief.md) | Production vertical slice and final gate | preparation allowed; production admission pending all required evidence |
