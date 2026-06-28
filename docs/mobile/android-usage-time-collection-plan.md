# Android 软件使用时长获取与跨端合并呈现计划

> **For agentic workers:** REQUIRED SUB-SKILL: 后续真正实现本计划时，使用 `superpowers:subagent-driven-development` 或 `superpowers:executing-plans`，按本文 P0-P8 的 checkbox 顺序执行。实现阶段必须切到 Feature track，并遵守 `.harness/AGENTS.md`、`.harness/CHARTER.md` 和对应规则文件。

**Goal:** 完整实现 Android 手机端软件使用时长获取、SQLite 存储、TimeArc 后端读取、桌面端 + 手机端累计计算，以及手机端/桌面端统一呈现。

**Architecture:** Android 系统 API 由 Kotlin/Java 原生桥接层负责调用；TimeArc C++/Qt 后端负责统一数据库模型、聚合查询和 QML 暴露；QML mobile/desktop UI 只消费已经合并好的统计结果。v1 以 Android `UsageStatsManager` 为权威数据源，`queryEvents()` 只补最近 session；实时记录路线留作 v2 评估。

**Tech Stack:** Android Kotlin/Java、JNI/Qt Android Extras、UsageStatsManager、AppOpsManager、PackageManager、Settings Intent、WorkManager、SQLite/Qt SQL、C++ repository/service、QML mobile/desktop。

---

## 1. 总结论

Android 端最合理方案是 **读取系统 UsageStats**。Android 系统已经记录应用使用情况，TimeArc 应读取、归一化、入库，再与桌面端数据在统计层合并呈现。

桌面端和手机端不应该做成两个互相隔离的统计系统。正确做法是：

- 采集时保留 `platform` 和 `device_id`，方便知道数据来自 Windows、macOS、Android 或未来 iOS。
- 存储时保留原始来源表，避免把不同精细度的数据硬塞成一种形态。
- 查询时通过统一 view/service 聚合，最后在 both 端呈现「总使用时长」和「按平台拆分」。

完成 P0-P7 后，TimeArc 可以拿到 Android App 使用时长，并与桌面端累计计算。完成 P8 后，UI 就可以把合并结果呈现在手机端和桌面端。

## 2. 精细度边界

Android v1 可以稳定获取：

- 哪个 App 被使用。
- 每个 App 今天、本周、本月用了多久。
- 最近几天内，尝试通过 `queryEvents()` 还原前台/后台 session。
- 包级别使用时长与桌面端一起累计。

Android v1 通常不能稳定获取：

- App 内具体页面标题。
- 视频 App 正在看哪个视频。
- 音乐 App 正在听哪首歌。
- 聊天对象、文件名、网页 URL 等敏感细节。

桌面端现在可以记录 `window_title` 和 `media_title`，所以精细度高于 Android UsageStats。Android 官方 `UsageStats.getTotalTimeInForeground()` 提供的是包在前台的总毫秒数；`queryEvents()` 事件只保留几天，不能作为长期 session 级唯一来源。

不要在 v1 默认使用 AccessibilityService 做普通使用统计。官方定位是辅助无障碍用户使用设备和应用，合规风险高。

## 3. 统一数据命名

当前桌面端 SQL 已有核心命名：

| 现有字段 | 含义 |
| --- | --- |
| `apps.app_identifier` | 应用唯一标识 |
| `apps.app_name` | 应用原始名称 |
| `apps.display_name` | UI 展示名称 |
| `apps.platform` | 平台，当前默认 `windows` |
| `frontmost_sessions.window_title` | 桌面窗口标题 |
| `frontmost_sessions.start_unix_sec` | session 开始秒 |
| `frontmost_sessions.end_unix_sec` | session 结束秒 |
| `frontmost_sessions.duration_sec` | session 总秒数 |
| `frontmost_sessions.active_sec` | 活跃秒数 |
| `media_sessions.media_title` | 媒体标题 |
| `media_sessions.playback_sec` | 媒体播放秒数 |

Android 端必须尽量映射到同一套命名：

