#ifndef USAGESTATMANAGER_H
#define USAGESTATMANAGER_H

#include <QDate>
#include <QList>
#include <QHash>
#include <QObject>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

#include <functional>

#include "services/categorization/matcher.h"

class QSqlDatabase;
class CategorizationManager;

// 自动使用统计服务。
//
// 这个类运行在 Qt UI 进程中，读取 service SQLite 历史，
// 再聚合成 QML 可直接展示的 QVariantMap 列表。它不负责采集，只负责读取、
// 归类、合并 foreground/audio 时间段，以及给当前页面提供实时状态。
class UsageStatManager : public QObject {
  Q_OBJECT
  Q_PROPERTY(int todaySoftwareMinutes READ todaySoftwareMinutes NOTIFY usageStatsChanged)
  Q_PROPERTY(int monthSoftwareMinutes READ monthSoftwareMinutes NOTIFY usageStatsChanged)
  Q_PROPERTY(int yearSoftwareMinutes READ yearSoftwareMinutes NOTIFY usageStatsChanged)
  Q_PROPERTY(int allSoftwareMinutes READ allSoftwareMinutes NOTIFY usageStatsChanged)

 public:
  explicit UsageStatManager(QObject* parent = nullptr);

  int todaySoftwareMinutes() const;
  int monthSoftwareMinutes() const;
  int yearSoftwareMinutes() const;
  int allSoftwareMinutes() const;

  // 分类规则表由 CategorizationManager 持有；读层只消费它，规则变更会清缓存并
  // 让各页重算（类别永远是读出时算的，所以编辑规则对全部历史即时生效）。
  void setCategorizationManager(CategorizationManager* manager);

  Q_INVOKABLE void refresh();
  // 数据代际：m_records 真实变化（全量重读或增量追加）时自增。
  // 供 UI（统计页）跳过无新数据的重算（避免 5s Timer 每次都做昂贵聚合 → 长期卡顿）。
  Q_INVOKABLE int recordsGeneration() const { return m_recordsGeneration; }
  // active = foreground + audio 合并视图；重叠时间会按区间合并，避免双算。
  Q_INVOKABLE QVariantList softwareForRange(const QString& range) const;
  Q_INVOKABLE QVariantList activeSoftwareForRange(const QString& range) const;
  // 只看前台窗口使用时长。
  Q_INVOKABLE QVariantList foregroundSoftwareForRange(const QString& range) const;
  // 只看音频播放时长。
  Q_INVOKABLE QVariantList audioForRange(const QString& range) const;
  Q_INVOKABLE int softwareSecondsForRange(const QString& range) const;
  Q_INVOKABLE int activeSoftwareSecondsForRange(const QString& range) const;
  Q_INVOKABLE int foregroundSoftwareSecondsForRange(const QString& range) const;
  Q_INVOKABLE int audioSecondsForRange(const QString& range) const;

