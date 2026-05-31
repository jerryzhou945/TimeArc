#ifndef CALENDARMANAGER_H
#define CALENDARMANAGER_H

#include <QObject>
#include <QString>

class SettingsRepository;

// Lightweight calendar data bridge for QML.
// QML edits todo/photo/date JSON strings; persistence goes through
// SettingsRepository when available, with the legacy QSettings path kept only
// as a fallback for isolated construction.
class CalendarManager : public QObject {
  Q_OBJECT

  Q_PROPERTY(QString savedTodos READ savedTodos NOTIFY calendarDataChanged)
  Q_PROPERTY(QString dayPhotos READ dayPhotos NOTIFY calendarDataChanged)
  Q_PROPERTY(QString selectedDateKey READ selectedDateKey NOTIFY calendarDataChanged)

 public:
  explicit CalendarManager(SettingsRepository* settingsRepository = nullptr,
                           QObject* parent = nullptr);

  QString savedTodos() const;
  QString dayPhotos() const;
  QString selectedDateKey() const;

  Q_INVOKABLE void setSavedTodos(const QString& value);
  Q_INVOKABLE void setDayPhotos(const QString& value);
  Q_INVOKABLE void setSelectedDateKey(const QString& value);
  Q_INVOKABLE void completeTodo(const QString& dateKey, const QString& text);

 signals:
  void calendarDataChanged();

 private:
  QString m_savedTodos;
  QString m_dayPhotos;
  QString m_selectedDateKey;
  SettingsRepository* m_settingsRepository;

  void load();
  void save();
};

#endif
