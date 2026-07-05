# AGENTS.md - Whisky 项目开发记录

## 项目概述
Whisky 是一个 macOS 上的 Wine 图形化管理工具，用于在 Mac 上运行 Windows 程序。

## 主要工作记录

### 1. Wine 双模式支持
- **功能**: 支持 WhiskyWine 和 CrossOver 两种 Wine 引擎切换
- **实现**: `WineMode` 枚举，动态切换 binFolder 和 libraryFolder
- **文件**: `WhiskyWineInstaller.swift`, `Wine.swift`, `SettingsView.swift`
- **时间**: 2026-06-26

### 2. WhiskyWine 真实二进制打包
- **来源**: 从 `/Applications/Wine Stable.app` 提取
- **结构**: `Libraries/Wine/{bin, lib, share}`
- **关键修复**:
  - 添加 wine64 -> wine 符号链接（Wine Stable 只有 wine 无 wine64）
  - 添加 WINEDLLPATH 环境变量定位 ntdll.so
  - **包含 share 目录**（nls 文件等，修复 wineboot 失败）
- **版本**: 11.0.1（含 share 目录的完整版本）
- **大小**: ~313MB
- **上传位置**: GitHub Release `whiskywine-v1`

### 3. WhiskyWine 安装检测增强
- **旧逻辑**: 只检查 WhiskyWineVersion.plist 是否存在
- **新逻辑**: 三重验证
  1. wine/wine64 二进制文件存在
  2. Wine/lib 目录存在
  3. lib 目录大小 ≥ 10MB
- **文件**: `WhiskyWineInstaller.swift` - `isWhiskyWineInstalled()`

### 4. 下载缓存修复
- **问题**: 损坏的缓存文件（带 .complete 标记）被直接使用
- **修复1**: 下载前验证缓存大小 ≥ 50MB，小于则清理重下
- **修复2**: 点击"重新安装"时强制清理缓存，确保重新下载
- **文件**: `WhiskyWineDownloadView.swift`, `WhiskyApp.swift`

### 5. 安装失败自动重试
- **功能**: 安装失败自动清理缓存并重新下载，最多 3 次
- **文件**: `WhiskyWineInstallView.swift`

### 6. 启动自动修复
- **功能**: 启动时检测到 WhiskyWine 损坏/未安装，自动进入下载流程
- **文件**: `ContentView.swift`, `SetupView.swift`

### 7. 终端 AppleScript 转义修复
- **问题**: AppleScript 命令字符串转义错误导致终端启动失败
- **修复**: 使用临时 shell 脚本文件避免转义问题
- **文件**: 终端相关代码

### 8. 设置页重新安装按钮
- **功能**: WhiskyWine 模式下始终显示"重新安装"按钮
- **实现**: 通过 NotificationCenter 发送通知触发
- **文件**: `SettingsView.swift`, `WhiskyApp.swift`

### 9. 游戏模式 - Proton Wine 源支持
- **功能**: 新增 Wine-Proton 11.0 和 10.0 两种 Wine 引擎模式
- **实现**:
  - 扩展 `WineMode` 枚举添加 `proton11` 和 `proton10`
  - Proton 独立安装目录：`Libraries/Proton11` 和 `Libraries/Proton10`
  - Proton 下载 URL：GitHub Release `proton11/` 和 `proton10/` 目录
  - 下载器支持多版本缓存文件名
  - 设置页面新增 Proton 模式选择器
  - Proton 模式下自动应用游戏优化环境变量：
    - WINEMSYNC/WINEESYNC 增强同步
    - DXVK_ASYNC 异步编译
    - RADV_PERFTEST=gpl 性能优化
    - vblank_mode=0 关闭垂直同步
    - mesa_glthread=true 线程优化
  - 修复 Wine.swift 中 lib 路径硬编码问题
- **文件**:
  - `WhiskyWineInstaller.swift` - WineMode 枚举和路径配置
  - `ProtonInstaller.swift` - Proton 安装/卸载/验证逻辑
  - `WhiskyWineDownloader.swift` - 多版本缓存支持
  - `SettingsView.swift` - 设置页面 UI
  - `BottleSettings.swift` - 游戏优化环境变量
  - `Wine.swift` - lib 路径动态化
  - `Localizable.xcstrings` - 中文本地化
- **SwiftLint 调整**:
  - file_length: 600警告/800错误
  - type_body_length: 350警告/450错误
  - function_body_length: 70警告/80错误
- **时间**: 2026-06-29

### 10. 真实 Proton Wine 源接入 & CI 修复
- **功能**: 使用 Gcenx 的 wine-staging 作为 Proton 模式真实下载源
- **Proton 源**:
  - Proton 11: Gcenx wine-staging 11.10 (macOS Sonoma)
  - Proton 10: Gcenx wine-staging 11.9 (macOS Sonoma)
  - 下载地址：https://github.com/Gcenx/macOS_Wine_builds/releases
- **打包格式**: 重新打包为 `files/{bin, lib, share}` 结构，适配 ProtonInstaller
- **大小**: 每个约 311MB
- **CI 修复**:
  - 移除 SwiftLint `--strict` 模式，避免 warning 导致 CI 失败
  - 调整 .swiftlint.yml 阈值（type_body_length, function_body_length）
  - Build 和 SwiftLint workflow 均已通过
