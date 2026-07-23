#include "services/mobile/mobile_usage_service.h"

#include <QDate>
#include <QDateTime>
#include <QDebug>
#include <QMap>
#include <QSet>
#include <QTimeZone>
#include <QVector>

#ifdef Q_OS_ANDROID
#include <QGuiApplication>
#include <QJniObject>
#include <QtCore/qcoreapplication_platform.h>
#endif

#include <algorithm>

#include "services/mobile/mobile_usage_repository.h"
#include "services/mobile/mobile_usage_insight_engine.h"

namespace {

const QString kAndroidPlatform = QStringLiteral("android");

QString rangeLabel(const QString& range) {
  const QString key = range.trimmed().toLower();
  if (key == QStringLiteral("week") || key == QStringLiteral("7d"))
    return QStringLiteral("本周");
  if (key == QStringLiteral("month") || key == QStringLiteral("30d"))
    return QStringLiteral("本月");
  if (key == QStringLiteral("year")) return QStringLiteral("今年");
  if (key == QStringLiteral("all") || key == QStringLiteral("total"))
    return QStringLiteral("总计");
  return QStringLiteral("今天");
}

QPair<QString, QString> personalizedConversion(int seconds, int variant) {
  switch (variant % 4) {
    case 0:
      return {
          QStringLiteral("songs"),
          QStringLiteral("若每首歌四分钟，这段时间足够听完约 %1 首歌。")
              .arg(qMax(1, qRound(seconds / 240.0)))};
    case 1:
      return {
          QStringLiteral("poem"),
          QStringLiteral("如同安静读过约 %1 字的诗，时间也有了自己的韵脚。")
              .arg(qMax(800, qRound(seconds / 60.0 * 320.0)))};
    case 2:
      return {
          QStringLiteral("tea"),
          QStringLiteral("若用一盏茶的二十分钟慢下来，足够拥有约 %1 次短暂晴天。")
              .arg(qMax(1, qRound(seconds / 1200.0)))};
    default:
      return {
          QStringLiteral("film"),
          QStringLiteral("像完整看过约 %1 部九十分钟的电影，片尾都有你的名字。")
              .arg(qMax(1, qRound(seconds / 5400.0)))};
  }
}

int stableConversionVariant(const QString& appKey) {
  return static_cast<int>(qHash(appKey, 0u) % 4u);
}

}  // namespace

MobileUsageService::MobileUsageService(MobileUsageRepository* repository,
                                       QObject* parent)
    : QObject(parent), repository_(repository) {}

bool MobileUsageService::usageAccessGranted() const {
  return usageAccessGranted_;
}

QString MobileUsageService::syncStatus() const { return syncStatus_; }

QString MobileUsageService::syncStatusText() const { return syncStatusText_; }

