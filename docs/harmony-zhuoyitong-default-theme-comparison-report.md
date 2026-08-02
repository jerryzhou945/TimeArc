# 鸿蒙卓易通默认主题对照报告

## 对比结论

7 月 4 日可运行 APK 与当前 APK 具有相同的包名、minSdk 28、targetSdk 36、arm64-v8a ABI 和 debug 签名。两包中的 `libQt6Core_arm64-v8a.so` 与 Qt Android 平台插件 SHA-256 完全相同，因此 Qt 版本、CPU 架构、SDK 和签名均被排除。

可运行 APK 本身包含 AndroidX Startup、WorkManager、Usage Access 权限和启动同步逻辑。这直接否定了“计时权限或 WorkManager 导致启动退出”的上一假设。

## 当前单变量

新启动体验为 `QtActivity` 绑定了 `TimeArcLaunchTheme`；7 月 4 日 APK 没有 Activity 主题绑定，使用 Qt 默认主题。本次恢复全部计时逻辑，只移除该主题绑定：launcher/adaptive/round 图标、最新 QML UI、QML 启动动画及当前功能全部保留。

## 验证

- Android APK 构建成功。
- 合并 Manifest 中没有 `android:theme` Activity 属性，并重新包含 `androidx.startup.InitializationProvider` 与 `androidx.work.WorkManagerInitializer`。
- Android launch/usage/mobile UI/desktop UX 静态检查通过。
- Windows 构建成功；CTest 4/4 通过。
- APK v2 debug 签名通过，SHA-256：`19A4036B0142FEBA96BF739E5E0ED1B26018AA8266A78B81AAD1D264CEA4A896`。

## 待确认

该包仍需 Pura 90 Pro 卓易通真机复测。若仍退出，下一阶段将保持同一 Manifest，二分当前 QML/应用初始化路径。

## 回滚

回滚本次默认主题隔离提交即可重新绑定原生启动主题；不涉及数据迁移。
