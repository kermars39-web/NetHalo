# NetHalo

一款原生、轻量、只在本机运行的 macOS 菜单栏状态工具。当前版本为 1.0。

## 主要能力

- 菜单栏以紧凑固定宽度双行显示下载和上传，不会随数字变化左右晃动
- 点击网络、CPU 或内存卡片，切换查看对应的分应用实时占用排行
- 自动记住最后一次选中的排行类型，下次打开保持不变
- 应用排行显示真实应用图标，双行速度统一为上传在上、下载在下
- 详情卡片按上传在左、下载在右排列，与其他位置的阅读顺序一致
- CPU 和内存只在点击后的面板中显示
- 主面板和设置页保持同一窄宽，切换时不会被文字撑宽
- 支持开机自动启动
- 无账号、无网络请求、无管理员组件

## 构建

```bash
./Scripts/build-app.sh
```

构建产物位于 `dist/NetHalo.app`。

## 开发验证

```bash
swift build --disable-sandbox -c release
.build/release/NetHalo --self-test
```

## 卸载

退出 NetHalo 后移除 `/Applications/NetHalo.app`。如需同时清理偏好设置，再移除：

```text
~/Library/Preferences/com.kermars.nethalo.plist
```