QVariantMap MobileUsageService::getUsageDashboard(
    const QString& startDateLocal,
    const QString& endDateLocal) {
  QVariantMap dashboard;
  dashboard.insert(QStringLiteral("startDateLocal"), startDateLocal);
  dashboard.insert(QStringLiteral("endDateLocal"), endDateLocal);
  dashboard.insert(QStringLiteral("platform"), kAndroidPlatform);

  if (repository_ == nullptr) {
    dashboard.insert(QStringLiteral("totalSec"), 0);
    dashboard.insert(QStringLiteral("totalText"), formatDuration(0));
    dashboard.insert(QStringLiteral("topApps"), QVariantList());
    dashboard.insert(QStringLiteral("empty"), true);
    return dashboard;
  }

  QVariantList rows =
      repository_->getUsageByDateRange(startDateLocal, endDateLocal,
                                       kAndroidPlatform);
  int totalSec = 0;
  QSet<QString> activeDates;
  QMap<QString, QVariantMap> appAggregates;
  QMap<QString, QSet<QString>> appDates;
  QMap<QString, QString> appFirstDates;
  QString firstDateLocal;

  for (const QVariant& item : rows) {
    const QVariantMap row = item.toMap();
    const int seconds = row.value(QStringLiteral("foregroundSec")).toInt();
    if (seconds <= 0) continue;

    totalSec += seconds;
    const QString dateLocal = row.value(QStringLiteral("dateLocal")).toString();
    if (!dateLocal.isEmpty()) {
      activeDates.insert(dateLocal);
      if (firstDateLocal.isEmpty() || dateLocal < firstDateLocal)
        firstDateLocal = dateLocal;
    }

    QString key = row.value(QStringLiteral("appIdentifier")).toString();
    if (key.isEmpty()) key = row.value(QStringLiteral("packageName")).toString();
    if (key.isEmpty()) continue;

    QVariantMap aggregate = appAggregates.value(key);
    if (aggregate.isEmpty()) {
      aggregate = row;
      aggregate.insert(QStringLiteral("foregroundSec"), 0);
      const QString packageName =
          row.value(QStringLiteral("packageName")).toString();
      const QString displayName = friendlyDisplayName(
          packageName, row.value(QStringLiteral("displayName")).toString());
      aggregate.insert(QStringLiteral("displayName"), displayName);
      aggregate.insert(QStringLiteral("initial"), initialForName(displayName));
    }

    aggregate.insert(
        QStringLiteral("foregroundSec"),
        aggregate.value(QStringLiteral("foregroundSec")).toInt() + seconds);

    const QString iconPath = row.value(QStringLiteral("appIconPath")).toString();
    if (!iconPath.isEmpty() &&
        aggregate.value(QStringLiteral("appIconPath")).toString().isEmpty()) {
      aggregate.insert(QStringLiteral("appIconPath"), iconPath);
    }

    const QString displayName = row.value(QStringLiteral("displayName")).toString();
    if (!displayName.isEmpty() &&
        aggregate.value(QStringLiteral("displayName")).toString().isEmpty()) {
      const QString friendly = friendlyDisplayName(
          row.value(QStringLiteral("packageName")).toString(), displayName);
      aggregate.insert(QStringLiteral("displayName"), friendly);
      aggregate.insert(QStringLiteral("initial"), initialForName(friendly));
    }

    if (!dateLocal.isEmpty()) {
      appDates[key].insert(dateLocal);
      if (appFirstDates.value(key).isEmpty() ||
          dateLocal < appFirstDates.value(key)) {
        appFirstDates.insert(key, dateLocal);
      }
    }
    appAggregates.insert(key, aggregate);
  }

  QVector<QVariantMap> sortedApps;
  sortedApps.reserve(appAggregates.size());
  for (const QVariantMap& aggregate : appAggregates) {
    sortedApps.append(aggregate);
  }

  std::sort(sortedApps.begin(), sortedApps.end(),
            [](const QVariantMap& lhs, const QVariantMap& rhs) {
              const int leftSeconds =
                  lhs.value(QStringLiteral("foregroundSec")).toInt();
              const int rightSeconds =
                  rhs.value(QStringLiteral("foregroundSec")).toInt();
              if (leftSeconds != rightSeconds) return leftSeconds > rightSeconds;
              return lhs.value(QStringLiteral("displayName"))
                         .toString()
                         .localeAwareCompare(
                             rhs.value(QStringLiteral("displayName")).toString()) <
                     0;
            });

  QVariantList topApps;
  const int leaderSec =
      sortedApps.isEmpty()
          ? 0
          : sortedApps.first().value(QStringLiteral("foregroundSec")).toInt();
  const QDate rangeEnd =
      QDate::fromString(endDateLocal, Qt::ISODate).isValid()
          ? QDate::fromString(endDateLocal, Qt::ISODate)
          : QDate::currentDate();
  int rank = 1;
  for (QVariantMap row : sortedApps) {
    const int seconds = row.value(QStringLiteral("foregroundSec")).toInt();
    const QString displayName =
        row.value(QStringLiteral("displayName")).toString();
    QString key = row.value(QStringLiteral("appIdentifier")).toString();
    if (key.isEmpty()) key = row.value(QStringLiteral("packageName")).toString();
    const QString firstDate = appFirstDates.value(key);
    const QDate firstDateValue = QDate::fromString(firstDate, Qt::ISODate);
    const int recordedDays = appDates.value(key).size();
    const int spanDays =
        firstDateValue.isValid() ? firstDateValue.daysTo(rangeEnd) + 1 : 0;
    const int currentRank = rank++;
    row.insert(QStringLiteral("rank"), currentRank);
    row.insert(QStringLiteral("durationText"), formatDuration(seconds));
    row.insert(QStringLiteral("initial"), initialForName(displayName));
    row.insert(QStringLiteral("sharePct"),
               totalSec > 0 ? qRound(seconds * 100.0 / totalSec) : 0);
    row.insert(QStringLiteral("relativePct"),
               leaderSec > 0 ? qRound(seconds * 100.0 / leaderSec) : 0);
    row.insert(QStringLiteral("firstDateLocal"), firstDate);
    row.insert(QStringLiteral("recordedDays"), recordedDays);
    row.insert(QStringLiteral("spanDays"), qMax(0, spanDays));
    row.insert(
        QStringLiteral("storyText"),
        recordedDays > 1
            ? QStringLiteral("%1 在 %2 个有记录的日子里，留下了 %3。")
                  .arg(displayName)
                  .arg(recordedDays)
                  .arg(formatDuration(seconds))
            : QStringLiteral("%1 在这段时间里留下了 %2。")
                  .arg(displayName, formatDuration(seconds)));
    const QPair<QString, QString> conversion =
        personalizedConversion(seconds, stableConversionVariant(key));
    row.insert(QStringLiteral("conversionKind"), conversion.first);
    row.insert(QStringLiteral("conversionText"), conversion.second);
    topApps.append(row);
  }

  const int activeDayCount = activeDates.size();
  dashboard.insert(QStringLiteral("totalSec"), totalSec);
  dashboard.insert(QStringLiteral("totalText"), formatDuration(totalSec));
  dashboard.insert(QStringLiteral("activeDays"), activeDayCount);
  dashboard.insert(QStringLiteral("appCount"), sortedApps.size());
  dashboard.insert(QStringLiteral("averageDailySec"),
                   activeDayCount > 0 ? totalSec / activeDayCount : 0);
  dashboard.insert(QStringLiteral("averageDailyText"),
                   formatDuration(activeDayCount > 0 ? totalSec / activeDayCount
                                                     : 0));
  dashboard.insert(QStringLiteral("topApps"), topApps);
  dashboard.insert(QStringLiteral("firstDateLocal"), firstDateLocal);
  dashboard.insert(QStringLiteral("empty"), topApps.isEmpty());
  dashboard.insert(QStringLiteral("usageAccessGranted"), usageAccessGranted_);
  dashboard.insert(QStringLiteral("syncStatus"), syncStatus_);
  dashboard.insert(QStringLiteral("syncStatusText"), syncStatusText_);
  return dashboard;
}

