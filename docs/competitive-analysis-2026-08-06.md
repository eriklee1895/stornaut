# Stornaut 竞品与开源生态报告（2026-08-06）

> 调研日期：2026-08-06  
> 目标：为“个人自用、GitHub Public 开源”的 Stornaut 判断已有方案、可借鉴实现和仍然值得解决的问题。  
> 配套文档：[PRD.md](PRD.md)、[architecture.md](architecture.md)、[case-study-2026-08-06.md](case-study-2026-08-06.md)

> **后续项目状态（2026-08-07）**：市场事实、Star、版本和第三方许可证保留为 2026-08-06 时间切片；项目建议已由后续批准设计收敛。Stornaut 采用 MIT License，当前目录已有 `LICENSE`，但尚不是 Git 仓库且没有 remote；GitHub Public 是发布目标，不表示已经发布。v1 是按需启动的原生 Swift 单窗口 App，不做 MenuBarExtra 或后台监控；Rust 仅在 Swift Surveyor Benchmark 不达标后评估；外部工具只作为可选只读 Adapter，不能执行清理。实现以 PRD 2.3 和批准规格为准。

## 1. 结论摘要

Stornaut 所在的赛道并非空白。2026 年已经出现多款“开发者磁盘清理”产品，部分产品与当前 PRD 的基础能力高度重叠：

- 扫描 `node_modules`、`.venv`、`target`、DerivedData 等可重建产物
- 清理 npm/pnpm/uv/Go/Cargo/Homebrew 等开发缓存
- 按项目活跃时间筛选陈旧产物
- 检查 Git dirty 状态或提供保护名单
- 清理前预览，删除到废纸篓或要求二次确认

开源项目不存在一个简单的“综合第一”，更合理的方式是按维度选择参考对象：

