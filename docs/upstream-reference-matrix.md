# Stornaut 上游参考矩阵

> 目的：让 Coding Agent 在实现每个模块前重复学习相关项目，而不必重做整份竞品调研。  
> 基线日期：2026-08-06  
> 详细背景：[竞品与开源生态报告](competitive-analysis-2026-08-06.md)

> **批准设计边界（2026-08-07）**：菜单栏、Rust、CLI 和第三方工具描述只界定上游研究主题，不代表 Stornaut 的实现选择。v1 使用原生 Swift 按需单窗口 App，不创建 `MenuBarExtra` 或后台监控；ClearDisk 的菜单栏代码只用于学习窗口、状态管理和原生工程模式。kondo 的 Rust 实现只用于 taxonomy、行为和性能 Benchmark，除非 Swift Surveyor 真实 Benchmark 不达标，否则不引入 Rust。Mole、kondo 等只能作为用户已安装的可选只读 Adapter，核心不得依赖它们，Adapter 不得执行清理。项目自身采用 MIT License。

## 1. 使用规则

本文件是开发门禁，不是“灵感链接收藏夹”。开始一个 Epic 前，Coding Agent 必须：

1. 选择本 Epic 对应的上游项目。
2. 获取当前仓库 commit、版本、许可证和相关文件。
3. 更新本文件的“本次复核”记录或写模块 Implementation Brief。
4. 区分公开事实、设计思想、可复用代码和不可复制实现。
5. 实现后增加行为 Benchmark 或 fixture。

不要默认复制任何代码。许可证允许复用也不等于复用一定优于独立实现。

## 2. 许可证策略

| 类型 | Stornaut 策略 |
|---|---|
| MIT/宽松许可证 | 可选择性复用；记录具体文件、commit、版权和 NOTICE/attribution |
| GPL-3.0 | 学习行为、UX、协议、测试场景和公开事实；默认 clean-room 独立实现，不复制代码 |
| Commons Clause/source-available | 仅研究行为和设计；不视为无约束 Apache 项目 |
| 专有/闭源 | 仅做黑盒 Benchmark，不逆向、不复制实现 |
| Public 无 LICENSE | 只观察，不复制、修改或分发代码 |

## 3. 项目矩阵

### 3.1 Mole