| Android 来源 | TimeArc 统一字段 |
| --- | --- |
| Android 包名 `com.tencent.mm` | `app_identifier = android:com.tencent.mm` |
| `PackageManager` 应用名 | `apps.app_name` / `apps.display_name` |
| 固定平台 | `apps.platform = android` |
| UsageStats 前台时长 | `foreground_sec`，聚合查询时并入 `active_sec` |
| queryEvents 前台开始 | `start_unix_sec` |
| queryEvents 前台结束 | `end_unix_sec` |
| Android 无窗口标题 | `window_title = NULL` 或 `Android foreground` |
| Android 无媒体标题 | 不写入 `media_sessions` |

推荐统一规则：

- `app_identifier` 使用 `platform:native_id` 格式，例如 `windows:chrome.exe`、`android:com.android.chrome`。
- `platform` 固定小写枚举：`windows`、`macos`、`linux`、`android`。
- 所有跨端统计统一输出 `active_sec`，Android 聚合时长从 `foreground_ms / 1000` 转换。
- UI 展示优先使用 `display_name`，没有时回退 `app_name`，再回退 `app_identifier`。

## 4. SQL 存储策略

建议 Android 另开一张聚合原始表，同时继续共用 `apps`，并允许 `frontmost_sessions` 存最近 session。

不要只把 Android 数据硬写进 `frontmost_sessions`。原因是 UsageStats 的主数据是「时间范围内的聚合值」，不是天然逐段 session。硬塞成 session 会制造假精度。

推荐新增表：

```sql
CREATE TABLE IF NOT EXISTS device_usage_summaries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    platform TEXT NOT NULL,
    device_id TEXT NOT NULL,
    app_identifier TEXT NOT NULL,
    date_local TEXT NOT NULL,
    range_start_unix_sec INTEGER NOT NULL,
    range_end_unix_sec INTEGER NOT NULL,
    foreground_sec INTEGER NOT NULL,
    source TEXT NOT NULL,
    first_synced_at INTEGER NOT NULL,
    last_synced_at INTEGER NOT NULL,
    UNIQUE(platform, device_id, app_identifier, date_local, source)
);
```

推荐新增字段或等价迁移：

```sql
ALTER TABLE frontmost_sessions ADD COLUMN platform TEXT DEFAULT 'windows';
ALTER TABLE frontmost_sessions ADD COLUMN device_id TEXT DEFAULT 'local';
```

如果不想立刻改 `frontmost_sessions`，也可以通过 `apps.platform` 间接判断平台；但长期建议 session 表显式带 `platform` 和 `device_id`，方便跨设备排重和聚合。

## 5. 跨端累计呈现口径

最终呈现不是「桌面一套、手机一套」，而是同一个统计结果支持平台拆分。

合并逻辑：

```text
某 App 总使用时长 =
    桌面 frontmost_sessions.active_sec
  + Android device_usage_summaries.foreground_sec
  + 未来其他平台同口径 active_sec
```

UI 应同时展示：

- 全部平台总计：例如「微信 今日 3h20m」。
- 平台拆分：例如「Android 2h10m，Windows 1h10m」。
- 精细度提示：桌面有窗口/媒体标题；Android v1 是 App 级时长。
- 过滤器：全部、桌面、手机。

注意：如果用户电脑和手机同时使用同一个 App，v1 默认直接累计，因为这更能解释「一个人在所有设备上的软件暴露/使用总量」。未来如果要做「人的注意力净时长」，再增加重叠区间去重模型。

## 6. 核心运行模式

Android v1 不是实时记录模式，而是「系统先记录，TimeArc 后读取」模式。用户打开 TimeArc 或后台同步任务触发时，TimeArc 读取 Android 系统已经统计好的使用情况，再写入自己的 SQLite 数据库。

完整数据流：

```text
Android 系统 UsageStats 服务
        ↓
Kotlin/Java 原生读取层
        ↓
JNI / Qt Android bridge
        ↓
C++/Qt 移动端 repository
        ↓
SQLite: apps + device_usage_summaries + 最近 session
        ↓
C++/Qt 跨端统计 service
        ↓
QML mobile / QML desktop 呈现
```

各部分职责：

