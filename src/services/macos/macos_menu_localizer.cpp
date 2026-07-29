// SPDX-License-Identifier: GPL-3.0-or-later

#include "macos_menu_localizer.h"

#include <CoreFoundation/CoreFoundation.h>

#include <QCoreApplication>
#include <QDebug>
#include <QDir>
#include <QLibraryInfo>
#include <QLocale>
#include <QStringList>

namespace {

QString normalizedMode(const QString& mode) {
  if (mode == QLatin1String("en") || mode == QLatin1String("ja")) return mode;
  return QStringLiteral("zh");
}

CFStringRef appleLanguageForMode(const QString& mode) {
  if (mode == QLatin1String("en")) return CFSTR("en");
  if (mode == QLatin1String("ja")) return CFSTR("ja");
  return CFSTR("zh-Hans");
}

// AppKit adds its own rows to our menus — 自动填充 / 开始听写 / 表情与符号 in 编辑,
// 进入全屏幕 in 显示, the search field in 帮助 — and it finds those menus by
// comparing their titles against *its own* localization. Running under an
// English system while the UI is Chinese, it looks for "Edit"/"View"/"Help",
// finds 编辑/显示/帮助, matches nothing, and silently adds nothing.
//
// Writing AppleLanguages into our own preference domain is exactly what the
// system's per-app language setting does (System Settings › General ›
// Language & Region › Applications). AppKit then runs in the UI language, its
// expected titles are the ones we actually draw, and it contributes its rows
// in that language too.
//
// Bound at process start: a language change here takes effect on the next
// launch. Rows already contributed stay for the rest of the session, so no
// command is ever lost mid-run — see docs/macos-menu-bar-design.md §4.
void rememberAppKitLanguage(const QString& mode) {
  const void* values[] = {appleLanguageForMode(mode)};
  CFArrayRef languages =
      CFArrayCreate(nullptr, values, 1, &kCFTypeArrayCallBacks);
  if (!languages) return;

  CFPreferencesSetAppValue(CFSTR("AppleLanguages"), languages,
                           kCFPreferencesCurrentApplication);
  CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
  CFRelease(languages);
}

QLocale localeForMode(const QString& mode) {
  return mode == QLatin1String("ja") ? QLocale(QStringLiteral("ja"))
                                     : QLocale(QStringLiteral("zh_CN"));
}

QStringList translationDirectories() {
  const QString bundled =
      QDir(QCoreApplication::applicationDirPath())
          .filePath(QStringLiteral("../Resources/translations"));
  const QString installed =
      QLibraryInfo::path(QLibraryInfo::TranslationsPath);
  return bundled == installed ? QStringList{bundled}
                              : QStringList{bundled, installed};
}

}  // namespace

MacMenuLocalizer::MacMenuLocalizer(QObject* parent) : QObject(parent) {}

bool MacMenuLocalizer::setLanguage(const QString& mode) {
  const QString normalized = normalizedMode(mode);
  // Independent of the Qt catalog below, and cheap enough to re-assert: this
  // is what makes AppKit contribute its own rows to 编辑/显示/帮助 at all.
  rememberAppKitLanguage(normalized);
  if (normalized == activeMode_) return true;

  if (installed_) {
    QCoreApplication::removeTranslator(&translator_);
    installed_ = false;
  }
  activeMode_.clear();

  // English is Qt's source language, so removing the translator is sufficient.
  if (normalized == QLatin1String("en")) {
    activeMode_ = normalized;
    return true;
  }

  const QLocale locale = localeForMode(normalized);
  for (const QString& directory : translationDirectories()) {
    // Packaged builds deploy a merged qt_<locale>.qm. The qtbase fallback
    // keeps developer builds compatible with Qt installations that omit the
    // legacy meta catalog.
    for (const QString& catalog :
         {QStringLiteral("qt"), QStringLiteral("qtbase")}) {
      if (!translator_.load(locale, catalog, QStringLiteral("_"), directory)) {
        continue;
      }
      installed_ = QCoreApplication::installTranslator(&translator_);
      if (installed_) {
        activeMode_ = normalized;
        return true;
      }
    }
  }

  qWarning() << "Could not load Qt macOS menu translation for language"
             << normalized;
  return false;
}
