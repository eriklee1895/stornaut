# Stornaut UI Testing Guide

> 状态：Active
>
> 最近更新：2026-08-10
>
> 适用范围：Stornaut 原生 macOS App 的 UI 实现、回归与运行时视觉验收

本指南定义 Stornaut UI 改动的证据标准。目标不是“有一张截图”，而是把行为契约、真实窗口渲染、Light/Dark、Settings 和本机图形会话限制分开验证。

工具安装、版本、MCP 白名单和开发/产品隔离边界见 [Development Automation](development-tooling.md)。

## 1. Definition of Done

UI 小迭代完成必须同时满足：

1. 与批准的 PRD/UI 规格一致，不从概念图推导新功能；
2. 相关 domain/view-model 单元测试通过；
3. XCUITest 验证可重复的导航、窗口和状态契约；
4. 构建并启动真实 `Stornaut.app`，不是只看 SwiftUI Preview；
5. 在 awake/unlocked 本地图形会话中，用 Peekaboo 截取实际目标窗口并检查；
6. Light/Dark 或 Settings 受影响时，更新对应截图证据；
7. 最后运行 `scripts/verify`；
8. 不提交本机截图、私有路径、TCC 状态或 `.xcresult` 原始产物，除非它们是已脱敏、明确批准的文档资产。

只读源码、成功编译或 SwiftUI Preview 都不能单独证明 UI 正确。

## 2. Evidence Layers

| 层级 | 工具 | 负责证明 | 不负责证明 |
| --- | --- | --- | --- |
| Domain | Swift Testing / XCTest | 导航枚举、状态模型、localization key 等稳定契约 | 实际窗口布局 |
| App contract | XCUITest | 启动、四项 workspace、Sidebar Settings、`⌘,`、Light/Dark effective appearance | 所有真实桌面/TCC 条件 |
| Screenshot regression | XCUITest attachment + `.xcresult` | 稳定命名的 shell/Settings Light/Dark 证据 | 当前用户桌面上肉眼看到的最终结果 |
| Runtime visual | XcodeBuildMCP + Peekaboo | 当前构建的真实 `.app`、实际窗口、裁切/溢出/材质/层级 | CI 可移植性和行为断言 |
| Human review | Coding Agent + user | 视觉质量、是否符合设计意图 | 自动回归 |

这些层级互补，不互相替代。Peekaboo 是本地视觉补充；XCUITest 是可重复自动化契约。

## 3. Current UI Contracts

Epic 0 shell 当前必须保持：

- 只有 Overview、Scan、Investigations、History 四个 workspace；
- Settings 是 Sidebar 左下齿轮 affordance，但不是第五个 workspace；
- `⌘,` 打开同一个独立 Settings scene；
- App 只提供一个主窗口，不提供额外 workspace window；
- System Light/Dark 均可读；
- bundle identifier 为 `com.eriklee.stornaut`。

现有 XCUITest 必须生成十三个稳定附件：

```text
stornaut-shell-light.png
stornaut-settings-light.png
stornaut-shell-dark.png
stornaut-settings-dark.png
stornaut-overview-limited.png
stornaut-overview-zh-Hans.png
stornaut-scan-progress-dark.png
stornaut-scan-partial-light.png
stornaut-scan-results-inspector-light.png
stornaut-history-populated-light.png
stornaut-history-expired-dark.png
stornaut-history-corrupt-light.png
stornaut-history-trend-dark.png
```

`scripts/export-ui-screenshots` 将它们导出到 ignored 的 `.derivedData/ui-screenshots/`，`scripts/verify-ui-screenshots` 检查文件、尺寸和主题差异。

Task 22 起，shell Light/Dark 截图使用真实 `success` Overview fixture，不再
使用 foundation placeholder。额外两张截图分别固定 permission-limited
Overview 与 `zh-Hans` Overview；它们验证 Unknown/Unmeasurable 分离、安全暂停
Deep Dive 和 localization 层级，不复制概念图示例数字。