| 阶段 | 负责语言 / 层级 | 具体职责 |
| --- | --- | --- |
| 系统记录 | Android OS | 系统持续记录每个 App 的前台使用情况，TimeArc 不需要自己每秒轮询 |
| 权限检测 | Kotlin/Java | 用 `AppOpsManager` 检测 Usage Access 是否已授权 |
| 权限跳转 | Kotlin/Java | 用 `Settings.ACTION_USAGE_ACCESS_SETTINGS` 打开系统授权页 |
| 聚合读取 | Kotlin/Java | 用 `UsageStatsManager.queryAndAggregateUsageStats()` 读取日/周/月包级时长 |
| 最近 session | Kotlin/Java | 用 `UsageStatsManager.queryEvents()` 读取最近几天事件并组装 session |
| 应用信息 | Kotlin/Java | 用 `PackageManager` 把包名解析成应用名、图标引用 |
| 周期触发 | Kotlin/Java | 用 WorkManager 做轻量补同步，不做秒级实时采样 |
| 跨语言传输 | JNI / Qt Android bridge | 把 Android DTO 传给 C++，只传结构化数据，不让 QML 直接调 Android API |
| 本地入库 | C++/Qt | `mobile_usage_repository` 写入 SQLite，做 upsert、时间转换和字段归一化 |
| 统一 app identity | C++/Qt | 把 Android 包名映射成 `app_identifier = android:<package_name>`，并写入 `apps` |
| 跨端合并 | C++/Qt | `cross_device_usage_service` 合并桌面 `frontmost_sessions` 与 Android `device_usage_summaries` |
| UI model | C++/Qt | 向 QML 暴露 `usageRows`、`permissionState`、`lastSyncAt`、平台过滤结果 |
| 呈现 | QML | 展示授权状态、同步状态、App 排名、总时长、桌面/手机拆分 |

触发时机：

- 用户打开 TimeArc：立即检查权限；已授权则读取今天和最近几天数据并入库。
- 用户切回 TimeArc 前台：做一次轻量增量同步。
- WorkManager 周期任务触发：后台补齐最近数据；无权限时安全退出。
- 用户手动刷新：重新读取当前时间范围并覆盖当天聚合记录。

写库原则：

- Kotlin/Java 不直接决定 TimeArc 的最终统计口径，只负责拿到 Android 系统数据。
- C++/Qt repository 是唯一入库边界，负责写入 `apps`、`device_usage_summaries` 和最近 session。
- QML 不直接访问 SQLite，也不自己合并桌面/手机数据。
- Android 聚合数据可以覆盖更新，因为同一天时长会增长；桌面 session 数据保持 append/unique session 语义。

这个模式的好处是：省电、权限边界清晰、和 Android 系统统计口径一致，也更容易与桌面端现有 SQLite 后端合并。

## 7. Android API 与 TimeArc 分工

### Kotlin/Java Android 原生层负责

目录建议：

```text
android/src/main/AndroidManifest.xml
android/src/main/java/com/timearc/mobile/usage/UsageAccessBridge.kt
android/src/main/java/com/timearc/mobile/usage/UsageStatsReader.kt
android/src/main/java/com/timearc/mobile/usage/UsageEventsReader.kt
android/src/main/java/com/timearc/mobile/usage/UsageSyncWorker.kt
android/src/main/java/com/timearc/mobile/usage/UsageRecordDto.kt
```

职责：

- 调用 `UsageStatsManager.queryAndAggregateUsageStats()`。
- 调用 `UsageStatsManager.queryEvents()`。
- 调用 `AppOpsManager` 检查 Usage Access。
- 打开 `Settings.ACTION_USAGE_ACCESS_SETTINGS`。
- 用 `PackageManager` 解析包名、应用名称和图标信息。
- 用 WorkManager 做周期同步触发。
- 通过 JNI 或 Qt Android bridge 把 DTO 传给 C++。

### C++/Qt 后端负责

当前已有目录：

```text
src/services/
src/services/database_manager.cpp
src/services/stats_service.cpp
src/services/usage_stat_manager.cpp
qml/mobile/
qml/desktop/
```

建议新增：

```text
src/services/mobile/
src/services/mobile/android_usage_bridge.h
src/services/mobile/android_usage_bridge.cpp
src/services/mobile/mobile_usage_repository.h
src/services/mobile/mobile_usage_repository.cpp
src/services/mobile/cross_device_usage_service.h
src/services/mobile/cross_device_usage_service.cpp
```

职责：