QVariantMap MobileUsageService::getDashboardForRange(const QString& range) {
  const QDate today = QDate::currentDate();
  const QDate start = startDateForRange(range, today);
  QVariantMap dashboard =
      getUsageDashboard(start.toString(Qt::ISODate),
                        today.toString(Qt::ISODate));
  dashboard.insert(QStringLiteral("rangeKey"), range.trimmed().toLower());
  dashboard.insert(QStringLiteral("rangeLabel"), rangeLabel(range));
  dashboard.insert(
      QStringLiteral("rangeText"),
      QStringLiteral("%1 至 %2")
          .arg(start.toString(QStringLiteral("M月d日")),
               today.toString(QStringLiteral("M月d日"))));
  return dashboard;
}

QVariantMap MobileUsageService::getMonthlyReport(const QString& monthKey) {
  QDate month = QDate::fromString(monthKey.trimmed() + QStringLiteral("-01"),
                                  Qt::ISODate);
  if (!month.isValid()) {
    const QDate today = QDate::currentDate();
    month = QDate(today.year(), today.month(), 1);
  }

  const QDate monthStart(month.year(), month.month(), 1);
  const QDate naturalMonthEnd = monthStart.addMonths(1).addDays(-1);
  const QDate today = QDate::currentDate();
  const QDate monthEnd =
      monthStart.year() == today.year() && monthStart.month() == today.month()
          ? today
          : naturalMonthEnd;
  const QDate previousStart = monthStart.addMonths(-1);
  const QDate previousEnd = monthStart.addDays(-1);

  QVariantList dailyRows;
  QVariantList previousRows;
  QVariantList sessions;
  if (repository_ != nullptr) {
    dailyRows = repository_->getUsageByDateRange(
        monthStart.toString(Qt::ISODate), monthEnd.toString(Qt::ISODate),
        kAndroidPlatform);
    previousRows = repository_->getUsageByDateRange(
        previousStart.toString(Qt::ISODate), previousEnd.toString(Qt::ISODate),
        kAndroidPlatform);
    const QTimeZone localZone = QTimeZone::systemTimeZone();
    const qint64 startUnix =
        QDateTime(monthStart, QTime(0, 0), localZone).toSecsSinceEpoch();
    const qint64 endUnix =
        QDateTime(monthEnd.addDays(1), QTime(0, 0), localZone).toSecsSinceEpoch();
    sessions = repository_->getSessionsByRange(startUnix, endUnix,
                                               kAndroidPlatform);
  }

  QVariantMap report = MobileUsageInsightEngine::buildMonthlyReport(
      monthStart, dailyRows, sessions, previousRows);

  static const QStringList seasons = {
      QStringLiteral("winter"), QStringLiteral("spring"),
      QStringLiteral("spring"), QStringLiteral("spring"),
      QStringLiteral("summer"), QStringLiteral("summer"),
      QStringLiteral("summer"), QStringLiteral("summer"),
      QStringLiteral("autumn"), QStringLiteral("autumn"),
      QStringLiteral("winter"), QStringLiteral("winter")};
  static const QStringList particles = {
      QStringLiteral("frost"),   QStringLiteral("melt"),
      QStringLiteral("rain"),    QStringLiteral("petal"),
      QStringLiteral("dust"),    QStringLiteral("storm"),
      QStringLiteral("firefly"), QStringLiteral("lateRain"),
      QStringLiteral("leaf"),    QStringLiteral("ginkgo"),
      QStringLiteral("frost"),   QStringLiteral("snow")};
  static const QStringList layouts = {
      QStringLiteral("winter-opening"), QStringLiteral("spring-thaw"),
      QStringLiteral("spring-rain"),    QStringLiteral("spring-flower"),
      QStringLiteral("summer-day"),     QStringLiteral("summer-storm"),
      QStringLiteral("summer-night"),   QStringLiteral("summer-rain"),
      QStringLiteral("autumn-wind"),    QStringLiteral("autumn-corridor"),
      QStringLiteral("winter-morning"), QStringLiteral("winter-archive")};
  static const QStringList accents = {
      QStringLiteral("#D9F0F4"), QStringLiteral("#FFD2A7"),
      QStringLiteral("#CFE8B0"), QStringLiteral("#F2D9DF"),
      QStringLiteral("#F5E69E"), QStringLiteral("#B9E5F4"),
      QStringLiteral("#E5EF87"), QStringLiteral("#C9E4DE"),
      QStringLiteral("#F0CE84"), QStringLiteral("#F2B47E"),
      QStringLiteral("#DCE9EF"), QStringLiteral("#E8F1F5")};
  static const QStringList accentInks = {
      QStringLiteral("#20353D"), QStringLiteral("#4A2820"),
      QStringLiteral("#233529"), QStringLiteral("#492F37"),
      QStringLiteral("#473F1E"), QStringLiteral("#1F3D49"),
      QStringLiteral("#303817"), QStringLiteral("#24413D"),
      QStringLiteral("#493514"), QStringLiteral("#4A2618"),
      QStringLiteral("#273943"), QStringLiteral("#253946")};

  const int profileIndex = qBound(1, monthStart.month(), 12) - 1;
  QVariantMap profile;
  profile.insert(QStringLiteral("month"), monthStart.month());
  profile.insert(QStringLiteral("season"), seasons.at(profileIndex));
  profile.insert(
      QStringLiteral("sceneSource"),
      QStringLiteral("qrc:/qt/qml/time_arc/resources/mobile/monthly/month-%1.jpg")
          .arg(monthStart.month(), 2, 10, QLatin1Char('0')));
  profile.insert(QStringLiteral("accent"), accents.at(profileIndex));
  profile.insert(QStringLiteral("accentInk"), accentInks.at(profileIndex));
  profile.insert(QStringLiteral("particleKind"), particles.at(profileIndex));
  profile.insert(QStringLiteral("layoutVariant"), layouts.at(profileIndex));
  report.insert(QStringLiteral("profile"), profile);

  QVariantList pages;
  const QStringList pageKinds = {
      QStringLiteral("cover"),     QStringLiteral("overview"),
      QStringLiteral("highlight"), QStringLiteral("companion"),
      QStringLiteral("ranking"),   QStringLiteral("share")};
  for (const QString& pageKind : pageKinds) {
    pages.append(QVariantMap{{QStringLiteral("kind"), pageKind}});
  }
  report.insert(QStringLiteral("pages"), pages);
  report.insert(QStringLiteral("title"),
                QStringLiteral("%1的时间天气")
                    .arg(monthStart.toString(QStringLiteral("M月"))));
  report.insert(QStringLiteral("rangeText"),
                QStringLiteral("%1 至 %2")
                    .arg(monthStart.toString(QStringLiteral("M月d日")),
                         monthEnd.toString(QStringLiteral("M月d日"))));
  report.insert(QStringLiteral("usageAccessGranted"), usageAccessGranted_);
  report.insert(QStringLiteral("syncStatus"), syncStatus_);
  report.insert(QStringLiteral("syncStatusText"), syncStatusText_);
  return report;
}

