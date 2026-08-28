#ifndef SETTINGSREPOSITORY_H
#define SETTINGSREPOSITORY_H

#include <QObject>
#include <QString>
#include <QVariantMap>

class ManualProjectRepository;

class SettingsRepository : public QObject {
  Q_OBJECT

 public:
  explicit SettingsRepository(QObject* parent = nullptr);

  // 读缓存：首次读取时把整张 settings 表（几十行）一次性装进内存，之后 getValue/getBool
  // 纯内存命中。此前每次调用都 prepare+exec 一条 SELECT，而调用点包括**委托内的 text:
  // 绑定**（日历 displayTime / TimeRiver / StickyNote 每条目读一次 time_format），
  // 一次列表重排就是几十次 SQL。本进程是 GUI 库 settings 表的唯一写者（只经 setValue），
  // 故缓存即权威。整库被替换时必须 invalidateCache()。
  Q_INVOKABLE QString getValue(const QString& key,
                               const QString& defaultValue = QString());

  // 丢弃读缓存，下次读取重新装载。整库被换掉时调用（DatabaseManager::restoreDatabase
  // 会 emit databaseRestored；由 QML 转接，见 rules/04 §6：管理器之间不直连）。
  Q_INVOKABLE void invalidateCache();

  // The effective UI language: the stored `language_mode` when it names a
  // language TimeArc ships (en | zh | ja), otherwise the closest match to the
  // system language, persisted on the spot so the store stays the single
  // source of truth. Every reader of the UI language goes through this — no
  // caller carries a literal default.
  Q_INVOKABLE QString languageMode();

  Q_INVOKABLE bool setValue(const QString& key, const QString& value);

  Q_INVOKABLE bool getBool(const QString& key, bool defaultValue = false);

  Q_INVOKABLE bool setBool(const QString& key, bool value);

  Q_INVOKABLE bool migrateLegacyQSettings(
      ManualProjectRepository* manualProjectRepository);

  // 设置页导出（G-EXPORT）：整张 settings 表 (key -> value) 读成 QVariantMap，供 QML
  // 序列化成 JSON。只读，不动磁盘契约。
  Q_INVOKABLE QVariantMap getAllSettings();

  // 设置页导入（G-IMPORT 辅助）：读取本地文本文件内容（QML 无文件 IO，见 rules/04 §4）。
  // path 接受本地路径或 file:// URL；失败返回空串。只读取所选文件，不写 usage/契约文件。
  Q_INVOKABLE QString readTextFile(const QString& path);

  // 开机自启：Windows 注册当前用户的 TimeArc UI 登录项；macOS 由后台服务
  // 管理 launchd。纯 UI→系统登录项/子进程生命周期命令，不改 usage 磁盘契约。
  Q_INVOKABLE bool autostartSupported() const;

  // 查询是否已注册登录自启（解析 --status 输出的 autostart=on）。
  Q_INVOKABLE bool autostartEnabled();

  // 注册（true）/反注册（false）开机自启，返回是否成功。
  Q_INVOKABLE bool setAutostartEnabled(bool enabled);

  // Windows 首次成功启动默认注册登录自启。只执行一次；用户此后从设置关闭时
  // 会留下决定标记，后续启动绝不擅自重新开启。其他平台恒 false。
  Q_INVOKABLE bool ensureAutostartDefaultEnabled();

  // 当前是否有后台采集进程在跑（解析 --status 输出的 running=yes）。与「开机自启」
  // 注册态不同：自启只决定登录时是否拉起，这里是「此刻是否在采集」。
  Q_INVOKABLE bool isBackgroundCollectionRunning();

  // 优雅停止正在运行的后台采集（time-arc-service.exe --stop 置位 Local\TimeArcStop，
  // 让 tracker flush 当前会话后退出——非 /F 硬杀）。会轮询等待其真正释放数据库（迁移/
  // 恢复要拿独占文件锁）。返回停止后是否确已不在运行。守 I1：纯 UI→子进程命令。
  Q_INVOKABLE bool stopBackgroundCollection();

  // H5 S2：立即拉起一个后台采集进程（time-arc-service.exe --start；单实例 mutex 令其
  // 幂等——已在跑则新实例静默退出）。配合 stopBackgroundCollection 实现设置页「应用并
  // 重启采集」。被拉起的服务在启动时重读 service_config.json，故新写入的 idle/track 即时
  // 生效（服务侧读取待 A3 落地，见 DatabaseManager::writeServiceConfig）。
  // 返回启动后是否在采集（追踪被关时服务自行退出→false，即诚实的「已暂停」）。
  // 守 I1：纯 UI→子进程命令。
  Q_INVOKABLE bool startBackgroundCollection();

  // 一次 `status --json` 取回服务状态，供状态栏菜单一次开菜单只 spawn 一个子进程。
  // Windows 与 macOS 都返回真实运行态；Windows 的 autostartEnabled 取 TimeArc UI
  // 登录启动项（UI 再拉起 collector），macOS 取 service/launchd 注册态。
  // 键：ok / autostartEnabled / trackingRunning / trackingEnabled。ok=false 时其余
  // 键不可信（服务不可达），调用方应显示「未知」而非假的「关」。
  Q_INVOKABLE QVariantMap serviceState();

  // 立即开始采集：Windows 走幂等 `--start`；macOS 有注册就叫 launchd 拉起，
  // 没注册则起一个临时实例（`start` 动词）。与 macOS「应用并重启采集」不同——
  // 后者只走 `enable`，绝不制造 launchd 管不着的进程。
  Q_INVOKABLE bool startTrackingNow();

 signals:
  // 服务侧生命周期状态可能已变（自启注册、是否在采集），请重读。
  //
  // 只报「变了」不带新值：真值在 launchd，带值等于又造一份副本。状态栏菜单和设置页
  // 都经本类改状态，故本类是唯一能同时通知到两边的地方。注意这只覆盖 app 内的改动——
  // 用户在系统设置里手动关掉登录项，谁也收不到，那种要靠页面可见时重读。
  void serviceStateChanged();

 public:
  // macOS 启动自检：设置里开着自启时，问一次 `status --json`，把开关同步成真值，
  // 发现没注册/没在跑就 `enable` 修复（RunAtLoad 顺带把采集拉起来）。设置里没开自启
  // 就什么都不做——绝不擅自装登录项。返回自检后是否在采集。
  // 其他平台恒 false（Windows 行为不变）。守 I1：纯 UI→子进程命令。
  Q_INVOKABLE bool verifyBackgroundCollection();

 private:
  // 整张 settings 表的内存镜像。缓存是**进程级**的，不是每实例一份：所有实例都走同一个
  // 具名连接（"timearc"）、同一张表，而代码里确实会同时存在多个 SettingsRepository
  // （tests/db_smoke.cpp 就用第二个实例模拟「重启后重读」）。做成每实例一份的话，A 写入
  // 之后 B 仍拿着自己那份陈旧快照——db_smoke 正是这样抓到的。实现见 .cpp 的匿名命名空间。
  // 装不上（库未开 / 查询失败）时不置 loaded，getValue 退回 defaultValue，与加缓存前
  // 逐字节一致。
  void ensureCacheLoaded();
};

#endif
