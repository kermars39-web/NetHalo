# 更新日志 / Changelog

NetHalo 的主要变更记录在此。All notable changes to NetHalo are documented here.

## 1.3 — 2026-08-13

### Changed

- 菜单栏上传、下载速率补充 `/s` 单位，含义更明确。
- 保持上下行箭头固定左对齐、速率固定右对齐，并缩短两者之间的留白；数值变化时布局不抖动。
- Added explicit `/s` units to the menu bar meter and refined its fixed-width alignment for a tighter, steadier native layout.

## 1.2 — 2026-08-12

### Changed

- 重构点击后的状态面板，移除冗余页头和过度卡片，在保留网络、CPU、内存与分应用排行的前提下缩短整体高度。
- 分应用网速改为同行显示上传和下载；下载作为黑色主值，上传作为灰色次值，并修正图标、应用名与数值的挤压问题。
- 简化监控设置页和底部入口，菜单栏上下行箭头改用系统文字色，保持浅色与深色外观一致。
- Reworked the compact status panel, aligned per-app upload and download on one row, and improved hierarchy and spacing across light and dark appearances.

### Fixed

- 弹层现在只在点击面板外部时关闭，避免面板内部交互被失焦逻辑误收起。
- 新增离屏浅色、深色预览入口，便于界面调整后进行一致性验证。
- Fixed outside-click dismissal and added reproducible offscreen previews for UI verification.

## 1.1 — 2026-08-01

### Added

- 设置页新增手动“检查更新”；只有用户点击时才访问 GitHub 官方最新版本跳转地址。
- 不做后台轮询，不需要账号或 Token，不收集遥测数据。
- 新增“正在检查”“已是最新版”“发现新版本”和连接失败等状态。
- Added a manual **Check for Updates** action in Settings, with explicit checking, current, update available, and failure states.

### Fixed

- 补齐 macOS 图标的 16 px 和 32 px 非 Retina 图层，修复系统设置“登录项”中 NetHalo 图标缺失的问题。
- App 构建版本变化后会刷新登录项登记，避免沿用过期的路径、版本或图标元数据。
- Completed the small macOS icon layers and refreshes launch-at-login registration after app updates.

### Documentation

- 更新中英双语 README、项目边界、隐私说明和产品官网。
- Updated the bilingual README, project scope, privacy wording, and product website.

## 1.0 — 2026-07-30

- Initial public release.
- Added the fixed-width two-line network meter, one-minute network/CPU/memory trends, per-app rankings, and native launch-at-login support.
- Shipped as a local-only, ad-hoc signed Apple Silicon app for macOS 13 and later.