QVariantMap MobileUsageService::getMemoryLakeForCurrentMonth() {
  const QDate today = QDate::currentDate();
  QVariantMap report =
      getMonthlyReport(today.toString(QStringLiteral("yyyy-MM")));
  const QVariantMap dashboard = getDashboardForRange(QStringLiteral("month"));
  const QVariantList apps = report.value(QStringLiteral("topApps")).toList();

  report.insert(QStringLiteral("monthLabel"),
                today.toString(QStringLiteral("yyyy年M月")));
  report.insert(QStringLiteral("rangeText"),
                dashboard.value(QStringLiteral("rangeText")));
  report.insert(QStringLiteral("totalSec"),
                dashboard.value(QStringLiteral("totalSec")));
  report.insert(QStringLiteral("totalText"),
                dashboard.value(QStringLiteral("totalText")));
  report.insert(QStringLiteral("activeDays"),
                dashboard.value(QStringLiteral("activeDays")));
  report.insert(QStringLiteral("appCount"),
                dashboard.value(QStringLiteral("appCount")));
  report.insert(QStringLiteral("topApps"), apps);

  const int activeDays =
      dashboard.value(QStringLiteral("activeDays")).toInt();
  const QString totalText =
      dashboard.value(QStringLiteral("totalText")).toString();
  const QString leadName =
      apps.isEmpty()
          ? QStringLiteral("还没有应用")
          : apps.first().toMap().value(QStringLiteral("displayName")).toString();
  report.insert(
      QStringLiteral("title"),
      activeDays > 0
          ? QStringLiteral("%1，时间在 %2 个日子里留下痕迹")
                .arg(today.toString(QStringLiteral("M月")))
                .arg(activeDays)
          : QStringLiteral("%1，等待第一段时间被记住")
                .arg(today.toString(QStringLiteral("M月"))));
  report.insert(
      QStringLiteral("summary"),
      activeDays > 0
          ? QStringLiteral("%1 的记录分布在 %2 个日子里，%3 最常出现在时间线上。")
                .arg(totalText)
                .arg(activeDays)
                .arg(leadName)
          : QStringLiteral("开启使用情况访问并同步后，本月故事会从真实记录中生成。"));

  QVariantList moments;
  const int momentCount = qMin(5, apps.size());
  for (int index = 0; index < momentCount; ++index) {
    const QVariantMap app = apps.at(index).toMap();
    QVariantMap moment;
    const QString name =
        app.value(QStringLiteral("displayName")).toString();
    const int days = app.value(QStringLiteral("recordedDays")).toInt();
    moment.insert(QStringLiteral("dateLabel"),
                  app.value(QStringLiteral("firstDateLocal")));
    moment.insert(
        QStringLiteral("title"),
        days > 1
            ? QStringLiteral("%1，在 %2 个日子里反复出现").arg(name).arg(days)
            : QStringLiteral("%1，留下了本月的一段时间").arg(name));
    moment.insert(QStringLiteral("body"),
                  app.value(QStringLiteral("storyText")));
    moment.insert(QStringLiteral("durationText"),
                  app.value(QStringLiteral("durationText")));
    moment.insert(QStringLiteral("recordedDays"), days);
    moment.insert(QStringLiteral("apps"), QVariantList{app});
    moments.append(moment);
  }

  QVariantMap model;
  model.insert(QStringLiteral("report"), report);
  model.insert(QStringLiteral("moments"), moments);
  model.insert(QStringLiteral("topApps"), apps);
  model.insert(QStringLiteral("empty"), apps.isEmpty());
  return model;
}