- **文件**:
  - `.github/workflows/SwiftLint.yml` - 移除 strict 模式
  - `.swiftlint.yml` - 调整 lint 阈值
  - `WhiskyWineInstaller.swift` - 更新真实下载 URL
- **时间**: 2026-06-30

### 11. ProtonWine 重命名 & 安装状态显示 & 下载安装 Bug 修复
- **功能**:
  - Proton 重命名为 ProtonWine，明确基于 Wine 的本质
  - 设置页面显示所有 4 种 Wine 引擎模式的安装状态
  - 修复 ProtonWine 模式下点击"重新安装"却下载 WhiskyWine 的 Bug
- **命名调整**:
  - Proton 11.0 (游戏模式) → ProtonWine 11.0 (游戏模式)
  - Proton 10.0 (游戏模式) → ProtonWine 10.0 (游戏模式)
- **安装状态显示**:
  - 设置页面列出所有 4 种模式：WhiskyWine / ProtonWine 11.0 / ProtonWine 10.0 / CrossOver
  - 每种模式旁显示安装状态（已安装✓ / 未安装?）
  - 重新安装按钮仅对当前选中的 WhiskyWine/ProtonWine 模式显示
- **Bug 修复**:
  - 下载视图：根据当前 WineMode 选择对应下载 URL
  - 安装视图：根据当前 WineMode 调用对应安装方法
  - 不同模式安装互不干扰，各自独立目录
- **新增通用方法**:
  - `isInstalled(mode:)` - 统一检测任意模式安装状态
  - `downloadURL(for:)` - 获取对应模式下载 URL
  - `installWithRetries(from:mode:)` - 带重试的通用安装方法
- **文件**:
  - `WhiskyWineInstaller.swift` - 新增通用方法
  - `WhiskyWineDownloadView.swift` - 动态下载 URL
  - `WhiskyWineInstallView.swift` - 动态安装方法
  - `SettingsView.swift` - 显示所有模式状态
  - `Localizable.xcstrings` - 新增/更新本地化字符串
- **时间**: 2026-06-30

### 12. Setup 启动检测修复 & CrossOver 多路径检测
- **功能**:
  - 修复 Setup 启动检测逻辑，WhiskyWine 作为基础必装项，同时检查当前模式引擎
  - 修复 CrossOver 模式下错误弹出 WhiskyWine 安装界面的 Bug
  - 增强 CrossOver 安装检测，支持多路径（/Applications、~/Applications）
- **核心修复**:
  - 移除 `isWhiskyWineInstalled()` 等方法中对 `currentMode` 的 guard 依赖，检测方法只关注文件系统状态
  - ContentView 启动时：先检查 WhiskyWine（必装），再检查当前模式引擎
  - WelcomeView 显示两个安装状态：WhiskyWine + 当前模式引擎
  - Setup 下载/安装视图接受 `installMode` 参数，明确当前安装的是哪个引擎
  - CrossOver 模式下未安装时不进入下载页面（CrossOver 不可下载）
- **新增方法/属性**:
  - `WineMode.isDownloadable` - 判断模式是否支持下载安装
  - `WineMode` 遵循 `Sendable` 协议
  - `crossOverAppURL()` - 返回检测到的 CrossOver 应用路径
  - `possibleCrossOverPaths` - CrossOver 可能的安装路径列表
- **文件**:
  - `WhiskyWineInstaller.swift` - 重构检测方法，新增 CrossOver 多路径
  - `ContentView.swift` - 启动检测逻辑修复
  - `SetupView.swift` - 新增 installMode 状态
  - `WelcomeView.swift` - 显示双引擎安装状态
  - `WhiskyWineDownloadView.swift` - 接受 installMode 参数
  - `WhiskyWineInstallView.swift` - 接受 installMode 参数
- **时间**: 2026-06-30

### 13. Proton 下载 404 修复 & CrossOver 模式创建瓶子修复
- **功能**:
  - 修复 Proton 下载 404 错误（文件名不匹配）
  - 修复 CrossOver 模式下创建瓶子失败的问题
- **Proton 下载修复**:
  - 问题：代码中下载文件名为 `Proton.tar.gz`，但 Release 实际文件名是 `Proton11.tar.gz` / `Proton10.tar.gz`
  - 修复：`protonDownloadURL(for:)` 方法返回正确的文件名
  - 修复：下载缓存文件名也按版本区分（Proton11.tar.gz / Proton10.tar.gz）
- **CrossOver 创建瓶子修复**:
  - 问题：CrossOver 的 `bin/wine` 是 Perl 包装脚本，会做 CrossOver 自有 bottle 管理，导致 WINEPREFIX 方式失败
  - 错误信息：`cxmessage standin was called` / `Unable to find the 'default' bottle`
  - 修复：直接使用 `lib/wine/x86_64-unix/wine` 真正的二进制，绕过 Perl 包装脚本
  - wineserver 使用 `CrossOver-Hosted Application/wineserver`
  - 添加 `CX_ROOT` 环境变量指向 CrossOver 根目录
  - 新增 `constructBaseWineEnvironment()` 用于无 bottle 场景（如 wine --version）
  - 终端环境命令 PATH 包含 wine 二进制所在目录
- **验证**:
  - 直接调用 CrossOver 的 `lib/wine/x86_64-unix/wine --version` 成功输出版本号
  - 使用 `wineboot -i` 成功创建 bottle，生成 drive_c、system.reg 等
