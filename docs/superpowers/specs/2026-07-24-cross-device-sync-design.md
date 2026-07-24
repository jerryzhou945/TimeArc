# TimeArc 中国大陆跨端同步设计

**状态：** 已批准

**日期：** 2026-07-24

**目标分支：** `dev`

**首发地区：** 中国大陆

**首版应用范围：** 二次元游戏、社交、音乐/视频/直播

## 1. 目标与非目标

本文件是跨端同步的主架构规格。由于账号、云端 API、本机同步、桌面 UI 和
Android 调度是可独立交付的子系统，实施时每个 Epic 单独生成逐文件执行计划，
一次只激活一个 Epic；不把十个 Epic 塞进一个长期不收敛的功能分支。

### 1.1 目标

- 使用同一个 TimeArc 账号连接桌面端与 Android 手机端。
- 只同步两端能够归一到同一 `canonical_app_id` 的白名单应用。
- 云端只保存按“用户 × 设备 × 日期 × 应用”聚合后的使用时长。
- 页面展示总时长、桌面端时长、手机端时长和各自占比。
- 离线可继续记录；恢复网络后自动幂等补传。
- 首版面向中国大陆，登录和同步不依赖跨境链路。
- 云服务可以替换，客户端不直接耦合云数据库。

### 1.2 非目标

- 不上传窗口标题、聊天对象、媒体标题、文件路径、浏览内容或完整会话。
- 不同步所有软件；未知应用默认留在本地。
- 不做设备间实时状态、在线列表、好友或公开排行榜。
- 不在首版同步截图、图标文件、头像之外的媒体资源。
- 不修改 `timearc_service.db` 的表结构和单写者约束。
- 不承诺手机端后台音乐播放时长；首版跨端口径是前台使用时长。

## 2. 推荐架构

```text
Windows timearc_service.db ──只读──┐
                                   │
Android timearc.db ────────────────┤
                                   ▼
                         LocalUsageAggregator
                                   │
                         CanonicalAppResolver
                                   │
                         隐私过滤 + 每日聚合
                                   │
                             SyncOutbox
                                   │ HTTPS JSON
                                   ▼
                    TimeArc Sync API（Go）
                      CloudBase 云托管
                       │             │
                       │             └─ CloudBase Auth
                       ▼
                  CloudBase MySQL
```

客户端只认识 TimeArc Sync API。CloudBase Auth、MySQL 和部署方式被服务端
适配层隐藏，未来可替换为 Supabase、自建 PostgreSQL 或其他国内云服务。

### 2.1 本机组件

| 组件 | 职责 | 依赖 |
|---|---|---|
| `AuthManager` | 注册、登录、刷新会话、退出、设备撤销 | Qt Network、平台安全存储 |
| `CanonicalAppCatalog` | 缓存云端应用目录与别名，按版本更新 | `timearc.db` |
| `CanonicalAppResolver` | 把 exe、Android package、站点 ID 映射为统一应用 ID | 应用目录 |
| `LocalUsageAggregator` | 将本机记录按本地日期切分并聚合 | 桌面 service DB 只读；Android GUI DB |
| `SyncRepository` | outbox、游标、远端缓存、行哈希 | `timearc.db` |
| `SyncManager` | push/pull、退避重试、网络状态、手动同步 | Auth、Repository、Network |
| `CrossDeviceStatsManager` | 为 QML 提供总量、设备占比和状态 | 远端缓存、本机数据 |

这些组件全部属于 UI/GUI 层。后台采集服务不访问网络、不持有账号令牌，也
不写云端，继续只负责本机采样。

### 2.2 服务端组件

| 组件 | 职责 |
|---|---|
| Auth adapter | 验证 CloudBase access token，提取不可伪造的用户 ID |
| Device service | 注册、重命名、撤销设备 |
| Catalog service | 发布带版本号的 canonical app 与 aliases |
| Sync service | 校验批次、幂等 upsert、生成服务端 change sequence |
| Query service | 按日期、设备、类别和应用返回聚合统计 |
| Privacy service | 导出云端数据、删除设备数据、删除全部云端数据 |

## 3. 数据口径

### 3.1 首版唯一跨端指标

`interactive_sec`：应用位于设备前台且用户未被判定为空闲的秒数。