  // 记忆湖：把区间内每个 app 的前台记录（同首页只读路径的 m_records）按
  // activity key 分组、相邻间隙 <= 60s 合并成"会话段"，用于推导 launches /
  // longest / 时间河流。每项 {groupKey, appId, appName, path, sessionCount,
  // longestSec, segments:[{startUnixSec,endUnixSec,seconds}]}。只组合自身记录，
  // 不开新数据路径，安全面与首页一致。
  Q_INVOKABLE QVariantList foregroundSegmentsForRange(const QString& range) const;
  // 记忆湖月度（阶段二）：指定自然月的 app 聚合（与 activeSoftwareForRange 同形），
  // 用于环比上月等需要"非当前月"数据的场景。只组合自身记录，不开新数据路径。
  Q_INVOKABLE QVariantList activeSoftwareForMonth(int year, int month) const;
  // 记忆湖月度：当月按天的 active(前台+音频并集) 使用秒数序列，覆盖整月每天
  // （无记录的天补 0），口径与 softwareSecondsForRange("month") 一致。
  // 返回 [{day:int(1..N), seconds:qlonglong}]，用于趋势曲线 / 月历柱。
  Q_INVOKABLE QVariantList dailySecondsForMonth(int year, int month) const;
  // ===== 统计页专用读路径：**只看 frontmost_sessions**（source == "foreground"）=====
  // 统计页的口径是「你人在哪个窗口前面」，不是「机器上还有什么在响」。media_sessions
  // 与前台并发（放视频的同时你在读 PDF），两条记录同时为真；把它们并进同一份 app 列表
  // 后按 app 求并集再相加，同一秒会被不同 app 各算一次，一天于是能超过 24h
  // （2026-08-04/05 各多出 227s / 209s）。统计页因此整条链路都走 foreground-only：
  // 名字里的 foreground 就是口径声明，别在这一页调用 active* 系列。
  // 首页 / 记忆湖 / 月度回顾要的是「设备被使用的覆盖面」，继续用 active*（前台∪音频）。
  //
  // 周 7 柱 / 任意期次逐日序列（G-1）：按 [startUnixSec, endUnixSec] 的本地自然日分桶，
  // 返回 [{dayStartUnix, seconds}]（每天一项，无记录补 0）。跨午夜的会话按天切片，
  // 每天只计入落在当天的那一段，故各柱之和与期次总时长同口径。
  Q_INVOKABLE QVariantList foregroundDailySecondsForRange(
      qint64 startUnixSec, qint64 endUnixSec) const;
  // 期次任意窗口（G-9）+ 环比 WoW/MoM/YoY（G-8/G-2）：与 [startUnixSec, endUnixSec]
  // 闭区间**相交**的记录入选，区间截断到窗口内（见 ClipWindow）。前台记录彼此不重叠，
  // 加上截断，一个自然日的总时长恒 <= 24h。QML 传入本地周期边界（末秒为 end）。
  Q_INVOKABLE QVariantList foregroundSoftwareForWindow(qint64 startUnixSec,
                                                       qint64 endUnixSec) const;
  Q_INVOKABLE int foregroundSoftwareSecondsForWindow(qint64 startUnixSec,
                                                     qint64 endUnixSec) const;
  Q_INVOKABLE QVariantList foregroundSegmentsForWindow(qint64 startUnixSec,
                                                       qint64 endUnixSec) const;
  // 年视图 12 月序列（G-7）：单遍扫描，替代 12 次 activeSoftwareForMonth。
  // 返回 [{month:1..12, seconds}]（当年到当前月、过去年整 12、未来年全 0）。
  Q_INVOKABLE QVariantList foregroundMonthlySecondsForYear(int year) const;
  // 专注聚合（G-6 / A-5）：开发/办公/笔记 类目跨 app 连续块（间隙<=10min、最短>=5min）。
  // 返回 {focusSeconds:qlonglong, focusDays:int}，供月·专注天数 / 年·专注小时。只读。
  Q_INVOKABLE QVariantMap foregroundFocusStatsForWindow(qint64 startUnixSec,
                                                        qint64 endUnixSec) const;
  // 统计页的全历史清单（「累计总时长」/「历史最长」/「本期活跃 x / y」的分母）。
  // 与 allApps() 同形，但只统计前台记录；allApps() 保持全来源，设置页的应用清单
  // 要靠它列出**服务见过的每一个 app**（含只出过声的），那是另一件事。
  Q_INVOKABLE QVariantList foregroundApps() const;
  // 导出报告（G-10）：把 UI 组装的统计 JSON 写到下载/文档目录（报告文件，非 usage 数据，
  // 不动磁盘契约/不写 usage/SQLite）。返回完整路径，失败空串。
  Q_INVOKABLE QString exportReport(const QString& fileBaseName,
                                   const QString& jsonContent) const;

  // 设置页存储概览（G-STORAGE）：只读取文件字节大小 / 已解析记录条数，供「存储空间」卡 +
  // 数据概览。只用 QFileInfo 取大小，不读内容、不写任何数据，不触碰磁盘契约。path 接受
  // 本地路径或 file:// URL；文件不存在返回 0。
  Q_INVOKABLE double fileSizeBytes(const QString& path) const;
  Q_INVOKABLE int recordCount() const;

