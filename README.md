# Stornaut

> Map the known. Investigate the unknown. Reclaim with evidence.

**读音**：`STORE-naut`（/ˈstɔːr.nɔːt/，两音节）。名字由 `storage + -naut` 构成，意为“存储空间探索者”。

## 一句话定位

**Stornaut 是证据驱动的开发者磁盘调查与治理工具：成熟规则快速处理已知空间，Codex 调查指挥官按科学方法追踪未知空间，Swift 安全执行链掌握最终写权限。**

## 缘起

2026-08-06，一块 460GB 的磁盘告急（仅剩 10GB，98%）。作者用 Claude Code 做了三轮"扫描 → 分级 → 确认 → 清理"的人机协作，**安全释放 ~70GB**，其中绝大部分是 CleanMyMac / BuhoCleaner 找不到的开发者特有占用：

- 1204 个 `node_modules`（23.7 GB）
- 41 个 `.venv`（10 GB，多个含 torch）
- 各包管理器缓存（uv/pnpm/bun/npm/go，~44 GB）
- AI 工具的 VM 镜像、更新残留、旧版扩展……

完整过程记录：[docs/research/case-study-2026-08-06.md](docs/research/case-study-2026-08-06.md)

## 状态

🚧 产品、Agent、UI 功能交互与品牌基线已批准；Epic 0–1 foundation/risk
spikes 已完成。Epic 2–4 deterministic product core 的实现、focused gate 与
真实机器证据已完成；用户已完成标准 Automation Mode 认证，首次 strengthened
verifier 暴露的负载敏感测试、认证编排和 UI-runner 竞态已修复；最终统一
verifier 单次 exit 0，Phase B 已关闭。当前 Quick Scan 在 460 GiB-class 本机 Home
范围内用 Swift product path 于 5 分钟内完成，保持 bounded memory、
Partial/Unmeasurable truth、零 Codex 与零目标写入。Deep Dive 的旧
Broker-only 前提已由 ADR 0004 修订为能力优先边界：Codex 可直接只读调查、
live search 与访问公共互联网，但仍无本地写入或清理执行权。R1–R6 runtime
foundation evidence gate 已得出 `go`；生产 Deep Dive 仍未实现，release
仍未评估。Phase C Tasks 27–35 已完成：唯一 signed-App diagnostic Trash
attempt、zero-replay recovery、source-bound receipt、独立审查与 authoritative
full verifier 均通过，admission 为 `go`；普通 App execution 仍
`writeDisabled`。Phase D Tasks 36–38 已完成；Task 38 closed fake-runtime
coordinator、strict event/lineage/token normalization、terminal/recovery
barrier、独立审查、811-test serialized regression 与 23/23 authoritative
full verifier 均通过。Task 39 已进入 signed-App diagnostic gate；39A
contract/composition foundation 与 39B1a Store/async-lifecycle prerequisites
已完成并分别通过独立审查与 23/23 authoritative full verifier；39B1b-i
package-closed transport/non-product composition 也已完成并通过独立审查与
23/23 authoritative full verifier。39B1b-ii strict DEBUG App leaf 的实现、
11-test dedicated App target、pure-product Debug/Release boundary、846-test
serialized regression、独立 post-fix review 与 23-stage authoritative full
verifier 已通过。Task 39B2c 仍在实现：aggregate i-c2、
L3c3c-ii-b5b-ii-a/ii-b/ii-c/ii-d 与 ii-c0a 均已完成并保持
non-admitting。ii-c0a 的 exact 8-path / 1,863-line implementation、
90 focused、536 affected、1,418-test/73-suite clean serial、三项 boundary
gates 与 independent review 已通过。fresh source/topology audit 又将原
ii-b5b-iii 拆为 b0 protocol、a per-epoch continuity、b1 injected cohort、
b2a0 typed physical bridge、b2a-i canonical supervisor admission、b2a-ii-a
Darwin physical session 与 b2b entry/artifact；b0 preflight 已冻结，iii-a、
iii-b1、iii-b2a0 与 iii-b2a-i 已完成并保持 non-admitting。
iii-b1 的 exact 7-path / 2,438-line
implementation、13 focused、573 affected、1,455-test/75-suite clean serial、
三项 boundary gates、immutable replay seal 与 independent review 已通过；
iii-b2a0 的 exact 8-path / 2,198-line implementation、36-test/3-suite combined
bridge/continuity/cohort、580-test/43-suite affected、1,462-test/76-suite clean
serial、三项 boundary gates 与 independent semantic/verifier/cross-group review
已通过。physical result 仍是 untrusted DTO，不能直接进入 single-epoch result
或 continuity；iii-b2a-i 已关闭 canonical protocol、one-shot receiver、private
admission 与 same-owner containment proof；iii-b2a-ii-a1、a2-0、a2-i、
a2-ii、iii-b2b-0、iii-b2b-1a-0 与 iii-b2b-1a-1 已完成并保持
non-admitting。iii-b2b-1b 因预算触发拆分：1b-i production/focused
implementation `6b2608258d59787bca592012086a2377d647473e`（tree
`462d40bfc36954ec60c533e946bbd0019470aa88`）以 5 paths / 2,434 changed
lines 完成，1,550 tests / 81 suites 通过，4 个 P1 已修复且无 unresolved
P0–P2；1b-ii verifier/Mach-O implementation
`1c8ab1d5c06f87f7d2af548228835adcd43a1ae9`（tree
`d7b6c05fdb90f0db693e8f506e45eae5b98a45f9`）以 4 paths / 971 changed
lines 完成，`verify-contract` 与 App/Release gates 均 exit 0，独立审查无
unresolved P0–P2；immutable seal
`a314b855f9e5d15d3bf7789d95533369b7cb1349`（tree
`aac9d81a7275e964999ebe1d0d9d057bd8db34a4`）已落盘。1b 整体
complete/non-admitting，未运行 `verify --full`、root/App/XPC/model/network；
ii-c0b-i 已以 exact 7 non-document paths / 1,900 changed lines、95 tests /
5 suites、三项 green gates 与 independent no-unresolved-P0–P2 review 完成并
保持 non-admitting；按设计未运行 serial/full 或任何 root/App/helper/driver
live path。c0b-ii fresh preflight 已完成并拆为 ii-c0b-ii-a kernel ownership 与
ii-c0b-ii-b capsule owner；ii-a 又因 2,600-line 预算漂移拆为 exact 3-path /
2,000-line a1 behavior 与 exact 4-path / 1,200-line a2 verifier closure；a1 已以
commit `d18354b` / tree `d6a4b0e`、3 paths / 1,981 lines、132 concrete cases、
target/object/APFS gates 与 no-unresolved-P0–P2 review 完成。a2 已以
implementation `f11eea42ef295f49b20e1c0f3912d4b32448b968` / tree
`d0683495ea37d0692677c98f491f3037eaedba4c`、exact 4 non-document paths /
889 changed lines 完成；a1+a2 aggregate 为 7 paths / 2,870 lines，bare
verify-contract/component/App-Release gates exit 0，双人 review 无 unresolved
P0–P2，按设计未运行 serial/full/root/App/XPC/model/network。a2 保持
non-admitting。retained-base、capsule publication/settlement、fixed launcher 与
verifier closure 随后全部完成并推送；当前 `ced4da2` 已关闭 c0b-i/c0b-ii/
c0b-iii，均保持 non-admitting。c0b-iv 的 iv-a0、iv-a-r、iv-b1a、iv-b1b-i
与 iv-b1b-ii 已完成并保持 non-admitting；iv-b1b-ii 以 exact 5 paths /
2,193 changed lines、七场景 physical matrix、808/808 clean serial、三项
dedicated gates 与无 unresolved P0–P2 的独立终审收口。iv-b2 已以
implementation `4e8d672d35e4416b0114c5c4dbebb1cb6a4d5089` / tree
`e02a515283225b0b19443a47fad0b90fe3d0ddfd` 完成并保持 non-admitting。
shared-deadline repair `c144c1e`、fixed-gate deadline cleanup repair
`bc42fbc`、interactive-native identity binding repair `531f79f` / consumer
seal `26e785a` 与 fixed-gate historical replay `aa8a7f1` 均已完成并保持
non-admitting。ii-c-a 已以 implementation `81f185c` / tree `7cf4db75` 完成；
当前 frontier 为 ii-c-b → ii-c-c → L3c3d → L3c4；这些 repairs 是
machine-campaign prerequisite checkpoints，不是新的 Task。machine admission
尚未发生，最终 authoritative full 仍仅归
L3c4；Task 39 尚未完成，production Deep Dive 仍 unavailable。
见文档：