- Windows：来自 `frontmost_sessions.active_sec`，按本地日期切分。
- Android：来自 UsageEvents/UsageStats 得到的前台会话。
- 桌面 `media_sessions` 继续服务本地统计，但首版不上云。
- 同时使用两台设备时，两台设备的时长分别保留；“总设备时长”是二者之和，
  页面明确标注为设备使用总量，不推断人的唯一注意力时长。

采用这一口径是为了让桌面和手机可比较。Android 当前无法可靠获得所有应用
的后台实际播放时长，因此不能把桌面音频时长混入首版跨端总量。

### 3.2 日期和时区

- 客户端在记录发生地按本地午夜切日。
- 上传 `local_date`、`timezone_name`、`utc_offset_min`。
- 跨午夜会话在本地拆成两个日期桶。
- 用户跨时区后，新记录按新时区归档；既有日期不重写。
- 服务端时间只用于版本、游标和审计，不用于重算用户日期。

## 4. 统一应用模型

### 4.1 标识规则

`canonical_app_id` 使用稳定的小写命名空间：

- 游戏：`game:<slug>`
- 社交：`social:<slug>`
- 音乐：`music:<slug>`
- 视频：`video:<slug>`
- 直播：`live:<slug>`

同一产品的国内版、国际版和不同平台包名映射到同一 ID。展示名、分类和别名
可以更新，但 canonical ID 一旦发布不得复用或改名。

### 4.2 匹配优先级

1. Android 完整 package name 精确匹配。
2. 桌面稳定 app ID 或 exe 文件名精确匹配。
3. 浏览器站点 ID 精确匹配，如 `site:bilibili`。
4. exe + 安装路径发行商片段的组合匹配。
5. 窗口标题只作为第二条件，禁止单独用宽泛标题匹配。

禁止只用 `game.exe`、`client.exe`、`launcher.exe` 等通用进程名。匹配冲突时
返回 unknown，不上传。

### 4.3 首版应用目录

下表是首版 seed catalog。`已知` 可以直接进入实现；`设备验证` 必须通过真实
Windows 采集记录和 Android 安装包名测试后才能在生产目录中启用。

#### 二次元游戏

| canonical ID | 展示名 | Windows aliases | Android aliases | 状态 |
|---|---|---|---|---|
| `game:genshin-impact` | 原神 | `YuanShen.exe`, `GenshinImpact.exe` | `com.miHoYo.Yuanshen`, `com.miHoYo.GenshinImpact` | 已知 |
| `game:honkai-star-rail` | 崩坏：星穹铁道 | `StarRail.exe` | `com.miHoYo.hkrpg`, `com.HoYoverse.hkrpgoversea` | 已知 |
| `game:zenless-zone-zero` | 绝区零 | `ZenlessZoneZero.exe` | `com.miHoYo.Nap`, `com.HoYoverse.Nap` | 设备验证 |
| `game:wuthering-waves` | 鸣潮 | 发行商路径 + `Client-Win64-Shipping.exe` | `com.kurogame.mingchao`, `com.kurogame.wutheringwaves.global` | 设备验证 |
| `game:honkai-impact-3` | 崩坏3 | 产品标题 + 安装路径组合 | 国内包、国际包待设备采集 | 设备验证 |
| `game:punishing-gray-raven` | 战双帕弥什 | 产品标题 + 库洛路径组合 | `com.kurogame.haru` 及渠道包待验证 | 设备验证 |
| `game:snowbreak` | 尘白禁区 | 产品标题 + 西山居路径组合 | 国内包、国际包待设备采集 | 设备验证 |
| `game:tower-of-fantasy` | 幻塔 | 产品标题 + 完美世界路径组合 | 国内包、国际包待设备采集 | 设备验证 |
| `game:infinity-nikki` | 无限暖暖 | 产品标题 + 叠纸路径组合 | 国内包、国际包待设备采集 | 设备验证 |

#### 社交与沟通

