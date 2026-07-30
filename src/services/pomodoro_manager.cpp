#include "services/pomodoro_manager.h"

#include <QDate>
#include <QDateTime>
#include <QJsonDocument>
#include <QJsonObject>
#include <QtGlobal>

#include "services/settings_repository.h"

namespace {

// 存档键沿用 QML 时代的名字：改名等于把用户手上在途的那一程静默丢掉，只为消掉
// 名字里的 Memo。番茄钟早已不属于备忘黑板，键名从此只是历史。
const char kStoreKey[] = "memoryLakeMemoPomodoro";
const char kTodayKey[] = "pomodoro_today";
const char kDurationKey[] = "pomodoro_duration";
const char kTitleKey[] = "pomodoro_title";

constexpr int kDefaultTotalSeconds = 25 * 60;
constexpr int kMaxMinutes = 180;
constexpr int kSaveDebounceMs = 500;
constexpr int kTickMs = 1000;

int clampMinutes(int v) { return qBound(0, v, kMaxMinutes); }
int clampSeconds(int v) { return qBound(0, v, 59); }

}  // namespace

PomodoroManager::PomodoroManager(SettingsRepository* settings, QObject* parent)
    : QObject(parent),
      m_total(kDefaultTotalSeconds),
      m_remain(kDefaultTotalSeconds),
      m_running(false),
      m_title(QStringLiteral("专注一会儿")),
      m_loaded(false),
      m_anchorMs(0),
      m_remainAtAnchor(kDefaultTotalSeconds),
      m_settings(settings) {
  // 1Hz 只是刷新节拍，不是计时来源：漏拍不丢秒，下一拍照样算得准。
  m_timer.setInterval(kTickMs);
  connect(&m_timer, &QTimer::timeout, this, &PomodoroManager::onTick);

  m_saveTimer.setInterval(kSaveDebounceMs);
  m_saveTimer.setSingleShot(true);
  connect(&m_saveTimer, &QTimer::timeout, this, [this]() { save(); });

  load();
}

qint64 PomodoroManager::currentMs() const {
  return QDateTime::currentMSecsSinceEpoch();
}

int PomodoroManager::total() const { return m_total; }

int PomodoroManager::remain() const { return m_remain; }

bool PomodoroManager::running() const { return m_running; }

QString PomodoroManager::title() const { return m_title; }

QString PomodoroManager::timeText() const {
  const int mm = m_remain / 60;
  const int ss = m_remain % 60;
  return QStringLiteral("%1:%2")
      .arg(mm, 2, 10, QLatin1Char('0'))
      .arg(ss, 2, 10, QLatin1Char('0'));
}

qreal PomodoroManager::progress() const {
  if (m_total <= 0) return 0.0;
  return 1.0 - static_cast<qreal>(m_remain) / static_cast<qreal>(m_total);
}

QString PomodoroManager::settingsValue(const QString& key) const {
  if (!m_settings) return QString();
  return m_settings->getValue(key, QString());
}

// 设置页的默认专注分钟：无 / 非法 / 非正 → 0，表示沿用本引擎默认的 25 分钟。
int PomodoroManager::settingsMinutes() const {
  bool ok = false;
  const int v = settingsValue(QString::fromLatin1(kDurationKey)).toInt(&ok);
  return (ok && v > 0) ? v : 0;
}

void PomodoroManager::load() {
  bool hadSaved = false;

  const QString raw = settingsValue(QString::fromLatin1(kStoreKey));
  if (!raw.isEmpty()) {
    QJsonParseError err{};
    const QJsonDocument doc = QJsonDocument::fromJson(raw.toUtf8(), &err);
    if (err.error == QJsonParseError::NoError && doc.isObject()) {
      const QJsonObject o = doc.object();
      if (o.value(QStringLiteral("total")).isDouble() &&
          o.value(QStringLiteral("total")).toInt() > 0) {
        m_total = o.value(QStringLiteral("total")).toInt();
      }
      const QJsonValue titleValue = o.value(QStringLiteral("title"));
      if (titleValue.isString() && !titleValue.toString().isEmpty()) {
        m_title = titleValue.toString();
      }
      const QJsonValue remainValue = o.value(QStringLiteral("remain"));
      const int rm = remainValue.isDouble() ? remainValue.toInt() : m_total;
      m_remain = qBound(0, rm > 0 ? rm : m_total, m_total);
      // 重启一律恢复为暂停态：跨重启没有墙钟锚点可续（进程不在，没人记录起点），
      // 自动续跑等于凭空捏造一段专注。
      m_running = false;
      hadSaved = true;
    }
  }

  if (!hadSaved) {
    // 无存档 → 采用设置页的默认时长 / 标题。
    const int m = settingsMinutes();
    if (m > 0) {
      m_total = m * 60;
      m_remain = m_total;
    }
    const QString t = settingsValue(QString::fromLatin1(kTitleKey));
    if (!t.isEmpty()) m_title = t;
  }

  m_remainAtAnchor = m_remain;
  m_loaded = true;

  emit totalChanged();
  emit remainChanged();
  emit runningChanged();
  emit titleChanged();
  emit progressChanged();
}