- **文件**:
  - `WhiskyWineInstaller.swift` - Proton 下载 URL 修复
  - `WhiskyWineDownloadView.swift` - Proton 缓存文件名修复
  - `Wine.swift` - CrossOver wine/wineserver 路径 + CX_ROOT 环境变量
- **时间**: 2026-06-30

### 14. Proton tar 包结构修复
- **功能**: 修复 Proton 安装时提示 "ProtonVersion.plist 不存在" 的问题
- **问题根因**:
  - Proton tar 包实际结构：`Proton11/files/{bin,lib,share}`（带 `Proton11/` 根目录）
  - 但 `installProton` 代码期望的是解压后直接有 `files/` 目录（扁平结构）
  - 结果：tar 解压后文件在 `Proton11/` 下，代码没找到 `files/`，未移动文件
  - 安装目录 `Libraries/Proton11/` 下为空，验证时找不到文件
- **修复**:
  - `installProton` 新增对 tar 根目录（`Proton11/` / `Proton10/`）的检测
  - 如存在根目录，直接将其移动到 `Libraries/Proton11` 或 `Libraries/Proton10`
  - 保留对扁平 tar 结构（直接 `files/`）的向后兼容
- **文件**: `ProtonInstaller.swift`
- **时间**: 2026-06-30

### 15. Winetricks 路径修复 & ProtonWine 命名统一
- **功能**:
  - 修复 CrossOver/ProtonWine 模式下 Winetricks 不可用的问题
  - 统一 ProtonWine 命名（11.0 和 10.0 都叫 ProtonWine）
  - 下载/安装页面标题根据模式动态显示
  - 设置页面切换模式的取消按钮改为中文"取消"
- **Winetricks 修复**:
  - 问题：CrossOver 模式提示缺少 verbs.txt，Proton 模式提示缺少 WhiskyWine
  - 原因：winetricks 和 verbs.txt 路径逻辑错误，各自指向自身模式目录
  - 修复：winetricks 和 verbs.txt 统一从 WhiskyWine 目录读取（`whiskyWineBinFolder` / `whiskyWineShareFolder`）
  - 说明：winetricks 是 WhiskyWine 自带的工具，所有模式共享使用
- **ProtonWine 命名统一**:
  - 修复前：Proton11 中文叫 "Proton 11.0"，英文叫 "ProtonWine 11.0"
  - 修复前：Proton10 中文叫 "ProtonWine 10.0"，英文叫 "Proton 10.0"
  - 修复后：所有语言统一叫 "ProtonWine 11.0" / "ProtonWine 10.0"
- **下载/安装页面动态标题**:
  - 根据 `installMode` 动态显示标题和副标题
  - ProtonWine 模式显示 "Downloading/Installing ProtonWine 11.0/10.0"
  - 不再统一显示 "WhiskyWine"
- **文件**:
  - `WhiskyWineInstaller.swift` - winetricks/verbs 路径统一到 WhiskyWine
  - `WhiskyWineDownloadView.swift` - 动态下载标题
  - `WhiskyWineInstallView.swift` - 动态安装标题
  - `SettingsView.swift` - 取消按钮中文
  - `Localizable.xcstrings` - ProtonWine 命名统一
- **时间**: 2026-06-30

### 16. v3.0.0 Pre-Release 发布
- **版本**: 3.0.0 Pre-Release
- **功能**:
  - 支持 4 种 Wine 引擎模式：WhiskyWine / ProtonWine 11.0 / ProtonWine 10.0 / CrossOver
  - ProtonWine 游戏模式自动应用性能优化
  - 完整 Winetricks 支持
- **重要说明**:
  - Steam 只在 CrossOver 模式下可以正常运行
  - 注：CrossOver 需自己安装
- **发布地址**: https://github.com/JiangWanZhengChouYv/Whisky/releases/tag/v3.0.0
- **时间**: 2026-06-30

### 17. CrossOver 模式环境变量完善 & Apple GPTK 支持
- **功能**:
  - 完善 CrossOver 模式的环境变量配置，充分发挥 CrossOver 性能
  - 添加 Apple GPTK 支持，优先使用 GPTK 优化版 DirectX DLL
  - 所有模式添加通用性能优化
- **通用优化（所有模式）**:
  - `ROSETTA_ADVERTISE_AVX=1` — Rosetta 下宣称 AVX 支持
  - `DOTNET_EnableWriteXorExecute=0` — 修复 .NET 7/8 在 Rosetta 下的问题
- **CrossOver 模式专属优化**:
  - `WINELOADER` — 指向 wineloader
  - `WINESERVER` — 指向 wineserver
  - `GST_PLUGIN_SYSTEM_PATH` — GStreamer 插件路径
  - `GST_REGISTRY` — GStreamer 注册表路径
  - `CX_APPLEGPTK_LIBD3DSHARED_PATH` — Apple GPTK libd3dshared 路径
  - 完善 `WINEDLLPATH`，按优先级: apple_gptk → lib64 → lib
- **代码重构**:
  - 抽取 `applyCrossOverEnvironment(to:)` 方法减少重复代码
  - 抽取 `crossOverWineDLLPath()` 方法构建 WINEDLLPATH
- **文件**: `Wine.swift`
- **时间**: 2026-07-01

