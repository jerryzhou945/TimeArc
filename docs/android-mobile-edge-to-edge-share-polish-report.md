# Android 移动端全屏与分享打磨报告

## 目标

在保留鸿蒙卓易通可运行的 QtActivity 默认主题与现有计时权限/WorkManager 流程的前提下，修复系统栏未铺满、功能图标缺字、应用图标直角、华为桌面包名泄露以及分享预览布局失衡。

## 已完成

- Android 运行时启用 Edge-to-Edge，状态栏和导航栏透明；页面背景铺满，交互内容使用系统安全区。
- 深浅模式同步切换系统栏图标明暗，不重新绑定 `TimeArcLaunchTheme`。
- 设置和分享操作改用离线 Material Symbols SVG，移除 Unicode 图标字符。
- 所有应用图标通过统一约 22% 圆角遮罩显示；无华为桌面图标时使用 Home 语义 fallback。
- Android 元数据解析可从 `com.huawei.android.launcher.LauncherApplication` 还原基础包名并显示“华为桌面”；C++ 展示层同步覆盖旧数据库记录。
- 单应用、排行榜和月报预览提升到全窗口层级，底部导航不再穿透；海报响应屏幕高度，长名称支持两行。
- 月报移除嵌套玻璃事实卡，改为季节场景、标题、大时长和简洁摘要的单一层级。
- Material Symbols Apache-2.0 全文已离线打包并加入 README、许可规则与应用内许可清单。

## 验证

- Windows harness build：PASS。
- Android UI target build：PASS。
- Android APK target build：PASS。
- CTest：4/4 PASS。
- `android_launch_experience_static_test.py`：PASS。
- `android_usage_static_test.py`：PASS。
- `mobile_qml_static_test.py`：PASS。
- 移动预览进程保持响应；Qt 日志扫描未发现日志文件/警告。
- APK v2 签名：PASS；包名 `com.timearc.app`；ABI `arm64-v8a`；保留 `PACKAGE_USAGE_STATS`。
- 合并 Manifest 的 QtActivity 无 `android:theme` 属性。

## APK

- 文件：`dist/TimeArc-1.0-android-arm64-v8a-mobile-polish-debug.apk`
- SHA-256：`ADABE1684BB591698C123BAF52A01D5D00FA2F8BBA5D4B54012DF1B824AC2984`

## 已知限制

- Android 全目标构建仍会错误尝试链接桌面 service 的空 Linux stub；本次按既有 Android 发布路径构建 `time-arc` 与 `time-arc_make_apk`，未修改冻结 CMake。
- Edge-to-Edge 系统图标明暗、卓易通分享面板和实际圆角裁切仍需 Pura 90 Pro 真机视觉确认。

## 回滚

回滚本功能提交即可恢复之前的移动 UI；不涉及数据库迁移。不要回滚已验证的默认 Activity Theme 提交，否则可能恢复鸿蒙一秒退出。
