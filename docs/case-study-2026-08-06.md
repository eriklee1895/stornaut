# 案例：一次约 70GB 的证据驱动磁盘清理（2026-08-06）· 完整操作实录

> 本文是 Stornaut 的"出生证明"：用 Claude Code（CLI agent）对一块告急的 460GB 开发机磁盘做了三轮"扫描 → 分级 → 确认 → 清理"的人机协作，安全释放 ~70GB。本文按时间顺序记录**每一步的命令、发现、决策与验证结果**。

> **史料状态说明（2026-08-07）**：本文记录的是正式命名和产品设计批准之前发生的真实操作；`Stornaut` 是事后采用的项目名称。“安全释放”和“零数据丢失”只描述本次最终观察结果，不构成产品安全保证；`safe/caution/no` 是当时报告用语，当前产品采用 `Ready to Reclaim`、`Review Recommended`、`Protected`、`Unknown`。后续产品约束以 PRD 2.3 和批准规格为准。

## TL;DR

| 指标 | 之前 | 之后 |
|---|---|---|
| 磁盘已用 | 400 GB（98%）⚠️ | **332 GB（82%）** |
| 可用空间 | **10 GB** | **77 GB** |
| 释放总量 | — | **~68-70 GB，本次操作未观察到数据丢失** |
| 另发现"重启即可回收" | — | ~31 GB（swap 28.5G + 浏览器签名克隆 2.9G） |
| 扫描轮次 | — | 3 轮（10 + 8 + 8 个并行子代理）+ 系统卷根级盘点 |

机器：MacBook（Apple Silicon），36GB 内存，macOS 26.5.1，重度开发者使用（多 IDE、多语言生态、大量开源克隆、AI 工具链若干）。已开机 5 天 18 小时（上次重启 ≈ 7 月 31 日）。

---

## 0. 背景：为什么通用工具失效

磁盘告急时，用户此前尝试过 CleanMyMac、BuhoCleaner，也试过 Codex Desktop app 扫描清理，效果都不理想。用户的两个观察（后来成为产品洞察）：

1. **桌面 app 不如 CLI agent**——"我猜是 CLI 端 bash 权限更大"：du/find/git/brew/go/npm 等工具链随手可用，判断一个目录"是什么"时可以现场验证。
2. **通用工具没有开发者语义**——它们不知道 `node_modules` 可重建、`.venv` 里的 torch 也是可重建的、`pnpm/store` 是内容寻址缓存、`*ShipIt*` 是 Electron 更新残留、3.8GB 的 `.git` pack 属于"试完即弃的克隆"还是"工作链依赖"。

**方法论**：每个清理项给出五元组 `<大小, 是什么, safe/caution/no, 为什么, 怎么清>`；**删除权永远在用户手里**；每轮清理后复扫验证。

---

## 1. Phase 0：初始侦察（确认灾情）

```bash
df -h / /System/Volumes/Data
diskutil apfs list
```

结果：

- Data 卷（`/System/Volumes/Data`）：460Gi 总，**400Gi 已用，仅剩 10Gi（98%）**
- APFS 容器 494.4 GB，已分配 483.1 GB（97.7%）
- System 卷 12.6G（密封）、FileVault 已解锁

**踩坑 #1（macOS 语法）**：第一次跑 `du -sh -d1 ~` 直接报 usage 错误——**macOS 的 du 不支持 `-s` 和 `-d` 混用**（BSD du 与 GNU du 差异）。修正为：

```bash
du -h -d1 ~ 2>/dev/null | sort -rh | head -25
```

HOME 顶层分布（**总计 271G**）：

| 目录 | 大小 | 目录 | 大小 |
|---|---|---|---|
| Library | 90 G | .vscode | 5.5 G |
| code | 86 G | .npm | 5.4 G |
| go | 12 G | .trae-cn | 4.8 G |
| .cache | 11 G | Pictures | 3.8 G |
| .local | 8.3 G | .hermes / .codex | 各 3.4 G |
| .bun | 5.9 G | Applications(用户级) | 3.2 G |
| data | 5.5 G | aiotvideo | 3.0 G |

