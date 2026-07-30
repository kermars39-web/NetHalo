# NetHalo

**A lightweight, privacy-first macOS menu bar monitor.**<br>
**轻量、原生、注重隐私的 macOS 菜单栏监控工具。**

[English](#english) · [简体中文](#简体中文)

## English

NetHalo keeps the information you need one click away without turning your menu bar into a dashboard. It shows real-time upload and download speed in a compact, fixed-width meter, with CPU, memory, and per-app usage available in the popover.

### Highlights

- Compact two-line menu bar meter: upload on top, download below
- Fixed-width values that do not shift as network speed changes
- One-minute network, CPU, and memory trends
- Click the Network, CPU, or Memory card to switch the per-app ranking
- Remembers the last selected ranking between launches
- Uses real application icons and groups helper processes under their parent app
- Native AppKit interface with no third-party dependencies
- No account, telemetry, uploads, or administrator helper

### Requirements

- macOS 13 or later
- Swift 5.9 or later and the Xcode Command Line Tools for building
- Tested on Apple Silicon; Intel builds are welcome to be tested by contributors

### Build and install

```bash
git clone https://github.com/kermars39-web/NetHalo.git
cd NetHalo
./Scripts/build-app.sh
open dist/NetHalo.app
```

The build script creates an ad-hoc signed app at `dist/NetHalo.app`. You can drag it into `/Applications` after testing it.

### How it works

NetHalo reads macOS system statistics locally. Overall network, CPU, and memory metrics refresh every second while the panel is open. Per-app rankings are sampled periodically with the system `nettop` and `ps` tools. CPU usage can exceed 100% when an app uses more than one CPU core.

NetHalo does not send data anywhere and does not inspect file contents.

### Development

```bash
swift build --disable-sandbox -c release
.build/release/NetHalo --self-test
```

Issues and pull requests are welcome. Please keep the interface compact, native, and quiet: high-frequency interactions should prioritize clarity over decorative animation.

### Uninstall

Quit NetHalo and remove `NetHalo.app`. To also clear its preferences, remove:

```text
~/Library/Preferences/com.kermars.nethalo.plist
```

### License

NetHalo is available under the [MIT License](LICENSE).

---

## 简体中文

NetHalo 把常用状态收进一次点击里，同时避免让菜单栏变成拥挤的仪表盘。菜单栏以紧凑、固定宽度的双行形式显示实时上传与下载速度；CPU、内存和分应用占用则在弹出面板中查看。

### 主要特点

- 菜单栏双行显示：上传在上、下载在下
- 固定宽度，网速数字变化时不会左右晃动
- 展示最近一分钟的网络、CPU 和内存趋势
- 点击网络、CPU 或内存卡片，切换对应的分应用排行
- 自动记住上次选择，下次打开保持不变
- 显示真实应用图标，并将 Helper 进程归并到主应用
- 原生 AppKit 界面，不依赖第三方组件
- 无账号、无遥测、无数据上传、无管理员辅助程序

### 系统要求

- macOS 13 或更高版本
- 本地构建需要 Swift 5.9 或更高版本及 Xcode Command Line Tools
- 已在 Apple Silicon 上测试，欢迎贡献者协助验证 Intel Mac

### 构建与安装

```bash
git clone https://github.com/kermars39-web/NetHalo.git
cd NetHalo
./Scripts/build-app.sh
open dist/NetHalo.app
```

构建脚本会在 `dist/NetHalo.app` 生成临时签名的应用。试用确认后，可将它拖入 `/Applications`。

### 工作方式与隐私

NetHalo 只在本机读取 macOS 系统统计信息。面板打开时，整体网络、CPU 和内存数据每秒刷新；分应用排行通过系统自带的 `nettop` 和 `ps` 定期采样。多核 CPU 环境下，单个应用的 CPU 占用可能超过 100%。

NetHalo 不会向外发送数据，也不会读取或扫描文件内容。

### 开发验证

```bash
swift build --disable-sandbox -c release
.build/release/NetHalo --self-test
```

欢迎提交 Issue 和 Pull Request。请保持界面紧凑、原生、克制；对于高频操作，清晰反馈应优先于装饰性动画。

### 卸载

退出 NetHalo 后移除 `NetHalo.app`。如需同时清理偏好设置，再移除：

```text
~/Library/Preferences/com.kermars.nethalo.plist
```

### 开源许可

NetHalo 使用 [MIT License](LICENSE) 开源。
