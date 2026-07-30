// SPDX-License-Identifier: GPL-3.0-or-later

#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QResource>
#include <QStringList>

namespace {

const QString kBackgroundRoot =
    QStringLiteral(":/qt/qml/time_arc/resources/app/backgrounds");
const QString kSiteIconRoot =
    QStringLiteral(":/qt/qml/time_arc/resources/app/icons/sites");
const QString kMonthlyRoot =
    QStringLiteral(":/qt/qml/time_arc/resources/features/monthly-recap");

bool hasFiles(const QString& root, QStringList expected) {
  expected.sort();
  return QDir(root).entryList(QDir::Files, QDir::Name) == expected;
}

bool registerPack(const QString& path) {
  return QResource::registerResource(path);
}

bool unregisterPack(const QString& path) {
  return QResource::unregisterResource(path);
}

}  // namespace

int main(int argc, char* argv[]) {
  QCoreApplication app(argc, argv);
  if (argc != 4) {
    return 1;
  }

  const QString backgrounds = QString::fromLocal8Bit(argv[1]);
  const QString siteIcons = QString::fromLocal8Bit(argv[2]);
  const QString monthlyRecap = QString::fromLocal8Bit(argv[3]);

  if (!registerPack(backgrounds) ||
      !hasFiles(kBackgroundRoot,
                {QStringLiteral("background.png"),
                 QStringLiteral("background_night.png")}) ||
      QDir(kSiteIconRoot).exists() || QDir(kMonthlyRoot).exists()) {
    return 2;
  }
  if (!unregisterPack(backgrounds) || QDir(kBackgroundRoot).exists()) return 3;

  if (!registerPack(siteIcons) ||
      QDir(kSiteIconRoot).entryList(QDir::Files).size() != 26 ||
      !QFile::exists(kSiteIconRoot + QStringLiteral("/bilibili.png")) ||
      !QFile::exists(kSiteIconRoot + QStringLiteral("/douyin.ico")) ||
      QDir(kBackgroundRoot).exists() || QDir(kMonthlyRoot).exists()) {
    return 4;
  }
  if (!unregisterPack(siteIcons) || QDir(kSiteIconRoot).exists()) return 5;

  QStringList expectedMonths;
  for (int month = 1; month <= 12; ++month) {
    expectedMonths.append(
        QStringLiteral("month-%1.jpg").arg(month, 2, 10, QLatin1Char('0')));
  }
  if (!registerPack(monthlyRecap) ||
      !hasFiles(kMonthlyRoot, expectedMonths) ||
      QDir(kBackgroundRoot).exists() || QDir(kSiteIconRoot).exists()) {
    return 6;
  }
  if (!unregisterPack(monthlyRecap) || QDir(kMonthlyRoot).exists()) return 7;

  const QStringList packs = {
      backgrounds,
      siteIcons,
      monthlyRecap,
  };
  for (const QString& pack : packs) {
    if (!registerPack(pack)) return 8;
  }
  if (!QFile::exists(kBackgroundRoot + QStringLiteral("/background.png")) ||
      !QFile::exists(kSiteIconRoot + QStringLiteral("/bilibili.png")) ||
      !QFile::exists(kMonthlyRoot + QStringLiteral("/month-12.jpg")) ||
      QFile::exists(QStringLiteral(
          ":/qt/qml/time_arc/resources/features/memory-lake/memory_bg.png"))) {
    return 9;
  }
  return 0;
}