| canonical ID | 展示名 | Windows aliases | Android aliases | 状态 |
|---|---|---|---|---|
| `social:wechat` | 微信 | `WeChat.exe`, `Weixin.exe` | `com.tencent.mm` | 已知 |
| `social:qq` | QQ | `QQ.exe` | `com.tencent.mobileqq` | 已知 |
| `social:discord` | Discord | `Discord.exe` | `com.discord` | 已知 |
| `social:telegram` | Telegram | `Telegram.exe` | `org.telegram.messenger` | 已知 |
| `social:dingtalk` | 钉钉 | `DingTalk.exe` | `com.alibaba.android.rimet` | 已知 |
| `social:feishu` | 飞书 | `Feishu.exe` | `com.ss.android.lark` | 已知 |
| `social:tencent-meeting` | 腾讯会议 | `wemeetapp.exe` | `com.tencent.wemeet.app` | 设备验证 |
| `social:zoom` | Zoom | `Zoom.exe` | `us.zoom.videomeetings` | 已知 |
| `social:microsoft-teams` | Microsoft Teams | `ms-teams.exe`, `Teams.exe` | `com.microsoft.teams` | 设备验证 |

聊天窗口标题、联系人、群名、频道名和会议标题均在匹配完成后丢弃，不进入
outbox。

#### 音乐、视频与直播

| canonical ID | 展示名 | Windows / site aliases | Android aliases | 状态 |
|---|---|---|---|---|
| `music:qq-music` | QQ音乐 | `QQMusic.exe`, `site:qq-music` | `com.tencent.qqmusic` | 已知 |
| `music:netease-cloud-music` | 网易云音乐 | `cloudmusic.exe`, `site:music-163` | `com.netease.cloudmusic` | 已知 |
| `music:spotify` | Spotify | `Spotify.exe`, `site:spotify` | `com.spotify.music` | 已知 |
| `music:apple-music` | Apple Music | `AppleMusic.exe`, `site:apple-music` | `com.apple.android.music` | 设备验证 |
| `video:bilibili` | 哔哩哔哩 | 客户端别名、`site:bilibili` | `tv.danmaku.bili` | 已知 |
| `video:tencent-video` | 腾讯视频 | `QQLive.exe`, `TencentVideo.exe`, `site:tencent-video` | `com.tencent.qqlive` | 已知 |
| `video:iqiyi` | 爱奇艺 | `QyClient.exe`, `site:iqiyi` | `com.qiyi.video` | 已知 |
| `video:youku` | 优酷 | `Youku.exe`, `site:youku` | `com.youku.phone` | 设备验证 |
| `video:youtube` | YouTube | `site:youtube` | `com.google.android.youtube` | 已知 |
| `video:douyin` | 抖音 | 客户端别名、`site:douyin` | `com.ss.android.ugc.aweme` | 设备验证 |
| `video:xiaohongshu` | 小红书 | `site:xiaohongshu` | `com.xingin.xhs` | 已知 |
| `live:douyu` | 斗鱼直播 | 客户端别名、`site:douyu` | `air.tv.douyu.android` | 设备验证 |
| `live:huya` | 虎牙直播 | 客户端别名、`site:huya` | Android 包待设备采集 | 设备验证 |
| `live:bilibili-live` | 哔哩哔哩直播 | `site:bilibili-live` | `tv.danmaku.bili` | 已知 |

同一个 Android 包可以根据产品维度只映射到一个 canonical ID。哔哩哔哩普通
视频与直播无法仅凭 Android package 区分，因此 Android 统一记为
`video:bilibili`；桌面站点能够可靠识别直播页时才使用
`live:bilibili-live`。

### 4.4 目录发布与回滚

- 服务端目录具有递增 `catalog_version`。
- 客户端请求时发送本地版本和 `If-None-Match`。
- 目录返回 canonical apps、aliases、禁用项和 SHA-256。
- 客户端在事务中替换目录；校验失败继续使用旧版本。
- alias 误匹配时通过禁用 alias 发布新版本，不删除 canonical app。
- 已上传的历史数据不因目录更新自动改写；需要显式 migration job。

## 5. 云端 MySQL 数据库

所有业务表使用 `utf8mb4`、UTC `DATETIME(3)`。CloudBase Auth 是账号来源，
业务表只保存其稳定 UID，不保存密码。

### 5.1 `schema_migrations`

| 字段 | 类型 | 约束 |
|---|---|---|
| `version` | BIGINT | PK |
| `name` | VARCHAR(120) | NOT NULL |
| `checksum` | CHAR(64) | NOT NULL |
| `applied_at` | DATETIME(3) | NOT NULL |

### 5.2 `user_profiles`