Task 23 的三张 Scan 截图固定 deterministic DEBUG fake state，绝不扫描真实
home：Dark active 验证五阶段 rail、四种独立进度单位和渐进结果；Light
partial 验证 page-preserving partial truth；Light completed + Inspector
验证 grouped lifecycle table 和只读证据详情。截图中不得出现 enabled Review、
Trash、Registered Action 或 Codex action。

Task 24 的四张 History 截图固定 typed DEBUG Evidence fixture：Light populated
验证日期分组 master-detail 与真实 ledger measures；Dark expired 验证 retention
语义；Light corrupt 验证单条 session/ledger 隔离；Dark trend 验证至少四个
measured、可比较、不同时间戳样本的 Used/Free 直标与非因果文案。它们不得
显示 Deep Dive、Cleanup Manifest、export 或暗示后台采集。

Settings 附件必须截取包含 `settings.content` 的独立 window，不能直接对
`settings.content` accessibility element 截图。后者在 macOS 26 的透明
Settings scene 中可能把材质合成到白色背景，无法可靠反映窗口主题。
截图前还必须确认 `settings.content` 与所属 window 都 hittable；若 Settings
被主窗口遮挡，只激活 App 并点击现有 Settings 内容将该 window 置前，不要
重复发送 `⌘,`。重复快捷键可能切换窗口状态，而对被遮挡 window 执行
`screenshot()` 会捕获遮挡后的屏幕矩形，产生看似主题漂移的假回归。

未来页面应在自己的 Task/ADR 中增加最小必要契约，不要把所有页面都塞进一个超长 smoke test。

## 4. Fast Iteration Loop

### 4.1 Narrow checks

先运行受影响的最小测试：

```sh
swift test

xcodebuild -quiet \
  -project Stornaut.xcodeproj \
  -scheme Stornaut \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .derivedData/tests \
  -skip-testing:StornautAppUITests \
  test
```

### 4.2 Build and launch the actual App

标准 smoke：

```sh
scripts/verify-ui-runtime
```

需要拆开排障时：

```sh
scripts/xcodebuildmcp macos build-and-run --output json
```

检查结构化结果至少包含：

- `didError: false`;
- project path 指向本仓库 `Stornaut.xcodeproj`;
- scheme `Stornaut`;
- configuration `Debug`;
- architecture `arm64`;
- bundle id `com.eriklee.stornaut`;
- 正数 process ID。

### 4.3 Read-only runtime inspection

```sh
mkdir -p .derivedData/peekaboo
scripts/peekaboo-readonly list apps --json-output
scripts/peekaboo-readonly image \
  --pid <build-and-run returned process ID> \
  --mode window \
  --retina \
  --path "$PWD/.derivedData/peekaboo/stornaut-window.png" \
  --json-output
```

检查截图：

- 是否只包含目标窗口，没有意外的桌面或其他应用内容；
- 窗口尺寸、Sidebar/toolbar/Settings 层级是否正确；
- 文本是否截断、重叠或使用错误 localization；
- Light/Dark 材质、对比度和 selected state 是否可读；
- requested interaction 后的状态是否真实出现；
- 概念图中的 fixture 文案/路径/数字是否被误写进产品。

默认使用 XcodeBuildMCP 返回的 PID，避免同名旧 App 实例或窗口标题本地化造成歧义。`see` / `inspect_ui` 只有在 Accessibility 已由用户独立授予且确有必要时才可作为额外只读证据。默认不要求、不申请该权限；`list windows` 在 Peekaboo `3.10.0` 下也可能要求 Accessibility，因此不应成为默认 screenshot 前置步骤。

### 4.4 Full regression

```sh
scripts/verify
```

开发 MCP/TCC 的独立验收：

```sh
scripts/doctor-dev-tools
```

两者都通过后才可声称本地 UI 自动化基础设施与项目回归同时健康。

## 5. Light/Dark and Settings Rules

- 受影响页面至少检查 System Light/Dark；若测试使用 Debug-only appearance/window-background override，Release/System 行为不得被修改。
- Settings 必须验证 Sidebar gear 与 `⌘,` 两条入口。
- Settings 截图应只捕获 Settings 窗口，不把主窗口混入截图。
- Debug-only appearance override 必须分别验证主窗口与按需新建的 Settings 窗口各自的 effective appearance。
- 不允许通过 click/type/hotkey MCP 工具操作 UI；这些工具不在 Peekaboo 白名单中。
- 需要自动交互的行为放在 XCUITest，通过 accessibility identifier 和 keyboard shortcut API 验证。
- UI 元素增加或重命名时，同步更新 localization、identifier、测试和截图名称契约。

