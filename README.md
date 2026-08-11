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
live search 与访问公共互联网，但仍无本地写入或清理执行权。生产实现尚待新的
运行时 evidence gate，release 仍未评估。见文档：

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
| [docs/plans/active/README.md](docs/plans/active/README.md) | Runtime R2 configurationReady；R3 pending |
| [docs/plans/active/capability-first-codex-runtime-gate.md](docs/plans/active/capability-first-codex-runtime-gate.md) | Task 29 前插入的 capability-first Runtime/containment evidence gate |
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
