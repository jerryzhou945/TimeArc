// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 TimeArc contributors

#include "harness_logger.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QMutex>
#include <QMutexLocker>
#include <QStandardPaths>
#include <QTextStream>
#include <QtGlobal>

namespace {

QMutex g_mutex;
QtMessageHandler g_previous = nullptr;
QString g_log_path;

QString computeLogPath() {
  // Put the log alongside other TimeArc state. GenericDataLocation maps to
  // %LOCALAPPDATA% on Windows and ~/.local/share on Unix; the subfolder
  // brings it under the same TimeArc/ directory the service already uses.
  const QString base =
      QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
  QDir dir(base);
  dir.mkpath(QStringLiteral("TimeArc/logs"));
  return dir.filePath(QStringLiteral("TimeArc/logs/harness-qt.log"));
}

const char* severityName(QtMsgType type) {
  switch (type) {
    case QtDebugMsg: return "DEBUG";
    case QtInfoMsg: return "INFO";
    case QtWarningMsg: return "WARNING";
    case QtCriticalMsg: return "CRITICAL";
    case QtFatalMsg: return "FATAL";
  }
  return "UNKNOWN";
}

void harnessMessageHandler(QtMsgType type,
                           const QMessageLogContext& ctx,
                           const QString& msg) {
  if (g_previous) {
    g_previous(type, ctx, msg);
  }
  if (type != QtWarningMsg && type != QtCriticalMsg && type != QtFatalMsg) {
    return;
  }
  QMutexLocker lock(&g_mutex);
  QFile f(g_log_path);
  if (!f.open(QIODevice::Append | QIODevice::Text)) {
    return;
  }
  QTextStream out(&f);
  const QString ts =
      QDateTime::currentDateTimeUtc().toString(Qt::ISODate);
  const QString category =
      QString::fromUtf8(ctx.category ? ctx.category : "default");
  const QString file =
      QString::fromUtf8(ctx.file ? ctx.file : "");
  out << ts << '\t' << severityName(type) << '\t' << category << '\t'
      << file << ':' << ctx.line << '\t' << msg << '\n';
}

}  // namespace

QString installHarnessLogger() {
  QMutexLocker lock(&g_mutex);
  if (!g_log_path.isEmpty()) {
    return g_log_path;
  }
  g_log_path = computeLogPath();
  g_previous = qInstallMessageHandler(harnessMessageHandler);
  return g_log_path;
}