## 6. Graphical Session and TCC Troubleshooting

### Screen Recording

```sh
scripts/peekaboo-readonly permissions status --json-output
```

- `Screen Recording: granted` 才能执行 Peekaboo screenshot；
- 缺失时停止本地视觉验收，不能自动打开、点击或重置 System Settings；
- Accessibility / Event Synthesizing 缺失不阻止默认 image-only loop。

### Displays asleep or session locked

症状：

- Peekaboo `No displays available for window capture`;
- native `screencapture` 同样失败；
- `CGGetActiveDisplayList` 返回 0；
- XCUITest App 停在 `Running Background`，无法 activate。

处理：

1. 不使用合成输入唤醒机器；
2. 记录本轮为 host graphical-session blocked，而不是产品失败；
3. 允许 unit/App tests 继续，但不能宣称 Peekaboo screenshot 或 XCUITest 已通过；
4. 用户回到 awake/unlocked session 后，重跑受影响的 capture/XCUITest；
5. CI 只依赖 XCUITest 等受控环境，不声明 Peekaboo/TCC 证据。

### XCTest waits for `Enable UI Automation`

症状：

- `StornautAppUITests-Runner` 在任何 test method 启动前失败；
- `.xcresult` 显示 `Timed out while enabling automation mode`;
- `automationmodetool` 报告 Automation Mode disabled，并要求 user
  authentication；
- LocalAuthentication UIAgent 显示 `Enable UI Automation` 的 Touch ID 或登录
  密码认证。

这是 XCTest 的 Automation Mode 安全认证，不等于 Screen Recording、
Accessibility 或 Event Synthesizing 缺失。先运行只读状态检查：

```sh
automationmodetool
xcrun xcresulttool get test-results summary \
  --path .derivedData/ui-tests.xcresult
```

普通开发机的处理：

1. 确保用户位于 awake/unlocked 图形会话；
2. 重新启动 UI-only test；
3. 用户本人在超时前批准 `Enable UI Automation`；
4. 确认 UI test methods 实际执行，而不只是 runner 初始化成功；
5. 再运行完整 `scripts/verify`。

系统 `automationmodetool(1)` 另提供
`enable-automationmode-without-authentication`，用于经管理员明确配置的 CI
或实验室机器。它会改变整台机器的 UI automation 认证策略，不是普通本地
排障命令。Coding Agent 不得自行执行该命令、输入用户凭据、创建
`/var/db/com.apple.dt.automationmode/` 状态文件、重启 root writer daemon，
或修改 TCC/SIP。若项目未来需要 unattended macOS UI CI，必须先由用户批准
独立的主机安全方案；恢复命令以本机 `man automationmodetool` 为准。

### Window found by app inventory but capture says `WINDOW_NOT_FOUND`

检查：

1. App process 是否仍在运行；
2. App 是否 finished launching 且 `windowCount > 0`;
3. 显示器是否 active；
4. 是否同时有旧 Stornaut 实例；
5. 当前 Peekaboo daemon 与 CLI 是否同为 pinned `3.10.0`。

不要以授予 Accessibility 作为第一修复手段。若 `image --app ... --mode window` 在 active session 仍失败，保留日志并使用 XCUITest screenshot 作为 fallback，再单独记录工具问题。

## 7. Failure Reporting

报告 UI 验证结果时必须区分：

- **Passed**：测试/截图实际完成并检查；
- **Failed**：App 行为或视觉契约不满足；
- **Tool failed**：XcodeBuildMCP/Peekaboo 协议、版本或 capture 失败；
- **Host blocked**：显示器 asleep、session locked、TCC 缺失；
- **Skipped**：本轮未执行，不能写成隐含通过。

失败时保留最小、安全的命令输出和 `.xcresult` 摘要；不要提交包含其他应用、用户路径或敏感内容的全屏截图。
