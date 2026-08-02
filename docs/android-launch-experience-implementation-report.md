# Android 桌面图标与启动体验实现报告

日期：2026-08-02

## 目标

为 TimeArc Android 版本补齐可识别的桌面图标、系统启动画面和应用内进入动画，
并产出可安装的 arm64-v8a APK。

## 实现范围

- 基于既有 TimeArc `T` 标志生成 1024×1024 手机端图标主稿，保留青紫渐变和深色字形。
- 提供 Android adaptive、round、themed monochrome 与 mdpi–xxxhdpi 旧版图标。
- Manifest 显式引用 launcher/round icon 和 `TimeArcLaunchTheme`。
- Android 12+ 使用系统 SplashScreen 属性；旧版 Android 使用同品牌启动背景。
- 新增移动端 QML 进入层：弧线旋转 960 ms，随后淡出 160 ms；减少动态效果开启时立即跳过。
- 启动表现不冒充数据同步状态，不改变 UsageStats、SQLite 或桌面服务契约。

## 主要文件

- `android/AndroidManifest.xml`
- `android/res/`
- `resources/bundle/android/timearc-launcher-master.png`
- `qml/mobile/components/MobileLaunchOverlay.qml`
- `qml/mobile/MobileAppShell.qml`
- `qml/CMakeLists.txt`
- `tests/android_launch_experience_static_test.py`

## 验证

- Android launch、Android usage、mobile UI、desktop UX、resource manifest 静态测试通过。
- Windows Harness 全量构建通过；CTest 4/4 通过。
- Android arm64-v8a APK 通过 Harness `apk` 目标构建。
- APK：`com.timearc.app`，版本 1.0，minSdk 28，targetSdk 36，arm64-v8a。
- APK 包内已确认 adaptive/themed/round/legacy 图标及启动资源。
- 构建产物 SHA-256：`EBEBF8BD46B050885A87230BE070F4E575654AC783975C7A6F60D6CDA284213B`。
- Windows 移动预览成功保持运行 5 秒；Qt Harness 日志无待扫描文件。

## 已知缺口

- 本机 ADB 探测未返回，未完成 Android/HarmonyOS 真机安装和首帧录屏验收。
- APK 是 Qt debug 签名包，适合直接测试安装，不是应用市场发布签名包。
- HarmonyOS 5/6 是否能通过卓易通安装以及 Usage Access 是否完整暴露，取决于设备和兼容层支持，需真机确认。

## 回滚

回滚本功能提交即可移除 Android 图标/主题覆盖和 QML 进入层；无数据迁移，现有使用记录不受影响。
