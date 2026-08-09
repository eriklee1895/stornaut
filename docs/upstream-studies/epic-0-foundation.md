# Epic 0 Foundation Upstream Study

> 状态：Accepted for Epic 0 implementation
> 日期：2026-08-09
> Coding Agent：TRAE CLI
> 目标模块：Repository foundation、Swift packages、native macOS App host、tests、local verification
> 覆盖计划：Epic 0 Task 1–2

## 1. 结论

Stornaut 采用以下工程拓扑：

```text
Stornaut.xcodeproj
├── StornautApp          macOS application target
└── StornautAppTests     macOS unit-test target

Package.swift
├── StornautCore         library target
├── StornautCodex        library target
├── StornautCoreTests
└── StornautCodexTests
```

- `Stornaut.xcodeproj` 作为 checked-in、无生成器依赖的真实 App host。
- App target 通过 Xcode 的 local package dependency 引用仓库根 `Package.swift` 中的 `StornautCore` 和 `StornautCodex` products。
- App、Core、Codex 保持三个生产模块；App 不直接承载扫描、Codex 进程或写操作实现。
- 不引入 xcodegen、Tuist、第三方依赖或自定义项目生成器。
- 不把 SwiftPM executable 或 `swift run` 当作 macOS App/TCC identity。
- 不把 ClearDisk 式手工 bundle 脚本作为正式 App host；它仅证明 SwiftPM binary 可以被包装成 `.app`。
- 当前机器没有有效 Apple Development/Developer ID code-signing identity。Epic 0 本地 Spike 使用 ad-hoc 签名和显式 designated requirement 建立可重复的本地身份；Developer ID、hardened runtime、notarization 和发布身份留到 Epic 9。
- bundle identifier 已由用户确认为 `com.eriklee.stornaut`。Task 2 起使用该 identity；一旦用于 TCC/FDA 实验，后续不得无 ADR 地更改。

该结论是 Epic 0 的 Implementation Brief，也是 ADR 0001 的输入。Task 2 完成真实 App shell 与实测后，ADR 0001 再记录最终工程路径、build settings、签名结果和限制。

## 2. 执行时环境

| 项目 | 观测值 |
| --- | --- |
| 日期 | 2026-08-09 |
| macOS | 26.5.1（Build 25F80） |
| Architecture | arm64 |
| Xcode | 26.6（Build 17F113） |
| Swift | 6.3.3 |
| Swift target | arm64-apple-macosx26.0 |
| 有效 code-signing identities | 0 |
| Repository | public GitHub，`main` 跟踪 `origin/main` |

这些值是本次证据，不是永久产品常量。实施时仍应通过命令重新记录。

环境与上游快照使用：

```text
sw_vers
uname -m
xcodebuild -version
swift --version
security find-identity -v -p codesigning
git clone --depth 1 <upstream>
git rev-parse HEAD
git describe --tags --always
```

## 3. 上游快照