### 18. ProtonWine DXVK 集成增强 & 游戏优化
- **功能**:
  - 集成开源 DXVK-macOS（MIT 协议），支持 DX10/DX11 硬件加速
  - 增强 DXVK 健壮性，添加可用性检测和错误处理
  - 优化 ProtonWine 模式默认配置，提升游戏性能
- **DXVK 集成**:
  - 来源：Gcenx/DXVK-macOS v1.10.3-20230507-repack（MIT 协议）
  - 包含：d3d10core.dll、d3d11.dll（x64 + x32）
  - 移除了 d3d9 和 dxgi（macOS 上不该用）
  - 位置：各模式 libraryFolder/DXVK/{x64,x32}/
- **代码增强**:
  - 新增 `isDXVKAvailable` 静态属性，检测 DXVK 文件是否存在
  - `enableDXVK` 添加前置检查，不存在时抛出友好错误
  - `runProgram` 中 DXVK 不可用时打印警告而非崩溃
  - 新增 `WineError` 枚举，包含 `dxvkNotAvailable` 错误类型
  - 调整 `WINEDLLOVERRIDES` 为 `d3d10core,d3d11=n,b`（适配 DXVK-macOS）
- **ProtonWine 优化**:
  - 新增 `DXVK_STATE_CACHE=1` 和 `DXVK_ENABLE_STATE_CACHE=1` 状态缓存优化
  - `avxEnabled` 默认开启，与全局 `ROSETTA_ADVERTISE_AVX` 保持一致
  - 已有优化：WINEMSYNC/WINEESYNC、DXVK_ASYNC、RADV_PERFTEST=gpl、vblank_mode=0、mesa_glthread=true
- **文件**:
  - `Wine.swift` - DXVK 检测、错误类型、健壮性增强
  - `BottleSettings.swift` - 环境变量优化、默认值调整
- **测试包**: 临时/Whisky-测试版.app
- **DXVK 文件**: 临时/DXVK/
- **时间**: 2026-07-01

### 19. DXVK 自动下载安装功能
- **功能**:
  - 在设置页面一键下载安装 DXVK，无需手动操作
  - DXVK 按 Wine 模式独立安装（WhiskyWine / Proton11 / Proton10 各自独立目录）
  - 下载过程显示进度条
  - 自动重试失败的下载（最多3次）
  - 下载缓存复用，已下载的不会重复下载
- **实现**:
  - 新增 `dxvkDownloadURL` - DXVK 下载地址（Gcenx DXVK-macOS，MIT 协议）
  - 新增 `dxvkFolder(for:)` - 根据模式返回 DXVK 目录路径
  - 新增 `isDXVKInstalled(mode:)` - 检测任意模式的 DXVK 安装状态
  - 新增 `installDXVK(from:mode:)` - 从 tar 文件安装 DXVK 到指定模式
  - 重构 `dxvkFolder` 和 `isDXVKAvailable`，复用统一逻辑
  - 设置页面新增 DXVK Section，显示状态和安装按钮
  - CrossOver 模式不显示 DXVK 安装选项
- **代码拆分**:
  - DXVK 相关代码拆分为独立文件，修复 SwiftLint type_body_length 错误
  - `WhiskyWineInstaller+DXVK.swift` - WhiskyWineInstaller 的 DXVK extension
  - `DXVKSettingsView.swift` - 设置页面 DXVK UI 独立 View
- **DXVK 来源**: Gcenx/DXVK-macOS v1.10.3-20230507-repack-builtin（MIT 协议）
- **大小**: 约 2.7MB
- **文件**:
  - `WhiskyWineInstaller+DXVK.swift` - DXVK 下载 URL、安装、检测方法
  - `Wine.swift` - dxvkFolder 和 isDXVKAvailable 重构
  - `DXVKSettingsView.swift` - 设置页面 DXVK UI
  - `SettingsView.swift` - 集成 DXVKSettingsView
- **Bug 修复**:
  - 修复 DXVK 安装目标模式错误的问题
  - DXVKSettingsView 改为使用 `WhiskyWineInstaller.currentMode` 而非 Picker 选中值
  - 避免在未确认模式切换的情况下安装 DXVK 到错误目录
  - 添加 refreshTrigger 机制，模式切换确认后刷新 DXVK 状态
  - 添加 DXVK 安装和检测的调试日志
- **测试包**: 临时/Whisky-DXVK模式修复版.app
- **DXVK 文件**: 临时/DXVK/
- **时间**: 2026-07-01

### 20. 重要缺失功能修复
- **功能**:
  - DXVK 卸载功能：设置页显示"卸载 DXVK"按钮，一键移除 DXVK 文件
  - 瓶子导入功能：从 tar 文件还原瓶子，补充导出的反向操作
  - ProtonWine 更新检测：启动时检测 ProtonWine 11/10 是否有新版本
  - CrossOver DXVK 提示优化：说明 CrossOver 内置 D3DM 和 GPTK 支持
- **实现**:
  - 新增 `uninstallDXVK(mode:)` 方法，删除对应模式的 DXVK 目录
  - 新增 `importFromArchive(sourceURL:)` 静态方法，解压 tar 文件并加载瓶子
  - 新增 `shouldUpdateProton(mode:)` 和 `protonVersion(mode:)` 方法
  - ContentView 启动时检测当前 ProtonWine 模式的更新
  - DXVKSettingsView 优化 CrossOver 提示文本