- `android_usage_bridge`：只负责从 Kotlin/Java 取回 UsageStats DTO。
- `mobile_usage_repository`：负责写入 `device_usage_summaries` 和 Android session。
- `cross_device_usage_service`：负责合并桌面 `frontmost_sessions` 与 Android `device_usage_summaries`。
- `database_manager`：负责迁移表结构、建索引、保证 SQLite schema。
- `stats_service` 或新 cross-device service：向 QML 暴露日/周/月合并结果。

### QML 前端负责

当前已有：

```text
qml/mobile/MobileAppShell.qml
qml/mobile/pages/
qml/mobile/components/
qml/desktop/
```

建议新增：

```text
qml/mobile/pages/MobileUsagePermissionPage.qml
qml/mobile/pages/MobileUsageStatsPage.qml
qml/mobile/components/MobilePlatformBreakdown.qml
qml/mobile/components/MobileUsageAppRow.qml
```

职责：

- 展示 Usage Access 授权入口。
- 展示同步状态和最近同步时间。
- 展示合并后的总时长。
- 提供平台过滤：全部 / 桌面 / 手机。
- 对 Android 数据显示「App 级统计」提示，不假装有窗口标题级精度。

## 8. 当前工程目录接入建议

当前工程已经有 `qml/mobile/`，说明手机 UI 层已有落点；`src/services/` 是现有 C++ 后端服务层；`src/service/` 是桌面原生后台采集服务，当前包含 `windows/`、`macos/`、`linux/`、`shared/`。

推荐目录策略：

- Android 原生 API 调用放在新的 `android/` 目录，不放进 `src/service/`。原因是 Android 手机端不是桌面后台服务同构实现，它依赖 Android Framework API 和 Gradle/Manifest。
- C++ 统一数据读写放在 `src/services/mobile/`，贴近现有 `database_manager`、`stats_service`。
- QML 手机页面继续放在 `qml/mobile/`。
- 跨端统计服务放在 C++，不要把累计计算写在 QML 里。

建议最终结构：

```text
android/
  src/main/AndroidManifest.xml
  src/main/java/com/timearc/mobile/usage/
    UsageAccessBridge.kt
    UsageStatsReader.kt
    UsageEventsReader.kt
    UsageSyncWorker.kt
    UsageRecordDto.kt

src/services/mobile/
  android_usage_bridge.h
  android_usage_bridge.cpp
  mobile_usage_repository.h
  mobile_usage_repository.cpp
  cross_device_usage_service.h
  cross_device_usage_service.cpp

qml/mobile/pages/
  MobileUsagePermissionPage.qml
  MobileUsageStatsPage.qml

qml/mobile/components/
  MobilePlatformBreakdown.qml
  MobileUsageAppRow.qml
```

## 9. 可执行计划

### P0：确认构建边界与目录落点

- [x] 确认 Android 构建入口使用 Qt for Android 还是独立 Gradle module。
- [x] 确认 `android/` 目录是否由 Qt Android package template 生成。
- [x] 确认新增 C++ 文件放入 `src/services/mobile/`。
- [x] 确认 QML 新页面放入 `qml/mobile/pages/`。
- [x] 确认本阶段不修改桌面采集服务 `src/service/windows|macos|linux`。

验收：

- 工程目录规划被记录在本文件或后续实现计划。
- 没有把 Android Framework 调用写进纯 C++ service 目录。

### P1：Usage Access 权限桥接

- [x] 在 Android manifest 声明 `android.permission.PACKAGE_USAGE_STATS`。
- [x] 新增 `UsageAccessBridge.kt`。（实现为 Java：`UsageAccessBridge.java`。）
- [x] 实现 `hasUsageAccess(context): Boolean`。
- [x] 实现 `openUsageAccessSettings(activity)`。
- [ ] C++ `android_usage_bridge` 暴露 `hasUsageAccess()`。
- [ ] QML 权限页根据授权状态切换按钮和说明。

验收：

- 首次安装显示未授权。
- 点击授权入口跳转系统 Usage Access 设置页。
- 授权后回到 App 能识别已授权。
- 撤销授权后不读取数据、不写空记录。

### P2：UsageStats 聚合读取

