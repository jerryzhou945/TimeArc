# Android 使用时长后端采集 P0-P5 实施报告

日期：2026-06-29  
分支：`codex/android-usage-backend`

## 已完成

- P0：建立 Android 原生层目录 `android/src/main/java/com/timearc/mobile/usage/`，并确认 Android Framework 调用不放入桌面 `src/service/`。
- P1：新增 `PACKAGE_USAGE_STATS` manifest 权限、Usage Access 授权检测、系统授权页跳转。
- P2：新增 UsageStats 聚合读取，支持任意 begin/end 窗口，按 `getTotalTimeInForeground()` 输出包级前台时长。
- P3：新增 `device_usage_summaries` 表和 `MobileUsageRepository`，支持 `android:<package_name>` 统一命名、Android app upsert、日聚合 upsert 与汇总查询。
- P4：新增 UsageEvents 最近 session 解析，新增 `device_usage_sessions` 表，支持 Android session 去重写入和范围查询。
- P5：新增 WorkManager worker/scheduler、即时同步入口方法、Android DTO 到 C++ repository 的 JNI bridge。

## 未完成/后续接入

- QML 权限页还未接入 `hasUsageAccess()` 状态。
- App 启动/回前台时调用 `UsageSyncScheduler.enqueueImmediateSync()` 的生命周期 hook 还未接入。
- WorkManager AndroidX 依赖还未接入 Qt Android Gradle 打包链；当前代码和依赖说明已放在 `android/README.md`。
- `queryEvents()` 对未闭合 session 已用查询窗口结束时间截断，但数据库暂未增加 `confidence = estimated` 字段。
- P6/P7/P8 的跨端合并统计 service、桌面/mobile UI 呈现还未实现。

## 验证

- `javac` 使用 Android SDK `android-36/android.jar` 编译核心 Android 采集/桥接类通过。
- `.harness/tools/build.py` 通过。
- `ctest --test-dir build --output-on-failure -R timearc_db_smoke` 通过。
- `.harness/tools/harness_check.py` 通过。

## 相关提交

- `a47e1c7` Add Android usage access reader
- `80131bd` Add mobile usage summary repository
- `4760d87` Add Android usage event session storage
- `89b2c34` Add Android usage sync scheduler
