#ifndef CALENDARMANAGER_H
#define CALENDARMANAGER_H

#include <QObject>
#include <QString>

// 日历页轻量数据服务。
//
// QML 负责编辑待办、每日照片和选中日期；这里只做持久化和少量 JSON 修改。
// 数据暂存在 QSettings 中，savedTodos/dayPhotos 本身是 QML 使用的 JSON 字符串。
class CalendarManager : public QObject {
  Q_OBJECT

  Q_PROPERTY(QString savedTodos READ savedTodos NOTIFY calendarDataChanged)
  Q_PROPERTY(QString dayPhotos READ dayPhotos NOTIFY calendarDataChanged)
  Q_PROPERTY(QString selectedDateKey READ selectedDateKey NOTIFY calendarDataChanged)

 public:
  explicit CalendarManager(QObject* parent = nullptr);

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

  void load();
  void save();
};

#endif