- [x] 新增 `UsageStatsReader.kt`。（实现为 Java：`UsageStatsReader.java`。）
- [x] 实现按本地日窗口读取 `queryAndAggregateUsageStats(begin, end)`。
- [x] 实现按本地周窗口读取。
- [x] 实现按本地月窗口读取。
- [x] 用 `getTotalTimeInForeground()` 生成 `foreground_ms`。
- [x] 用 `PackageManager` 填充 `package_name`、`app_label`。
- [x] 过滤 `foreground_ms <= 0`。
- [x] 通过 JNI/bridge 返回 DTO 数组给 C++。

验收：

- Android 模拟器和真机都能读取今日 App 使用列表。
- 主要 App 的时长能与系统使用情况页大致对齐。
- 无权限时返回明确错误状态，而不是空成功。

### P3：SQLite 表与 repository

- [x] 在 `database_manager` 迁移中新增 `device_usage_summaries`。
- [x] 为 `(platform, device_id, app_identifier, date_local, source)` 建唯一约束。
- [x] 新增 `mobile_usage_repository`。
- [x] 实现 `upsertDailyUsageSummary()`。
- [x] 保留 `first_synced_at`，更新 `last_synced_at`。
- [x] 写入或更新 `apps` 表，`platform = android`。
- [x] Android 包名统一映射为 `app_identifier = android:<package_name>`。

验收：

- 重复同步同一天同一 App 不产生重复行。
- 同一天时长增长时，记录被覆盖更新。
- `apps` 中能看到 Android App，且不与桌面 App 冲突。

### P4：最近 session 补强

- [x] 新增 `UsageEventsReader.kt`。（实现为 Java：`UsageEventsReader.java`。）
- [x] 查询最近 24 小时事件。
- [x] 查询最近 7 天事件。
- [x] 配对前台/后台事件生成 session。
- [ ] 没有结束事件时用查询窗口结束时间截断，并标记 `confidence = estimated`。
- [x] 将高可信 session 写入 `frontmost_sessions` 或后续专门 session 表。
- [x] Android session 写入时带 `platform = android`、`device_id`。

验收：

- 最近一天能显示 App 使用时间段。
- 锁屏、重启、App 快速切换不会生成负时长。
- 长期统计仍以 P2 聚合时长为准，不依赖 queryEvents 历史。

### P5：WorkManager 周期同步

- [x] 新增 `UsageSyncWorker.kt`。（实现为 Java：`UsageSyncWorker.java`。）
- [ ] App 启动/回前台时触发一次同步。
- [x] WorkManager 周期任务触发日增量同步。
- [x] 无权限时任务安全退出。
- [x] 网络不可用时只写本地库，等待后续同步。
- [ ] 记录最近同步状态和错误原因。

验收：

- App 关闭一段时间后重新打开，数据能补齐。
- 撤销权限后 worker 不刷错误日志。
- 低电量或省电模式下失败不会破坏已有数据。

### P6：跨端合并统计服务

- [ ] 新增 `cross_device_usage_service`。
- [ ] 实现按日期读取桌面 `frontmost_sessions.active_sec`。
- [ ] 实现按日期读取 Android `device_usage_summaries.foreground_sec`。
- [ ] 按 `app_identifier` 或归一化 app identity 聚合总时长。
- [ ] 输出 `total_sec`、`desktop_sec`、`mobile_sec`、`platform_breakdown`。
- [ ] 支持日、周、月范围。
- [ ] 支持平台过滤：all、desktop、mobile。

验收：

- 同一个 App 的桌面与手机时长能合并显示。
- UI 可以展开看到平台拆分。
- 统计结果不需要 QML 自己拼 SQL。

### P7：后端暴露给 QML

- [ ] 在现有 `StatsService` 或新服务中注册跨端统计 QObject。
- [ ] 暴露 `refreshUsage(range, platformFilter)`。
- [ ] 暴露 `usageRows` model。
- [ ] 每行包含 `displayName`、`totalSec`、`desktopSec`、`mobileSec`、`platformBreakdown`。
- [ ] 暴露 `permissionState` 和 `lastSyncAt`。
- [ ] QML 只绑定 model，不直接访问数据库。

验收：

- mobile QML 可以展示合并后的使用统计。
- desktop QML 后续也能复用同一服务。
- 切换平台过滤后数据一致。

### P8：UI 呈现