  // 设置页读层过滤（2A 游戏/分类/合并 · 2B 逐项显隐 · 2C 标题脱敏）：
  // 把 UI 私有偏好推入读出聚合层。只影响 UI 读出，不写/不删 usage，不动磁盘契约/服务。
  // 默认无过滤（不脱敏/不隐藏/全分类/合并）= 与历史逐字节一致。变更后发
  // usageStatsChanged 并自增 recordsGeneration，令各消费页重算。
  // 逐项显隐自愈（G-HIDEAPP）：把设置页存下的 hidden_apps 归一到**当前**身份方案。
  // 规则表升级会改变一个 app 的 group key（loginwindow 从旧回退键 exe:loginwindow
  // 变成规则键 app:macos-shell），存量键于是失配、隐藏静默失效。读侧认全部别名，
  // 但「取消隐藏」只会删掉当前键、留下陈旧键，所以设置层启动时用这个写回一次。
  // 只改写旧回退键（exe:/path:）；app:/site: 是当前方案产出的，原样保留。
  Q_INVOKABLE QStringList canonicalHiddenKeys(const QStringList& stored) const;
  // 同上，作用于 app_display_name_overrides。这张表也按 group key 存，所以规则表
  // 一升级同样会失配——只是失败得更安静：自定义名字不再生效，没有任何提示。
  Q_INVOKABLE QVariantMap canonicalDisplayNameKeys(
      const QVariantMap& stored) const;
  Q_INVOKABLE void setReadFilters(bool autoClassify, bool gameClassify,
                                  bool mergeSimilar, bool hideTitles,
                                  const QStringList& hiddenKeys);
  Q_INVOKABLE void setAppDisplayNameOverrides(const QVariantMap& overrides);
  // 逐项显隐选单（2B / G-HIDEAPP）：去重列出已采集到的 app，供设置页应用清单勾选。
  // 每项 {groupKey, name, appName, path, hidden}。忽略隐藏集做枚举（含被隐藏项，标 hidden），
  // 让用户能取消隐藏。只读自身记录，不开新数据路径。
  Q_INVOKABLE QVariantList allApps() const;

  // 采集到的**原始应用身份**（app_id / display_name / path），按 app_id 去重。
  // 刻意不经过规则表：分类规则的播种要用它，若这里再去问 matcher 就成了环。
  Q_INVOKABLE QVariantList recordedAppIdentities() const;

signals:
  void usageStatsChanged();

 private:
  struct UsageRecord {
    // SQLite session 的 UI 归一化字段。
    QString appId;
    QString source;
    QString appName;
    QString windowTitle;
    QString path;
    qint64 startUnixSec = 0;
    quint64 durationSec = 0;  // 墙钟跨度 end - start（只用于「最近使用」时刻）
    // 计入统计的长度。前台 = active_sec（会话跨 idle 保持打开，CHARTER v0.11，
    // 所以墙钟跨度里含锁屏和离座）；媒体 = duration_sec（在播就是在播）。
    // 所有区间都构造成 [start, start + activeSec)：长度精确，落点误差上界是服务
    // 侧的 maxSessionSec（当前 300s）。
    quint64 activeSec = 0;
    // startUnixSec 的本地自然日，装载时算一次。此前每次 range 判定都要对每条记录做
    // QDateTime::fromSecsSinceEpoch().toLocalTime().date()（含时区换算），而一次开页
    // 要跑好几遍聚合。记录一经追加即不可变，故可安全预存；系统时区变了要整表重载
    // （见 m_recordsTimeZoneId）。
    QDate localDate;
  };

  // 一个 range 对应的本地日期闭区间。每次聚合解析一次，而不是每条记录解析一次
  // （原先 QDate::currentDate() 也在逐记录的判定里）。
  struct DateWindow {
    bool matchesAll = false;  // range == "all"：不看日期
    bool valid = false;       // 无法识别的 range：一条都不匹配（同旧行为）
    QDate from;
    QDate to;

