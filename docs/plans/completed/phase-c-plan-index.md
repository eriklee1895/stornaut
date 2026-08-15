# Phase C Plan Index

> Status: Archived on 2026-08-15. This snapshot records the completed Phase C
> execution sequence and is not current implementation authorization.

Phase C deterministic Epic 8 与 Task 28 后插入的
ADR 0004 capability-first runtime interlock 已完成；Task 29 的 closed
Execution Profile Catalog、shared one-snapshot Activity/Evidence、完整 Store
join、Cleanup Plan Builder、bounded Review projection、独立 review 与 unified
verifier 已完成。Task 30 的 pure Policy、fresh revalidation 与 one-shot
authorization、independent review 与 unified verifier 已完成。Task 31 的
serial injected fake-Trash coordinator、durable journal、per-item fresh Policy、
Manifest/accounting、audit retry、no-replay recovery、independent review 与
unified verifier 已完成。Task 32 的 typed Scan→Review routing、Core-backed
Plan/Policy、write-disabled execution seam、native UI、实际窗口验证与
independent review 与 authoritative unified verifier 已完成。详细
R1–R6 计划见
[`capability-first-codex-runtime-gate.md`](capability-first-codex-runtime-gate.md)，
详尽计划已获批准。R1 study/ADR/probe/review 与 R2 closed profile/report/
diagnostic 已完成；R2 结论为 `configurationReady`。R3 已因 new-session
descendant lifecycle escape 拒绝 process-group-only candidate；用户批准的
audit-session lifecycle supervisor 随后通过 final privileged composition，
R3 得出 `behaviorReady` candidate。用户 review 后已继续；R4 的 Investigation
Envelope v2、Swift identity binding、独立 ProcessSupport/ProbeBridge module
seam 与 no-Executor verifier 已完成并得出 `protocolReady`。R5 的
	root-only local lifecycle、closed auth、App Server runtime worker 与 machine
	verifier 已实现。官方 `openai` + ChatGPT subscription 的真实
	`gpt-5.6-luna` worker 已观察 direct read、
shell/unified exec、live search、public command network、browser/direct
fetch、image、skill 与 subagent 共 9/9 capabilities；errno-only fixed probe
观察到 IPv4/IPv6/private/local/Unix denial，worker containment 6/6。独立
review findings 已修复；post-fix review 进一步关闭 command/image/subagent
伪造窗口、random denial-token 映射、outer/inner privacy preflight 与漏 staged
	`codex-code-mode-host`。后续审查又修复 current-build binding、XPC
	one-shot continuation、external-state outcome priority 与 exact subagent
	sender identity；final live fixes 又关闭 vanished-process errno 分类、
	provider strict-schema `$ref` sibling 与 direct-read fixed command 漂移。
	历史 TeamoRouter/usage-limit 只保留为 superseded 调试证据。current-source
	signed App/helper 已得出 `signedRuntimeReady`：9/9 capabilities、12/12
	integrity；fixed topology 随后卸载并证明零残留。R5 已提交推送。R6 已完成
	exact receipt、five-dimensional Settings、typed disclosure、final matrix、
	actual-window evidence 与 post-fix review；runtime foundation 结论为 `go`。
	Tasks 29–35 已完成。Task 33 Cleanup Result/Manifest UI 的 tests-first
	实现、精确 terminal admission、真实 Review→terminal DEBUG fixture、
	独立审查修复、App tests、focused XCUITest、actual-App/Peekaboo 与
	authoritative full verifier 已完成，后者单次 exit 0。

Task 30 的 collector/pure-gate 分层、memory-only `ReviewSelection`、bounded
Store lookup、typed stale contract、workflow exclusion snapshot 与 actor-owned
one-shot authorization 计划见
[`task-30-implementation-brief.md`](task-30-implementation-brief.md)。本 Task
完成证据见
[Task 30 Review](../../reports/epic-8-task-30-review.md)。它不添加 Trash、App
Review UI/CTA、Registered Action、Deep Dive 或 Store v4。

Task 31 的 serial coordinator、durable journal ordering、per-item fresh Policy、
fake-only Trash、truthful accounting、immutable Manifest、audit-pending 与 crash
recovery 计划见
[`task-31-implementation-brief.md`](task-31-implementation-brief.md)，完成证据
见 [Task 31 Review](../../reports/epic-8-task-31-review.md)。真实 App Trash
依赖仍保持关闭。