1. [Mole](https://github.com/tw93/Mole)：产品体验、CLI 交互、传播和用户采用的首要 Benchmark；但它是覆盖清理、卸载、分析、优化和监控的通用 Mac 工具箱，不等于开发项目治理能力最强。
2. [kondo](https://github.com/tbillington/kondo)：成熟的开发生态 artifact taxonomy 和高性能扫描参考。
3. [ClearDisk](https://github.com/bysiber/cleardisk)：与 Stornaut 原生 macOS 产品形态最接近，覆盖菜单栏、开发缓存、项目类型、风险标签和 Trash。
4. [devklean](https://github.com/smurftyy/devklean)：危险路径拒绝、符号链接保护、Trash 事务和历史记录等安全不变量值得研究；但项目采用量很小，不能视为经过社区实战验证的成熟产品。
5. [Cluttered](https://github.com/gatteo/cluttered)：Git dirty、IDE 活跃状态和项目陈旧度信号值得研究，但同样处于非常早期阶段。

最直接的商业或专有竞品是：

1. [CodeCleaner](https://code-cleaner.com/)：原生 macOS 开发者清理器，功能覆盖面与 Stornaut PRD 高度重叠。
2. [CleanMyMac CLI](https://github.com/MacPaw/cleanmymac-cli)：MacPaw 的开发者 CLI，覆盖项目产物、开发缓存、AI 工具残留和磁盘分析。
3. [Soji](https://sojimac.com/) 等 AI 清理器：已经开始使用端侧模型解释文件和给出安全建议。

因此，下面这类定位已经不足以形成差异化：

> “其他工具不懂 node_modules/.venv，Stornaut 懂开发生态。”

更能成立的定位是：

> **Stornaut 是证据驱动的开发者磁盘调查与治理工具：确定性引擎负责发现事实，Codex 调查未知目录并生成证据链，规则安全闸门掌握执行权。**

对“个人自用 + 开源”目标而言，这个项目仍然非常值得做。它不需要在商业功能数量上超过所有竞品；它需要把真实案例中有效的 Agent 调查方法，变成一个透明、可审计、自己敢长期使用的系统。

## 2. 调研口径

### 2.1 产品分类

本报告把相关工具分为四类：

| 类别 | 解决的问题 | 代表 |
|---|---|---|
| 开发者产物清理器 | 找出项目中的依赖、虚拟环境和构建目录 | Cluttered、devklean、kondo、Spaci |
| 开发者系统清理器 | 同时处理项目产物、包缓存、IDE、Docker、Xcode、AI 工具数据 | CodeCleaner、CleanMyMac CLI |
| AI 磁盘清理器 | 使用模型解释目录或生成清理建议 | Soji、CleanerCat、Cacheless |
| 通用/邻近工具 | App 卸载、磁盘可视化、通用缓存清理、单生态清理 | Pearcleaner、Mole、DaisyDisk、npkill |

### 2.2 许可证用语

报告严格区分以下概念：

- **开源**：仓库存在明确的 OSI 风格许可证，例如 MIT、Apache-2.0、GPL-3.0。
- **source-available**：源码可见，但许可证包含用途限制，例如 Commons Clause。
- **源码公开但无许可证**：可以阅读，默认不能复制、修改、分发。
- **public 文档仓库**：GitHub 仓库公开，但不包含产品源代码。
- **闭源/专有**：只提供二进制或受专有 EULA 约束。

“仓库是 Public”不等于“项目是开源”。

### 2.3 Star 与项目采用信号

截至 2026-08-06，GitHub 仓库公开数据如下：

| 项目 | 创建时间 | Star | Fork | 这个数字可以说明什么 |
|---|---:|---:|---:|---|
| [Mole](https://github.com/tw93/Mole) | 2025-09 | 62,246 | 2,193 | 当前最强的关注度、传播力和采用信号 |
| [kondo](https://github.com/tbillington/kondo) | 2020-01 | 2,357 | 64 | 长期存在、跨平台 artifact 清理需求得到持续验证 |
| [ClearDisk](https://github.com/bysiber/cleardisk) | 2026-02 | 564 | 32 | 新项目中较明显的原生开发者清理需求信号 |
| [devklean](https://github.com/smurftyy/devklean) | 2026-03 | 8 | 1 | 仍属早期，缺少广泛用户和环境验证 |
| [Spaci](https://github.com/Raccoon254/spaci) | 2026-06 | 4 | 0 | 仍属早期 |
| [Cluttered](https://github.com/gatteo/cluttered) | 2025-12 | 1 | 0 | 仍属早期 |

Star 是“有人愿意关注、收藏或表达认可”的信号，不是活跃安装量，也不能直接证明扫描准确率、删除安全性、维护质量或对 Stornaut 场景的适配度。项目年龄、作者影响力、发布传播、README、覆盖范围和是否解决大众问题都会显著影响 Star。

因此本报告不会用 Star 直接选“最好用”：Mole 是产品化和采用度标杆；kondo 是成熟 taxonomy 标杆；ClearDisk 是原生形态标杆；devklean 仅作为部分安全设计的源码参考，而不是成熟度标杆。

## 3. 市场地图

```text
                            更强调解释 / 智能判断
                                      ↑
                    Soji / CleanerCat │      Stornaut 目标位置
                                      │      证据链 + 未知目录调查
            DaisyDisk                 │
            只展示空间                │
  通用 Mac  ←─────────────────────────┼────────────────────────→ 开发生态
                                      │
       CleanMyMac / Buho              │   CodeCleaner / CleanMyMac CLI
       Mole / PureMac                 │   Cluttered / devklean / kondo
                                      ↓
                              更强调固定规则执行
```

当前市场并不缺“扫描已知开发产物”的工具；更稀缺的是：

- 对规则未命中的大目录进行现场调查
- 展示可复核的判断证据，而不只显示绿色安全标签
- 理解目录之间的工作链依赖
- 区分“可重建”与“重建代价低”
- 对 APFS、swap、稀疏文件、dataless 文件、系统卷等给出一致的空间口径
- 让 Agent 参与调查，但不能绕过安全策略直接执行

## 4. 直接开源或源码公开项目

### 4.1 ClearDisk

- 项目：[github.com/bysiber/cleardisk](https://github.com/bysiber/cleardisk)
- 许可证：[MIT](https://github.com/bysiber/cleardisk/blob/main/LICENSE)
- 技术栈：Swift、SwiftUI、SPM，无外部依赖
- 平台：macOS 14+
- 产品形态：菜单栏 App

ClearDisk 是本次调研中与 Stornaut 技术形态最接近的开源项目：

- 63 个开发缓存路径，覆盖 Xcode、npm/pnpm/Bun、Homebrew、Docker、pip/uv/Conda、Cargo、Go、Gradle、IDE 和 AI 工具
- 23 种项目类型，识别 `node_modules`、`.venv`、`.next`、`target`、Pods、Unity/Unreal 产物等
- 人话缓存说明和 Safe/Caution/Risky 风险标签
- Xcode 运行状态检查
- 90 天历史和线性回归磁盘耗尽预测
- 清理到 Trash
- 无遥测、无网络访问

它直接证明以下能力不能再作为 Stornaut 的独特卖点：原生 SwiftUI、菜单栏、开发缓存目录表、项目产物扫描、风险分级、人话解释和 Trash。

Stornaut 仍可拉开的差距：

- ClearDisk 明确只扫描已知路径，不做全盘语义调查
- 年龄建议主要基于时间，没有完整 Git/进程/依赖关系多信号模型
- 风险标签来自内置规则，没有可审计的证据链
- 没有 Agent 调查规则 miss
- 没有“Agent 建议—规则 veto—类型化 Executor”的授权模型
- `Total saved` 与 Trash 中尚未真正释放的空间语义需要实测验证

最值得借鉴：轻量 SwiftUI 工程、缓存 taxonomy、项目类型覆盖、菜单栏与预测 UX。正式复用前仍应审查实际路径规范化、符号链接、Trash 和执行时二次授权逻辑，README 声明不能替代安全测试。

### 4.2 Cluttered

- 项目：[github.com/gatteo/cluttered](https://github.com/gatteo/cluttered)
- 许可证：[MIT](https://github.com/gatteo/cluttered/blob/main/LICENSE)
- 技术栈：Electron、React、TypeScript/JavaScript、SQLite、Zustand
- 平台：macOS
- 产品形态：GUI

核心能力：

- 识别 Node.js、Python、Rust、Go、Xcode、Android、Ruby、PHP、Java、Elixir、.NET 等项目
- 扫描 `node_modules`、`.venv`、`target`、`build`、`.next`、Pods 等产物
- 根据修改时间把项目分为 Active、Recent、Stale、Dormant
- 检查未提交 Git 修改
- 检测项目是否正在 IDE 中打开
- 支持 protected paths
- 默认移动到废纸篓

源码核对暴露了一个值得 Stornaut 重点防范的问题：README 声称 dirty Git 项目“不会删除”，但当前主 IPC 删除路径将 dirty 状态更多留给 UI 确认，仓库中还存在另一套更严格的 protection service。安全约束如果分散在 UI、旧 service 和实际 Executor 中，就可能出现文档与真实授权路径不一致。Stornaut 应只有一条可测试的授权路径。

与 Stornaut 的重叠：

- 项目识别、陈旧度、Git 保护、Trash 和 GUI 都已实现
- 证明“开发者专属清理器 + 活跃度判断”不是空白市场

Stornaut 仍可拉开的差距：

- Cluttered 主要依赖项目类型与目录名匹配，不负责调查任意未知目录
- 未建立“判断—证据—反证—恢复成本”的完整证据模型
- 未覆盖 macOS 卷级空间解释和复杂系统占用
- 没有 Agent 与确定性安全闸门的职责分离

最值得借鉴：生态插件边界、Git dirty 保护、IDE 活跃状态检测、MIT 项目的测试用例设计。

### 4.3 devklean

- 项目：[github.com/smurftyy/devklean](https://github.com/smurftyy/devklean)
- 发行：[PyPI devklean](https://pypi.org/project/devklean/)
- 许可证：MIT
- 技术栈：Python
- 平台：macOS、Linux、Windows
- 产品形态：CLI/TUI

核心能力：

- `scan`：只读扫描可清理开发产物
- `clean`：确认后移入系统废纸篓
- `analyze`：基于 artifact-signature registry 给出风险、陈旧度和 workspace health
- `explain`：解释目录由什么生成、如何重建、风险等级和理由
- `history` / `doctor`：清理历史与元数据维护
- Git last commit + 最新源文件 mtime 的陈旧度估计
- 危险路径拒绝、符号链接保护、大体积删除必须输入 `DELETE`
- 支持压缩、验证后再把归档送入废纸篓，减少 Trash 中的占用
- TOML 自定义目标与 ignore 配置

从源码设计看，这是与 Stornaut 部分安全不变量和“人话解释”较接近的开源项目之一；但截至调研日只有 8 Star、1 Fork，尚不足以证明它经过大量真实机器、复杂目录和长期使用的验证。

需要注意，其默认分支实际内置目标数量比产品描述给人的印象更窄，核心仍以 `node_modules`、venv、`__pycache__`、`.next`、`dist`、`.cache` 等 basename 为主。它的可借鉴点主要是显式安全检查，而不是生态覆盖面或产品成熟度。测试和防护代码是正面证据，但不能替代真实采用与独立验证。

Stornaut 仍可拉开的差距：

- devklean 对未知目录明确不给风险结论；Stornaut 可让 Codex 做只读调查
- 主要治理项目树，不负责完整 Mac 卷级盘点
- 没有原生 SwiftUI 权限、菜单栏和系统集成
- 解释来自静态 signature registry，不是动态证据调查

最值得借鉴：危险路径校验、Trash 压缩事务、结构化历史、未识别目录不虚构置信度。

### 4.4 kondo

- 项目：[github.com/tbillington/kondo](https://github.com/tbillington/kondo)
- 许可证：[MIT](https://github.com/tbillington/kondo/blob/master/LICENSE)
- 技术栈：Rust
- 平台：macOS、Linux、Windows
- 产品形态：CLI + GUI

核心能力：

- 支持 20 多种项目类型
- 识别并清理依赖与构建产物
- 支持多个扫描根目录
- 支持 `--older 3M` 等年龄过滤
- CLI 与 GUI 共用核心库

它的 README 明确警告：kondo 本质上接近“带提示的 `rm -rf`”。因此它更像高性能产物发现与删除器，而不是完整的磁盘治理系统。

与 Stornaut 的关系：

- 可作为项目类型和 artifact taxonomy 的参考实现
- 不应照搬其执行安全模型
- 没有 Git dirty、依赖关系、未知目录调查、Manifest/Undo 等完整能力

### 4.5 Spaci

- 项目：[github.com/Raccoon254/spaci](https://github.com/Raccoon254/spaci)
- 许可证：截至调研日，仓库未发现 LICENSE
- 技术栈：Electron/JavaScript
- 平台：macOS，项目扫描部分强调多开发生态
- 产品形态：GUI

核心能力：

- 项目产物扫描和逐项选择
- npm、pnpm、Bun、Gradle、Maven、Cargo、CocoaPods、pip、Go、Deno 等缓存
- Xcode、系统缓存、浏览器缓存
- Git branch、大小、安全标签、最近修改时间
- 基于固定目录表和 `du` 的扫描

源码中的实际清理使用递归永久删除；历史记录是“发生过什么”的日志，不是恢复机制。部分字段中的 `reversible` 更接近“可以重新生成”，不能理解成“可撤销删除”。这再次说明产品必须区分：可重建、可恢复、已隔离、已永久释放。

许可证结论：仓库 Public 只能证明源码可见。没有许可证时，不应复制代码或把它列为可复用开源依赖。

### 4.6 npkill

- 项目：[github.com/voidcosmos/npkill](https://github.com/voidcosmos/npkill)
- 许可证：[MIT](https://github.com/voidcosmos/npkill/blob/main/LICENSE)
- 定位：专门查找和删除 `node_modules` 的跨平台 CLI

它证明了“项目依赖目录批量治理”存在长期需求，但能力边界很窄。Stornaut 不应与它比扫描目录数量，而应强调跨生态、陈旧度证据和安全决策。

## 5. 直接商业与专有竞品

### 5.1 CodeCleaner

- 官网：[code-cleaner.com](https://code-cleaner.com/)
- 产品形态：原生 macOS GUI
- 源码状态：官方页面未链接公开源码仓库；按专有产品看待

官方列出的覆盖范围非常完整：

- Xcode DerivedData、Simulator、Archives、SPM
- Docker、Colima、Lima VM、镜像、卷和 build cache
- npm、yarn、pnpm、Rust/Cargo、Python、Gradle、Go、Ruby、Flutter、Maven、Homebrew
- VS Code、Cursor、JetBrains 缓存
- 全盘 `node_modules` 扫描
- `.venv`、`target`、`dist`、`.next`、`.nuxt` 等项目产物
- 大文件、重复文件和磁盘分析
- whitelist-based deletion，本地处理，清理前逐项检查

这是与 Stornaut 当前 PRD 功能面最接近的产品。它说明仅靠“SwiftUI + 开发生态覆盖 + 安全标签”无法构成差异化。

Stornaut 的机会：

- CodeCleaner 强在已知类别覆盖，未体现对未知目录的 Agent 调查
- 它展示结果，但未公开可审计的规则、证据和决策过程
- Stornaut 可成为开源、透明、可扩展的调查引擎，而不是追求更多清理模块

### 5.2 CleanMyMac CLI

- 仓库：[github.com/MacPaw/cleanmymac-cli](https://github.com/MacPaw/cleanmymac-cli)
- 许可证：[MacPaw 专有 EULA](https://github.com/MacPaw/cleanmymac-cli/blob/main/LICENSE)
- 状态：2026 年公开 Beta
- 产品形态：CLI/TUI

重要澄清：该 GitHub 仓库公开，但树中主要是 README、LICENSE、SECURITY 等文档，并未开放产品实现。许可证仅允许个人非商业使用，并禁止复制、修改、派生和逆向工程，因此它不是开源项目。

核心能力：

- `clean dev`：包管理器、IDE、Docker、编译缓存
- `clean ai`：AI 工具产生的可清理数据
- `purge`：扫描常见开发目录中的 `node_modules`、`.venv`、`.next`、`target` 等
- 按年龄预选项目产物
- `analyze`：交互式磁盘空间浏览
- ignore list、交互确认、protected system locations
- `optimize purgeable`：请求 macOS 释放 purgeable space

对 Stornaut 的启示：

- “开发者清理”已经得到成熟 Mac 工具厂商验证
- CLI 和 GUI 并不是核心差异，判断透明度才是
- Stornaut 必须避免复用其专有实现，只能进行黑盒行为对比

## 6. AI 清理产品

### 6.1 Soji

- 官网：[sojimac.com](https://sojimac.com/)
- 产品形态：macOS App
- 官方价格：调研时为一次性 6.99 美元
- AI：Apple Intelligence 端侧模型，要求支持 Apple Intelligence 的 Mac 和 macOS 26+
- 隐私：官方声称无网络访问、文件名与路径不离开本机
- 删除：只移入 Trash，不提供永久删除
- 源码状态：未发现公开产品源码

Soji 已占据“本地 AI 告诉你什么能删”的表层叙事。Stornaut 不应只强调“用了 AI”，而应强调：

- Agent 使用了哪些工具和证据
- 结论能否复核
- 安全策略如何否决 Agent
- 未知目录如何从一次判断沉淀为社区规则

### 6.2 CleanerCat、Cacheless、DiskCopilot

这些产品分别强调对话式清理、AI 解释目录、智能建议或 AI 磁盘助手。公开页面的信息不足以证明其内部是否真正执行 Agent 式调查，也无法确认完整安全模型和源码状态，因此本报告仅把它们视为“AI cleaner”市场信号，不把营销描述等同于已验证能力。

相关入口：

- [CleanerCat App Store](https://apps.apple.com/us/app/cleaner-cat/id6757230471)
- [Cacheless Product Hunt](https://www.producthunt.com/products/cacheless-ai-powered-disk-cleanup)
- [DiskCopilot](https://diskcopilot.com/)

### 6.3 Agent 清理工作流与 Skills

本次补充调研发现，Agent 驱动的磁盘清理并非完全空白，但目前更常见的形态是“通用编码 Agent + Skill/提示词”，而不是独立的磁盘清理产品：

- [Claude Code disk cleanup Skill](https://gist.github.com/alvinvogelzang/6b2098530794d9512e940bac80c1520e)：要求 Agent 从当前机器最大的空间消费者开始调查，而不是只执行固定清单；会检查缓存、VM、陈旧项目、Git 状态，并等待用户批准。
- [daymade macos-cleaner Skill](https://github.com/daymade/claude-code-skills/blob/main/README.zh-CN.md)：让 Claude Code 运行磁盘分析、按风险分类、解释清理影响并在确认后执行。

它们是 Stornaut 最接近的“概念竞品”，也验证了用户今天通过 Claude Code/Codex 找回大量空间的体验具有可复现性。不过，它们仍然依赖通用 Agent 的 shell 权限、上下文和提示词约束，尚未形成同时具备以下层次的完整独立应用：

1. 原生或高性能确定性扫描器
2. 开发生态规则库与结构化证据模型
3. 只读、受限的未知目录 Agent 调查
4. 与 Agent 隔离的策略闸门和类型化 Executor
5. Trash、Manifest、恢复与安全回归测试

本报告将“真正的 Agent”定义为：它能根据前一步观察自主选择下一项只读调查工具，处理规则未知的目录，显式输出证据、不确定性和建议。仅把固定扫描结果交给模型生成一句解释，或者在 UI 中使用“AI”标签，不算 Agent 式调查。

因此更准确的市场结论不是“没有 AI 磁盘清理”，而是：

> **已经出现 AI 解释产品和 Agent 清理 Skills，但本次调研尚未发现把确定性扫描、受限 Agent 调查、策略否决权和安全执行器整合在一起的成熟开源 macOS 产品。**

## 7. 邻近工具

### 7.1 Pearcleaner

- 项目：[github.com/alienator88/Pearcleaner](https://github.com/alienator88/Pearcleaner)
- 许可证：[Apache-2.0 + Commons Clause](https://github.com/alienator88/Pearcleaner/blob/main/LICENSE.md)
- 状态：README 标记为 On Hold
- 定位：App 卸载、App 残留、Homebrew、开发环境和多种 macOS 工具集合

它是优秀的原生 Swift/SwiftUI macOS 工程参考，但 Commons Clause 禁止销售软件，项目自己也称为 source-available/fair-code。对 Stornaut 最有价值的是：

- Full Disk Access 和 privileged helper 的用户引导
- 原生 Trash/Undo 体验
- App 关联文件搜索与路径保护
- SwiftUI 工程组织和 macOS 分发经验

它不负责项目陈旧度、开发产物工作链或未知目录 Agent 调查。

### 7.2 Mole

- 项目：[github.com/tw93/mole](https://github.com/tw93/mole)
- CLI 许可证：[GPL-3.0](https://github.com/tw93/Mole/blob/main/LICENSE)
- 定位：终端中的 Mac 清理、卸载、磁盘分析、优化和监控；另有原生付费 Mac App

Mole 证明命令行清理和通用 Mac 工具可以拥有很好的产品体验。GPL-3.0 代码若被复制进 Stornaut，会带来强 copyleft 义务；适合作为行为和 UX 参考，不适合无意中粘贴实现。

截至 2026-08-06，Mole 拥有 62,246 Star，是本报告中采用信号最强的项目。这足以把它视为产品化、安装体验、CLI UX、文档和社区传播的首要 Benchmark，但不能据此推导它在开发项目陈旧度、未知目录判断、Git 工作状态保护或删除安全上必然优于专项工具。它覆盖的清理、卸载、分析、优化和监控也比 Stornaut 更宽，Star 来自的需求面并不相同。

### 7.3 PureMac

- 项目：[github.com/momenbasel/PureMac](https://github.com/momenbasel/PureMac)
- 许可证：MIT
- 定位：原生 SwiftUI、通用缓存、Xcode/Homebrew、Full Disk Access、定时清理

它适合参考 SwiftUI 权限探测、原生工程和通用缓存模块，但产品重心不是开发项目语义或 Agent 调查。

### 7.4 DaisyDisk、CleanMyMac GUI、BuhoCleaner

这三类工具是用户真实尝试过但没有解决本案例的方案：

- [DaisyDisk](https://daisydiskapp.com/)：擅长空间可视化和人工下钻，不负责判断开发产物能否删除。
- [CleanMyMac](https://macpaw.com/cleanmymac)：擅长已知系统/应用垃圾，开发者能力正在向 CLI 扩展。
- [BuhoCleaner](https://www.drbuho.com/buhocleaner)：通用 Mac 清理与卸载，不以跨项目开发语义为核心。

它们不是“扫描失败”，而是产品职责不同：能展示或删除通用垃圾，不会替开发者调查一个 4GB 的陌生目录是否属于可重建工作链。

## 8. 功能对比矩阵

图例：✅ 明确支持；◐ 部分支持或范围有限；— 未发现；? 官方资料不足。

| 产品 | 项目产物 | 全局开发缓存 | macOS 系统盘点 | 陈旧度 | Git/活跃保护 | Trash/恢复 | 目录解释 | 未知目录 Agent | 开放规则扩展 | 许可证 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| **Stornaut（规划）** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | MIT |
| ClearDisk | ✅ | ✅ | ◐ | ✅ | ◐ | ✅ | ✅（静态规则） | — | ◐（代码） | MIT |
| CodeCleaner | ✅ | ✅ | ✅ | ✅ | ? | ? | ◐ | — | — | 专有/未公开源码 |
| Cluttered | ✅ | ◐ | — | ✅ | ✅ | ✅ | ◐ | — | ◐（代码插件） | MIT |
| CleanMyMac CLI | ✅ | ✅ | ✅ | ✅ | ◐（ignore/确认） | ? | ◐ | — | — | 专有 EULA |
| devklean | ✅ | ◐ | — | ✅ | ◐ | ✅ | ✅（静态规则） | — | ✅（TOML） | MIT |
| kondo | ✅ | — | — | ✅ | — | — | — | — | ◐（代码） | MIT |
| Spaci | ✅ | ✅ | ◐ | ✅ | ◐ | ? | ◐ | — | ◐（代码） | 无许可证 |
| Soji | ◐ | ◐ | ◐ | ? | ? | ✅ | ✅（端侧 AI） | ◐ | — | 专有 |
| Pearcleaner | — | ◐ | ◐ | — | — | ✅ | ◐ | — | — | Apache + Commons Clause |
| Mole | ◐ | ✅ | ✅ | — | — | ? | ◐ | — | ◐（代码） | GPL-3.0（CLI） |

Claude Code disk cleanup、daymade macos-cleaner 等 Agent Skills 未放入此表，因为它们不是独立清理产品，也没有固定扫描器和 Executor 可按相同口径比较；它们作为第 6.3 节的概念竞品单独评估。

## 9. Stornaut 真正可防守的差异

### 9.1 从 Cleaner 转向 Investigator

现有工具大多从“已知清理规则”出发：知道路径就显示，规则不认识就忽略。Stornaut 应增加调查对象模型：

```json
{
  "path": "~/Library/Application Support/UnknownTool/vm_bundles",
  "sizeBytes": 15400000000,
  "producerEvidence": ["bundle identifier", "README", "running process"],
  "activityEvidence": ["last write", "open file", "app last used"],
  "dependencyEvidence": ["referenced by app", "workspace link"],
  "rebuildEvidence": ["official command", "download source", "lockfile"],
  "rebuildCost": "15GB download + next launch initialization",
  "risk": "medium",
  "confidence": 0.91,
  "disposition": "reviewRecommended"
}
```

用户看到的不是“AI 说安全”，而是“这些证据支持 `Review Recommended`，风险为 medium，仍需人工确认”。

### 9.2 Agent 没有删除授权

已有 AI cleaner 容易把“模型参与判断”当卖点。Stornaut 应把约束本身作为卖点：

- Agent 只能经 Probe Broker 调用类型化只读调查工具
- 规则未命中且只有 Agent 证据时，处置最高只能是 `Review Recommended`
- `Ready to Reclaim` 必须同时得到已审核规则与 Policy Gate 支持，并默认使用 Trash
- Agent 输出置信度不能绕过 veto
- 真正执行由 Swift Executor 完成并记录 Manifest

### 9.3 解释“空间为什么对不上”

真实案例中，HOME 与已用空间曾相差约 30GB，最终由 VM/swap、系统目录、根隐藏目录等解释。Stornaut 可以把以下内容做成统一账本：

- 当前真实可用空间
- 可重建缓存
- 可隔离但尚未释放空间
- 永久释放空间
- 重启后短期回收空间
- swap 预计回涨
- APFS purgeable、clone、sparse file 的逻辑/物理大小差异
- TCC/FDA 导致的“无法测量空间”

这是多数“项目产物清理器”没有覆盖的层次。

### 9.4 开放策略与社区知识

规则库不应只是路径 glob，还应包含：

- 生产者识别证据
- 前置条件，例如 App 未运行
- 活跃性信号
- 危险子路径与 veto
- 推荐的官方清理命令
- 重建步骤与预计成本
- 规则来源、验证日期和适用版本
- fixture 与安全回归测试

一次 Agent 调查不能直接变成规则；应生成候选规则，由人审核、补测试后合并。

## 10. 对现有文档的影响

### 10.1 README 定位应调整

当前文案：

> CleanMyMac 不懂你的 node_modules，我们懂。

这句话有记忆点，但随着 CodeCleaner、Cluttered、CleanMyMac CLI 和 devklean 出现，事实基础已经变弱。可保留作情绪化副标题，但正式定位建议改为：

> 不只告诉你什么占空间，还用证据解释它是什么、为什么能清、删除后如何恢复。

### 10.2 PRD 的竞品描述应更新

当前 PRD 对 kondo/npkill 的判断基本成立，但缺少：

- CodeCleaner：直接原生商业竞品
- Cluttered：带陈旧度和 Git 保护的开源 GUI
- devklean：带解释、Trash、历史和安全门的开源 CLI
- CleanMyMac CLI：成熟厂商进入开发者清理赛道
- Soji 等本地 AI cleaner
- Claude Code disk cleanup、daymade macos-cleaner 等 Agent Skills：证明“现场调查未知占用”的工作流已出现，但尚未产品化为完整安全架构

### 10.3 Agent v1 职责值得重新评估

如果 Agent v1 只生成“人话解释”，它与 devklean 的静态 explain registry、Soji 的 AI 标签差异有限。更有价值的职责是：

1. 对规则 miss 且体积显著的目录执行受限只读调查
2. 输出结构化证据，而不是让模型直接决定 ReclaimDisposition
3. 将解释建立在证据和策略结果之上

## 11. 开源复用建议

| 项目 | 可以做什么 | 注意事项 |
|---|---|---|
| ClearDisk（MIT） | 研究 SwiftUI 菜单栏、taxonomy、项目扫描和预测 UX | 先审计真实执行路径，不把 README 安全声明当成保证 |
| Cluttered（MIT） | 研究生态探测、Git/IDE 活跃保护、测试样例 | 复用代码时保留版权与许可证声明 |
| devklean（MIT） | 研究危险路径保护、Trash 事务、历史和 signature schema | 不要照搬 Python 架构；提取安全不变量 |
| kondo（MIT） | 研究项目类型和 artifact taxonomy、扫描性能 | 不采用其直接删除安全模型 |
| npkill（MIT） | 研究大规模 `node_modules` 发现和交互 | 单生态能力只作局部参考 |
| PureMac（MIT） | 研究 SwiftUI、FDA 和 macOS 原生工程 | 核对每个目录规则的来源与安全性 |
| Mole（GPL-3.0） | 行为、CLI UX 和测试对照 | 复制代码会触发 GPL 义务 |
| Pearcleaner（Commons Clause） | 阅读原生权限/Trash/Helper 设计 | source-available，不要当作无约束 Apache-2.0 |
| Spaci（无 LICENSE） | 仅观察产品和公开实现 | 不复制、修改或分发代码 |
| CleanMyMac CLI / CodeCleaner | 黑盒功能与结果 Benchmark | 专有实现，不逆向或复制 |

推荐做法不是 fork 某个项目，而是：

> 自己实现 Swift 原生核心，吸收 MIT 项目的安全不变量、taxonomy 和测试思想，再加入 Codex 证据调查层。

## 12. 建议的 Benchmark

为了让 Stornaut 的价值可验证，可把真实案例目录结构匿名化成 fixture，然后用同一组任务比较：

| 指标 | 说明 |
|---|---|
| 已知产物召回率 | 1204 个 node_modules、41 个 .venv、各类构建产物能发现多少 |
| 规则覆盖率 | 不调用 Agent 时能解释多少空间 |
| 未解释空间 | 扫描结果与 Data 卷已用量相差多少 |
| false Ready-to-Reclaim | 活跃项目、唯一扩展版本、照片库等是否被错误归入 Ready to Reclaim |
| 工作链保护 | remotion 被 OpenMontage 依赖时是否能识别 |
| 预测准确率 | 预计释放与实际永久释放的误差 |
| 时间与资源 | 全盘扫描耗时、CPU、内存、磁盘 I/O |
| 可恢复性 | Trash/Manifest/官方重建命令是否真的可用 |
| 解释质量 | 用户能否仅凭证据作出清理决定 |

建议将 Mole、ClearDisk、CodeCleaner、kondo、CleanMyMac CLI 作为第一批产品 Benchmark；Cluttered 和 devklean 作为早期源码设计参考；Claude Code disk cleanup 和 daymade macos-cleaner 作为 Agent 工作流对照。开源工具可做源码级对照，专有工具只做黑盒结果对照。目标不是证明它们差，而是找出 Stornaut 的确定性优势和真实盲区。

## 13. 最终建议

基于“个人自用、公开开源”的目标，推荐的产品路线是：

1. 不追求一次覆盖所有竞品功能。
2. 第一版先解决案例中最痛的三类空间：全局开发缓存、陈旧项目产物、未知大目录。
3. 扫描与分类先确定性化；Agent 只调查规则 miss。
4. 优先实现证据模型和安全不变量，再做漂亮 GUI。
5. 用真实机器和匿名 fixture 与现有工具做持续 Benchmark。
6. 将 Stornaut 定义为开源调查与策略引擎，而不是“免费版 CodeCleaner”。
7. 首次 public push 前必须有明确开源许可证。后续项目决策已选择 MIT，当前目录现已包含 `LICENSE`；发布前仍需核对第三方 NOTICE 与复用记录。

一句话总结：

> **市场上已经有不少开发者 Cleaner，但仍然缺少一个开源、证据驱动、允许 Agent 调查未知目录而又不把删除权交给 Agent 的 macOS 磁盘治理工具。**

## 14. 主要资料来源

- [CodeCleaner 官方网站](https://code-cleaner.com/)
- [ClearDisk GitHub](https://github.com/bysiber/cleardisk) / [MIT License](https://github.com/bysiber/cleardisk/blob/main/LICENSE)
- [Cluttered 官方网站](https://www.cluttered.dev/) / [GitHub](https://github.com/gatteo/cluttered) / [MIT License](https://github.com/gatteo/cluttered/blob/main/LICENSE)
- [CleanMyMac CLI GitHub](https://github.com/MacPaw/cleanmymac-cli) / [EULA](https://github.com/MacPaw/cleanmymac-cli/blob/main/LICENSE)
- [devklean GitHub](https://github.com/smurftyy/devklean) / [PyPI](https://pypi.org/project/devklean/)
- [kondo GitHub](https://github.com/tbillington/kondo) / [MIT License](https://github.com/tbillington/kondo/blob/master/LICENSE)
- [Spaci GitHub](https://github.com/Raccoon254/spaci)
- [Soji 官方网站](https://sojimac.com/)
- [Pearcleaner GitHub](https://github.com/alienator88/Pearcleaner) / [License](https://github.com/alienator88/Pearcleaner/blob/main/LICENSE.md)
- [Mole GitHub](https://github.com/tw93/mole) / [GPL-3.0](https://github.com/tw93/Mole/blob/main/LICENSE)
- [PureMac GitHub](https://github.com/momenbasel/PureMac)
- [npkill GitHub](https://github.com/voidcosmos/npkill)
- [DaisyDisk](https://daisydiskapp.com/)
- [CleanMyMac](https://macpaw.com/cleanmymac)
- [BuhoCleaner](https://www.drbuho.com/buhocleaner)
- [Claude Code disk cleanup Skill](https://gist.github.com/alvinvogelzang/6b2098530794d9512e940bac80c1520e)
- [daymade macos-cleaner Skill](https://github.com/daymade/claude-code-skills/blob/main/README.zh-CN.md)

## 15. 调研限制

- 产品功能、价格和许可证可能变化，本报告是 2026-08-06 的时间切片。
- 闭源产品只能依据官方文档和可观察行为评估，不能验证其内部实现。
- “未发现”只代表本次调研未找到权威公开证据，不等于绝对不存在。
- 营销页面中的“AI”“安全”“释放空间”等词不等同于经过独立测试的能力。
- 正式复用任何第三方代码前，应再次核对具体 commit 对应的许可证和 NOTICE 要求。