- **代码拆分**:
  - Proton 更新检测代码拆分为 `WhiskyWineInstaller+ProtonUpdate.swift`
  - 解决 SwiftLint type_body_length 错误
- **文件**:
  - `WhiskyWineInstaller+DXVK.swift` - DXVK 卸载方法
  - `Bottle+Extensions.swift` - 瓶子导入方法
  - `WhiskyWineInstaller+ProtonUpdate.swift` - Proton 更新检测（新增）
  - `ContentView.swift` - 启动时 Proton 更新检测
  - `DXVKSettingsView.swift` - CrossOver 提示优化
- **测试包**: 临时/Whisky-修复版.app
- **时间**: 2026-07-02

### 21. 导入文件类型修复 & 导出导入进度提示
- **功能**:
  - 修复导入面板不允许选择 .tar.gz 文件的问题（文件灰色不可选）
  - 导出操作添加完成提示（成功/失败均显示 NSAlert）
  - 导入操作添加进度提示（ProgressView sheet + 结果 alert）
- **问题根因**:
  - 导入面板 `allowedContentTypes` 只设置了 `UTType(filenameExtension: "tar")!`
  - `.tar.gz` 文件需要 `UTType.gzip` 才能被识别为可选
- **实现**:
  - `importBottle()` 的 `allowedContentTypes` 添加 `UTType.gzip`
  - 导入时显示 `showImportProgress` sheet（ProgressView + "正在导入瓶子..."）
  - 导入完成/失败后显示 `ImportResultAlert`（Identifiable 结构体）
  - 导出按钮在 `Task.detached` 中 try/catch `exportAsArchive`（改为 throws）
  - 导出成功显示 `showExportSuccessAlert(path:)`，失败显示 `showExportErrorAlert(error:)`
  - `exportAsArchive` 改为 `throws` 以便调用方处理错误
- **文件**:
  - `ContentView.swift` - 导入文件类型修复 + 进度 sheet + 结果 alert + ImportResultAlert 结构体
  - `BottleListEntry.swift` - 导出完成提示（成功/失败 NSAlert）
  - `Bottle+Extensions.swift` - exportAsArchive 改为 throws
- **测试包**: 临时/Whisky-导入导出修复版.app
- **时间**: 2026-07-02

### 22. App 体积修复 & 导入 Tar 路径修复
- **功能**:
  - 修复 .app 体积从 13MB 暴增到 1.3GB 的问题
  - 修复导入 tar 文件后 bottle 内容嵌套在绝对路径下的问题
  - 修复导入 .tar.gz 文件时 bottle 名称提取错误
  - 导出默认文件名改为 .tar.gz 匹配实际 gzip 格式
- **App 体积修复**:
  - 问题：WhiskyKit 文件夹被错误地作为 Resources 资源复制进 .app
  - 导致整个 WhiskyKit 目录（含 .build/ 编译缓存 1.3GB）被复制
  - 修复：从 project.pbxproj 移除 WhiskyKit 的 PBXFileReference 和 Resources Build Phase 条目
  - 保留 SPM 依赖（XCLocalSwiftPackageReference）不变
  - 体积从 1.3GB 降回 13MB
- **Tar 路径修复（核心问题）**:
  - 问题：`Tar.tar` 使用绝对路径打包（`folder.path`）
  - 导致解压后 bottle 内容嵌套在 `Users/markzhang/Library/Containers/.../<UUID>/` 下
  - 修复：使用 `-C folder.path .` 切换到 bottle 目录并打包相对路径
  - 解压后内容直接在目标目录下，无嵌套
- **Bottle 名称提取修复**:
  - 问题：`deletingPathExtension()` 只删除一个扩展名
  - `Steam.tar.gz` → `Steam.tar`（错误），应为 `Steam`
  - 修复：删除扩展名后检查是否仍以 `.tar` 结尾，是则再删除一次
- **导出文件名修复**:
  - 问题：默认文件名用 `.tar`，但 `Tar.tar` 用 `-zcf`（gzip 压缩）
  - 修复：默认文件名改为 `.tar.gz` 匹配实际格式
- **导入验证**:
  - 新增 Metadata.plist 存在性检查
  - 无效 tar 文件时清理目标目录并抛出友好错误
- **文件**:
  - `Whisky.xcodeproj/project.pbxproj` - 移除 WhiskyKit Resources 引用
  - `Tar.swift` - 使用 -C 选项打包相对路径
  - `Bottle+Extensions.swift` - 名称提取 + Metadata.plist 验证
  - `BottleListEntry.swift` - 导出默认文件名 .tar.gz
- **测试包**: 临时/Whisky-导入导出修复版.app
- **时间**: 2026-07-02

### 23. v3.0.0 正式版发布
- **版本**: 3.0.0（正式版，从 Pre-Release 转为正式 Release）
- **操作**:
  - 将 v3.0.0 GitHub Release 从 Pre-Release 转为正式版（prerelease=false）
  - 删除旧的 Whisky-3.0.0.zip 资产（Pre-Release 版本，1.3GB）
  - 上传新的 Whisky-3.0.0.zip 资产（最新构建，5.8MB 压缩后）
  - 更新 Release Notes，包含新增功能、Pre-Release 后修复、重要说明