Task 32 的 typed Scan→Review routing、Core Plan/Policy service seam、
memory-only selection、write-disabled execution contract、native Decision
Table/Inspector/confirmation/stale UI 与实际窗口验收计划见
[`task-32-implementation-brief.md`](task-32-implementation-brief.md)，completion
audit 见 [Task 32 Review](../../reports/epic-8-task-32-review.md)。

Task 33 的 immutable Manifest/journal projection、typed Evidence enrichment、
Reversible First Cleanup Result、只读 Manifest detail、Open Trash/audit-only
retry 与 Scan-owned route 计划见
[`task-33-implementation-brief.md`](task-33-implementation-brief.md)。当前实现
仍保持 production execution `writeDisabled`；正常 DEBUG fixtures 已通过
Review preflight/confirmation/terminal event 到达 Cleanup Result，只有 corrupt
record 使用隔离直达态。完成证据见
[Task 33 Review](../../reports/epic-8-task-33-review.md)。

Task 34 的 Store v3 Manifest paging、独立 7/90-day retention、typed
Quick Scan/Manifest History union、exact local-record deletion、
privacy-bounded export 与 non-causal trend marker 计划见
[`task-34-implementation-brief.md`](task-34-implementation-brief.md)。实现已
通过 Core/App/XCUITest、actual-App/Peekaboo、independent review 与
authoritative `scripts/verify --full` 单次 exit 0；完成证据见
[Task 34 Review](../../reports/epic-8-task-34-review.md)。Task 34 未执行真实
Trash，production execution 仍保持 `writeDisabled`。

Task 29 的 tests-first、closed Execution Profile Catalog、shared one-snapshot
activity、完整 Store join、Plan Builder、boundary/benchmark/review 计划见
[`task-29-implementation-brief.md`](task-29-implementation-brief.md)，完成证据
见 [Task 29 Review](../../reports/epic-8-task-29-review.md)。它保持：

- execution profile 与 generic Rule Catalog 分离；
- 新 Rule Catalog generation 只提升 npm/pip，Go 保持 Review，uv 无 profile；
- Review projection 不创建 selection、Policy 或 authority；
- Store v3 未迁移；
- Task 29 不包含 App CTA、Trash、Registered Action 或 Deep Dive。

Epic 2–4 Tasks 9–26 已完成并归档；最终统一 verifier 单次 exit `0`。
Phase C deterministic Epic 8 的详尽 plan 已于 2026-08-11 获用户批准，见
[`epic-8-safe-execution-vertical-slice.md`](epic-8-safe-execution-vertical-slice.md)。
Tasks 27–28 的 study/ADR、domain v2、Evidence Store v3、crash journal、
code review 与 unified verifier 已完成。ADR 0004 回顾发现的旧
Broker-only runtime/protocol/UI 漂移已由 R1–R6 关闭。获批的交付顺序为：

```text
Task 28 complete
→ R1–R6 capability-first runtime evidence gate
→ resume deterministic Task 29–35
→ production Deep Dive still requires its Phase D implementation plan
```

R1–R6 必须证明 direct read、shell/unified exec、live search、browser/direct
fetch、image、skills/subagents 与公共联网可用，同时 Codex 全进程树不可写用户
数据、不可访问 localhost/私网/任意 Unix socket 且无 Executor 路径。不得用
`danger-full-access`、关闭调查能力、命令/公共域名 allowlist 或逐命令审批制造
通过。R1–R2 已完成，R2 结论为 `configurationReady`；R3 首先证明 direct
`setsid()`、`POSIX_SPAWN_SETSID` 与 launchd user-job cleanup 均不能保证整个
调查进程树回收，随后用用户批准的 audit-session supervisor 关闭该 hard
gate。最终 live/combined/recovery 均 drained，identity drop、outer Seatbelt、
audit-session inheritance、proxy-owner recovery 均 observed，residue 为 0。
R3 为 `behaviorReady` candidate。R4 已完成并通过独立 review。R5 原
notarization blocker 已由个人本机 local-only scope decision解决；历史
API-key/App Server blocker 及 provider/schema 根因保留在
[R5 App Server Historical Blocker](../../reports/capability-first-runtime-r5-api-key-blocker.md)。
	官方 `openai` worker 与 repository gates 已通过；历史 provider blocker 见
	[R5 Usage-Limit Blocker](../../reports/capability-first-runtime-r5-usage-limit-blocker.md)，
	已被当前 subscription evidence supersede。R5 证据见
	[R5 Review](../../reports/capability-first-runtime-r5-review.md)：signed
	machine report 与零残留证明已完成。R6 final admission 见
	[Runtime Validation](../../reports/capability-first-runtime-validation-report.md)
	与 [R6 Review](../../reports/capability-first-runtime-r6-review.md)。