| 项目/文档 | commit/version | license | 阅读文件/文档 |
| --- | --- | --- | --- |
| [ClearDisk](https://github.com/bysiber/cleardisk) | `1aaec92b91c40fdc0c2fce92fef20df08b5f5c43`；tag `v1.9.0` | MIT | `Package.swift`、`scripts/build_app.sh`、`scripts/dev.sh`、`Sources/ClearDisk/ClearDiskApp.swift`、`README.md`、`LICENSE` |
| [PureMac](https://github.com/momenbasel/PureMac) | `e586b50bb30f68d0afff173e7d8389a50020095e` | MIT | `project.yml`、`PureMac.xcodeproj/project.pbxproj`、shared scheme、`Info.plist`、entitlements、`PureMacApp.swift`、`PureMacTests/*`、`README.md`、`LICENSE` |
| Swift Package Manager | execution-time main documentation snapshot via Context7 | Apache-2.0 | [`executableTarget`](https://github.com/swiftlang/swift-package-manager/blob/main/Sources/Runtimes/PackageDescription/PackageDescription.docc/Curation/Target.md)、package products/targets、Xcode integration |
| Apple Xcode documentation | Xcode 26.6 local docs + developer.apple.com | Apple documentation terms | [editing a package dependency as a local package](https://developer.apple.com/documentation/xcode/editing-a-package-dependency-as-a-local-package)、[organizing code with local packages](https://developer.apple.com/documentation/xcode/organizing-your-code-with-local-packages)、XCTest、[bundle/signing inspection](https://developer.apple.com/documentation/xcode/embedding-a-helper-tool-in-a-sandboxed-app)、`xcodebuild -help` |
| Local Xcode templates | Xcode 26.6 | Apple tool installation | `macOS App Base.xctemplate`、`App.xctemplate`、macOS entitlements template |

### Source fingerprints

用于确认本次实际阅读的上游文件：

| 文件 | SHA-256 |
| --- | --- |
| ClearDisk `Package.swift` | `76f3da04868b2093ee25ba4d21dade1f1af650baf3e37b91919a9028c5e8a329` |
| ClearDisk `scripts/build_app.sh` | `b8fabdf0bb7853403874a59d828f6a71f2d62992ae6c9c70b1c6d0e0820524f9` |
| ClearDisk `ClearDiskApp.swift` | `86e4c1fd1d877a6976fb261a6df72e49806236436dbc0252f53d856241f8037b` |
| PureMac `project.yml` | `7d6c749c26605d73d6725c866e4c30326f02af90365edf95bce55e1aa049f092` |
| PureMac `project.pbxproj` | `d1572ed0ed5d498002172ff22e29d065806cefdb52159484f0cbad4d4263543e` |
| PureMac shared scheme | `f67eb136be72ddb9a20ba252dfe1c6c21c54c2e9d541d9e02c7f5115edf09faa` |
| PureMac `Info.plist` | `cc2e82a29dff36a8cd2728cc1a178b1dc68f2f36142137df4a792320a059bd2a` |
| PureMac entitlements | `99daef167cdc678891a0b49601b6a34a0fae7240c2aa8bd44a753edc131c7d6d` |

## 4. 上游观察

### 4.1 ClearDisk：SwiftPM + 手工 `.app` bundle

ClearDisk 使用一个 SwiftPM executable target。`scripts/build_app.sh`：

1. 使用 `swift build` 构建 binary；
2. 创建 `ClearDisk.app/Contents/MacOS` 和 `Resources`；
3. 通过 heredoc 写入固定 bundle identifier 的 `Info.plist`；
4. 复制 icon；
5. 运行 `codesign --force --deep -s -` 做 ad-hoc 签名；
6. 通过 `open ClearDisk.app` 启动。

可借鉴：

- `.app` 必须通过 LaunchServices 启动，不能用 `swift run` 代替 App-context 行为；
- bundle identifier、Info.plist、资源和签名应被脚本验证；
- build 脚本应 fail fast，并检查产物路径、架构和签名；
- App 内通过 `Bundle.main` 读取版本，避免 UI 与产物版本漂移。

限制：

- 仓库没有测试 target；
- 默认 ad-hoc 签名没有稳定的证书/team identity；
- 默认 designated requirement 由 `cdhash` 构成，binary 变化后 identity 也变化；
- 手工 bundle 会复制 Xcode 已经原生处理的资源、test host、scheme、archive 和 signing 逻辑；
- ClearDisk 是 MenuBar-only 产品，不能照搬其 App 生命周期和后台 timer。

### 4.2 PureMac：Xcode App/Test targets

PureMac 使用 `PBXNativeTarget`：

- `PureMac.app`：`com.apple.product-type.application`
- `PureMacTests.xctest`：`com.apple.product-type.bundle.unit-test`
- shared scheme 同时构建 App 与 tests；
- `Info.plist`、entitlements、bundle identifier、test host、resources 和 archive 由 Xcode 管理；
- 测试使用 `@testable import PureMac`；
- 构建文档使用 `xcodebuild -project ... -scheme ... -derivedDataPath ...`。

可借鉴：

- 正式 macOS App host 使用 Xcode App target；
- App tests 依赖真实 App target，而不是测试终端 executable；
- checked-in shared scheme 提供稳定的 `xcodebuild` 入口；
- explicit `Info.plist` 和 entitlements 便于审计 TCC/FDA、bundle identity 和发布配置；
- 可通过 `xcodebuild` 指定 DerivedData，便于 CI 和清理。

限制：

- PureMac 通过 xcodegen 的 `project.yml` 维护工程，并依赖 Sparkle；Stornaut Epic 0 不需要这些依赖；
- PureMac Debug 配置禁用了 signing，因此不能直接作为 App-context TCC identity 模板；
- PureMac 包含 MenuBar 监控、自动更新与更宽的产品能力，Stornaut v1 明确不采用；
- 其 macOS 13、Intel、Sparkle 和现有 entitlements 不是 Stornaut 需求。

### 4.3 Apple/SwiftPM 证据

- SwiftPM 的 `executableTarget` 定义 executable product，不定义完整的 macOS App bundle/signing/TCC host 契约。
- Apple Xcode 的 App template 原生提供 macOS application target、SwiftUI lifecycle、unit/UI test targets、asset catalog、bundle settings 和 App Sandbox settings。
- Apple 文档支持在 Xcode App project 中添加仓库内 local Swift package，并把 package products 链接到指定 target。
- `xcodebuild` 支持 project/scheme、DerivedData、build、test、archive、export 和 package resolution。
- Apple code-signing 文档使用 `codesign -d -vvv --entitlements` 检查 identifier、authority、team identifier 和 entitlements；仅看到一个 `.app` 目录不足以证明身份。

## 5. 本机签名实验

在 `/tmp` 创建两个 bundle identifier 相同、binary 内容不同的 disposable `.app`，不读取用户数据。

### 默认 ad-hoc 签名

命令形态：

```text
codesign --force --sign - --identifier com.eriklee.stornaut.probe <app>
```

结果：

- 两个 bundle 均通过 `codesign --verify --deep --strict`；
- `Signature=adhoc`，`TeamIdentifier=not set`；
- designated requirement 默认为各自的 `cdhash`；
- binary 变化后 `cdhash` 和 designated requirement 均变化；
- `spctl` 拒绝该产物，符合未正式签名/公证的预期。

结论：默认 ad-hoc 签名不能作为跨构建稳定的 TCC identity 证据。

### 显式 designated requirement

命令形态：

```text
codesign --force --sign - \
  --identifier com.eriklee.stornaut.probe \
  --requirements '=designated => identifier "com.eriklee.stornaut.probe"' \
  <app>
```

结果：

- 两个不同 binary 的 designated requirement 都是
  `designated => identifier "com.eriklee.stornaut.probe"`；
- code hash 仍不同；
- signature 仍是 ad-hoc、没有 TeamIdentifier，不能通过 Gatekeeper，也不能代表 Developer ID。

结论：显式 requirement 可以作为本机 Spike 的可重复 identity mechanism，但只用于测量 TCC/FDA 与子进程继承。它不证明生产签名、发布安全或 notarization。

## 6. App host 方案比较

| 方案 | 真实 `.app` | App/Test target | 稳定本地 identity | 依赖 | 后续分发路径 | 结论 |
| --- | --- | --- | --- | --- | --- | --- |
| 纯 SwiftPM executable + `swift run` | 否 | 否 | 否 | 无 | 需要重做 | 拒绝 |
| SwiftPM executable + 手工 bundle | 是 | 需自建 | 可通过显式 ad-hoc DR 做 Spike | 脚本 | 需补齐 Xcode/签名体系 | 仅作参考 |
| xcodegen 生成 Xcode project | 是 | 是 | 可配置 | 新增 xcodegen | 可行 | Epic 0 不引入 |
| checked-in Xcode App/Test project + local package | 是 | 是 | 可配置并审计 | 仅 Xcode/SwiftPM | 直接通向 archive/Developer ID | 采用 |

## 7. Stornaut 方案

### 7.1 Physical layout

```text
Stornaut.xcodeproj/
StornautApp/
├── AppShell/
├── Resources/
├── Settings/
├── StornautApp.swift
├── Info.plist
└── StornautApp.entitlements
StornautAppTests/
Package.swift
Sources/
├── StornautCore/
└── StornautCodex/
Tests/
├── StornautCoreTests/
└── StornautCodexTests/
```

### 7.2 Xcode targets

- `StornautApp`
  - product type：macOS application
  - bundle identifier：`com.eriklee.stornaut`
  - shared scheme：`Stornaut`
  - source：仅 App shell/UI composition
  - package products：`StornautCore`、`StornautCodex`
- `StornautAppTests`
  - unit-test bundle
  - 依赖 `StornautApp`
  - 先验证 `AppDestination`、scene/command contract 和 localization resources

### 7.3 Signing modes

- `Debug-Local`
  - ad-hoc signing；
  - 显式 designated requirement：匹配最终确认的 bundle identifier；
  - 仅用于本机 Spike 与 LaunchServices/TCC identity 测量；
  - 每次测量记录 `codesign -d -vvv -r- --entitlements`。
- `Release`
  - Epic 0 不伪造 Developer ID；
  - 没有有效 identity 时不得声称 distribution/notarization 已验证；
  - Epic 9 再配置 Developer ID、hardened runtime、archive/export/notarization。

若 Xcode target 无法直接表达自定义 ad-hoc designated requirement，允许在 `xcodebuild` 产物上运行一个 repository-owned、可审计的 post-build signing script。该脚本只能处理受验证 DerivedData 下的 `Stornaut.app`，不得修改其他 App。

### 7.4 Sandbox

- v1 产品已批准为非 App Store sandbox。
- App target 不启用 App Sandbox。
- 这不自动授予 FDA；FDA/TCC 仍由系统按 App identity 和用户授权决定。
- Codex 子进程是否继承 App 权限必须由后续 Spike 测量，不能从 entitlements 猜测。

### 7.5 Verification commands

Task 1 完成库骨架后：

```text
swift package clean
swift build
swift test
scripts/check-doc-links
```

Task 2 加入 App host 后，`scripts/verify` 追加：

```text
xcodebuild -project Stornaut.xcodeproj \
  -scheme Stornaut \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .derivedData \
  build test
```

随后对产物运行：

```text
plutil -p <Stornaut.app>/Contents/Info.plist
codesign --verify --deep --strict --verbose=2 <Stornaut.app>
codesign -d -vvv -r- --entitlements - <Stornaut.app>
open <Stornaut.app>
```

具体 `codesign` 参数需在实现时用当前 Xcode/codesign `--help` 再确认，不硬编码本文中的实验语法。

## 8. Tests / Fixtures / Benchmark

Epic 0 foundation 应至少覆盖：

- SwiftPM Core/Codex smoke tests；
- App target build；
- App unit test target；
- `AppDestination` 精确四项且不包含 Settings/MenuBar；
- English/`zh-Hans` localization 文件存在且 key 对齐；
- App bundle identifier、package type、minimum OS、executable name；
- App Sandbox 为关闭状态；
- code signature 可验证，designated requirement 与预期一致；
- shared scheme 可从 clean checkout 通过 `xcodebuild` 构建/测试；
- `scripts/verify` 同时覆盖 SwiftPM 与 App host；
- CI 只允许手动触发，且不声称验证 FDA/TCC。

## 9. 许可证与复用边界

- ClearDisk 与 PureMac 均为 MIT，可合法参考；本次不复制代码。
- Stornaut 只复用公开工程事实、测试思想和行为模式。
- 不复制 ClearDisk build script、PureMac project.yml/pbxproj 或产品实现。
- Stornaut 的 Xcode project、scripts、Info.plist、entitlements 和 tests 独立创建。
- Epic 0 不新增第三方 package；`ThirdPartyNotices` 暂无新条目。

## 10. 相对上游的改进

- 相比 ClearDisk：保留 SwiftPM 可测试库，同时使用标准 App/Test host；不依赖手工 bundle 作为唯一构建路径。
- 相比 PureMac：不引入 xcodegen/Sparkle，不禁用所有 Debug signing 后再声称 TCC 已测；明确区分本地 ad-hoc identity 与 Developer ID。
- 同时验证 SwiftPM、App target、签名、文档链接和 Git 状态。
- 把 FDA/TCC 和子进程权限视为后续实验证据，不把 README、entitlements 或可启动 `.app` 当作结论。

## 11. 已知限制与下一 Gate

- 本机当前没有有效 Apple Development/Developer ID identity。
- 显式 ad-hoc designated requirement 是否被当前 macOS TCC 数据库稳定采用，需要 Task 5 App-context canary 实验确认。
- Xcode project 的具体 object format、local package references 和 signing build settings 必须由 Task 2 生成后通过 `xcodebuild -showBuildSettings` 与产物检查验证。
- bundle identifier 已确认为 `com.eriklee.stornaut`；Task 5 开始 TCC/FDA 实验后不得无 ADR 地更改。
- Developer ID、hardened runtime、notarization 和 release export 保留到 Epic 9。
- 下一 Gate：创建 Task 1 SwiftPM/verify 骨架；App host 在 Task 2 实现并写 ADR 0001。