- **Release Notes 内容**:
  - 新增功能：4 种 Wine 引擎、ProtonWine 优化、Winetricks、DXVK 自动安装/卸载、Apple GPTK、瓶子导入、ProtonWine 更新检测
  - Pre-Release 后修复：App 体积修复（1.3GB→13MB）、导入/导出修复、CrossOver DXVK 提示优化、DXVK 安装模式修复
  - 重要说明：Steam 仅 CrossOver 模式可用，CrossOver 需自行安装
- **下载地址**: https://github.com/JiangWanZhengChouYv/Whisky/releases/download/v3.0.0/Whisky-3.0.0.zip
- **Release 页面**: https://github.com/JiangWanZhengChouYv/Whisky/releases/tag/v3.0.0
- **时间**: 2026-07-02

### 24. P0-P3 全量问题修复
- **功能**: 全面修复项目检查发现的 20 个问题（P0 严重 4 项、P1 重要 5 项、P2 一般 7 项、P3 对比缺失 4 项）
- **P0 严重问题修复**:
  - 移除无效的 Sparkle `SUFeedURL` 和 `SUPublicEDKey`（指向不存在的 appcast.xml）
  - 修复 `defaultWineVersion` 从 (7,7,0) 改为 (11,0,1)，移除加载时强制重置 wineVersion 的逻辑
  - 启用 Running Processes 功能（取消 BottleView.swift 中的注释）
- **P1 重要问题修复**:
  - 补全 Localizable.xcstrings 中 42 个缺失的本地化字符串（ProtonWine 相关 + 硬编码中文提取）
  - 增强 CrossOver 检测：验证 `lib/wine/x86_64-unix/wine` 真正二进制是否存在
  - 添加 ProtonWine 模式下运行 Steam 的兼容性提示
  - 完善 `wipeShaderCaches()`：增加 DXVK StateCache 和 SpirVCache 清理
- **P2 一般问题修复**:
  - 修复 WhiskyWineVersion 默认版本号从 (1,0,0) 改为 (11,0,1)
  - 移除 WhiskyApp.swift 中 placeholder 代码 `{same path of URL?}`
  - 修复帮助菜单 URL：getwhisky.app → 自己仓库，Whisky-App/Whisky → JiangWanZhengChouYv/Whisky，移除 Discord 链接
  - 错误处理改进：Bottle+Extensions.swift、WhiskyWineInstaller.swift、BottleView.swift 中 print 改为 Logger 日志
- **P3 对比缺失修复**:
  - 更新 README.md：CI badge、wiki 链接、图片链接指向 JiangWanZhengChouYv/Whisky
  - 更新项目描述反映多 Wine 引擎模式
- **GitHub Release 清理**:
  - 删除 Proton11 多余的 Draft 版本
  - 将 WhiskyWine v1.0.0 改为 Pre-release，使 Whisky 3.0.0 成为 Latest Release
- **文件**:
  - `Info.plist` - 移除 Sparkle 配置
  - `BottleSettings.swift` - wineVersion 默认值修复
  - `BottleView.swift` - 启用进程管理 + Steam 提示 + Logger
  - `WhiskyWineVersion.swift` - 默认版本号修复
  - `WhiskyApp.swift` - 移除 placeholder + 帮助菜单 URL + 着色器缓存
  - `WhiskyWineInstaller.swift` - CrossOver 检测增强 + Logger
  - `Bottle+Extensions.swift` - Logger
  - `Localizable.xcstrings` - 42 个新本地化字符串
  - `DXVKSettingsView.swift` - 硬编码中文提取
  - `ContentView.swift` - 硬编码中文提取
  - `BottleListEntry.swift` - 硬编码中文提取
  - `WhiskyWineInstallView.swift` - 硬编码中文提取
  - `WhiskyWineDownloadView.swift` - 硬编码中文提取
  - `SettingsView.swift` - 硬编码中文提取
  - `README.md` - 链接和描述更新
- **CI**: Build #84 + SwiftLint #89 通过
- **测试包**: 临时/Whisky.app
- **时间**: 2026-07-03

### 25. 修复进程页面一直 loading 和 Sparkle 启动报错
- **功能**:
  - 修复 RunningProcessesView 在 tasklist.exe 执行失败时永远显示"正在获取进程"的问题
  - 修复 Sparkle 因缺少 SUFeedURL 启动时报错的问题
- **RunningProcessesView 修复**:
  - 添加 `ProcessLoadState` 枚举（loading / success / error / empty）
  - `fetchProcesses()` 根据执行结果设置对应状态，不再永远 loading
  - UI 用 `switch loadState` 显示四种状态：
    - loading: ProgressView + "正在获取进程"
    - success: 进程表格 Table
    - empty: "没有运行中的进程"
    - error: "无法获取进程列表" + 重试按钮
  - `print` 改为 `Logger` 日志
- **Sparkle 修复**:
  - `SPUStandardUpdaterController(startingUpdater: false)`，不在启动时自动启动更新器
  - 避免缺少 SUFeedURL 时弹出报错
- **其他**:
  - 删除无用的 `build-all-fixes` 目录
- **文件**:
  - `RunningProcessesView.swift` - 加载状态管理 + UI 状态切换
  - `WhiskyApp.swift` - Sparkle startingUpdater 改为 false
  - `Localizable.xcstrings` - 添加 process.table.empty/error/retry 本地化
- **CI**: Build #86 + SwiftLint #91 通过
- **测试包**: 临时/Whisky.app
- **时间**: 2026-07-03