| 文档 | 内容 |
|---|---|
| [docs/README.md](docs/README.md) | 文档地图、规范优先级、生命周期和 Coding Agent 读取规则 |
| [docs/agent/development-tooling.md](docs/agent/development-tooling.md) | 固定版本 XcodeBuildMCP、Peekaboo 只读边界与真实窗口 UI 验证循环 |
| [docs/agent/ui-testing-guide.md](docs/agent/ui-testing-guide.md) | UI 分层测试、Light/Dark/Settings 截图契约与图形会话排障 |
| [docs/product/PRD.md](docs/product/PRD.md) | 完整产品需求：双模式、Agent 调查、安全与验收标准 |
| [docs/architecture/system-architecture.md](docs/architecture/system-architecture.md) | 原生 Swift 全栈 + Codex 子进程 + Probe Broker 技术架构 |
| [docs/design/agent-disk-governance.md](docs/design/agent-disk-governance.md) | 用户批准的 Agent、双模式与安全设计基线 |
| [docs/design/ui-ux.md](docs/design/ui-ux.md) | 单窗口信息架构、核心流程、Agent 表达、Light/Dark 与品牌规范 |
| [docs/assets/ui-concepts/RESILIENCE-STATES-ROUND-1.md](docs/assets/ui-concepts/RESILIENCE-STATES-ROUND-1.md) | 权限受限、安全阻断、部分结果、stale preflight 与历史保留的恢复状态契约 |
| [docs/reports/epic-2-4-validation-report.md](docs/reports/epic-2-4-validation-report.md) | Phase B domain/persistence、真实 Quick Scan benchmark、accounting、UI 与 scope gate |
| [docs/plans/completed/epic-2-4-deterministic-product-core.md](docs/plans/completed/epic-2-4-deterministic-product-core.md) | 已归档的 Phase B Tasks 9–26 计划与逐 Task 证据 |
| [docs/plans/active/README.md](docs/plans/active/README.md) | Phase D approved；Tasks 36–38 complete，Task 39B2c in progress；ii-c-a complete/non-admitting；current frontier ii-c-b → ii-c-c → L3c3d → L3c4；machine admission pending |
| [docs/reports/phase-d-task-39b2c-l3c3c-ii-c0a-projection-capsule-preflight.md](docs/reports/phase-d-task-39b2c-l3c3c-ii-c0a-projection-capsule-preflight.md) | v1 capsule bytes preserved；frozen enclosing projected-cohort binary contract、8-path/2,600-line ceiling and corrected remaining order |
| [docs/reports/phase-d-task-39b2c-l3c3c-ii-c0a-review.md](docs/reports/phase-d-task-39b2c-l3c3c-ii-c0a-review.md) | ii-c0a exact 8-path / 1,863-line completion、90 focused、536 affected、1,418-test serial、boundary gates 与 independent review |
| [docs/reports/phase-d-task-39b2c-l3c3c-ii-c0b-i-review.md](docs/reports/phase-d-task-39b2c-l3c3c-ii-c0b-i-review.md) | c0b-i semantic producer completion audit；exact 7 paths / 1,900 lines、95 tests / 5 suites；complete/non-admitting |
| [docs/reports/phase-d-task-39b2c-l3c3c-ii-c0b-ii-ownership-preflight.md](docs/reports/phase-d-task-39b2c-l3c3c-ii-c0b-ii-ownership-preflight.md) | APFS physical evidence；ii-c0b-ii-a kernel ownership → ii-c0b-ii-b capsule owner；ii-a budget split frozen |
| [docs/reports/phase-d-task-39b2c-l3c3c-ii-c0b-ii-a-budget-split-preflight.md](docs/reports/phase-d-task-39b2c-l3c3c-ii-c0b-ii-a-budget-split-preflight.md) | original 7-path / 2,600-line ii-a split into exact 3-path / 2,000-line a1 behavior and exact 4-path / 1,200-line a2 verifier closure；a1/a2 complete/non-admitting |
| [docs/reports/phase-d-task-39b2c-l3c3c-ii-c0b-ii-a1-review.md](docs/reports/phase-d-task-39b2c-l3c3c-ii-c0b-ii-a1-review.md) | a1 ownership behavior completion；3 paths / 1,981 lines、132 concrete cases、target/object/APFS gates；complete/non-admitting |
| [docs/reports/phase-d-task-39b2c-l3c3c-ii-c0b-ii-a2-review.md](docs/reports/phase-d-task-39b2c-l3c3c-ii-c0b-ii-a2-review.md) | a2 verifier closure；implementation `f11eea42` / tree `d0683495`、4 paths / 889 lines、a1+a2 7 paths / 2,870 lines、bare gates exit 0、双人 review 无 unresolved P0–P2；complete/non-admitting |
| [docs/reports/phase-d-task-39b2c-l3c3c-ii-c0b-iv-b1b-i-review.md](docs/reports/phase-d-task-39b2c-l3c3c-ii-c0b-iv-b1b-i-review.md) | iv-b1b-i injected Darwin lifecycle；implementation `41d34f26` / tree `8ab58932`、3 paths / 1,173 production lines、806/806 affected、Release target 与两组终审；complete/non-admitting |
| [docs/reports/phase-d-task-39b2c-l3c3c-ii-c0b-iv-b1b-ii-review.md](docs/reports/phase-d-task-39b2c-l3c3c-ii-c0b-iv-b1b-ii-review.md) | iv-b1b-ii dedicated physical/verifier closure；implementation `373431d4` / tree `b08342e5`、5 paths / 2,193 lines、七场景 physical、808/808 serial、三项 gates 与无 unresolved P0–P2 review；complete/non-admitting |
| [docs/reports/phase-d-task-39b2c-l3c3c-ii-c0b-iv-b2-review.md](docs/reports/phase-d-task-39b2c-l3c3c-ii-c0b-iv-b2-review.md) | iv-b2 zero-argument coordinator/verifier closure；implementation `4e8d672d35e4416b0114c5c4dbebb1cb6a4d5089` / tree `e02a515283225b0b19443a47fad0b90fe3d0ddfd`；complete/non-admitting |
| [docs/reports/phase-d-task-39b2c-iic-machine-campaign-preflight.md](docs/reports/phase-d-task-39b2c-iic-machine-campaign-preflight.md) | ii-c split：ii-c-a static topology complete；ii-c-b root-owned Gate/dry-run harness current；ii-c-c owns the unique privileged campaign |
| [docs/reports/phase-d-task-39b2c-iic-a-static-installed-topology-review.md](docs/reports/phase-d-task-39b2c-iic-a-static-installed-topology-review.md) | ii-c-a implementation `81f185c` / tree `7cf4db75`、11 paths / 2,669 lines、856/856 affected serial；complete/non-admitting |
| [docs/reports/phase-d-task-39b2c-shared-deadline-repair-review.md](docs/reports/phase-d-task-39b2c-shared-deadline-repair-review.md) | shared-deadline repair；implementation `c144c1e` / tree `3c2d7f0`；14 paths / 1,500 lines；complete/non-admitting |
| [docs/reports/phase-d-task-39b2c-fixed-gate-deadline-cleanup-repair-review.md](docs/reports/phase-d-task-39b2c-fixed-gate-deadline-cleanup-repair-review.md) | fixed-gate absolute-deadline cleanup；implementation `bc42fbc` / tree `29eb2d0`；5 paths / 399 lines、847/847 serial；complete/non-admitting |
| [docs/reports/phase-d-task-39b2c-interactive-native-identity-binding-repair-preflight.md](docs/reports/phase-d-task-39b2c-interactive-native-identity-binding-repair-preflight.md) | completed exact 14-path interactive-native contract；strict digest propagation → suspended native launch/observed-digest closure |
| [docs/reports/phase-d-task-39b2c-interactive-native-identity-binding-repair-review.md](docs/reports/phase-d-task-39b2c-interactive-native-identity-binding-repair-review.md) | implementation `531f79f` / tree `00a8434d`、2,389 lines、1,756-test serial、Debug/Release 与 boundary gates；complete/non-admitting |
| [docs/reports/phase-d-task-39b2c-fixed-gate-deadline-cleanup-historical-replay-preflight.md](docs/reports/phase-d-task-39b2c-fixed-gate-deadline-cleanup-historical-replay-preflight.md) | fixed-gate accepted-tree replay 与 historical alternate-index fixture closure |
| [docs/reports/phase-d-task-39b2c-fixed-gate-deadline-cleanup-historical-replay-review.md](docs/reports/phase-d-task-39b2c-fixed-gate-deadline-cleanup-historical-replay-review.md) | implementation `aa8a7f1` / tree `8176e92a`、one verifier path / 16 lines、bare Investigation/App Release gates；complete/non-admitting |
| [docs/reports/phase-d-task-39b2c-l3c3c-ii-c0b-ii-b-retained-base-split-preflight.md](docs/reports/phase-d-task-39b2c-l3c3c-ii-c0b-ii-b-retained-base-split-preflight.md) | ii-b design correction；a3 retained-base prerequisite → b1 publication/lease → b2 settlement/recovery → b3 verifier closure；documentation-only/non-admitting |
| [docs/reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b0-outer-inner-protocol-preflight.md](docs/reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b0-outer-inner-protocol-preflight.md) | outer/inner protocol、FD 0/1/2/7/8/9、inner-led PGID、parent-crash containment 与五段 bounded split |
| [docs/reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-a-review.md](docs/reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-a-review.md) | iii-a per-epoch completion/continuity、40 focused、559 affected、1,446-test serial 与 independent review |
| [docs/reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b1-review.md](docs/reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b1-review.md) | iii-b1 injected eight-epoch cohort、13 focused、573 affected、1,455-test serial、immutable replay seal 与 independent review |
| [docs/reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2b-0-review.md](docs/reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2b-0-review.md) | iii-b2b-0 Release graph closure、Debug/Release positive controls、1,517-test serial、immutable replay 与 independent review |
| [docs/reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2b-1a0-review.md](docs/reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2b-1a0-review.md) | iii-b2b-1a-0 canonical helper-provenance carriage、1,525-test serial、clean-build projection、immutable replay 与 independent review |
| [docs/reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2b-1a1-review.md](docs/reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2b-1a1-review.md) | iii-b2b-1a-1 concrete outer observation、1,535-test serial、App/Release gate、immutable replay 与 no unresolved P0–P2 |
| [docs/reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2b-1b-preflight.md](docs/reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2b-1b-preflight.md) | iii-b2b-1b historical zero-argument entry preflight、预算触发的 1b-i/1b-ii split 与 final non-admitting outcome |
| [docs/reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2b-1b-review.md](docs/reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2b-1b-review.md) | iii-b2b-1b production/focused + verifier/Mach-O completion audit、1,550-test serial、App/Release gates、immutable seal 与 no unresolved P0–P2 |
| [docs/reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2a0-typed-physical-bridge-preflight.md](docs/reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2a0-typed-physical-bridge-preflight.md) | iii-b2a0 typed invocation/result bridge、untrusted DTO boundary、8-path/2,200-line ceiling 与 validation funnel |
| [docs/reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2a0-review.md](docs/reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2a0-review.md) | iii-b2a0 exact 8-path / 2,198-line completion、36 combined、580 affected、1,462-test serial、immutable seal 与 no unresolved P0–P2；complete/non-admitting |
| [docs/reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2a-i-review.md](docs/reports/phase-d-task-39b2c-l3c3c-ii-b5b-iii-b2a-i-review.md) | iii-b2a-i canonical supervisor admission、12 focused、593 affected、1,475-test serial、three boundary gates、immutable seal 与 no unresolved P0–P2；complete/non-admitting |
| [docs/reports/phase-d-task-36-review.md](docs/reports/phase-d-task-36-review.md) | Task 36 deterministic planning core、performance evidence 与 completion audit |
| [docs/reports/phase-d-task-37-review.md](docs/reports/phase-d-task-37-review.md) | Task 37 Store v4、capacity/performance evidence 与 completion audit |
| [docs/reports/phase-d-task-38-review.md](docs/reports/phase-d-task-38-review.md) | Task 38 closed coordinator、review repairs 与 completion audit |
| [docs/reports/phase-d-task-39b1b-ii-review.md](docs/reports/phase-d-task-39b1b-ii-review.md) | Task 39B1b-ii strict DEBUG App leaf、review repairs 与 checkpoint audit |
| [docs/plans/completed/epic-8-safe-execution-vertical-slice.md](docs/plans/completed/epic-8-safe-execution-vertical-slice.md) | 已归档的 Phase C Tasks 27–35 计划 |
| [docs/reports/epic-8-safe-execution-validation-report.md](docs/reports/epic-8-safe-execution-validation-report.md) | Phase C final matrix、signed receipt 与 admission `go` |
| [docs/plans/completed/capability-first-codex-runtime-gate.md](docs/plans/completed/capability-first-codex-runtime-gate.md) | 已归档的 capability-first Runtime/containment evidence gate |
| [docs/reports/capability-first-runtime-validation-report.md](docs/reports/capability-first-runtime-validation-report.md) | Runtime final matrix、ADR 0004 residual-risk mapping 与 `go` |
| [docs/plans/completed/epic-0-1-foundation-spikes.md](docs/plans/completed/epic-0-1-foundation-spikes.md) | 第一阶段工程骨架与高风险技术 Spike 实施计划 |
| [docs/reports/epic-0-1-validation-report.md](docs/reports/epic-0-1-validation-report.md) | Epic 0–1 evidence gate、conditional-go/no-go 与残余风险 |
| [docs/research/](docs/research/) | 真实案例、竞品时间切片、上游学习与许可证边界 |

