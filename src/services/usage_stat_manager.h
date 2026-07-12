#ifndef USAGESTATMANAGER_H
#define USAGESTATMANAGER_H

#include <QList>
#include <QObject>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QVariantMap>

#include <functional>

class QSqlDatabase;

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
  // 统计页周视图（G-1）：任意窗口逐日 active 秒数序列，口径同 dailySecondsForMonth，
  // 但按 [startUnixSec, endUnixSec] 的本地自然日分桶。返回 [{dayStartUnix, seconds}]
  // （窗口内每天一项，无记录补 0），供周 7 柱 / 任意期次序列。range "week" 已在
  // matchesRange 支持（周一为首），周窗口起止由 QML 计算后传入，二者口径一致。
  Q_INVOKABLE QVariantList dailySecondsForRange(qint64 startUnixSec,
                                                qint64 endUnixSec) const;
  // 统计页期次任意窗口（G-9）+ 环比 WoW/MoM/YoY（G-8/G-2）：按记录起始 unix 落在
  // [startUnixSec, endUnixSec] 闭区间聚合，口径与 matchesRange 当前周期一致；
  // QML 传入本地周期边界（末秒为 end）即可取任意周/月/年窗口与其上一周期。
  Q_INVOKABLE QVariantList activeSoftwareForWindow(qint64 startUnixSec,
                                                   qint64 endUnixSec) const;
  Q_INVOKABLE int activeSoftwareSecondsForWindow(qint64 startUnixSec,
                                                 qint64 endUnixSec) const;
  Q_INVOKABLE QVariantList foregroundSegmentsForWindow(qint64 startUnixSec,
                                                       qint64 endUnixSec) const;
  // 年视图 12 月序列（G-7）：单遍扫描，替代 12 次 activeSoftwareForMonth。
  // 返回 [{month:1..12, seconds}]（当年到当前月、过去年整 12、未来年全 0）。
  Q_INVOKABLE QVariantList monthlySecondsForYear(int year) const;
  // 专注聚合（G-6 / A-5）：开发/办公/笔记 类目跨 app 连续块（间隙<=10min、最短>=5min）。
  // 返回 {focusSeconds:qlonglong, focusDays:int}，供月·专注天数 / 年·专注小时。只读。
  Q_INVOKABLE QVariantMap focusStatsForWindow(qint64 startUnixSec,
                                              qint64 endUnixSec) const;
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
  Q_INVOKABLE void setReadFilters(bool autoClassify, bool gameClassify,
                                  bool mergeSimilar, bool hideTitles,
                                  const QStringList& hiddenKeys);
  // 逐项显隐选单（2B / G-HIDEAPP）：去重列出已采集到的 app，供设置页应用清单勾选。
  // 每项 {groupKey, name, appName, path, hidden}。忽略隐藏集做枚举（含被隐藏项，标 hidden），
  // 让用户能取消隐藏。只读自身记录，不开新数据路径。
  Q_INVOKABLE QVariantList allApps() const;

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
    quint64 durationSec = 0;
  };

  QList<UsageRecord> m_records;
  int m_recordsGeneration = 0;
  bool m_historyInitialized = false;
  // SQLite 增量高水位：仅装载 rowid 大于上次的新行。
  qint64 m_sqliteFrontmostMaxId = 0;
  qint64 m_sqliteMediaMaxId = 0;

  // 设置页读层过滤（UI 私有；启动 + 开关变更时经 setReadFilters 推入）。默认 = 现状。
  bool m_autoClassify = true;    // 关 → 类别一律「其他」（停用自动归类）
  bool m_gameClassify = true;    // 关 → 游戏类别降级为「其他」（不识别游戏）
  bool m_mergeSimilar = true;    // 关 → 多进程变体按 exe 细分（站点仍单列）
  bool m_hideTitles = false;     // 类默认不脱敏（保字节一致契约）；UI 默认开由 KV 启动推入
  QSet<QString> m_hiddenKeys;    // 逐项显隐：被排除出聚合的 group key 集

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
  QVariantList aggregateSoftwareForRange(const QString& range,
                                         const QString& sourceFilter) const;
  // 聚合核心：按 inWindow 谓词筛记录、按 activity key 分组、合并重叠区间。
  // range 字符串版与显式自然月版共用同一核心，避免逻辑漂移。
  QVariantList aggregateSoftware(
      const std::function<bool(const UsageRecord&)>& inWindow,
      const QString& sourceFilter) const;
  // 前台会话段聚合核心（range 版与任意窗口版共用，谓词决定纳入哪些记录）。
  QVariantList foregroundSegmentsImpl(
      const std::function<bool(const UsageRecord&)>& inWindow) const;
  int aggregateSoftwareSecondsForRange(const QString& range,
                                       const QString& sourceFilter) const;
  bool matchesRange(const UsageRecord& record, const QString& range) const;
  bool matchesYearMonth(const UsageRecord& record, int year, int month) const;
  bool matchesSource(const UsageRecord& record,
                     const QString& sourceFilter) const;
  QString secondsToTimeText(quint64 totalSeconds) const;
};

#endif