bool MobileUsageService::refreshUsageAccessState() {
#ifdef Q_OS_ANDROID
  const QJniObject activity =
      QNativeInterface::QAndroidApplication::context();
  const bool granted = QJniObject::callStaticMethod<jboolean>(
      "com/timearc/mobile/usage/UsageAccessBridge", "hasUsageAccess",
      "(Landroid/content/Context;)Z", activity.object<jobject>());
  setStatus(granted, syncStatus_,
            granted ? QStringLiteral("Usage Access granted")
                    : QStringLiteral("Usage Access required"));
  return granted;
#else
  setStatus(false, QStringLiteral("preview"),
            QStringLiteral("Android Usage Access is available on device"));
  return false;
#endif
}

bool MobileUsageService::openUsageAccessSettings() {
#ifdef Q_OS_ANDROID
  const QJniObject activity =
      QNativeInterface::QAndroidApplication::context();
  QJniObject::callStaticMethod<void>(
      "com/timearc/mobile/usage/UsageAccessBridge",
      "openUsageAccessSettings",
      "(Landroid/content/Context;)V", activity.object<jobject>());
  return true;
#else
  setStatus(false, QStringLiteral("preview"),
            QStringLiteral("Open on Android device to grant access"));
  return false;
#endif
}

bool MobileUsageService::requestImmediateSync() {
#ifdef Q_OS_ANDROID
  const QJniObject context =
      QNativeInterface::QAndroidApplication::context();
  QJniObject::callStaticMethod<void>(
      "com/timearc/mobile/usage/UsageSyncScheduler",
      "enqueueImmediateSync",
      "(Landroid/content/Context;)V", context.object<jobject>());
  setStatus(usageAccessGranted_, QStringLiteral("queued"),
            QStringLiteral("Android usage sync queued"));
  emit dataChanged();
  return true;
#else
  setStatus(false, QStringLiteral("preview"),
            QStringLiteral("Sync runs on Android device"));
  return false;
#endif
}

