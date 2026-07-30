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

// English is the fallback for anything unrecognized, deliberately. This used
// to fall back to Chinese, which made Chinese an attractor: any stray or
// transient value re-pinned zh, and an English or Japanese session would then
// find AppKit speaking Chinese. Degrading to English is tolerable; degrading
// to a language the user did not choose is not.
QString normalizedMode(const QString& mode) {
  if (mode == QLatin1String("zh") || mode == QLatin1String("ja")) return mode;
  return QStringLiteral("en");
}

CFStringRef appleLanguageForMode(const QString& mode) {
  if (mode == QLatin1String("zh")) return CFSTR("zh-Hans");
  if (mode == QLatin1String("ja")) return CFSTR("ja");
  return CFSTR("en");
}

QString stringFromCFString(CFStringRef value) {
  if (!value) return {};
  const CFIndex length = CFStringGetLength(value);
  QString out(length, Qt::Uninitialized);
  CFStringGetCharacters(value, CFRangeMake(0, length),
                        reinterpret_cast<UniChar*>(out.data()));
  return out;
}

// The single element currently pinned, or an empty string when unset or
// shaped differently (a multi-entry list means someone else wrote it).
QString pinnedAppKitLanguage() {
  CFPropertyListRef stored = CFPreferencesCopyAppValue(
      CFSTR("AppleLanguages"), kCFPreferencesCurrentApplication);
  if (!stored) return {};

  QString result;
  if (CFGetTypeID(stored) == CFArrayGetTypeID()) {
    CFArrayRef list = static_cast<CFArrayRef>(stored);
    if (CFArrayGetCount(list) == 1) {
      CFStringRef first =
          static_cast<CFStringRef>(CFArrayGetValueAtIndex(list, 0));
      if (first && CFGetTypeID(first) == CFStringGetTypeID())
        result = stringFromCFString(first);
    }
  }
  CFRelease(stored);
  return result;
}

// AppKit contributes its own rows to our menus — 自动填充 / 开始听写 / 表情与符号
// to Edit, 进入全屏幕 to View, the search field to Help — but only to menus it
// recognizes, and it recognizes them by comparing titles against ITS OWN
// localization. Under an English system with a Chinese UI it looks for
// "Edit"/"View"/"Help", sees 编辑/显示/帮助, and silently adds nothing.
//
// Pinning AppleLanguages in our own preference domain is the one mechanism
// that fixes all three menus at once, and it is what the system's per-app
// language setting does (System Settings › General › Language & Region ›
// Applications). AppKit then runs in the UI language, expects the titles we
// actually draw, and contributes its rows in that language.
//
// AppKit resolves this once at process start, so a change lands on the next
// launch. Rows already contributed stay for the rest of the session, so no
// command disappears mid-run. See docs/macos-menu-bar-design.md §4.1.
void rememberAppKitLanguage(const QString& mode) {
  const QString wanted = stringFromCFString(appleLanguageForMode(mode));
  const QString pinned = pinnedAppKitLanguage();
  if (pinned == wanted) return;

  // Only interesting on the first divergence of a session: it says the OS rows
  // cannot appear until the next launch, and in which language they will be.
  static bool reported = false;
  if (!reported && !pinned.isEmpty()) {
    reported = true;
    qWarning().nospace()
        << "macOS menu bar: AppKit is running \"" << pinned
        << "\" while the UI language is \"" << mode
        << "\". System-provided menu rows stay in \"" << pinned
        << "\" until TimeArc is relaunched.";
  }

  const void* values[] = {appleLanguageForMode(mode)};
  CFArrayRef languages =
      CFArrayCreate(nullptr, values, 1, &kCFTypeArrayCallBacks);
  if (!languages) return;
  CFPreferencesSetAppValue(CFSTR("AppleLanguages"), languages,
                           kCFPreferencesCurrentApplication);
  CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
  CFRelease(languages);

  const QString readBack = pinnedAppKitLanguage();
  if (readBack != wanted) {
    qWarning() << "macOS menu bar: pinning AppleLanguages to" << wanted
               << "did not stick; preferences report" << readBack;
  }
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

MacMenuLocalizer::MacMenuLocalizer(QObject* parent) : QObject(parent) {
  // Nothing that arrives after this point reflects a user choice. On quit the
  // QML engine outlives SettingsRepository for a moment, so bindings like
  // DesktopAppShell.languageMode re-evaluate against a null repository and
  // emit their fallback — which would otherwise be pinned for the *next*
  // launch, leaving AppKit speaking a language nobody selected.
  if (QCoreApplication* app = QCoreApplication::instance()) {
    QObject::connect(app, &QCoreApplication::aboutToQuit, this,
                     [this]() { shuttingDown_ = true; });
  }
}

bool MacMenuLocalizer::setLanguage(const QString& mode) {
  if (shuttingDown_) return true;
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