    bool contains(const QDate& date) const {
      if (matchesAll) return true;
      if (!valid || !date.isValid()) return false;
      return date >= from && date <= to;
    }
  };

  // 读层时间窗口（unix 秒，半开区间 [start, end)）。窗口读路径统一走它：记录按
  // **区间相交**入选，入选后区间再**截断**到窗口内。此前所有窗口读路径只判定
  // record.startUnixSec 落在窗口里，然后整段计入——一条 18:43 开始、次日 12:19
  // 结束的会话会把 17.6h 全部记到起始那天，于是「今日」可以超过 24h；同时昨晚
  // 跨过午夜的那一段又整个从今天消失。截断同时修掉这两个方向的偏差。
  struct ClipWindow {
    qint64 start = 0;
    qint64 end = 0;          // 开区间右端（不含）
    bool unbounded = false;  // range == "all"：不看时间，记录区间原样返回
    bool valid = true;       // 无法识别的 range：一条都不匹配（同旧行为）

    // 记录区间 ∩ 窗口。无交集（或记录本身非法）返回 false。
    bool clip(qint64 recStartUnixSec, quint64 durationSec, qint64* outStart,
              qint64* outEnd) const;
  };

  DateWindow rangeWindow(const QString& range) const;
  // DateWindow（本地自然日闭区间）→ ClipWindow（unix 半开区间）。
  static ClipWindow clipWindowForDates(const DateWindow& window);
  // QML 传入的 [start, end] 闭区间（end 为期次末秒）→ 半开 [start, end + 1)。
  static ClipWindow clipWindowForBounds(qint64 startUnixSec, qint64 endUnixSec);

  QList<UsageRecord> m_records;
  int m_recordsGeneration = 0;
  bool m_historyInitialized = false;
  // SQLite 增量高水位：仅装载 rowid 大于上次的新行。
  qint64 m_sqliteFrontmostMaxId = 0;
  qint64 m_sqliteMediaMaxId = 0;
  // 预存 localDate 用的系统时区。用户在会话中途改时区会让已存的本地日失效，
  // 故 refresh 时比对一次；变了就整表重载（重算全部 localDate）。DST 不受影响——
  // 时区规则是按时刻历史应用的，过去某一刻的本地日不会因为进入夏令时而改变。
  QByteArray m_recordsTimeZoneId;

  // allApps() 记忆化。结果只取决于 m_records + 读层过滤 + 规则表 + UI 语言，而这四者
  // 的任何变化都会自增 m_recordsGeneration（语言经 CategorizationManager::setLanguage
  // → rulesChanged → 本类的 lambda），故单个整数就是完整的缓存键。
  // 统计页 rebuild() 每次切换周/月/年或期次都会调它，但它是全历史的、与窗口无关。
  mutable QVariantList m_allAppsCache;
  mutable int m_allAppsGeneration = -1;
  // foregroundApps() 的同款记忆化（两种来源口径各缓存一份，键同为 generation）。
  mutable QVariantList m_foregroundAppsCache;
  mutable int m_foregroundAppsGeneration = -1;

  // 设置页读层过滤（UI 私有；启动 + 开关变更时经 setReadFilters 推入）。默认 = 现状。
  bool m_autoClassify = true;    // 关 → 类别一律「其他」（停用自动归类）
  bool m_gameClassify = true;    // 关 → 游戏类别降级为「其他」（不识别游戏）
  bool m_mergeSimilar = true;    // 关 → 多进程变体按 exe 细分（站点仍单列）
  bool m_hideTitles = false;     // 类默认不脱敏（保字节一致契约）；UI 默认开由 KV 启动推入
  QSet<QString> m_hiddenKeys;    // 逐项显隐：被排除出聚合的 group key 集
  QHash<QString, QString> m_displayNameOverrides;
  CategorizationManager* m_categorization = nullptr;
  mutable QHash<QString, TimeArc::Categorization::Resolution> m_resolutionCache;
  mutable int m_resolutionGeneration = -1;  // 原始 group key -> 本地显示名称
  mutable int m_representativePathsGeneration = -1;
  mutable QHash<QString, QString> m_representativePaths;