| 字段 | 类型 | 约束 |
|---|---|---|
| `user_id` | VARCHAR(64) | PK，来自 Auth |
| `display_name` | VARCHAR(80) | 可空 |
| `timezone_name` | VARCHAR(64) | NOT NULL |
| `sync_enabled` | BOOLEAN | NOT NULL DEFAULT FALSE |
| `created_at` | DATETIME(3) | NOT NULL |
| `updated_at` | DATETIME(3) | NOT NULL |
| `cloud_deleted_at` | DATETIME(3) | 可空 |

### 5.3 `devices`

| 字段 | 类型 | 约束 |
|---|---|---|
| `device_id` | CHAR(36) | PK，客户端生成 UUID |
| `user_id` | VARCHAR(64) | NOT NULL |
| `platform` | VARCHAR(16) | `windows` / `android` |
| `device_name` | VARCHAR(100) | NOT NULL |
| `install_id` | CHAR(36) | NOT NULL |
| `app_version` | VARCHAR(32) | NOT NULL |
| `catalog_version` | BIGINT | NOT NULL DEFAULT 0 |
| `last_seen_at` | DATETIME(3) | NOT NULL |
| `revoked_at` | DATETIME(3) | 可空 |
| `created_at` | DATETIME(3) | NOT NULL |

索引与约束：

- `UNIQUE(user_id, install_id)`
- `INDEX(user_id, revoked_at)`
- 被撤销设备的 access token 即使尚未过期，Sync API 也拒绝写入。

### 5.4 `canonical_apps`

| 字段 | 类型 | 约束 |
|---|---|---|
| `canonical_app_id` | VARCHAR(80) | PK |
| `category` | VARCHAR(24) | NOT NULL |
| `display_name_zh_cn` | VARCHAR(100) | NOT NULL |
| `enabled` | BOOLEAN | NOT NULL |
| `catalog_version` | BIGINT | NOT NULL |
| `created_at` | DATETIME(3) | NOT NULL |
| `updated_at` | DATETIME(3) | NOT NULL |

### 5.5 `app_aliases`

| 字段 | 类型 | 约束 |
|---|---|---|
| `alias_id` | BIGINT | PK AUTO_INCREMENT |
| `canonical_app_id` | VARCHAR(80) | FK |
| `platform` | VARCHAR(16) | NOT NULL |
| `matcher_type` | VARCHAR(32) | NOT NULL |
| `matcher_value` | VARCHAR(255) | NOT NULL |
| `secondary_value` | VARCHAR(255) | 可空 |
| `priority` | SMALLINT | NOT NULL |
| `verification_state` | VARCHAR(16) | `active` / `verify` / `disabled` |
| `catalog_version` | BIGINT | NOT NULL |

`UNIQUE(platform, matcher_type, matcher_value, secondary_value)` 防止同一别名
同时指向多个产品。

### 5.6 `sync_batches`

| 字段 | 类型 | 约束 |
|---|---|---|
| `batch_id` | CHAR(36) | PK，客户端生成 |
| `user_id` | VARCHAR(64) | NOT NULL |
| `device_id` | CHAR(36) | NOT NULL |
| `payload_sha256` | CHAR(64) | NOT NULL |
| `row_count` | SMALLINT | NOT NULL |
| `status` | VARCHAR(16) | `accepted` / `partial` / `rejected` |
| `received_at` | DATETIME(3) | NOT NULL |

相同 `batch_id` 与相同 hash 返回首次结果；相同 ID 不同 hash 返回 409。

### 5.7 `daily_usage`

| 字段 | 类型 | 约束 |
|---|---|---|
| `usage_id` | BIGINT | PK AUTO_INCREMENT |
| `user_id` | VARCHAR(64) | NOT NULL |
| `device_id` | CHAR(36) | NOT NULL |
| `canonical_app_id` | VARCHAR(80) | NOT NULL |
| `local_date` | DATE | NOT NULL |
| `timezone_name` | VARCHAR(64) | NOT NULL |
| `utc_offset_min` | SMALLINT | NOT NULL |
| `interactive_sec` | INT UNSIGNED | NOT NULL |
| `source_revision` | BIGINT UNSIGNED | NOT NULL |
| `source_hash` | CHAR(64) | NOT NULL |
| `catalog_version` | BIGINT | NOT NULL |
| `is_deleted` | BOOLEAN | NOT NULL DEFAULT FALSE |
| `server_updated_at` | DATETIME(3) | NOT NULL |

