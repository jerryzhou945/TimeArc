#include "calendarmanager.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSettings>

#include "services/SettingsRepository.h"

namespace {
const QString kSavedTodosKey = QStringLiteral("calendar_saved_todos");
const QString kDayPhotosKey = QStringLiteral("calendar_day_photos");
const QString kSelectedDateKey = QStringLiteral("calendar_selected_date");
}  // namespace

CalendarManager::CalendarManager(SettingsRepository* settingsRepository,
                                 QObject* parent)
    : QObject(parent), m_settingsRepository(settingsRepository) {
  load();
}

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
  if (m_settingsRepository) {
    m_savedTodos = m_settingsRepository->getValue(kSavedTodosKey, "");
    m_dayPhotos = m_settingsRepository->getValue(kDayPhotosKey, "");
    m_selectedDateKey = m_settingsRepository->getValue(kSelectedDateKey, "");
    return;
  }

  QSettings settings("TimeArc", "CalendarManagerData");
  m_savedTodos = settings.value("savedTodos", "").toString();
  m_dayPhotos = settings.value("dayPhotos", "").toString();
  m_selectedDateKey = settings.value("selectedDateKey", "").toString();
}

void CalendarManager::save() {
  if (m_settingsRepository) {
    m_settingsRepository->setValue(kSavedTodosKey, m_savedTodos);
    m_settingsRepository->setValue(kDayPhotosKey, m_dayPhotos);
    m_settingsRepository->setValue(kSelectedDateKey, m_selectedDateKey);
    return;
  }

  QSettings settings("TimeArc", "CalendarManagerData");
  settings.setValue("savedTodos", m_savedTodos);
  settings.setValue("dayPhotos", m_dayPhotos);
  settings.setValue("selectedDateKey", m_selectedDateKey);
  settings.sync();
}