  void refreshHistoryFromSqlite();
  // SQLite 高水位 MAX(rowid)（空表→0；连接坏→false）。
  bool sqliteMaxIds(QSqlDatabase& db, qint64* maxFront, qint64* maxMedia) const;
  // 装载 rowid > *sinceMaxId 的会话行（JOIN apps 还原名称/path）追加进 out，更新水位。
  // sql 须产出 7 列：app_id, display_name, path, title, start, duration, rowid。
  int appendSqliteSessionsSince(QList<UsageRecord>* out, const QString& sql,
                                const QString& source, qint64* sinceMaxId) const;
  // 读层有效 group key：按当前过滤标志返回记录的有效分组键（合并关→exe 细键），
  // 被隐藏的 app 返回空串（调用方据此跳过）。
  QString effectiveGroupKey(const UsageRecord& record) const;

  const TimeArc::Categorization::Matcher& matcher() const;
  TimeArc::Categorization::Resolution resolveActivity(
      const QString& appId, const QString& appName,
      const QString& windowTitle) const;
  QString activityGroupKey(const QString& appId, const QString& appName,
                           const QString& path,
                           const QString& windowTitle) const;
  QString activityDisplayName(const QString& groupKey, const QString& appId,
                              const QString& appName,
                              const QString& path) const;
  QString classifyActivity(const QString& groupKey, const QString& appId,
                           const QString& appName, const QString& path,
                           const QString& windowTitle) const;
  void applyRuleMetadata(QVariantMap* item, const QString& ruleId,
                         const QString& path) const;
  QStringList ruleIconColors(const QString& ruleId, const QString& path) const;
  QSet<QString> focusCategories() const;
  bool isDeprioritizedCategory(const QString& category) const;
  QString uiLanguage() const;
  QString representativePathForGroup(const QString& groupKey) const;
  void rebuildRepresentativePaths() const;
  QVariantList aggregateSoftwareForRange(const QString& range,
                                         const QString& sourceFilter) const;
  // 聚合核心：按 window 截取记录区间、按 activity key 分组、合并重叠区间。
  // range 字符串版与显式自然月版共用同一核心，避免逻辑漂移。
  QVariantList aggregateSoftware(const ClipWindow& window,
                                 const QString& sourceFilter) const;
  // allApps() / foregroundApps() 的共同实现；sourceFilter 为空表示全来源。
  QVariantList allAppsImpl(const QString& sourceFilter,
                           QVariantList* cache, int* cacheGeneration) const;
  // 前台会话段聚合核心（range 版与任意窗口版共用，window 决定纳入哪些记录）。
  QVariantList foregroundSegmentsImpl(const ClipWindow& window) const;
  int aggregateSoftwareSecondsForRange(const QString& range,
                                       const QString& sourceFilter) const;
  bool matchesSource(const UsageRecord& record,
                     const QString& sourceFilter) const;
  // 一个 app 在不同规则表版本 / 不同合并开关下会产生不止一个 group key。
  // 显隐判定必须认全部别名，否则设置页里勾掉的 app 会在规则更新后回到统计里。
  QStringList activityAliases(const QString& appId, const QString& appName,
                              const QString& path,
                              const QString& windowTitle) const;
  bool isHiddenActivity(const QString& appId, const QString& appName,
                        const QString& path,
                        const QString& windowTitle) const;
  // 自定义显示名同样按别名查找：设置页存的键可能来自旧身份方案。
  QString displayNameOverrideFor(const QString& appId, const QString& appName,
                                 const QString& path) const;
  // 旧回退键（exe:/path:）→ 当前身份键。两个归一函数共用。
  QHash<QString, QString> legacyKeyMap() const;
  QString secondsToTimeText(quint64 totalSeconds) const;
};

#endif
