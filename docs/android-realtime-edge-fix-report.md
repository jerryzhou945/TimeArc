# Android 真圆角、全屏与实时记录修复报告

## 目标

修复 Pura 90 Pro 卓易通中应用图标仍为方形、顶部和底部没有铺满，以及当天数据没有刷新而全部集中到 7 月 1 日的问题，同时保留已验证可启动的 Qt 默认主题。

## 修复内容

- 应用图标改用 `MobileRoundedFrame` 的 GPU 遮罩，22% 圆角真正作用于图片像素。
- 新增轻量 `TimeArcActivity`，只负责 Activity 生命周期；Manifest 不绑定自定义 Theme。
- Activity 创建和恢复时重新设置透明系统栏、兼容布局标志与刘海短边模式。
- 每次进入 TimeArc 都请求唯一的立即同步，周期 WorkManager 保留。
- Android UsageStats 从“上月初到现在的一整段”改为按本地自然日逐日读取。
- 每日导入前只清理同设备、同日期、同聚合来源的旧摘要；其他来源和原始会话保留。
- WorkManager 完成持久化后通过 JNI 通知 Qt，再刷新首页、统计、记忆湖和设置页。

## 验证

- Windows Harness build：PASS。
- CTest：4/4 PASS，包括每日替换不删除会话和其他来源。
- Android UI target：PASS。
- Android APK target / javac：PASS。
- 三组移动端静态回归：PASS。
- APK v2 签名：PASS；包名 `com.timearc.app`；ABI `arm64-v8a`。
- `PACKAGE_USAGE_STATS`、WorkManager 权限保留。
- 合并 Manifest 使用 `TimeArcActivity`，且没有 `android:theme` 属性。

## APK

- 文件：`dist/TimeArc-1.0-android-arm64-v8a-realtime-edge-debug.apk`
- SHA-256：`8DC43532F86623D3A93DC64D74271C3D9B2C235AEF12D000BC95211DA76634B7`

## 已知限制

Pura 90 Pro 卓易通的实际系统栏覆盖、ChatGPT 图标圆角和当天 UsageStats 修复仍需安装本包后确认。浅色模式本轮未调整。

## 回滚

分别回滚圆角遮罩、Activity 生命周期或逐日同步提交即可恢复对应旧行为；不要恢复 `TimeArcLaunchTheme` 绑定，否则可能重新出现一秒退出。