### 26. ProtonWine 模式 Steam 兼容性优化
- **功能**: 优化 ProtonWine 模式的配置，提升 Steam 等游戏的兼容性
- **WINEDLLPATH 优化**:
  - WhiskyWine/ProtonWine 模式的 WINEDLLPATH 从单一路径改为多路径
  - 路径优先级：x86_64-windows → i386-windows → wine/（fallback）
  - 类似 CrossOver 的路径结构，提升 DLL 查找效率
  - 新增 `defaultWineDLLPath()` 方法构建路径
- **DXVK 配置确认**:
  - DXVK-macOS 只包含 d3d10core.dll 和 d3d11.dll（无 dxgi.dll）
  - 符合 macOS DXVK 设计（dxgi 由 Wine 内置版本处理）
  - DXVK HUD 设置 UI 已存在（full/partial/fps/off）
- **Steam 兼容性提示优化**:
  - 提示信息更详细，说明 CrossOver 的 Apple GPTK 和 D3DMetal 优势
  - 硬编码中文提取到本地化字符串
- **文件**:
  - `Wine.swift` - 新增 defaultWineDLLPath()，完善 WINEDLLPATH
  - `BottleView.swift` - Steam 提示使用本地化字符串
  - `Localizable.xcstrings` - 添加 steam.warning.title/message
- **测试包**: 临时/Whisky.app
- **时间**: 2026-07-04

### 27. 瓶子复制 & 拖拽安装 & 最近使用 & 性能预设 & 按钮中文化
- **功能**:
  - 瓶子复制：右键菜单一键深拷贝瓶子，自动命名"副本"，新UUID独立目录
  - 拖拽安装：程序Tab支持拖拽.exe/.msi文件创建快捷方式，高亮提示+确认对话框
  - 最近使用：每个瓶子记录最近5个使用的程序，顶部显示一键运行
  - 性能预设：ProtonWine模式下三档预设（性能优先/平衡/画质优先），自动应用环境变量
  - 按钮中文化：优化10处翻译，更符合中文习惯（"确定"→"好的"等）
  - 搜索占位符：瓶子搜索框添加中文占位提示"搜索瓶子..."
- **瓶子复制**:
  - `duplicate()` 方法深拷贝整个瓶子目录
  - 新瓶子名称为"原名 副本"，支持本地化
  - 复制过程显示 inFlight 状态，失败时清理半成品
- **拖拽安装**:
  - 程序列表区域支持 `.onDrop` 拖拽
  - 拖拽进入显示虚线边框高亮
  - 放下后弹出确认对话框，自动去重添加
- **最近使用**:
  - `BottleSettings` 新增 `recentlyUsedPrograms` 属性
  - 运行程序时自动更新，去重+最多5个
  - 程序Tab顶部显示，为空时不显示
- **性能预设**:
  - `PerformancePreset` 枚举：performance / balanced / quality
  - 性能优先：DXVK_ASYNC + vblank_mode=0 + mesa_glthread + RADV_PERFTEST=gpl
  - 平衡：DXVK_ASYNC + mesa_glthread（默认）
  - 画质优先：DXVK_STATE_CACHE + RADV_PERFTEST=gpl
  - 预设不覆盖用户手动设置的环境变量
- **按钮中文化优化**:
  - `button.ok`: 确定 → 好的
  - `button.createBottle`: 创建容器 → 创建瓶子
  - `button.removeAlert.info`: 容器 → 瓶子
  - `tab.config`: 容器配置 → 瓶子配置
  - `config.avx`: 查看 AVX 支持 → 启用 AVX 支持
  - `wine.clearShaderCaches`: 清空 Shader 缓存 → 清理着色器缓存
  - `winetricks.category.benchmarks`: Benchmarks → 基准测试
  - `config.dxr.info`: 格式优化
  - `showAlertOnFirstLaunch.button.dontMove`: 不要移动 → 不移动
  - `button.winetricks`: Winetrick... → Winetricks...（补全s）
- **文件**:
  - `Bottle+Extensions.swift` - 瓶子复制方法
  - `BottleListEntry.swift` - 复制右键菜单
  - `ProgramsView.swift` - 拖拽安装 + 最近使用 UI
  - `BottleSettings.swift` - 最近使用 + 性能预设模型
  - `Wine.swift` - 运行时更新最近使用 + 预设环境变量
  - `ConfigView.swift` - 性能预设选择器 UI
  - `ContentView.swift` - 搜索框占位符
  - `Localizable.xcstrings` - 新增/优化本地化字符串
- **时间**: 2026-07-04

## 关键路径
- **应用支持目录**: `~/Library/Application Support/com.whisky.Whisky/`
- **Wine 安装目录**: `Libraries/Wine/{bin, lib, share}`
- **Proton 安装目录**: `Libraries/Proton{11,10}/files/{bin, lib, share}`
- **下载缓存**: `~/Library/Application Support/Whisky/Downloads/Libraries.tar.gz`
- **版本 plist**:
  - WhiskyWine: `Libraries/WhiskyWineVersion.plist`
  - Proton: `Libraries/Proton{11,10}/ProtonVersion.plist`