核心约束与索引：

- `UNIQUE(user_id, device_id, canonical_app_id, local_date)`
- `INDEX(user_id, local_date, is_deleted)`
- `INDEX(user_id, canonical_app_id, local_date)`
- `interactive_sec <= 86400`
- 设备只能写自己的 `device_id`。

### 5.8 `usage_change_log`

| 字段 | 类型 | 约束 |
|---|---|---|
| `change_seq` | BIGINT | PK AUTO_INCREMENT |
| `user_id` | VARCHAR(64) | NOT NULL |
| `usage_id` | BIGINT | NOT NULL |
| `operation` | VARCHAR(12) | `upsert` / `delete` |
| `changed_at` | DATETIME(3) | NOT NULL |

`INDEX(user_id, change_seq)` 支持不依赖客户端时钟的增量 pull。日志保留 180
天；游标过旧时服务端返回 `full_resync_required`。

### 5.9 `account_audit_events`

只记录安全事件类型、用户、设备、服务端时间和结果，不记录使用内容。用于设备
撤销、全部退出、数据导出和云端数据删除的审计。

## 6. 本地 `timearc.db` 新表

这些表由 GUI 写入，不触碰 `timearc_service.db`。

| 表 | 用途 |
|---|---|
| `sync_state` | 当前账号 ID、catalog version、pull cursor、最近成功/失败时间 |
| `sync_devices` | 当前安装的 device/install UUID、名称和撤销状态 |
| `sync_outbox` | 待上传绝对值行、source revision、hash、重试次数 |
| `sync_remote_daily_cache` | 从其他设备拉取的 daily usage |
| `canonical_apps_cache` | canonical app 目录 |
| `app_aliases_cache` | 平台别名目录 |
| `sync_app_preferences` | 用户对每个 canonical app 的同步开关 |

access token 和 refresh token 不以明文写入 SQLite：

- Windows 使用 Credential Manager。
- Android 使用 Keystore 加密后保存。
- 登出删除本机令牌，但不删除本机使用记录。

## 7. HTTP API

所有接口使用 `/v1`、HTTPS、JSON UTF-8，并要求：

```http
Authorization: Bearer <cloudbase-access-token>
X-TimeArc-Device-Id: <uuid>
X-TimeArc-App-Version: <semver>
```

### 7.1 设备

```text
POST   /v1/devices/register
GET    /v1/devices
PATCH  /v1/devices/{device_id}
DELETE /v1/devices/{device_id}
POST   /v1/devices/revoke-all
```

注册请求包含 install ID、平台、设备显示名和 app version。服务端从 token 获取
用户 ID，忽略客户端提交的任何 `user_id`。

### 7.2 目录

```text
GET /v1/catalog?after_version=<n>
```

无更新返回 304；有更新返回完整目录。目录响应不包含本地 exe 路径或任何用户
数据。

### 7.3 Push

```text
POST /v1/sync/push
```

单批最多 200 行，最大 256 KiB：

```json
{
  "schema_version": 1,
  "batch_id": "uuid",
  "device_id": "uuid",
  "catalog_version": 12,
  "rows": [
    {
      "canonical_app_id": "game:genshin-impact",
      "local_date": "2026-07-24",
      "timezone_name": "Asia/Shanghai",
      "utc_offset_min": 480,
      "interactive_sec": 5400,
      "source_revision": 3,
      "source_hash": "sha256"
    }
  ]
}
```

上传绝对累计值而不是增量值，避免网络重试造成重复计时。

服务端逐行处理：

1. 校验 token、设备归属、设备未撤销。
2. 校验 schema/catalog 版本和 canonical app 已启用。
3. 校验日期、时区、秒数和 hash。
4. 若 `source_revision` 小于等于当前行，返回 `stale`。
5. 若 revision 更大，在事务中 upsert 并追加 change log。
6. 提交批次结果。

### 7.4 Pull

```text
GET /v1/sync/pull?after=<change_seq>&limit=500
```

响应：

