#ifndef USAGESTATMANAGER_H
#define USAGESTATMANAGER_H

#include <QList>
#include <QObject>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

#include <functional>

class QJsonObject;

// 自动使用统计服务。
//
// 这个类运行在 Qt UI 进程中，读取 Windows service 写出的 JSONL/current 文件，
// 再聚合成 QML 可直接展示的 QVariantMap 列表。它不负责采集，只负责读取、
// 归类、合并 foreground/audio 时间段，以及给当前页面提供实时状态。
class UsageStatManager : public QObject {
  Q_OBJECT
  Q_PROPERTY(QString usageRecordsPath READ usageRecordsPath CONSTANT)
  Q_PROPERTY(int todaySoftwareMinutes READ todaySoftwareMinutes NOTIFY usageStatsChanged)
  Q_PROPERTY(int monthSoftwareMinutes READ monthSoftwareMinutes NOTIFY usageStatsChanged)
  Q_PROPERTY(int yearSoftwareMinutes READ yearSoftwareMinutes NOTIFY usageStatsChanged)
  Q_PROPERTY(int allSoftwareMinutes READ allSoftwareMinutes NOTIFY usageStatsChanged)

 public:
  explicit UsageStatManager(QObject* parent = nullptr);

  QString usageRecordsPath() const;
  int todaySoftwareMinutes() const;
  int monthSoftwareMinutes() const;
  int yearSoftwareMinutes() const;
  int allSoftwareMinutes() const;

  Q_INVOKABLE void refresh();
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
  Q_INVOKABLE QVariantMap currentSoftware() const;

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

signals:
  void usageStatsChanged();

 private:
  struct UsageRecord {
    // 对应 usage_record JSON 的字段；live 表示来自 usage_current.json。
    QString appId;
    QString source;
    QString appName;
    QString windowTitle;
    QString path;
    qint64 startUnixSec = 0;
    quint64 durationSec = 0;
    qint64 updatedUnixSec = 0;
    bool live = false;
  };

  QList<UsageRecord> m_records;
  UsageRecord m_currentRecord;
  bool m_hasCurrentRecord = false;

  QString recordsFilePath() const;
  QString currentFilePath() const;
  UsageRecord parseRecordObject(const QJsonObject& object, bool live) const;
  QVariantMap recordToVariantMap(const UsageRecord& record) const;
  QVariantList aggregateSoftwareForRange(const QString& range,
                                         const QString& sourceFilter) const;
  // 聚合核心：按 inWindow 谓词筛记录、按 activity key 分组、合并重叠区间。
  // range 字符串版与显式自然月版共用同一核心，避免逻辑漂移。
  QVariantList aggregateSoftware(
      const std::function<bool(const UsageRecord&)>& inWindow,
      const QString& sourceFilter) const;
  int aggregateSoftwareSecondsForRange(const QString& range,
                                       const QString& sourceFilter) const;
  bool matchesRange(const UsageRecord& record, const QString& range) const;
  bool matchesYearMonth(const UsageRecord& record, int year, int month) const;
  bool matchesSource(const UsageRecord& record,
                     const QString& sourceFilter) const;
  QString secondsToTimeText(quint64 totalSeconds) const;
};

#endif
