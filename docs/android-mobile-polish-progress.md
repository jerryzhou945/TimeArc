# Android 移动端全屏与分享打磨进度

- [x] Edge-to-Edge 系统栏与安全区
- [x] Material Symbols SVG 操作图标
- [x] 全局应用图标圆角遮罩
- [x] 华为桌面名称与图标适配
- [x] 单应用分享预览重构
- [x] 月报分享预览重构
- [x] Android/HarmonyOS 构建与回归

## 状态

- Completed: 全屏、SVG、圆角、华为元数据、分享重构、Android APK 与报告均完成。
- Incomplete: Pura 90 Pro 卓易通真机视觉验收。
- Verification: Windows/Android build PASS；CTest 4/4；三组静态测试 PASS；APK v2 签名 PASS。
- Next: 安装 `TimeArc-1.0-android-arm64-v8a-mobile-polish-debug.apk` 验收系统栏和分享图。
- Risks: Android 全目标仍含桌面 service 链接缺口；本次 APK 使用已验证的 UI/APK 目标路径。
