# Architecture Decision Records

当前 ADR 编号：

1. `0001-package-first-native-shell.md`
2. [`0002-codex-discovery-and-capabilities.md`](0002-codex-discovery-and-capabilities.md) — Accepted for Task 3 discovery; runtime isolation remains unverified
3. [`0003-codex-process-protocol.md`](0003-codex-process-protocol.md) — Accepted for Task 4 process/protocol; historical Broker-only evidence retained
4. [`0004-codex-file-read-isolation.md`](0004-codex-file-read-isolation.md) — Amended and accepted 2026-08-11; capability-first direct read/Agent tools/live public internet with OS write denial and Swift-only execution
5. [`0005-swift-surveyor-performance.md`](0005-swift-surveyor-performance.md) — Accepted Task 6; Swift meets measured performance/memory/cancellation goals
6. [`0006-trash-and-registered-actions.md`](0006-trash-and-registered-actions.md) — Accepted Task 7; constrained Trash and fake registered-action lifecycle validated
7. [`0007-domain-persistence-boundary.md`](0007-domain-persistence-boundary.md) — Accepted; dual-store SQLite boundary verified in Task 11
8. [`0008-production-quick-scan-lifecycle.md`](0008-production-quick-scan-lifecycle.md) — Accepted; production Surveyor and persisted lifecycle validated in Task 12
9. [`0009-space-accounting-semantics.md`](0009-space-accounting-semantics.md) — Accepted; truthful Space Ledger reconciliation validated in Task 13
10. [`0010-knowledge-activity-policy.md`](0010-knowledge-activity-policy.md) — Accepted; Tasks 14–19 compiler, catalog, activity and structured knowledge gates validated
11. [`0011-review-policy-authorization.md`](0011-review-policy-authorization.md) — Accepted for Phase C; separates Plan/selection/Policy from one-shot execution authority
12. [`0012-cleanup-execution-journal.md`](0012-cleanup-execution-journal.md) — Accepted for Phase C; write-ahead recovery and insert-only Manifest semantics
13. [`0013-capability-first-runtime-containment.md`](0013-capability-first-runtime-containment.md) — Accepted through R6 local-only runtime foundation; exact managed-proxy exception, signed-App evidence and final admission are complete
14. [`0014-view-snapshot-regression.md`](0014-view-snapshot-regression.md) — Accepted for the test architecture workstream; off-screen view goldens supplement window-level luminance sanity checks with component/page visual contracts
15. [`0015-headless-ci-verification.md`](0015-headless-ci-verification.md) — Accepted; ordinary GitHub Actions run deterministic build/test gates while XCUITest, host UI evidence and performance remain in the local full verifier
16. [`0016-investigation-lifecycle-supervisor.md`](0016-investigation-lifecycle-supervisor.md) — Accepted; privileged audit-session supervisor closes descendant escape and proves lifecycle drain/recovery
17. [`0017-investigation-planning-and-stop-semantics.md`](0017-investigation-planning-and-stop-semantics.md) — Accepted for Phase D Task 36; planning, budget, stop and no-Executor semantics
18. [`0018-parent-owned-investigation-handoff.md`](0018-parent-owned-investigation-handoff.md) — Proposed for Task 39 L3c3c; external root launch rejected, ii-a/ii-b0a/ii-b0b complete, ii-b1 current

每份 ADR 至少记录 Status、Context、Evidence、Decision、Consequences、Residual Risks 和 Validation。安全假设没有测量证据时不得标记 Accepted。

ADR 0002/0003/0006 等早期文件中的 Broker-only/no-go 表述记录当时的
Spike 结论，不再定义当前产品权限；当前 Codex 边界以修订后的 ADR 0004 为准。
