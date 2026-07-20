# AGENTS.md - Whisky 项目规则

## 项目概述
Whisky 是 macOS 上的 Wine 图形化管理工具。

## 关键路径
- 应用支持目录: `~/Library/Application Support/com.whisky.Whisky/`
- Wine 安装目录: `Libraries/Wine/{bin, lib, share}`
- Proton 安装目录: `Libraries/Proton{11,10}/files/{bin, lib, share}`
- 下载缓存: `~/Library/Application Support/Whisky/Downloads/`

## 规则
- 上传文件时设定 ALL_PROXY=http://127.0.0.1:7890
- 下载文件放"临时/"文件夹
- UI 操作必须标记 @MainActor
- 测试包放在临时/，不加后缀
- 编译命令: `xcodebuild -scheme Whisky -configuration Release build CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`

## 当前状态
- 版本: 3.0.0
- Sine: x86_64 编译成功，解决 macOS 27 SIGKILL 问题
- CI: Build + SwiftLint 均通过
- 测试包: 临时/Whisky.app

## GitHub
- 主仓库: https://github.com/JiangWanZhengChouYv/Whisky
- Sine: https://github.com/JiangWanZhengChouYv/sine