```json
{
  "next_cursor": 88921,
  "has_more": false,
  "rows": [
    {
      "change_seq": 88921,
      "operation": "upsert",
      "device_id": "uuid",
      "platform": "windows",
      "canonical_app_id": "game:genshin-impact",
      "local_date": "2026-07-24",
      "interactive_sec": 5400,
      "server_updated_at": "2026-07-24T03:20:00.000Z"
    }
  ]
}
```

客户端只有在整个响应事务写入本地缓存成功后才推进 cursor。

### 7.5 查询

```text
GET /v1/usage/summary?from=YYYY-MM-DD&to=YYYY-MM-DD
GET /v1/usage/apps?from=...&to=...&category=...
GET /v1/usage/devices?from=...&to=...
```

查询接口只返回当前用户数据。首版不需要 Realtime 或 WebSocket。

### 7.6 隐私

```text
GET    /v1/account/export
DELETE /v1/account/cloud-data
DELETE /v1/account
```

删除操作需要最近登录验证和显式确认。账号删除先撤销所有设备，再删除业务
数据，最后调用 Auth 删除账号；失败时可重试，不留下仍可写入的设备。

## 8. 同步状态机

```text
Disabled
  └─用户登录并同意同步→ CatalogLoading
CatalogLoading
  ├─成功→ RegisteringDevice
  └─失败→ WaitingForNetwork
RegisteringDevice
  ├─成功→ BackfillPreparing
  └─认证失败→ ReauthRequired
BackfillPreparing
  └─默认最近 90 天，用户可显式选择全部历史→ Pushing
Pushing
  ├─成功→ Pulling
  ├─429/5xx/超时→ Backoff
  ├─401→ RefreshingToken
  └─409→ ConflictReview
Pulling
  ├─完成→ Idle
  └─游标过旧→ FullResync
Idle
  └─本地变更/恢复前台/手动同步/定时器→ Pushing
```

### 8.1 触发时机

- 登录成功后首次回填。
- 桌面端启动、每 15 分钟、跨日、退出前和手动同步。
- Android 恢复前台、系统允许的 WorkManager 周期任务和手动同步。
- 默认只重算今天与昨天；首次回填按所选历史范围分批扫描。

### 8.2 重试

- 网络错误、408、429、5xx：指数退避加随机抖动，15 秒至 6 小时。
- 401：只刷新一次 token；仍失败进入重新登录。
- 400/403/422：不自动死循环，隔离坏行并展示可诊断错误码。
- 目录版本过旧：先刷新目录，再重建受影响的 outbox。
- 每次重试复用 batch ID 和 payload hash。

## 9. 冲突与幂等

- 一台设备只能写自己名下的 daily rows，因此没有跨设备同一行写冲突。
- 同一设备同一天同应用上传最新绝对累计值。
- `source_revision` 单调递增；低版本不会覆盖高版本。
- 同 batch 重试得到同结果。
- 本机聚合结果未变化时，source hash 相同，不进入 outbox。
- 设备改名只改变设备元数据，不影响历史行。
- 卸载重装生成新 install/device ID，旧设备在账号页可撤销。
- 用户关闭某应用同步后发送 tombstone，删除该应用的云端历史；本地保留。

## 10. 隐私与安全

- 跨端同步默认关闭，必须登录并完成数据预览确认。
- 默认回填最近 90 天；“全部历史”需要单独选择。
- 上传前页面展示将同步的应用列表和估算行数。
- 只上传 canonical ID、日期、时区、设备和秒数。
- 禁止日志输出 token、邮箱完整值或 payload 明文。
- 服务端按用户和设备做授权，不能相信请求中的 user ID。
- API 限流：用户、设备、IP 三层。
- MySQL 凭据只存在云托管服务端环境变量/密钥管理中。
- 生产使用备案自定义域名和 HTTPS；CloudBase 默认域名只用于开发测试。
- 提供云端数据导出、单应用删除、单设备删除和全部云端数据删除。

## 11. UI 设计

### 11.1 设置页

桌面和手机均增加“账号与跨端同步”：

- 未登录：功能说明、隐私摘要、注册/登录入口。
- 已登录：邮箱脱敏、同步总开关、应用分类与单应用开关。
- 历史范围：最近 90 天 / 全部历史。
- 设备管理：设备名、平台、最近同步、撤销。
- 状态：正在同步、已同步、等待网络、需要登录、部分失败。
- 操作：立即同步、导出云端数据、删除云端数据、退出登录。

### 11.2 统计呈现