void PomodoroManager::save() {
  if (!m_settings || !m_loaded) return;
  QJsonObject o;
  o.insert(QStringLiteral("total"), m_total);
  o.insert(QStringLiteral("remain"), m_remain);
  o.insert(QStringLiteral("title"), m_title);
  m_settings->setValue(
      QString::fromLatin1(kStoreKey),
      QString::fromUtf8(QJsonDocument(o).toJson(QJsonDocument::Compact)));
}

void PomodoroManager::scheduleSave() {
  if (!m_loaded) return;
  m_saveTimer.start();
}

// 今日完成数（供设置页数据概览）：date-stamped，跨天自动归零。
void PomodoroManager::recordCompletion() {
  if (!m_settings) return;
  const QString today = QDate::currentDate().toString(QStringLiteral("yyyy-MM-dd"));
  int n = 1;
  const QString raw = settingsValue(QString::fromLatin1(kTodayKey));
  if (!raw.isEmpty()) {
    const QJsonDocument doc = QJsonDocument::fromJson(raw.toUtf8());
    if (doc.isObject()) {
      const QJsonObject o = doc.object();
      if (o.value(QStringLiteral("d")).toString() == today) {
        n = o.value(QStringLiteral("n")).toInt() + 1;
      }
    }
  }
  QJsonObject out;
  out.insert(QStringLiteral("d"), today);
  out.insert(QStringLiteral("n"), n);
  m_settings->setValue(
      QString::fromLatin1(kTodayKey),
      QString::fromUtf8(QJsonDocument(out).toJson(QJsonDocument::Compact)));
}

void PomodoroManager::setTotalSeconds(int seconds) {
  if (seconds == m_total) return;
  m_total = seconds;
  emit totalChanged();
  emit progressChanged();
  scheduleSave();
}

void PomodoroManager::setRemainSeconds(int seconds) {
  if (seconds == m_remain) return;
  m_remain = seconds;
  emit remainChanged();
  emit progressChanged();
}

void PomodoroManager::setTitle(const QString& title) {
  if (title == m_title) return;
  m_title = title;
  emit titleChanged();
  scheduleSave();
}

void PomodoroManager::anchorNow() {
  m_anchorMs = currentMs();
  m_remainAtAnchor = m_remain;
}

void PomodoroManager::refreshFromClock() {
  if (!m_running) return;

  const qint64 now = currentMs();
  if (now < m_anchorMs) {
    // 墙钟被往回拨（NTP 校正 / 用户改表）。既不能让剩余时间倒着涨，也不能就此冻住
    // 到真实时间追上来，于是就地重锚，从当前剩余继续走。
    anchorNow();
    return;
  }

  const qint64 elapsed = (now - m_anchorMs) / 1000;
  const int next =
      static_cast<int>(qMax<qint64>(0, static_cast<qint64>(m_remainAtAnchor) - elapsed));
  if (next == m_remain) return;

  setRemainSeconds(next);
  if (m_remain == 0) finishSession();
}

void PomodoroManager::finishSession() {
  m_running = false;
  m_timer.stop();
  emit runningChanged();
  save();
  recordCompletion();
  emit finished();
}

void PomodoroManager::onTick() { refreshFromClock(); }

void PomodoroManager::startTimer() {
  if (m_running) return;
  // 0 分 0 秒不可开始，否则秒针刚跑就判完成。
  if (m_total <= 0) return;
  if (m_remain <= 0) setRemainSeconds(m_total);

  m_running = true;
  anchorNow();
  m_timer.start();
  emit runningChanged();
}

void PomodoroManager::pauseTimer() {
  if (!m_running) {
    save();   // 与旧实现一致：pauseTimer() 无条件落一次盘。
    return;
  }
  // 先按墙钟结账到此刻，再停表——否则最后那不足一拍的时间会被抹掉。
  refreshFromClock();
  if (!m_running) return;   // 刚好走到零，finishSession() 已经收尾。

  m_running = false;
  m_timer.stop();
  emit runningChanged();
  save();
}

void PomodoroManager::resetTimer() {
  if (m_running) {
    m_running = false;
    m_timer.stop();
    emit runningChanged();
  }
  // 重置回设置页的默认时长 / 标题（标题与时长对称同步）。
  const int m = settingsMinutes();
  if (m > 0) setTotalSeconds(m * 60);
  const QString t = settingsValue(QString::fromLatin1(kTitleKey));
  if (!t.isEmpty()) setTitle(t);

  setRemainSeconds(m_total);
  m_remainAtAnchor = m_remain;
  save();
}

void PomodoroManager::setMinutes(int minutes) {
  const int s = m_remain % 60;
  setTotalSeconds(clampMinutes(minutes) * 60 + (m_running ? 0 : clampSeconds(s)));
  if (!m_running) {
    setRemainSeconds(m_total);
    m_remainAtAnchor = m_remain;
  }
}

void PomodoroManager::setSeconds(int seconds) {
  const int mnt = (m_running ? m_total : m_remain) / 60;
  setTotalSeconds(mnt * 60 + clampSeconds(seconds));
  if (!m_running) {
    setRemainSeconds(m_total);
    m_remainAtAnchor = m_remain;
  }
}
