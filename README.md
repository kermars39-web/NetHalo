# GlanceBar

一款原生、轻量、只在本机运行的 macOS 菜单栏状态工具。

## 主要能力

- 菜单栏以固定宽度双行显示下载和上传，不会随数字变化左右晃动
- 点击查看最近一分钟趋势和高占用应用
- CPU 和内存只在点击后的面板中显示
- 支持开机自动启动
- 无账号、无网络请求、无管理员组件

## 构建

```bash
./Scripts/build-app.sh
```

构建产物位于 `dist/GlanceBar.app`。

## 开发验证

```bash
swift build --disable-sandbox -c release
.build/release/GlanceBar --self-test
```

## 卸载

退出 GlanceBar 后移除 `/Applications/GlanceBar.app`。如需同时清理偏好设置，再移除：

```text
~/Library/Preferences/com.kermars.glancebar.plist
```