> 补充扫描：`~/code` 内部 top——my_project 20G、aigc 16G、agent 13G、llm 8.9G、byteedge-iec 7.2G、aiot 6.3G。

## 2. Round 1：全量深度扫描（10 路并行子代理）

派发 10 个并行扫描代理（workflow `wf_c38405f9-fdd`，耗时 ~22 分钟，154 次工具调用），每个代理负责一个区域、返回结构化五元组清单（只收录 ≥200MB 条目）：

| 代理 | 负责区域 | 核心发现 |
|---|---|---|
| ① | ~/Library/Caches | 7.1G：go-build 2.6G、JetBrains 1.1G、Chrome 986M、**VSCode ShipIt 913M**、ms-playwright 520M、AIME ShipIt 347M |
| ② | Library 开发工具链 | App Support 共 69G：**Chrome 20G、Claude vm_bundles 9.3G、Claude-3p 6.9G、飞书 8G、Trae×2 7.9G**；Xcode 开发目录全空（无模拟器/DerivedData） |
| ③ | Containers 等 | 微信 3.3G（大量 7 月接收的视频）、geod 1.5G、Docker 1.5G；**Mail/Messages 被 TCC 拦截无法测量** |
| ④ | 用户目录 | 照片图库 3.8G（不可动）、Documents/Codex 1.5G |
| ⑤ | 包管理缓存 | **共 ~68G**：go/pkg 11G、uv 7.9G、pnpm 7.4G、bun 5.5G、npm 5.4G；`brew cleanup -n` 预估可清 3.2G；**node_modules 1204 个共 23.7G** |
| ⑥ | 虚拟化 | Docker.raw 1.4G（稀疏文件，表观 60G）；OrbStack 镜像表观 460G 实际仅 65M |
| ⑦ | 大文件 >1G | Claude rootfs.img ×2（7G+5.1G）+ .zst ×2（2G+1.2G）、Chrome 端侧模型 weights.bin 4G、remotion .git pack 3.8G |
| ⑧ | /Applications + Homebrew | ~98G：Cellar 19G（**texlive 4.7G**、qt 1.6G、llvm 双版本 3G）、**JetBrains 全家桶 16.7G**、Xcode 4G、Docker 1.8G |
| ⑨ | 系统杂项 | var/folders 4G（**Chrome 签名克隆 2G + 豆包 911M**）、sleepimage 2G、诊断日志 1.2G；废纸篓为空、无 iOS 备份 |
| ⑩ | git 仓库 | 632 个仓库，`.git` 共 29G；remotion 3.9G、hermes-agent 1.6G、open-design/openclaw 各 1.2G、litellm 1G |

### Round 1 报告：四梯队

| 梯队 | 内容 | 估值 |
|---|---|---|
| 🟢 纯缓存放心删 | go/uv/pnpm/bun/npm 缓存、ShipIt 残留、brew cleanup、go-build、旧版 Claude 等 | ~51 G |
| 🟡 可重建产物 | node_modules 23.7G、.git 大 pack（gc/浅克隆） | ~30 G |
| 🟠 大户会重下 | Claude vm_bundles 15.4G、Chrome 端侧模型 4G | ~19 G |
| 🔴 需决策 | JetBrains 16.7G、Xcode 4G、texlive 4.7G、飞书/Trae/微信缓存 | ~30 G+ |

**用户决策**：清第一梯队 + node_modules；`.git` 先不动。

## 3. Round 1 清理执行

执行前基线检查：`df` 显示 386Gi/23Gi（系统波动，可用从 10G 自己涨到 23G——APFS 动态回收 purgeable 空间）；确认当前 Claude 版本 2.1.223（旧版可删）；`/Library/Updates` 为 root:wheel 无权删（跳过）。

**5 路并行执行**：