QString MobileUsageService::formatDuration(int seconds) {
  const int safeSeconds = std::max(0, seconds);
  const int hours = safeSeconds / 3600;
  const int minutes = (safeSeconds % 3600) / 60;
  if (hours > 0) {
    return minutes > 0 ? QStringLiteral("%1h %2m").arg(hours).arg(minutes)
                       : QStringLiteral("%1h").arg(hours);
  }
  if (minutes > 0) return QStringLiteral("%1m").arg(minutes);
  return QStringLiteral("%1s").arg(safeSeconds);
}

QString MobileUsageService::initialForName(const QString& displayName) {
  const QString trimmed = displayName.trimmed();
  if (trimmed.isEmpty()) return QStringLiteral("?");
  return trimmed.left(qMin<qsizetype>(2, trimmed.size())).toUpper();
}

QDate MobileUsageService::startDateForRange(const QString& range,
                                            const QDate& today) {
  const QString normalized = range.trimmed().toLower();
  if (normalized == QStringLiteral("7d") ||
      normalized == QStringLiteral("week")) {
    return today.addDays(1 - today.dayOfWeek());
  }
  if (normalized == QStringLiteral("30d") ||
      normalized == QStringLiteral("month")) {
    return QDate(today.year(), today.month(), 1);
  }
  if (normalized == QStringLiteral("year")) {
    return QDate(today.year(), 1, 1);
  }
  if (normalized == QStringLiteral("all") ||
      normalized == QStringLiteral("total")) {
    return QDate(1970, 1, 1);
  }
  return today;
}