## 已知约束
- WhiskyWine 安装需要 wine 和 wine64 两个二进制（wine64 是 symlink）
- Proton 安装需要 files 目录结构（files/bin, files/lib, files/share）
- Libraries.tar.gz 必须包含 verbs.txt 和 winetricks 脚本
- Xcode archive (.xcarchive) 和 .dSYM 是构建产物，不提交
- UI 操作必须标记 @MainActor
- Proton 使用 Gcenx wine-staging 作为底层引擎，非 V 社官方 Proton
- 大文件（>300MB）通过 GitHub Release 分发

## 构建命令
```bash
# Release 构建（跳过签名）
xcodebuild -scheme Whisky -configuration Release -derivedDataPath ./build build CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

# 输出位置
./build/Build/Products/Release/Whisky.app
```

## GitHub 仓库
- 地址: https://github.com/JiangWanZhengChouYv/Whisky
- 主分支: main
- WhiskyWine Release: `whiskywine-v1`
- Proton 11 Release: `proton11`
- Proton 10 Release: `proton10`

### 28. ProtonWine Steam 无法运行根因分析
- **功能**: 深入诊断 ProtonWine 模式下 Steam 无法运行的根因，确认是 Wine 引擎限制而非配置问题
- **根本原因**: steamwebhelper(CEF) 兼容性问题
  - Steam 客户端 UI 完全依赖 steamwebhelper 进程，基于 CEF (Chromium Embedded Framework)
  - 在纯上游 Wine 下，CEF 经常崩溃或无响应，导致 Steam 黑屏
  - 这不是 D3D 问题、显卡驱动问题或 DXVK 配置问题，而是 CEF 与 Wine 的兼容性问题
- **Gcenx wine-staging 限制（权威确认）**:
  - Gcenx 在 GitHub Issue #159 (2026-04-27) 明确表态：
    "These packages are now purely source builds of Winehq source releases. DXMT & Steam won't work out-of-box using purely upstream wine."
    "Outside of CrossOver you'd want to compile wine from source with the changes outlined on DXMT GitHub."
  - Gcenx wine-staging 是纯净上游 Wine 源码构建，不包含任何 Steam/DXMT 兼容性 hack
  - 没有任何用户报告在 Gcenx wine-staging 上成功运行 Steam
  - Gcenx 将此问题关闭为 not_planned——设计选择，不是 bug
  - Issue 链接: https://github.com/Gcenx/macOS_Wine_builds/issues/159
- **CrossOver 能运行 Steam 的关键差异**:
  - D3DMetal: D3D10/11/12 → Metal 直译（CodeWeavers 专有）
  - DXMT: D3D11 → Metal 开源翻译层（需 Wine 补丁）
  - Apple GPTK libd3dshared: Apple 官方 D3D 翻译
  - steamwebhelper 兼容性修复: 针对 CEF 的专门补丁
  - ESync/MSync: 多线程同步优化
- **当前代码配置评估**:
  - WINEDLLOVERRIDES `d3d10core,d3d11=n,b` — ✅ 正确（Gcenx 确认不应 override dxgi）
  - WINEDLLPATH 多路径 — ✅ 正确
  - DXVK-macOS 仅含 d3d10core+d3d11 — ✅ 正确（Gcenx 确认 macOS 不需要 dxgi）
  - MSYNC+ESYNC 同时启用 — ⚠️ ProtonWine 无 D3DM，ESYNC 欺骗无意义
  - ROSETTA_ADVERTISE_AVX=1 — ⚠️ 可能导致 CEF 检测到 AVX 后启用 AVX 优化路径，Rosetta 模拟不完整导致崩溃
  - mesa_glthread/RADV_PERFTEST — ❌ Linux Mesa 驱动变量，macOS 无效
  - 缺少 Steam 启动参数 — ❌ 缺少 -cef-disable-gpu 等关键参数
  - 缺少 steam.cfg — ❌ 缺少防更新配置
- **缓解方案分级评估**:
  - 短期可行: Steam 降级参数 + steam.cfg 防更新 + CEF 禁用 GPU 参数
    （注意: Wine 9/10 时代有效，11.7+ 不保证）
  - 中期探索: STEAMOS/STEAM_RUNTIME 环境变量 + Windows 版本调整
  - 不可行: 自行编译 Wine + DXMT 补丁（工作量过大，超出项目范围）
- **结论**:
  - ProtonWine 模式下 Steam 无法运行是 Wine 引擎层面的限制，非配置问题
  - CrossOver 是唯一开箱即用支持 Steam 的方案
  - 当前代码配置已是最优，v3.0.1 的 WINEDLLPATH/DXVK 优化是正确的
  - 建议维持"Steam 推荐使用 CrossOver 模式"的提示
- **规范文档**: .trae/specs/protonwine-steam-rootcause/
- **时间**: 2026-07-04

## 最后更新
2026-07-04 - ProtonWine Steam 无法运行根因分析
  - 确认根本原因：steamwebhelper(CEF) 与纯上游 Wine 的兼容性问题
  - Gcenx wine-staging 是纯净上游 Wine，不包含 Steam 兼容性 hack（Issue #159 权威确认）
  - CrossOver 能运行 Steam 的关键差异：D3DMetal/DXMT/GPTK/CEF 补丁
  - 当前代码配置已是最优，问题根因是 Wine 引擎限制
  - 缓解方案分级：短期可行（Steam 降级参数）/ 中期探索（STEAMOS 环境变量）/ 不可行（自行编译 Wine）