R1 证明 read-only Seatbelt 能阻断 user-data writes，且 Codex experimental
managed proxy 能让公网请求成功并阻断 direct bypass、任意
localhost/private/link-local 目标与 Unix socket。但是该机制必须允许 Codex
descendants 连接到**同一调查会话、父进程拥有、随机端口**的一个 loopback
proxy listener。当前产品边界字面上拒绝全部 localhost，因此
[ADR 0013](../../adr/0013-capability-first-runtime-containment.md) 已接受这个
唯一的内部 transport 例外用于 R2 configuration candidate：

```text
只允许连接 same-session managed proxy；
其他 localhost/private/link-local 和所有 Unix sockets 继续 OS-blocked。
```

用户已批准 ADR 0013 的 same-investigation parent-owned random-loopback
managed-proxy 例外；R2 已按
[`task-r2-implementation-brief.md`](task-r2-implementation-brief.md) 完成
configuration candidate，并由
[R2 Review](../../reports/capability-first-runtime-r2-review.md) 记录
`configurationReady`。R3 behavioral gate 已通过；详见
[R3 Review](../../reports/capability-first-runtime-r3-review.md)。
[R4 Review](../../reports/capability-first-runtime-r4-review.md) 记录 strict v2
advisory protocol 与 structural no-Executor seam 的 `protocolReady` 结论。

R6 已关闭当前个人本机 capability-first runtime foundation，但不证明
ServiceManagement distribution、Developer ID/notarization、FDA/TCC product
flow 或 production Deep Dive。Deep Dive 保持 unavailable；Tasks 29–35 已完成。

Task 35 的唯一授权 real Trash attempt 已消费。exact diagnostic-owned fixture
被移动且 journal durably 停在 `actionOutcomeRecorded`；Manifest timeline
缺陷使原 signed report 正确保持 blocked，未重试。随后独立 signed
recovery-only App 以 Executor invocation `0` 完成 journal finalization、
one-record Manifest、1 success / 0 failed/cancelled/unknown、permanent bytes
`0`，并按 identity 恢复 fixture。privacy-safe checked receipt 已绑定原始/
恢复 reports、final Store 与安全关键源码。mutation scripts 均已 sealed；
authoritative full verifier 只允许 receipt/source/raw evidence read-only
validation。

旧 global same-UID Node safe-window 已删除；Chrome、Cursor、Claude、MCP 或
其他 App 的进程不得成为 Task 35 verifier blocker 或 kill target，contracts
禁止 `pkill`/`killall`/`pgrep`/`ps -U` 全局协调。focused product gate
74/74、SwiftPM 634/634、完整 App/UI、receipt/raw evidence 与
Debug/Release gates 已通过；authoritative full verifier 22/22 stages 单次
exit 0，最终 independent reviews 无 unresolved P0–P2，Phase C admission
为 `go`。
当前 completion audit 见
[Task 35 Review](../../reports/epic-8-task-35-review.md)，完整 Phase C
prompt-to-artifact 矩阵见
[Safe Execution Validation](../../reports/epic-8-safe-execution-validation-report.md)。

正常 App 仍保持真实 Trash 依赖关闭；Task 35 只证明 sealed diagnostic
foundation，不启用普通 App execution。Task 32–34 的产品验收只使用
fake/write-disabled coordinator。

Epic 0–1 evidence gate 已完成，历史计划见
[`../completed/epic-0-1-foundation-spikes.md`](../completed/epic-0-1-foundation-spikes.md)；
Epic 2–4 历史计划见
[`../completed/epic-2-4-deterministic-product-core.md`](../completed/epic-2-4-deterministic-product-core.md)；
不得从 completed plan 继续推断新任务。
