# 更新日志 / Changelog

NetHalo 的主要变更记录在此。All notable changes to NetHalo are documented here.

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
