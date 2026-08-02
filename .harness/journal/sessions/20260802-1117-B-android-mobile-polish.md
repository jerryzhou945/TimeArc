# Android 移动端全屏与分享打磨

Goal: 在保留鸿蒙可启动默认 Activity Theme 的前提下，完成 Android Edge-to-Edge、统一圆角图标、华为应用元数据和两类分享预览重构。

Service side: 后台采集服务和磁盘契约不变；Android UsageStats 同步仍写入原始 package 标识与当前权限/WorkManager 计时链路。

UI side: Android 元数据解析与 C++ 展示层提供友好名称和图标，QML 统一 SVG/圆角组件、系统安全区和分享海报布局；Java 仅在运行时配置窗口系统栏。

Expected files: `android/src/main/java/com/timearc/mobile/{ui,usage}/`, `src/services/mobile/`, `qml/mobile/`, `resources/app/icons/mobile/`, `resources/licenses/`, targeted tests and docs. Rules: 01, 02, 04, 06, 08. Frozen files are out of scope; especially do not edit `src/CMakeLists.txt`, service contracts, schema, root CMake, or Activity theme binding.

- Completed: Edge-to-Edge、SVG 图标、统一圆角、华为桌面元数据、单卡/排行/月报分享重构、许可与 APK。
- Incomplete: Pura 90 Pro 卓易通真机视觉验收。
- Verification: Windows/Android build PASS；CTest 4/4；三组静态测试 PASS；移动预览响应；APK v2 签名与 Manifest/ABI/权限检查 PASS。
- Next: 安装 `dist/TimeArc-1.0-android-arm64-v8a-mobile-polish-debug.apk`，确认状态栏、手势区和两类分享图。
- Risks: Android 全目标会链接桌面 service 空 stub；本次使用 `time-arc` + `time-arc_make_apk` 目标。默认 Activity Theme 不得恢复为自定义 Theme。