每个日期范围显示：

- 跨端设备使用总量。
- 桌面端时长、手机端时长和百分比。
- 三类应用的分段条。
- 每个应用的总时长、桌面/手机分量和占比。
- 设备筛选和“仅本机/全部设备”切换。
- 数据更新时间和口径说明。

当远端不可用时，本机统计仍正常；跨端区域显示最后成功缓存和过期提示。

## 12. 测试与验收

### 12.1 单元测试

- alias 精确匹配、冲突、禁用和版本回滚。
- 跨午夜、空闲时间、时区和 86400 秒上限。
- 绝对值 upsert、revision、hash 和 tombstone。
- 状态机的 401、429、5xx、断网和游标过期。
- 原始标题和路径不会进入序列化 payload。

### 12.2 集成测试

- 同一账号连接 Windows 与 Android。
- 两端分别上传原神、微信和哔哩哔哩。
- 重复发送同 batch 不增加时长。
- 桌面断网一天后恢复并补传。
- 手机撤销后旧 token 无法继续同步。
- catalog 更新后别名切换且历史 canonical ID 稳定。
- 删除云端数据后两端 pull tombstone 并清除远端缓存。

### 12.3 完成标准

- `timearc_service.db` 无 schema 和写入路径变化。
- 不支持应用不会进入请求 payload。
- 桌面/手机占比与云端 daily rows 一致。
- 断网、重试、重复请求不产生重复时长。
- 两端退出登录后本机记录仍可用。
- 账号隐私操作均有可验证结果。

## 13. Git 与交付规则设计

实施前补强现有 `.harness/rules/08-git-workflow.md`，并按冻结文件流程更新
`.harness/AGENTS.md` 的规则路由。`07` 已由产品 AI 卡片规则占用，不新增重复
规则。先提交 change proposal，再改冻结文件。

### 13.1 小功能提交

“小功能”定义为一个可独立验证的 checklist 项，而不是每次文件保存。例如：

- 一个表迁移及其测试。
- 一个 API endpoint 及其授权测试。
- 一个 resolver 规则组及其测试。
- 一个 QML 状态及其截图/手测。

每个小功能完成后：

1. 运行该项相关测试。
2. 更新进度表的“完成/未完成/验证证据”。
3. 仅暂存该项相关文件。
4. 创建一个语义清晰的 commit。

### 13.2 大功能 PR

“大功能”定义为进度表中的一个 Epic。每个 Epic：

1. 使用 `codex/cross-sync-eN-<slug>` 分支。
2. Epic 所有 checklist 完成并通过 harness/build/test。
3. 更新会话记录、README 和进度表。
4. push 并创建 PR，目标分支为 `dev`。
5. PR 检查通过后 merge。
6. 验证 `dev` 包含 merge 结果。
7. 删除远端与本地功能分支。
8. 在进度表记录 PR、merge commit、完成项和遗留项。

不得在 PR 未合并或 merge 未验证时提前清理分支。

### 13.3 每次记录

每个 session log 和进度表更新都必须包含：

- 本次完成。
- 本次未完成。
- 验证结果。
- 下一步。
- 已知风险或阻塞。

## 14. 云端选择结论

首版使用：

- 腾讯 CloudBase Auth。
- 腾讯 CloudBase 云托管运行 TimeArc Sync API。
- CloudBase MySQL 保存结构化聚合数据。
- 备案自定义域名提供生产 HTTPS API。

不选择 Supabase 托管版作为大陆首发主链路，原因是没有中国大陆区域。也不在
首版自建 Supabase，因为其安全、升级、备份、监控和容灾成本显著高于本功能
本身。

客户端通过自有 API 隔离云厂商。如果未来转向国际用户，只需要实现新的服务端
存储/Auth adapter，不改变 `/v1/sync` 客户端协议。

## 15. 参考

- [腾讯 CloudBase 产品概述](https://cloud.tencent.com/document/product/876/18431)
- [腾讯 CloudBase HTTP 访问服务](https://cloud.tencent.com/document/product/876/122894)
- [腾讯 CloudBase 身份认证](https://cloud.tencent.com/document/product/876/121347)
- [Supabase 可用区域](https://supabase.com/docs/guides/platform/regions)
- [Supabase 自托管责任](https://supabase.com/docs/guides/self-hosting)
