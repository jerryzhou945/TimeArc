#include "calendarmanager.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>

CalendarManager::CalendarManager(QObject* parent) : QObject(parent) { load(); }

QString CalendarManager::savedTodos() const { return m_savedTodos; }

QString CalendarManager::dayPhotos() const { return m_dayPhotos; }

QString CalendarManager::selectedDateKey() const { return m_selectedDateKey; }

void CalendarManager::setSavedTodos(const QString& value) {
  if (m_savedTodos == value) return;
  m_savedTodos = value;
  save();
  emit calendarDataChanged();
}

void CalendarManager::setDayPhotos(const QString& value) {
  if (m_dayPhotos == value) return;
  m_dayPhotos = value;
  save();
  emit calendarDataChanged();
}

void CalendarManager::setSelectedDateKey(const QString& value) {
  if (m_selectedDateKey == value) return;
  m_selectedDateKey = value;
  save();
  emit calendarDataChanged();
}

void CalendarManager::completeTodo(const QString& dateKey, const QString& text) {
  // savedTodos 是按日期分组的 JSON 字符串。这里只修改目标日期下第一个同名待办，
  // 然后整体写回 QSettings，QML 收到信号后重新渲染。
  QJsonObject root;
  if (!m_savedTodos.isEmpty()) {
    QJsonDocument doc = QJsonDocument::fromJson(m_savedTodos.toUtf8());
    if (doc.isObject()) root = doc.object();
  }

  QJsonArray todos = root.value(dateKey).toArray();
  for (int i = 0; i < todos.size(); ++i) {
    QJsonObject todo = todos.at(i).toObject();
    if (todo.value("text").toString() == text) {
      todo["done"] = true;
      todos.replace(i, todo);
      break;
    }
  }

  root[dateKey] = todos;
  m_savedTodos =
      QString::fromUtf8(QJsonDocument(root).toJson(QJsonDocument::Compact));
  save();
  emit calendarDataChanged();
}

void CalendarManager::load() {
  // QSettings 会落到当前平台的用户配置区；对这个轻量日历数据足够简单可靠。
  QSettings settings("TimeArc", "CalendarManagerData");
  m_savedTodos = settings.value("savedTodos", "").toString();
  m_dayPhotos = settings.value("dayPhotos", "").toString();
  m_selectedDateKey = settings.value("selectedDateKey", "").toString();
}

void CalendarManager::save() {
  QSettings settings("TimeArc", "CalendarManagerData");
  settings.setValue("savedTodos", m_savedTodos);
  settings.setValue("dayPhotos", m_dayPhotos);
  settings.setValue("selectedDateKey", m_selectedDateKey);
  settings.sync();
}
