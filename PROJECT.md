# NetHalo Project Scope / 项目范围

Current version / 当前版本：**1.0**

## Goals / 目标

NetHalo is a native macOS menu bar utility for monitoring network speed, CPU, memory, and per-app resource usage with a compact, low-distraction interface.

NetHalo 是一款原生 macOS 菜单栏工具，以紧凑、低干扰的方式展示网速、CPU、内存和分应用资源占用。

## Current scope / 当前范围

- Fixed-width, two-line upload and download meter in the menu bar / 菜单栏固定宽度双行显示上传和下载速度
- One-minute network, CPU, and memory trends / 最近一分钟的网络、CPU 和内存趋势
- Switchable per-app rankings for network, CPU, and memory / 可切换的网络、CPU、内存分应用排行
- Persistent selection between launches / 记住上次选择
- Native launch-at-login support / 使用系统原生开机启动能力
- Local-only processing with no telemetry or uploads / 完全本地处理，不含遥测和数据上传

## Non-goals for 1.x / 1.x 暂不包含

Temperature, GPU power, fan control, and private SMC access are intentionally excluded. These features would require privileged helpers and introduce additional security and compatibility costs.

暂不读取温度、GPU 功耗、风扇或私有 SMC 数据，避免引入管理员辅助程序以及额外的安全与兼容成本。

## Technical baseline / 技术基线

- Swift, AppKit, Combine
- macOS 13+
- No third-party runtime dependencies / 无第三方运行时依赖
- No network service or external backend / 无网络服务和外部后端