- [ ] 新增 `MobileUsagePermissionPage.qml`。
- [ ] 新增 `MobileUsageStatsPage.qml`。
- [ ] 新增 `MobilePlatformBreakdown.qml`。
- [ ] 新增 `MobileUsageAppRow.qml`。
- [ ] 手机端显示总时长、App 排名、平台拆分、最近同步状态。
- [ ] 桌面端统计页后续接入同一跨端 service。
- [ ] 对 Android 数据明确标记为 App 级统计。

验收：

- 用户能在手机端看到总使用时长。
- 用户能看到「全部 / 桌面 / 手机」切换。
- Android 数据不会显示虚假的窗口标题或媒体标题。
- 桌面端与手机端读取同一套合并统计口径。

### P9：测试与验收

- [ ] Windows 上用 Android Studio Emulator 测权限跳转。
- [ ] Emulator 测 UsageStats API 读取。
- [ ] Emulator 测 SQLite upsert。
- [ ] Emulator 测 QML 权限页与统计页。
- [ ] Pixel 或原生系统真机测试。
- [ ] 小米 / Redmi 真机测试。
- [ ] OPPO / OnePlus 真机测试。
- [ ] vivo 真机测试。
- [ ] Samsung 真机测试。
- [ ] Android 10、12、14、15/16 版本覆盖。
- [ ] 对比系统「数字健康 / 使用情况」主应用时长。
- [ ] 测跨 0 点。
- [ ] 测重启。
- [ ] 测撤销权限。
- [ ] 测省电模式。
- [ ] 测桌面 + 手机累计计算。

验收：

- P0-P7 完成后，Android 使用时长可以完整采集、入库、被 TimeArc 后端读取并与桌面累计。
- P8 完成后，手机端 UI 可以呈现合并结果。
- 桌面端接入同一 service 后，both 端可以看到一致的累计结果。

## 10. 官方 API 与权限参考

可直接调用的核心 API：

- `UsageStatsManager.queryAndAggregateUsageStats(beginTime, endTime)`：读取指定时间范围内按包名聚合后的使用统计，适合日、周、月总时长。
- `UsageStatsManager.queryUsageStats(intervalType, beginTime, endTime)`：按系统 interval 读取统计，适合需要保留系统分桶时使用。
- `UsageStatsManager.queryEvents(beginTime, endTime)`：读取最近几天内的使用事件，适合生成最近 session 明细；事件只保留几天，所以不能作为长期唯一数据源。
- `UsageStats.getTotalTimeInForeground()`：获取某个包在前台的总毫秒数，是 TimeArc v1 的核心时长字段。
- `android.permission.PACKAGE_USAGE_STATS`：声明使用情况访问意图，用户必须到系统设置里手动授权。
- `Settings.ACTION_USAGE_ACCESS_SETTINGS`：跳转到系统「使用情况访问权限」设置页。

官方参考：

- [UsageStatsManager](https://developer.android.com/reference/android/app/usage/UsageStatsManager)
- [UsageStats](https://developer.android.com/reference/android/app/usage/UsageStats)
- [PACKAGE_USAGE_STATS](https://developer.android.com/reference/android/Manifest.permission#PACKAGE_USAGE_STATS)
- [ACTION_USAGE_ACCESS_SETTINGS](https://developer.android.com/reference/android/provider/Settings#ACTION_USAGE_ACCESS_SETTINGS)
- [WorkManager WorkRequest](https://developer.android.com/develop/background-work/background-tasks/persistent/getting-started/define-work)
- [Foreground service types](https://developer.android.com/develop/background-work/services/fgs/service-types)
- [AccessibilityService](https://developer.android.com/reference/android/accessibilityservice/AccessibilityService)

## 11. 最终推荐路线

优先级固定为：

1. P0 目录和构建边界。
2. P1 Usage Access 权限桥接。
3. P2 UsageStats 聚合读取。
4. P3 SQLite 表与 repository。
5. P4 queryEvents 最近 session 补强。
6. P5 WorkManager 周期同步。
7. P6 跨端合并统计服务。
8. P7 后端暴露给 QML。
9. P8 UI 呈现。
10. P9 测试验收。

这条路线完成后，TimeArc 就能做到：Android 手机端获取软件使用时长，存入 SQL 数据库，由 C++/Qt 后端读取并与桌面端累计计算，最后在手机端和桌面端以统一口径呈现。
