# 鸿蒙卓易通安全启动修复报告

## 目标

修复 Pura 90 Pro 通过卓易通启动 TimeArc 时，启动背景显示约一秒后进程退出的问题，并生成可安装的 arm64-v8a 诊断 APK。

## 范围

- Android 固定采用 OpenGL Qt Quick 后端。
- 移除进程创建阶段的 AndroidX Startup Provider。
- WorkManager 改为权限可用后按需初始化，失败时降级。
- 使用情况权限检测延迟到 QML 启动动画完成后。
- 首次进入不再自动拉起系统权限 Activity；用户仍可在设置页主动授权。
- Java 与 C++ JNI 边界捕获异常并返回明确的不可用状态。

## 变更文件

- `android/AndroidManifest.xml`
- `android/src/main/java/com/timearc/mobile/usage/UsageAccessBridge.java`
- `android/src/main/java/com/timearc/mobile/usage/UsageSyncScheduler.java`
- `qml/mobile/MobileAppShell.qml`
- `src/main.cpp`
- `src/services/mobile/mobile_usage_service.cpp`
- `tests/android_usage_static_test.py`

## 验证

- Android `apk` 目标构建成功，合并 Manifest 中无 AndroidX Startup 初始化器。
- Windows 构建成功；CTest 4/4 通过。
- Android usage、launch experience、mobile UI、desktop UX、Windows 等相关静态检查通过。
- APK：`com.timearc.app`，version `1.0`，minSdk 28，targetSdk 36，仅 `arm64-v8a`，debug v2 签名。
- Pura 90 Pro 卓易通真机复测仍待用户安装新 APK 后确认。

## 已知缺口

- 卓易通是否提供 Android UsageStats 数据仍由其兼容层决定；不可用时 TimeArc 只能降级，不会获得其他应用的自动用时。
- 仓库已有 `macos_build_script_static_test.py` 基线失败，与本次 Android 变更无关。

## 回滚

回滚本修复提交即可恢复原启动路径；不涉及数据库或磁盘数据迁移。