- 仓库：[tw93/Mole](https://github.com/tw93/Mole)
- 许可证：GPL-3.0
- 角色：产品化、CLI UX、已知缓存覆盖、活动 App 保护、空间报告
- 必学内容：
  - 缓存与残留类别如何组织
  - scan/clean/uninstall/analyze 等命令心智
  - dry-run、白名单、受保护路径和活动 App 跳过
  - 清理统计和 free-space delta 的展示
  - 安装、帮助、错误信息和终端交互
- Stornaut 应更进一步：
  - 把静态规则结果与未知目录 Agent 调查合并
  - 区分候选大小、处理量、Trash 和真实可用空间变化
  - 提供证据链、Policy Gate 和类型化执行
- 边界：不复制 GPL 实现；可将 Mole 作为用户已安装的可选只读 Adapter。

### 3.2 kondo

- 仓库：[tbillington/kondo](https://github.com/tbillington/kondo)
- 许可证：MIT
- 角色：项目类型与 artifact taxonomy、Rust 扫描性能对照（不是 v1 技术选型）
- 必学内容：
  - 多语言项目识别和构建产物映射
  - 扫描根、年龄过滤和 CLI/GUI 共用核心
  - fixture 和跨平台测试思路
- Stornaut 应更进一步：Git/IDE 活动保护、Trash、证据、未知目录调查。
- 边界：不要照搬其接近 `rm -rf` 的执行模型。

### 3.3 ClearDisk

- 仓库：[bysiber/cleardisk](https://github.com/bysiber/cleardisk)
- 许可证：MIT
- 角色：最接近 Stornaut 的原生 macOS 产品形态
- 必学内容：
  - SwiftUI 菜单栏实现中的窗口和状态管理经验；不把 MenuBarExtra 带入 Stornaut v1
  - developer cache 路径 taxonomy
  - 项目类型、风险标签和人话说明
  - Trash、历史、预测 UX
- Stornaut 应更进一步：Agent 调查、证据链、Git/进程多信号、执行前重验证。
- 边界：README 的安全声明必须通过源码和测试复核。

### 3.4 devklean

- 仓库：[smurftyy/devklean](https://github.com/smurftyy/devklean)
- 许可证：MIT
- 角色：早期安全设计参考，不是成熟度标杆
- 必学内容：
  - 根/HOME/挂载点危险路径拒绝
  - symlink 防护
  - Trash、压缩验证、历史和强确认
  - signature/explain schema
- Stornaut 应更进一步：原生 macOS、卷级扫描、Agent 证据和更广 taxonomy。
- 风险：采用量很小；必须独立验证，不因存在测试就视为 battle-tested。

### 3.5 Cluttered

- 仓库：[gatteo/cluttered](https://github.com/gatteo/cluttered)
- 许可证：MIT
- 角色：项目活跃状态、Git/IDE 保护和 GUI 参考
- 必学内容：
  - Active/Recent/Stale/Dormant 分类
  - Git dirty 和 IDE open 信号
  - protected paths
  - UI 声明与真实 Executor 路径可能分叉的反面案例
- Stornaut 应更进一步：单一 Policy Gate、完整审计和未知目录调查。

### 3.6 PureMac

- 仓库：[momenbasel/PureMac](https://github.com/momenbasel/PureMac)
- 许可证：MIT
- 角色：原生 SwiftUI、FDA、通用 macOS 缓存与分发参考
- 必学内容：权限探测、原生工程、缓存模块、定时能力的取舍。
- Stornaut 应更进一步：开发项目语义和 Codex 调查。

### 3.7 Pearcleaner

- 仓库：[alienator88/Pearcleaner](https://github.com/alienator88/Pearcleaner)
- 许可证：Apache-2.0 + Commons Clause，source-available/fair-code
- 角色：App 关联文件、FDA、Trash/Undo、Helper 和原生 UX 参考
- 必学内容：
  - macOS 权限与 Helper 引导
  - App 残留发现和路径保护
  - Trash/Undo 体验
- 边界：不要按普通 Apache-2.0 项目处理，不复制受限制代码。

### 3.8 npkill

- 仓库：[voidcosmos/npkill](https://github.com/voidcosmos/npkill)
- 许可证：MIT
- 角色：大量 `node_modules` 发现和交互参考
- 必学内容：扫描反馈、选择体验、单生态性能。
- Stornaut 应更进一步：跨生态、陈旧度、Git 保护和 Agent 调查。

### 3.9 Spaci

- 仓库：[Raccoon254/spaci](https://github.com/Raccoon254/spaci)
- 许可证：基线日期未发现 LICENSE
- 角色：产品观察和路径覆盖参考
- 边界：不复制、修改或分发代码；“可重建”不能被误写成“可撤销”。

### 3.10 CodeCleaner 与 CleanMyMac CLI

- CodeCleaner：[官网](https://code-cleaner.com/)
- CleanMyMac CLI：[公开文档仓库](https://github.com/MacPaw/cleanmymac-cli)
- 许可证/源码：专有或未开放实现
- 角色：功能覆盖、产品结果和成熟厂商行为 Benchmark
- 必学内容：开发缓存分类、项目 purge、ignore、分析和官方动作范围。
- 边界：黑盒比较，不逆向或复制实现。

### 3.11 Agent 清理 Skills

- [Claude Code disk cleanup Skill](https://gist.github.com/alvinvogelzang/6b2098530794d9512e940bac80c1520e)
- [daymade macos-cleaner Skill](https://github.com/daymade/claude-code-skills/blob/main/README.zh-CN.md)
- 角色：Agent 现场调查方法和安全交互参考
- 必学内容：
  - 从最大空间消费者开始，而不是固定清单
  - safe/ask/project-specific 分类
  - Git 未推送保护
  - 用户确认和调查报告结构
- Stornaut 应更进一步：把提示词约束变成 Probe Broker、Policy Gate 和 Executor 代码约束。

## 4. 模块到上游的强制映射

| Stornaut Epic | 必读 | 可选 |
|---|---|---|
| App Shell / SwiftUI | ClearDisk、PureMac | Pearcleaner |
| FDA / Trash / 分发 | PureMac、Pearcleaner、ClearDisk | Apple 官方文档 |
| Surveyor | Mole、ClearDisk、kondo | npkill、DaisyDisk 黑盒 |
| Knowledge Base | Mole、ClearDisk、kondo | CleanMyMac CLI、CodeCleaner |
| Activity / Git | Cluttered、Mole | devklean |
| Probe Broker / 隔离 | Agent Skills、Codex 官方实现/文档 | macOS sandbox/TCC 官方资料 |
| Evidence / Agent 协议 | Agent Skills、真实案例 | Soji 等 AI cleaner 黑盒 |
| Policy Gate | devklean、Cluttered、ClearDisk | Pearcleaner |
| Action Registry | Mole、各工具官方文档 | CleanMyMac CLI 黑盒 |
| Space Accounting | Mole 真实输出、案例 | Apple APFS 官方资料 |

## 5. Implementation Brief 模板

```markdown
# <Epic> Upstream Study

- 日期：
- Coding Agent：
- 目标模块：

## 上游快照

| 项目 | commit/version | license | 阅读文件/文档 |
|---|---|---|---|

## 值得借鉴

## 反面案例或限制

## 许可证与复用边界

## Stornaut 方案

## 行为 Benchmark / Fixtures

## 相对上游的改进
```

## 6. 规则 provenance 要求

任何进入内置 Knowledge Base 的路径或动作规则都必须可追溯：

```yaml
provenance:
  sources:
    - project: Mole
      url: https://github.com/tw93/Mole
      commit: <sha>
      license: GPL-3.0
      usage: behavior-reference-only
  independentlyVerified: true
  verifiedOn: macOS 26
  verifiedAt: 2026-08-06
```

Coding Agent 不能把网上搜索到的路径直接标为 `Ready to Reclaim`。必须确认生产者、内容类型、活动前置条件、恢复方式和危险子路径，并增加 fixture。

## 7. 复核记录

首次实施计划开始时创建第一轮复核记录。此后只在相关 Epic 开始、上游有重大更新或规则失效时增量复核，不要求每次任务重读所有项目。
