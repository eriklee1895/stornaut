# Architecture Decision Records

Epic 0–1 计划使用以下编号：

1. `0001-package-first-native-shell.md`
2. [`0002-codex-discovery-and-capabilities.md`](0002-codex-discovery-and-capabilities.md) — Accepted for Task 3 discovery; runtime isolation remains unverified
3. [`0003-codex-process-protocol.md`](0003-codex-process-protocol.md) — Accepted for Task 4 process/protocol; Broker-only isolation remains unverified
4. [`0004-codex-file-read-isolation.md`](0004-codex-file-read-isolation.md) — Accepted Task 5 no-go; Broker protocol proven, Broker-only runtime not enforced
5. [`0005-swift-surveyor-performance.md`](0005-swift-surveyor-performance.md) — Accepted Task 6; Swift meets measured performance/memory/cancellation goals
6. `0006-trash-and-registered-actions.md`

每份 ADR 至少记录 Status、Context、Evidence、Decision、Consequences、Residual Risks 和 Validation。安全假设没有测量证据时不得标记 Accepted。
