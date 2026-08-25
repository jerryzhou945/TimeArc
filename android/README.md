# TimeArc for Android

TimeArc Android 是桌面时间线的移动端查看与采集实现。它通过 Android 系统的
`UsageStatsManager` / `UsageEvents` 读取应用级使用时长，写入与桌面端兼容的本地
SQLite 数据，再由 Qt/QML 页面展示。

> 当前为 ARM64 功能预览。HarmonyOS + 卓易通属于 Android 兼容层运行方式，
> 并非原生 HarmonyOS/HAP 应用。

## 安装与首次同步

1. 安装 `arm64-v8a` APK。
2. 在系统设置中授予 TimeArc“使用情况访问权限”。
3. 回到应用；每次进入前台都会立即补齐最近记录。
4. 后续由 WorkManager 做周期同步，统计页只读取已落盘数据。

如果“今天”没有变化，先确认系统日期/时区、Usage Access 是否仍授权，再完全退出并重进应用。

## 已实现

- 四标签移动 UI、全屏 edge-to-edge 和安全区适配。
- 自适应、圆形与传统 launcher 图标；应用图标统一 GPU 圆角遮罩。
- 应用标签/图标解析，避免把 `com.huawei...` 包名当展示名称。
- 日/周/月/年与全部应用时长。
- 应用卡/月报分享预览及 FileProvider 保存/分享。
- 打开应用立即同步，按本地自然日替换 UsageStats，持久化完成后再通知 QML。
- 启动覆盖动画；保持 Qt 默认 Activity theme 以兼容已验证的卓易通启动路径。

## 数据链路

```text
UsageStatsManager / UsageEvents
  -> AndroidUsageCollector (Java)
  -> AndroidUsageNativeBridge (JNI)
  -> src/services/mobile repositories (C++)
  -> timearc_service.db
  -> Qt/QML read-only views
```

包名会标准化为 `android:<package_name>`。QML 不直接调用 Android framework API。

## 构建要求

- Qt 6 Android kit
- Android SDK / NDK
- JDK
- Gradle/Android Gradle Plugin 版本以 [build.gradle](build.gradle) 为准
- AndroidX WorkManager `2.9.1`

Qt 构建必须把本目录作为 Android package source。不要只单独运行 Gradle：
最终 APK 还需要 Qt 生成的 native library、QML 和资源。

## HarmonyOS / 卓易通

已验证的可运行基线保留以下条件：

- ARM64 ABI；
- Qt 默认 Android Activity theme；
- 标准 Usage Access 与 WorkManager 启动链；
- 不在启动前强制绑定自定义 splash theme。

若出现“黑屏约 1 秒后退出”，优先收集卓易通/Android 日志并比对 ABI、Activity theme、
Qt 库和权限；不要先删除计时权限。桌面图标是否正常与启动崩溃通常是两条独立链路。

## 权限与隐私

TimeArc 只申请实现本地使用时长所需的权限。Usage Access 提供应用级事件，
不等于读取聊天内容。分享前会生成图片预览，用户确认后才保存或交给系统分享面板。

## 已知限制

- 不同华为/小米/OPPO/vivo ROM 对后台任务和 UsageStats 的刷新频率不同。
- 卓易通升级后兼容行为可能变化。
- 系统启动器、兼容层或虚拟化容器可能只提供包名，需由应用身份映射补齐。
- 尚未提供原生 HarmonyOS HAP。

更多产品/发布状态见 [主 README](../README.md) 与
[移动端实现报告](../docs/mobile/android-usage-backend-implementation-report.md)。
