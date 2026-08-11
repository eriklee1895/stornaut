# Reports

本目录保存阶段验证、Benchmark 汇总和 release gate，不保存原始敏感路径、受控读取内容或未脱敏 Codex JSONL。

- [Development Automation Validation — 2026-08-09](development-automation-2026-08-09.md)：XcodeBuildMCP、Peekaboo 只读目录、真实 App build/run 与 PID 窗口截图证据。
- [Epic 0–1 Validation Report](epic-0-1-validation-report.md)：foundation、Codex、Surveyor、Action lifecycle 的 evidence gate，deterministic conditional go 与 Deep Dive no-go。
- [Epic 2–4 Validation Report](epic-2-4-validation-report.md)：domain/persistence、真实 product Quick Scan、Space Ledger、Knowledge/Activity、App/UI 与 scope evidence；当前仍等待最终统一 verifier，Deep Dive 继续 no-go/paused。
- [Epic 1 Final Code Review — 2026-08-09](epic-1-code-review-2026-08-09.md)：跨模块安全/并发/健壮性审查、确认缺陷与修复证据。
- [Epic 2–4 Task 9 Code Review — 2026-08-09](epic-2-4-task-9-review.md)：Phase B implementation studies、ADR 0007 与文档路由的审查和修复证据。
- [Epic 2–4 Task 10 Code Review — 2026-08-10](epic-2-4-task-10-review.md)：领域契约、匿名 fixtures、Surveyor transport 迁移与 10 组确认缺陷的修复证据。
- [Epic 2–4 Task 21 Code Review — 2026-08-10](epic-2-4-task-21-review.md)：App-owned state、DEBUG fixtures、semantic DesignSystem、Release 隔离与统一验证证据。
- [Epic 2–4 Task 22 Code Review — 2026-08-10](epic-2-4-task-22-review.md)：snapshot-first Overview、Space Ledger/Orbit、Top Opportunities、可访问性、Light/Dark 与六图验证证据。
- [Epic 2–4 Task 23 Code Review — 2026-08-10](epic-2-4-task-23-review.md)：App-owned Quick Scan、五阶段进度、ledger-owned 结果、只读 Evidence Inspector、三态 Peekaboo 与九图验证证据。
- [Epic 2–4 Task 24 Code Review — 2026-08-10](epic-2-4-task-24-review.md)：seven-day sweep、损坏隔离、确认删除、master-detail History 与 measured Storage Trend 证据。
- [Epic 2–4 Task 25 Code Review — 2026-08-10](epic-2-4-task-25-review.md)：closed preferences、fail-closed Primary Root、显式 exclusions、分离数据生命周期、六区 Settings 与十七图验证证据。
- [Epic 2–4 Task 26 Code Review — 2026-08-11](epic-2-4-task-26-review.md)：product scaling、typed aggregate、bounded candidate projection、App terminal metrics 与 Phase B scope 的审查、确认缺陷和修复证据。

报告记录测量事实；若事实要求降低安全、权限或隐私边界，必须先请求用户决策，不能直接改写批准规格。
