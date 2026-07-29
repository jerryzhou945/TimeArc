// SPDX-License-Identifier: GPL-3.0-or-later

#ifndef TIMEARC_SERVICES_MACOS_MACOS_MENU_LOCALIZER_H_
#define TIMEARC_SERVICES_MACOS_MACOS_MENU_LOCALIZER_H_

#include <QObject>
#include <QString>
#include <QTranslator>

// Owns the Qt Base translator used by Qt's native macOS application menu.
// TimeArc's regular QML strings stay in I18n.js; this bridge exists only
// because QCocoa replaces merged Preferences/Quit text with Qt catalog text.
class MacMenuLocalizer final : public QObject {
  Q_OBJECT

 public:
  explicit MacMenuLocalizer(QObject* parent = nullptr);

  Q_INVOKABLE bool setLanguage(const QString& mode);

 private:
  QTranslator translator_;
  QString activeMode_;
  bool installed_ = false;
};

#endif  // TIMEARC_SERVICES_MACOS_MACOS_MENU_LOCALIZER_H_