## 项目约束

- 原生 Swift/SwiftUI macOS App，v1 仅面向最新 macOS 与 Apple Silicon
- 使用用户已安装的 Codex，不捆绑模型运行时
- 采用现有 [MIT License](LICENSE)，代码库已发布到个人 GitHub Public 仓库，`main` 跟踪 `origin/main`
- App/项目名使用 `Stornaut`，CLI 与仓库名使用 `stornaut`
- v1 为按需启动的单窗口 App，不做菜单栏伴侣、后台监控或自动清理

## 核心设计预览

```text
Quick Scan：Swift 全盘快照 → 已知规则 → 活动保护 → 即时报告
Deep Dive：Codex 指挥官 → 直接只读 Agent 工具 + Probe Broker + live public internet → 证据链 → CleanupPlan
Execution：Swift Policy Gate → 用户批准 → Trash / 审核过的官方动作
```

- **站在前人肩膀上**：系统学习 Mole、ClearDisk、kondo、devklean、Cluttered 等项目
- **Agent 轨迹动态、方法固定**：观察、假设、验证、反证、量化、结论
- **Agent 没有删除权**：所有动作经过不可绕过的 Swift Policy Gate
- **能力优先调查**：首次启用时聚合披露模型上下文与公共联网；调查中不逐文件/逐命令批准，清理 protected-path policy 仍由 Swift 强制
- **可解释计量**：区分候选大小、实际处理、Trash、永久释放和可用空间变化