QString MobileUsageService::friendlyDisplayName(
    const QString& packageName,
    const QString& currentLabel) {
  const QString package = packageName.trimmed().toLower();
  const QString label = currentLabel.trimmed();
  const bool labelLooksLikePackage =
      label.isEmpty() || label.compare(packageName, Qt::CaseInsensitive) == 0 ||
      (label.contains(QLatin1Char('.')) && !label.contains(QLatin1Char(' ')));
  if (!labelLooksLikePackage) return label;

  static const QMap<QString, QString> names = {
      {QStringLiteral("com.tencent.mm"), QStringLiteral("微信")},
      {QStringLiteral("com.tencent.mobileqq"), QStringLiteral("QQ")},
      {QStringLiteral("com.xingin.xhs"), QStringLiteral("小红书")},
      {QStringLiteral("tv.danmaku.bili"), QStringLiteral("哔哩哔哩")},
      {QStringLiteral("com.netease.cloudmusic"), QStringLiteral("网易云音乐")},
      {QStringLiteral("com.ss.android.ugc.aweme"), QStringLiteral("抖音")},
      {QStringLiteral("com.android.chrome"), QStringLiteral("Chrome")},
      {QStringLiteral("com.microsoft.emmx"), QStringLiteral("Edge")},
      {QStringLiteral("com.spotify.music"), QStringLiteral("Spotify")},
      {QStringLiteral("com.google.android.youtube"), QStringLiteral("YouTube")},
      {QStringLiteral("com.termux"), QStringLiteral("Termux")},
  };
  const auto it = names.constFind(package);
  if (it != names.cend()) return it.value();

  if (!label.isEmpty()) return label;
  const QString tail = package.section(QLatin1Char('.'), -1);
  if (tail.isEmpty()) return QStringLiteral("未知应用");
  QString readable = tail;
  readable.replace(QLatin1Char('_'), QLatin1Char(' '));
  readable.replace(QLatin1Char('-'), QLatin1Char(' '));
  if (!readable.isEmpty()) readable[0] = readable.at(0).toUpper();
  return readable;
}

void MobileUsageService::setStatus(bool accessGranted,
                                   const QString& status,
                                   const QString& text) {
  const bool changed = usageAccessGranted_ != accessGranted ||
                       syncStatus_ != status ||
                       syncStatusText_ != text;
  usageAccessGranted_ = accessGranted;
  syncStatus_ = status;
  syncStatusText_ = text;
  if (changed) emit statusChanged();
}
