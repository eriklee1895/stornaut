# Reports

本目录保存阶段验证、Benchmark 汇总和 release gate，不保存原始敏感路径、受控读取内容或未脱敏 Codex JSONL。

> 2026-08-11 状态说明：报告中的 Broker-only/no-go/paused 是对应阶段的
> 历史测量结论。当前产品已通过修订后的
> [ADR 0004](../adr/0004-codex-file-read-isolation.md) 采用 capability-first
> direct read/Agent tools/live public internet；R5 signed machine gate 已
> `signedRuntimeReady`，R6 runtime foundation final admission 已得出 `go`。
> Deep Dive 仍等待后续生产实现，不因 runtime receipt 自动启用。

- [Development Automation Validation — 2026-08-09](development-automation-2026-08-09.md)：XcodeBuildMCP、Peekaboo 只读目录、真实 App build/run 与 PID 窗口截图证据。
- [Epic 0–1 Validation Report](epic-0-1-validation-report.md)：foundation、Codex、Surveyor、Action lifecycle 的历史 evidence gate；Broker-only no-go 已由 ADR 0004 修订。
- [Epic 2–4 Validation Report](epic-2-4-validation-report.md)：domain/persistence、真实 product Quick Scan、Space Ledger、Knowledge/Activity、App/UI 与 scope evidence；Deep Dive 不在 Phase B 范围。
- [Epic 1 Final Code Review — 2026-08-09](epic-1-code-review-2026-08-09.md)：跨模块安全/并发/健壮性审查、确认缺陷与修复证据。
- [Epic 2–4 Task 9 Code Review — 2026-08-09](epic-2-4-task-9-review.md)：Phase B implementation studies、ADR 0007 与文档路由的审查和修复证据。
- [Epic 2–4 Task 10 Code Review — 2026-08-10](epic-2-4-task-10-review.md)：领域契约、匿名 fixtures、Surveyor transport 迁移与 10 组确认缺陷的修复证据。
- [Epic 2–4 Task 21 Code Review — 2026-08-10](epic-2-4-task-21-review.md)：App-owned state、DEBUG fixtures、semantic DesignSystem、Release 隔离与统一验证证据。
- [Epic 2–4 Task 22 Code Review — 2026-08-10](epic-2-4-task-22-review.md)：snapshot-first Overview、Space Ledger/Orbit、Top Opportunities、可访问性、Light/Dark 与六图验证证据。
- [Epic 2–4 Task 23 Code Review — 2026-08-10](epic-2-4-task-23-review.md)：App-owned Quick Scan、五阶段进度、ledger-owned 结果、只读 Evidence Inspector、三态 Peekaboo 与九图验证证据。
- [Epic 2–4 Task 24 Code Review — 2026-08-10](epic-2-4-task-24-review.md)：seven-day sweep、损坏隔离、确认删除、master-detail History 与 measured Storage Trend 证据。
- [Epic 2–4 Task 25 Code Review — 2026-08-10](epic-2-4-task-25-review.md)：closed preferences、fail-closed Primary Root、显式 exclusions、分离数据生命周期、六区 Settings 与十七图验证证据。
- [Epic 2–4 Task 26 Code Review — 2026-08-11](epic-2-4-task-26-review.md)：product scaling、typed aggregate、bounded candidate projection、App terminal metrics 与 Phase B scope 的审查、确认缺陷和修复证据。
- [Epic 8 Task 27 Code and Design Review — 2026-08-11](epic-8-task-27-review.md)：Safe Execution study、profile 收窄、authorization/journal ADR 与四项确认设计问题修复。
- [Epic 8 Task 28 Code Review — 2026-08-11](epic-8-task-28-review.md)：cleanup domain v2、Evidence Store v3、path-free journal、atomic migration、immutable writes 与十三项确认问题修复。
- [Epic 8 Task 29 Code Review and Completion Audit — 2026-08-14](epic-8-task-29-review.md)：closed execution profiles、one-snapshot Activity/Evidence、Quick Scan Rule v2、完整 Store join、Cleanup Plan Builder、bounded Review projection、completion checklist 与 confirmed findings 修复。
- [Epic 8 Task 34 Code Review and Completion Audit — 2026-08-15](epic-8-task-34-review.md)：Store v3 Manifest paging、独立 7/90-day retention、typed History union、exact deletion、privacy-bounded export、actual-App evidence、independent review 与 authoritative full verifier。
- [Epic 8 Task 35 Code Review and Completion Audit — 2026-08-15](epic-8-task-35-review.md)：closed real-Trash runtime、唯一 signed-App fixture mutation、zero-replay recovery、source-bound privacy-safe receipt、sealed mutation scripts、zero-P0–P2 reviews 与 authoritative full verifier。
- [Phase D Task 36 Code Review and Completion Audit — 2026-08-15](phase-d-task-36-review.md)：deterministic Investigation domain/planner、maximum-source performance optimization、Task 35 seal preservation 与 authoritative full verifier。
- [Phase D Task 37 Code Review and Completion Audit — 2026-08-16](phase-d-task-37-review.md)：Evidence Store v4、source rejoin、retention/privacy、两轮 `30/30` capacity evidence、benchmark routing 与 23/23 authoritative full verifier。
- [Phase D Task 38 Code Review and Completion Audit — 2026-08-16](phase-d-task-38-review.md)：closed fake-runtime coordinator、strict event/lineage/token normalization、terminal/recovery barrier、六项 P1 review 修复、Task 35 seal preservation 与 23/23 authoritative full verifier。
- [Epic 8 Safe Execution Validation Report — 2026-08-15](epic-8-safe-execution-validation-report.md)：Tasks 27–35 prompt-to-artifact matrix、runtime interlock、signed receipt、22/22 full gate 与 Phase C admission `go`。
- [Capability-First Runtime R1 Review — 2026-08-11](capability-first-runtime-r1-review.md)：Codex `0.147.0` permission profiles、Seatbelt、managed network proxy、private Runtime Home 与 instruction/auth/browser 边界审查；R1 conditional-go，R2 等待 dedicated loopback proxy 决策。
- [Capability-First Runtime R2 Review — 2026-08-12](capability-first-runtime-r2-review.md)：closed capability-first profile、advertised/configured/observed/contained evidence 与 `configurationReady` 结论。
- [Capability-First Runtime R3 Review — 2026-08-12](capability-first-runtime-r3-review.md)：Runtime Home、external auth、Seatbelt/managed proxy 与 audit-session lifecycle supervisor 的 `behaviorReady` candidate。
- [Capability-First Runtime R4 Review — 2026-08-12](capability-first-runtime-r4-review.md)：strict Investigation Envelope v2、Swift identity binding、module separation 与 structural no-Executor `protocolReady` 证据。
- [Capability-First Runtime R5 Local-Only Topology Decision — 2026-08-12](capability-first-runtime-r5-blocker.md)：保留 packaged/notarization stop 与 rejected LaunchAgent 证据；用户随后批准个人本机 local-only lifecycle hard gate。
- [Capability-First Runtime R5 Historical App Server Blocker — 2026-08-12](capability-first-runtime-r5-api-key-blocker.md)：保留早期 sanitized `other` 证据；后续 tests-first provider/schema/raw-event 修复已让真实 worker达到 capability 9/9 与 containment 6/6。
- [Capability-First Runtime R5 Historical Provider/Usage-Limit Blocker — 2026-08-13](capability-first-runtime-r5-usage-limit-blocker.md)：保留 TeamoRouter 与 sanitized `usageLimitExceeded` 的历史诊断；当前 official subscription 已恢复，该报告已 superseded。
- [Capability-First Runtime R5 Review — 2026-08-13](capability-first-runtime-r5-review.md)：official `openai` signed App 9/9 capability、12/12 integrity、review repairs、machine gate 与零残留证明。
- [Capability-First Runtime Final Validation — 2026-08-13](capability-first-runtime-validation-report.md)：19-row prompt-to-evidence matrix、ADR 0004 九项 residual-risk mapping 与 runtime foundation `go`。
- [Capability-First Runtime R6 Review — 2026-08-13](capability-first-runtime-r6-review.md)：five-dimensional Settings、typed disclosure、actual-window evidence、review fixes 与 zero unresolved P0–P2。
- [Capability-First Runtime R2–R6 Progress Audit — 2026-08-13](capability-first-runtime-progress-audit-2026-08-13.md)：逐条映射 active objective、phase artifacts、commands、capability/integrity rows 与 guardrails；已由 final validation supersede。

报告记录测量事实；若事实要求降低安全、权限或隐私边界，必须先请求用户决策，不能直接改写批准规格。