```bash
# 批1：node_modules（限定项目目录，避开 ~/.vscode 等工具目录）
find ~/code ~/Documents ~/aiotvideo ~/data ~/Downloads -name node_modules -type d -prune -exec rm -rf {} +   # 100 个

# 批2：Go 缓存
go clean -modcache && go clean -cache                                                                        # ~13.6G

# 批3：Homebrew
brew cleanup                                                                  # 实测释放 3.2G

# 批4：各语言/工具缓存
uv cache clean                    # "Removed 221009 files (7.3GiB)"
npm cache clean --force           # ~5.4G
rm -rf ~/Library/pnpm/store       # 首次报 Directory not empty，重试成功，7.4G→76M
rm -rf ~/.bun/install/cache ~/.cache/codex-runtimes ~/.cache/puppeteer \
       ~/.gradle/caches ~/.m2/repository ~/.pub-cache

# 批5：更新残留与旧版本
rm -rf ~/Library/Caches/com.microsoft.VSCode.ShipIt \
       ~/Library/Caches/com.bytedance.aime.electron.ShipIt \
       ~/Library/Caches/aime-updater
rm -rf ~/Library/Caches/Google    # ⚠️ Chrome 运行中，部分锁定删除失败
rm -rf ~/Library/Application\ Support/Caches/*
rm -rf "$TMPDIR"com.anthropic.claudefordesktop.ShipIt.*
rm -f ~/.local/share/claude/versions/2.1.22{0,1,2}   # 保留当前 2.1.223
```

**结果**：344Gi 已用 / **66Gi 可用**。

### ⚠️ 事故：node_modules 误清活跃项目（重要教训）

批1 执行完成后，用户发来纠正："**node_modules 最好只清理 >2 个月未更新的**"——为时已晚，删除已完成。

**善后**：用 `find ... -name package.json -mtime -60` 找出受影响项目——**38 个近 2 个月活跃项目**的依赖被清（包括 my_project/rag-from-zero-to-hero、byteedge-iec/ai-video-gen-ui、agent/hermes-agent、Documents/Codex 下两个项目等）。向用户如实说明，提供三个补救选项（只装工作项目 / 全装 / 不装）。

**用户决策**：不重装，用到时自己 `npm i`。

**教训沉淀（→ 产品规则）**：
1. 陈旧度过滤必须是**默认行为**
2. 批量删除前**清单先存档**
3. 执行前**列清单确认**
4. 清理动作会**污染 mtime**（删子目录会更新父目录时间戳）——后续轮次判定时必须考虑

## 4. Round 2：复扫（发现"第二个 node_modules"）

基线：347G/62G；HOME 271G → **214G**（Library 90→75G、code 86→74G、go 12→4.8G、.cache 11→1.8G）。

8 路并行复扫（`wf_c8ce1577-fda`，~15 分钟，194 次工具调用）后的**新发现**：

**① 构建产物专项（第一轮完全没扫的盲区）**：

| 类别 | 数量 | 总量 |
|---|---|---|
| `.venv` | 41 个 | **9.97 G**（rag 1.8G、videoagent 1.2G、videoseek 915M…多个含 torch/cv2） |
| `.next` | 12 个 | 3.93 G |
| dist/build/target/out | ~80 个 | ~1.4 G |

**② 漏网 node_modules**：`videoagent-server/docs-site` 471M（无 .git 的文档站）、`~/.hermes/hermes-office` 846M（在第一轮扫描范围外的 dotfile 目录里）。

**③ dotfile 深扫（30.8G）**：mise 管理 **8 个 Go 版本**（2.7G，1.17~1.25 并存）、cc-switch 迁移备份 1.7G、VSCode/Trae 里旧版扩展二进制（每份 130-490M）、codex 会话/归档 1.3G、`~/.codex/.tmp` 377M。

**④ App 数据细分**：Chrome Profile 1 里 Service Worker 8.2G + WebStorage 6.3G；飞书 `update/` 旧安装包 1.8G；语雀 latest.dmg 188M + 旧 sqlite 备份 498M；Trae 系缓存/日志。

**⑤ Spotlight 取证**：JetBrains 全家桶、Xcode、VideoFusion 等的 `kMDItemLastUsedDate` 均为 null（近期无启动记录）。

### Round 2 报告与决策

给出 A（安全直清 ~22G）/ B（构建产物 ~15G）/ C（应用卸载 ~27G）/ D（工作媒体 ~14G）/ E（应用内清理 ~10G）五个方向。

