#include "services/mobile/mobile_usage_service.h"

#include <QDate>
#include <QDebug>

#ifdef Q_OS_ANDROID
#include <QGuiApplication>
#include <QJniObject>
#include <QtCore/qcoreapplication_platform.h>
#endif

#include <algorithm>

#include "services/mobile/mobile_usage_repository.h"

namespace {

const QString kAndroidPlatform = QStringLiteral("android");

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
  for (const QVariant& item : rows) {
    totalSec += item.toMap().value(QStringLiteral("foregroundSec")).toInt();
  }

  QVariantList topApps;
  for (const QVariant& item : rows) {
    QVariantMap row = item.toMap();
    const int seconds = row.value(QStringLiteral("foregroundSec")).toInt();
    const QString displayName =
        row.value(QStringLiteral("displayName")).toString();
    row.insert(QStringLiteral("durationText"), formatDuration(seconds));
    row.insert(QStringLiteral("initial"), initialForName(displayName));
    row.insert(QStringLiteral("sharePct"),
               totalSec > 0 ? qRound(seconds * 100.0 / totalSec) : 0);
    topApps.append(row);
  }

  dashboard.insert(QStringLiteral("totalSec"), totalSec);
  dashboard.insert(QStringLiteral("totalText"), formatDuration(totalSec));
  dashboard.insert(QStringLiteral("topApps"), topApps);
  dashboard.insert(QStringLiteral("empty"), topApps.isEmpty());
  dashboard.insert(QStringLiteral("usageAccessGranted"), usageAccessGranted_);
  dashboard.insert(QStringLiteral("syncStatus"), syncStatus_);
  dashboard.insert(QStringLiteral("syncStatusText"), syncStatusText_);
  return dashboard;
}

QVariantMap MobileUsageService::getDashboardForRange(const QString& range) {
  const QDate today = QDate::currentDate();
  return getUsageDashboard(startDateForRange(range, today),
                           today.toString(Qt::ISODate));
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

QString MobileUsageService::startDateForRange(const QString& range,
                                              const QDate& today) {
  const QString normalized = range.trimmed().toLower();
  if (normalized == QStringLiteral("7d") ||
      normalized == QStringLiteral("week")) {
    return today.addDays(-6).toString(Qt::ISODate);
  }
  if (normalized == QStringLiteral("30d") ||
      normalized == QStringLiteral("month")) {
    return today.addDays(-29).toString(Qt::ISODate);
  }
  return today.toString(Qt::ISODate);
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