**用户逐项点名**：语雀 latest.dmg + 旧 sqlite 备份、飞书 update/、旧版扩展——"list 一下，然后清理"；B 类构建产物"list 给我看，尤其 .venv，重点是长时间未更新的"。

## 5. Round 2 清理执行（先验证、再动手）

**① 语雀**（列目录验证后删）：`latest.dmg` 188M（2026-01 的安装包）+ `yq-meta-encrypted.sqlite.1736742911499` + `yq-public-35714760-encrypted.sqlite.1736747440873` 497M（2025-01 旧备份；**当前活跃库 595M 保留不动**）→ 释放 685M

**② 飞书 update/**（列目录验证后删）：发现 `update.noindex/Lark.app` 1.3G + `update_downloading` 502M，**时间戳是当天 10:41**——是一个已下载完成、待安装的新版飞书。删除后下次更新会重新下载，向用户说明后执行 → 释放 1.8G

**③ 旧版扩展 ×8**（逐一核对版本号，确认新版存在才删旧版）：

| 位置 | 删除 | 保留 |
|---|---|---|
| ~/.vscode | claude-code-2.1.222 (268M)、cpptools-1.33.5 (256M)、vscode-lldb-1.10.0/1.11.0/1.11.3 (393M) | 2.1.223、1.33.6、lldb-1.12.2 |
| ~/.trae-cn | claude-code-2.1.219 (254M)、cpptools-1.33.4 (256M)、chatgpt-26.721 (464M) | 2.1.222、1.33.5、26.727 |

⚠️ 验证时拦截了一个误删：**VSCode 里的 ChatGPT 扩展只有一个版本**（26.5730），不能删——只删了 trae-cn 里有新版对照的旧版。→ 释放 ~1.9G

**此刻**：339G/71G。

**④ 陈旧构建产物**（按用户规则：>2 个月未动）：

盘点命令（每个产物记录 `<大小|产物mtime|项目根mtime>`）：

```bash
find ~/code ~/Documents ~/aiotvideo ~/data -name ".venv" -type d -prune | while read d; do
  sz=$(du -sm "$d" | cut -f1); mt=$(stat -f "%Sm" -t "%Y-%m-%d" "$d")
  pmt=$(stat -f "%Sm" -t "%Y-%m-%d" "$(dirname "$d")"); echo "${sz}|${mt}|${pmt}|${d}"
done | sort -t'|' -k1 -rn
```

判定规则：`lastActivity = max(产物mtime, 项目根mtime)`，阈值 60 天（2026-06-07）。结果：

- **删除（25 个陈旧 .venv，~4.5G）**：videoseek 916M、chat_with_docs 743M（2025-05!）、NLWeb 516M、DeepTutor 421M、aio_sandbox_test 320M、manim-解题视频 313M、rag_playground 259M、skills-test 249M、agent-playground 169M、langextract 99M、uv-demo 88M、moviepy 80M、auto_pull_streams 74M、quick_learn_python 66M、trae-agent 57M、smolagents 50M、celery_tests 41M、mcp_server 23M、llm_study 18M（2024!）、mcp_client 13M + 5 个迷你 venv
- **删除（8 个陈旧构建产物，~0.65G）**：tiktoken/target 207M（2024-11）、hello_flutter/build 196M（2024-04）、ironclaw telegram/target 71M、video-gen-agent/.next 66M、mem0-demo/.next 49M、bisheng vditor/dist ×2、litellm proxy/out
- **保留（活跃，~10G）**：rag-from-zero-to-hero 1.8G（当天还在动）、videoagent-server 1.2G、knowledgebase 822M、hermes-agent-runtime 345M、writing-agent-harness 354M、OpenMontage 249M 等

**按新规矩执行**：清单先存档 `~/cleanup-stale-artifacts-2026-08-06.txt`（33 条），用户 "do it!" 后批量删除，逐条 ✓ 验证零残留。

**Round 2 结束**：**332G 已用 / 77G 可用（82%）**。

## 6. Round 3：复扫 + 用户质疑引出系统层盲区

基线复扫（`wf_a2afa969-d84`，8 代理，~10 分钟）确认趋势：HOME **204G**（271→214→204）。新发现：

- 上轮标记但未执行的漏网 node_modules 仍在（hermes-office 846M + docs-site 471M）
- claude-code **2.1.169** 残留 156M（藏在一个随机 UUID 目录里）、`.npm-global/.debug` 调试帧 215M、codex 旧日志库 210M
- **Open Design 更新 DMG ×2**（247M+238M）、DeerFlow 自解压 tar 394M
- 关键标注：`aigc/remotion`（4.5G）和 `aigc/hyperframes`（1.4G）虽数周未提交，但**被 OpenMontage 工作链实际依赖**——不能当陈旧克隆删

**用户质疑**："你好像只扫了我的 HOME 目录，其他系统目录你不扫吗？"——一针见血。HOME 204G + 已知系统区 ~100G ≈ 304G，对不上 332G 的已用量，有 **~30G "未解释空间"**。

### 系统卷根级盘点

```bash
du -x -h -d1 /System/Volumes/Data 2>/dev/null | sort -rh   # -x 不跨卷
df -h | grep -vE "devfs|map "
ls -lah /System/Volumes/VM/
sysctl vm.swapusage
```

**Data 卷完整构成（333G）**：

| 目录 | 大小 | 说明 |
|---|---|---|
| Users | 205 G | eriklee 204G + bytedance 18M + root 92M + Shared 7.7M |
| Applications | 65 G | （已扫） |
| opt | 20 G | Homebrew |
| private | 8.2 G | （已扫） |
| Library | 5.6 G | CLT 1.9G、Updates 899M、Frameworks |
| **System** | **5.3 G** | 🆕 全部是 AssetsV2（Siri 语音/系统 ML 模型）——勿动 |
| **macOS Install Data** | **2.6 G** | 🆕 孤儿更新包（详见下节） |
| usr | 1.6 G | corplink 813M 等 |
| root 隐藏目录 | **~19 G** | 🆕 .DocumentRevisions-V100/.Spotlight-V100/.fseventsd，无 sudo 测不了 |

**其他卷**：System 12G（密封 macOS）、**VM 30G**、Preboot 10G；无 Time Machine 本地快照。

### 悬案：VM 卷侦探记

矛盾：`du /private/var/vm` 只有 sleepimage 2G，但 `df` 显示 VM 卷用了 30G（仅 30 个 inode）。直接 `ls /System/Volumes/VM/` 真相大白——**31 个 swapfile × 1G**（日期从 7-31 到当天 14:23，仍在增长）：

```
vm.swapusage: total = 30720M  used = 30071M  free = 648M   ← 98% 已用！
（一小时后再看：total 33792M used 32504M —— 还在涨）
```

**用户追问与确认**："VM 卷就是 swap 对吧？36G 内存吃紧所以 macOS 用磁盘做 swap？"——对。补充机制：macOS 先压缩内存再换出；**swapfile 只增不减**（系统懒得主动回收），越积越多直到重启。

**沉淀出的预算模型（用户明确要求纳入清理预算）**：

```
重启后瞬时可得 ≈ 当前可用 + swap(28-33G) + code_sign_clone(2.9G)
稳态可用     ≈ 瞬时可得 − swap 回涨预期（该机负载每天 ~6G）
```

即：swap 释放的空间是"借来的"，做长期预算时只能当 ±20G 浮动项；真正踏实的只有永久删除换来的空间。

### macOS Install Data 安全验证

用户问能否清理。验证链条：

1. `sw_vers` → 当前 **macOS 26.5.1**
2. 遗留包 `UpdateBundle/Info.plist` 构建于 **2023-12-16**（Sonoma 14.x 时代），落后 2 年半以上
3. 目录自 2024-01-31 起未被触碰；无活跃更新进程在使用它
4. 结论：孤儿残留，安全。需 sudo，给用户 `!` 前缀命令自跑（含 `chflags -R nouchg` 解锁 "Locked Files" 的兜底）

**Round 3 清理**：Open Design 更新 DMG ×2（0.11.0 + 0.9.0 安装包）→ 释放 485M（该目录 541M→56M）。

---

## 7. 数字总账

### 分轮释放明细

| 轮次 | 清理项 | 释放 |
|---|---|---|
| R1 | node_modules ×100（项目目录内） | ~20 G |
| R1 | Go module + build 缓存 | 13.6 G |
| R1 | uv 7.3G / pnpm 7.3G / bun 5.5G / npm 5.4G | 25.5 G |
| R1 | brew cleanup | 3.2 G |
| R1 | codex-runtimes 1.5G + puppeteer 1.4G + gradle/m2/pub-cache ~0.6G | 3.5 G |
| R1 | ShipIt 残留 ×4（VSCode/AIME×2/Claude Desktop tmp） | ~2.3 G |
| R1 | 应用通用缓存 + 旧版 Claude 二进制 ×3 | ~2 G |
| R2 | 语雀 dmg+旧备份 / 飞书 update / 旧版扩展 ×8 | 4.4 G |
| R2 | 陈旧 .venv ×25 + 陈旧构建产物 ×8 | 5.2 G |
| R3 | Open Design 更新 DMG ×2 | 0.5 G |
| | **合计** | **~68-70 G** |

### 空间变化时间线

```
开始          400G 已用 / 10G 可用（98%）⚠️
R1 清理完成   344G / 66G
R2 清理完成   332G / 77G
R3 结束       332G / 73-77G（APFS 后台波动 ±4G 属正常）
```

### 遗留事项清单（未执行，供后续）

| 事项 | 大小 | 阻塞原因 |
|---|---|---|
| Chrome 网页缓存 | ~1 G | Chrome 运行中文件锁定，需退出后 `rm -rf ~/Library/Caches/Google` |
| /Library/Updates 旧 CLTools 包 | 899 M | root 权限，需 `sudo rm -rf /Library/Updates/140-17812` |
| macOS Install Data 孤儿更新包 | 2.6 G | 需 sudo（命令已交付用户） |
| 漏网 node_modules ×2 | 1.3 G | hermes-office 846M + docs-site 471M，R2 标记未执行 |
| 重启回收（swap + 签名克隆） | ~31 G | 待用户择机重启 |
| Claude vm_bundles | 15.4 G | 需先退出 Claude Desktop，删后自动重下 |
| JetBrains/Xcode/texlive 等 | ~27 G | 待用户决策 |
| Mail/Messages | 未知 | TCC 拦截，需 FDA 授权后复扫 |
| root 隐藏目录（~19G） | 未知 | 需 `sudo du` 测量 |

---

## 8. 为什么本次此前尝试的 GUI 工具没有解决问题

| 能力 | 本次此前尝试的通用 GUI 工具 | 本案例（agent 驱动） |
|---|---|---|
| 识别 node_modules/.venv 为可重建产物 | ❌ | ✅ 还知道哪个含 torch、重建命令是什么 |
| 项目陈旧度判断 | ❌ | ✅ git/mtime/Spotlight 多信号，60 天阈值 |
| App 特有怪癖知识（ShipIt/vm_bundles/签名克隆/更新 DMG/旧版扩展并存） | 少量内置 | ✅ 扫描中现场发现并逐个验证 |
| 区分"试完即弃的克隆"与"工作链依赖" | ❌ | ✅ remotion 不活跃但被 OpenMontage 依赖 → 保留 |
| 版本核对防误删 | ❌ | ✅ 拦截了"VSCode ChatGPT 扩展仅单版本"的误删 |
| 系统层盘点（swap/孤儿更新包/卷级构成/隐藏空间） | ❌ | ✅ 连"可用空间浮动预算模型"都给了 |
| 安全流程（分级/确认/清单存档/可恢复） | 部分 | ✅ 每步用户握有决定权 |

## 9. 这个案例教会产品的 7 件事

1. **开发者磁盘的大头常在开发生态产物**——依赖目录、虚拟环境、包缓存和构建产物需要专门 taxonomy；后续调研确认 Mole、CodeCleaner、CleanMyMac CLI 等已覆盖其中一部分已知类别
2. **陈旧度是核心判断力**，且信号会被污染（清理动作改 mtime）——必须多信号融合
3. **删除安全模型**：分级 → 报告 → 确认 → 清单存档 → 可恢复（废纸篓）
4. **漏网是常态**——R1 漏了 .venv 全域和两处 node_modules；扫描范围设计要多轮迭代
5. **系统层不可忽略**——swap、孤儿更新包、卷级构成，决定"可用空间"的真实口径
6. **本次 CLI agent 工作流优于当时尝试的桌面工具**（用户原话观察）——关键变量是工具链和动态调查能力，不代表产品必须做成 CLI
7. **每条判断都要给人话解释**——"这是 uv 的包缓存，删了下次 uv sync 自动重建"；解释力就是信任

→ 这些教训直接转化为 Stornaut 的产品决策，见 [PRD.md](PRD.md)。

> **后续批准状态（2026-08-07）**：以上是单机实测与案例假设，不是对整个市场的持续结论。批准的 v1 是按需启动的原生 Swift 单窗口 App，由用户已安装的 Codex 经 Probe Broker 使用受控只读能力；不提供 MenuBarExtra、后台监控，也不把执行权交给 Agent。

---

## 附录 A：历史操作命令（仅供取证复盘）

> **安全与产品状态说明**：以下命令仅保留为 2026-08-06 操作实录，不是当前机器建议、Stornaut Action Registry 或 Coding Agent 实施说明。再次使用前必须重新扫描并验证路径、版本、活动状态和恢复方式。批准的 v1 不允许 Agent 或 Adapter 执行任意 Shell 清理；普通文件默认移入 Trash，清理命令只能作为审核过的 Registered Action，永久动作单独确认，Trash 失败绝不回退为永久删除。尤其不要直接复用下方 `sudo rm -rf` 示例。

```bash
# 顶层分布（macOS du 不支持 -s -d 混用！）
du -h -d1 ~ 2>/dev/null | sort -rh | head -25

# 整卷根级盘点（-x 不跨卷）
du -x -h -d1 /System/Volumes/Data 2>/dev/null | sort -rh | head -20

# 包管理缓存一键清
go clean -modcache && go clean -cache
uv cache clean && npm cache clean --force && brew cleanup

# node_modules 查找（-prune 防嵌套）与陈旧度盘点
find <dirs> -name node_modules -type d -prune -print
find <dirs> -name ".venv" -type d -prune | while read d; do
  sz=$(du -sm "$d" | cut -f1); mt=$(stat -f "%Sm" -t "%Y-%m-%d" "$d")
  pmt=$(stat -f "%Sm" -t "%Y-%m-%d" "$(dirname "$d")")
  echo "${sz}|${mt}|${pmt}|${d}"
done | sort -t'|' -k1 -rn

# 大文件
find ~ -type f -size +1G -not -path "*/node_modules/*" 2>/dev/null

# swap 与内存
sysctl vm.swapusage; ls -lah /System/Volumes/VM/; uptime

# 应用最近使用时间（Spotlight 取证）
mdls -name kMDItemLastUsedDate /Applications/Some.app

# 需 sudo 的系统项（用户自跑）
sudo rm -rf "/System/Volumes/Data/macOS Install Data"   # 孤儿更新包
sudo rm -rf /Library/Updates/140-17812                   # 旧 CLTools 包
sudo du -sh /System/Volumes/Data/.DocumentRevisions-V100 \
            /System/Volumes/Data/.Spotlight-V100 \
            /System/Volumes/Data/.fseventsd              # 测量隐藏空间
```

## 附录 B：扫描代理编排统计

| 轮次 | 代理数 | 工具调用 | 耗时 | 产出 |
|---|---|---|---|---|
| R1 | 10 | 154 | ~22 min | 全磁盘首次画像 + 四梯队报告 |
| R2 | 8 | 194 | ~15 min | 构建产物盲区 + dotfile 深挖 |
| R3 | 8 | 134 | ~10 min | 成效核对 + 漏网与新长出项 |

每个代理返回结构化五元组 JSON（路径/大小/是什么/可否清理/理由/方法），只收录 ≥200MB 条目，按大小降序。
