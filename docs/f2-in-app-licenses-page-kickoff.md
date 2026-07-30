# F2 · 应用内第三方许可证页面（In-App Third-Party Licenses）· 实现启动（Kickoff / 多 session 拆分）

> **用途**：把 `docs/implementation-backlog.md` §F2（in-app 第三方许可证页面）从「散落待办」展开成
> **带依赖、可逐 session 落地**的执行计划。F2 是「发布合规」弧的第二张（UI 渲染侧），消费姊妹篇
> [`f1-release-dynamic-link-qt-kickoff.md`](f1-release-dynamic-link-qt-kickoff.md) §S2 产出的 `resources/licenses/`。
>
> **体例**参照 `docs/h5-service-config-channel-kickoff.md` / `docs/d1-export-backup-restore-kickoff.md` /
> `docs/settings-functional-replication.md`（设置页结构）。
>
> **配套权威**：`.harness/rules/06-licensing.md` **§4**（应用内页面三条硬要求）、`.harness/CHARTER.md` **I6**
> （文本须可从 UI 抵达）、`.harness/state/frozen-files.json`。
>
> **现行落点（2026-07-30）**：最初按 Route A 落在「导入导出」卡片；随后按
> Route B 提升为设置内独立的「关于与开源许可」分区。下文 Route A 内容保留为
> 初始实施记录，不再描述当前导航结构。
>
> **维护**：完成 → 勾掉下表 + 移进 session log，并**同时**更新 `.harness/rules/06-licensing.md §4` 与
> `README.md`（line 585 Roadmap + line 616-622 Third-Party 表）——`rules/06:64` 明文要求「Update this rule and
> the main README together when this lands」。（注：`harness_check` pass 7 仅在**新增独立源文件**[Route C] 时才强制连带触 rules/README；默认 Route A/B 改单文件不触发 pass 7——同步义务源自 `rules/06:64`，仍须做。）

---

## 0. 现状校正（这是 F2 的起点）

### 0.1 应用内零许可证页面（待补）

- 全 `qml/` 树 grep `licens|许可|License` **零命中**（除无关注释）；`README.md:585` Roadmap「Add an in-app licenses page」仍 `[ ]`。
- 唯一版本字串在**移动端**：`qml/mobile/pages/MobileSettingsPage.qml:99` `"TimeArc · 本地版本 1.0.0"`；**桌面端无「关于 / 版本 / 许可」任何面**，无 QML 可读的版本访问器。

### 0.2 落点：桌面设置页 = `DesktopProfilePage.qml`（5 tab）

- `qml/desktop/pages/DesktopProfilePage.qml`（~1856 行，v88 暗玻璃原地重皮 A-NAME，`:6`）。
- 5 个 tab（`:320-326`）：`general 通用` / `tracking 追踪与应用` / `privacy 隐私与数据` / `memo 备忘与番茄钟` / `export 导入导出`。
- **`export` tab 是数据 / 运维主页**（`:1409-1518`），已托管 D1「数据库备份与恢复」(`:1429`)、D2「数据库位置」(`:1444`)、「当前数据概览」(`:1482`)、「恢复与重置」(`:1500`)——**「关于与开源许可」卡的天然归宿**。

### 0.3 可复用模式（零或极少新文件）

- **`SettingsCard`**（`:1634-1676`）：`GlassPanel` + badge 图标 + 标题/描述头 + 默认 body 槽——卡片骨架。
- **`SilkyFlickable`**（`qml/desktop/memorylake/SilkyFlickable.qml`）：缓动滚轮 + 霓虹滚条——**滚动展示许可全文**用它。
- **`GhostBtn`**（`:1745`，primary/danger 变体）、**`MetricTile`**（`:1726`）、**`ThinRule`**（`:1704`）、**`PlaceholderNote`**（`:1711`）。
- **`GlassPanel` 等暗玻璃控件**在 `qml/desktop/memorylake/`（`import "../memorylake"`，`:4`）。
- **离线读文本（核心坑，须 S1 实测）**：`settingsRepository.readTextFile()`（`src/services/settings_repository.cpp:338-355`，`QFile` 实现）**只认 `:/` 资源前缀，不认 `qrc:` scheme**——而 QML 树内嵌在 `qrc:/qt/qml/time_arc/`（`src/main.cpp:163`），`Qt.resolvedUrl(".../x.txt")` 产出的正是 `qrc:/…` URL，直接传 `readTextFile` 会**静默返回空串**（现唯一调用方 `DesktopProfilePage.qml:412` 读的是 `FileDialog` 的 `file://`）。S1 须用 §2-S1 三选一可读路径并 build 抓图实测非空。

### 0.4 待呈现的清单（与 `rules/06 §1` / README Third-Party 表对齐）

| 组件 | 版本 | 许可 | 链接方式 | 文本来源（F1-S2 产出） |
|------|------|------|----------|------------------------|
| Qt 6 | ≥6.8（本机 6.11.1） | LGPL-3.0（with exceptions） | **动态** | `resources/licenses/qt-lgpl-3.0.txt` (+ `qt-gpl-3.0.txt`) |
| SQLite | 3.51.3（`sqlite3.h:149`） | Public domain | 静态（`thirdparty/sqlite3`） | `resources/licenses/sqlite-public-domain.txt` |
| Parson | 1.5.3（`parson.h:4` / `:37-39`） | MIT | 静态（`thirdparty/parson`） | `resources/licenses/parson-mit.txt` |
| TimeArc 自身 | — | GPL-3.0-or-later | — | `resources/licenses/timearc-gpl-3.0.txt`（= 仓库 `LICENSE`） |

> `rules/06 §4(1)` 仅强制 **名称 + 版本 + 全文**三项；上表「链接方式」为**自愿附加列**（§S1/§6 沿用四列展示，勿误读成义务）。**SQLite 为 public domain、无许可正文**——以作者 public-domain blessing + 「公有领域，无许可文本」显式说明满足 §4(1)（**有意偏离、已记录**）。

### 0.5 依赖与冻结边界

- **依赖 F1-S2**：`resources/licenses/*.txt` 由 F1 产出。**推荐 F1 先行**；若 F2 抢跑，可在 F2-S1 内自建这些文本（口径同 F1-S2），但**仍由 F1 拥有随包分发**——勿两份拷贝（见 §3 共享产物归属）。
- **非冻结落点**：`DesktopProfilePage.qml`、`qml/CMakeLists.txt`（`TIME_ARC_QML_FILES`，仅当新增独立 QML 文件）、`resources/CMakeLists.txt`、`qml/desktop/DesktopAppShell.qml`（仅当走独立页 Route C）。
- **冻结（不碰）**：顶层 `CMakeLists.txt`、`src/CMakeLists.txt`、`src/service/CMakeLists.txt`。**只要复用 `readTextFile()` 不新增 C++，就不触冻结的 `src/CMakeLists.txt` → 提案：否。**

---

## 1. 范围与落地顺序（依赖图）

```
（F1-S2 产出 resources/licenses/*.txt）
        └──> S1 应用内「关于与开源许可」面（渲染组件清单 + 查看全文 + 版本）
                    └──> S2 同步律：rules/06 §4 + README + thirdparty 新增即同步的流程
```

### 1.2 三条呈现路线（决策门 · 须维护者拍板）

**Route A — `export` tab 内新增卡（推荐 MVP · 零新文件注册 · 提案：否）**
在 `DesktopProfilePage.qml` 的 `export` SectionGrid（`:1517` 后）追加一张 `SettingsCard`（`badge:"©"`、`cardTitle:"关于与开源许可"`、`wide:true`）。复用现成暗玻璃卡 + 内联组件，**无须改任何 CMake / 路由**。**本 kickoff 默认走 Route A。**

**Route B — 新增第 6 个 tab（中 · 提案：否）**
在 `tabModel`（`:320-326`）加 `about` tab + 对应 SectionGrid。比 A 更显眼，仍仅改 `DesktopProfilePage.qml`，无新文件。适合「关于」内容会扩张（版本 / 致谢 / 更新日志）时。

**Route C — 独立全幅页 + 导航入口（重 · 提案：否，但改面最大）**
新建 `qml/desktop/pages/DesktopAboutPage.qml` → 注册 `qml/CMakeLists.txt` `TIME_ARC_QML_FILES`（非冻结）+ 在 `DesktopAppShell.qml` 加路由（`navItems :129-146` / `fullBleedPage :62-63` / route map `:172`）。仅当产品要把「关于」升为一等导航项时。

> 决策门产出：维护者在 A / B / C 间选一。默认 A：最小纵切、零注册、最快满足 CHARTER I6「reachable from the UI」。

---

## 2. 多 session 拆分（逐张范围卡）

### S1 — 应用内「关于与开源许可」面（MVP 纵切 · 非冻结 · Track B · 提案：否）

**目标**：在设置页呈现可离线阅读的第三方许可证全文，满足 `rules/06 §4` 三条 + CHARTER I6。
- **组件清单**：用 `Repeater` 渲染 §0.4 四行，每行一块 sunken `Rectangle`（仿 D2「数据库位置」卡 `:1444-1480` 的 `ml.calSunkBg` + `wrapMode`），显示 **名称 + 版本 + 许可 + 链接方式**，附 `GhostBtn "查看许可全文"`。
- **全文展示（载入器三选一 · 全部 提案：否 · S1 须实测非空）**：点「查看全文」→ `SilkyFlickable` 包换行 `Text`，文本取自 `resources/licenses/<file>.txt`，载入路径择一：
  - **(推荐) 纯 QML `XMLHttpRequest`** `GET` `Qt.resolvedUrl("../../resources/licenses/<file>.txt")`（QML 的 XHR 支持 `qrc:` scheme）——**零 C++**；
  - 把 `qrc:/…` 规整成 `:/…`（去掉 `qrc` 前缀）再传 `settingsRepository.readTextFile()`（`QFile` 认 `:/`）——**零 C++**；
  - 扩展 `readTextFile` 识别 `qrc:` scheme——改既有 `settings_repository.cpp`（**非冻结、已在 `src/CMakeLists`，提案：否**），增少量 C++。
- **应用名 + 版本**：显示「TimeArc」+ 版本。版本源决策（§5 风险）：MVP 用 QML 常量（对齐移动端 `:99` 的 `"1.0.0"`）；如需真值，在**既有类**（如 `settings_repository` 或一个 `AppInfo` 上下文属性）加只读访问器读 `PROJECT_VERSION`——注意 `CMakeLists.txt:3` `project(time-arc VERSION 0.1)`，真值是 **0.1** 非 1.0.0；改既有 .cpp/.h **非冻结、提案：否**，**仅新增独立文件**才触冻结 `src/CMakeLists.txt`。MVP 用常量以保纯 QML。
- 文件红线：🟢 `DesktopProfilePage.qml`（Route A：export tab 加卡）；如 Route C 另见 §1.2。⛔ 顶层 / `src` / `src/service` 的 `CMakeLists.txt`；⛔ 不新增 C++（守住「提案：否」）。
- 变更提案：**否**。验收：见 §6（离线全文滚动 + 抓图）。

### S2 — 同步律 + 文档（收尾 · 非冻结 · Track B · 提案：否）

**目标**：让页面随依赖演进不腐化，并按 `rules/06:64` 同步规则文档。
- 更新 `.harness/rules/06-licensing.md §4`（标注页面已落地 + 落点 + 文本路径）与 `README.md`（line 585 勾掉 + line 620 Qt 行「dynamic (planned)」→「dynamic」+ 表与 `rules/06 §1` 对齐）。
- 写入「新增 `thirdparty/CMakeLists.txt` 组件 → 必须新增 `resources/licenses/` 文本 + 本页 `Repeater` 条目」的同步清单（`rules/06 §4(3)`）；可选：给 `harness_check` 加一条「`thirdparty/` 组件数 == 页面条目数」断言（增强，非必须）。
- 文件红线：🟢 `.harness/rules/06-licensing.md`、`README.md`、（可选）`harness_check.py`。
- 变更提案：**否**。验收：`rules/06 §4` 与 README 与页面三者一致；`harness_check.py` exit 0（pass 7 仅 Route C 新增文件时才校验 rules/README；本同步义务源自 `rules/06:64`，不靠 pass 7 强制）。

---

## 3. 冻结文件与变更提案边界

**非冻结（可直接改）**：`qml/desktop/pages/DesktopProfilePage.qml`、`qml/desktop/DesktopAppShell.qml`、`qml/CMakeLists.txt`、`resources/CMakeLists.txt`、`resources/licenses/*`、`.harness/rules/06-licensing.md`、`README.md`、`docs/*`。

**冻结（改前须先填 `.harness/templates/change-proposal.md`）**：顶层 `CMakeLists.txt`、`src/CMakeLists.txt`、`src/service/CMakeLists.txt`。

**关键事实**：F2 走 Route A + 纯 QML 载入器（XHR，§S1）⇒ **不触任何冻结文件、不新增 C++ → 提案：否**。即便选「扩展 `readTextFile`」也只改非冻结的 `settings_repository.cpp`（已在 `src/CMakeLists`），仍 提案：否。唯一会踩冻结的是**新增独立 C++ 文件**（会触 `src/CMakeLists.txt`），故版本号 MVP 用常量、或把访问器加进既有类规避。

**共享产物归属（与 F1 的边界，杜绝 gap/overlap）**：`resources/licenses/*.txt` = **F1-S2 拥有产出 + 随包分发**；**F2 仅渲染**。F2 文档与代码注释须点名「文本由 F1-S2 产出」，不得各自再造一份。若 F2 先行临时自建文本，落地 F1 时须收敛为单一份、由 F1 拥有。

---

## 4. 必须保留的不变量

1. **CHARTER I6**：第三方文本**可从 UI 抵达** + **离线**（`rules/06 §4(2)`，文本在 `resources/`）。F2 守此。
2. **`rules/06 §4(1)`**：每个组件须显示**名称 + 版本 + 全文**——不可只列名称或截断全文。
3. **`rules/06 §4(3)` 同步律**：`thirdparty/CMakeLists.txt` 增组件 → 文本 + 页面条目同步增。
4. **单一真相源**：文本只来自 `resources/licenses/`（F1 产出），禁止页面内硬编码许可全文。
5. **设置页既有坑（来自 agent memory `timearc-settings-page`）**：勿重皮原生 `Controls`（用纯 `Item` + `Controls.Popup` 且 **Popup 背景须不透明**）；受控控件勿自写绑定属性；自定义 `Item` 勿撞基类成员名；设置 KV 无变更信号须主动重读。
6. **I1/I2 不碰**：F2 纯 UI 读 qrc 文本，不碰磁盘数据契约、不引入 IPC。

---

## 5. 风险登记

- **文本漂移**：页面清单与 `rules/06 §1` / README 表 / `resources/licenses/` 真实版本不一致。缓解：S1 渲染源用 §0.4 表，S2 落同步律。
- **`qrc:` scheme 读不出（核心坑）**：`readTextFile()`（`QFile`）不认 `qrc:`，而 `Qt.resolvedUrl` 产出的恰是 `qrc:`，直接用会**静默空串**。缓解：S1 用 XHR（认 `qrc:`）或把 `qrc:/` 规整成 `:/` 前缀；build 抓图实测全文非空。
- **版本号真值缺失**：无 QML 版本访问器；真值（`CMakeLists.txt:3` = **0.1**，非 1.0.0）须在**既有类**加只读访问器（改既有 .cpp/.h 非冻结、提案：否；仅**新增独立文件**才触冻结 `src/CMakeLists.txt`）。缓解：MVP 用常量保纯 QML。
- **离线断言遗漏**：若误从网络取文本则违反 §4(2)。缓解：仅读 `resources/licenses/` 内嵌资源；§6 拔网验收。
- **Popup / 透明度坑**：暗玻璃 Popup 背景透明会导致选项 / 全文叠影（设置页历史坑）。缓解：背景不透明、`SilkyFlickable` 内滚动。
- **新组件未上页**：日后加第三方依赖忘了上页 → 违反 §4(3)。缓解：S2 同步清单 +（可选）harness 断言。
- **品牌图标 / 游戏截图 IP（越界提醒）**：`resources/app/icons/sites/*`、`resources/features/memory-lake/*.png` 是第三方商标 / 版权美术，**不属本页代码许可范畴**，须维护者单独决策（署名 / 替换 / 移除）。勿擅自塞进许可页冒充已合规。

---

## 6. 验收口径（贯穿各 session）

- **离线全文**：拔网（或断面机）下，每个组件「查看全文」均能滚动出**完整**许可文本（非截断）。
- **三要素**：每行均含 名称 + 版本 + 全文（`rules/06 §4(1)` 三项硬要求；「许可 / 链接方式」为自愿附加列）；全文经 §S1 选定载入器读出、**实测非空**（规避 `qrc:` scheme 坑）。
- **可达性**：从设置页 `export` tab（Route A）即可抵达，满足 I6「reachable from the UI」。
- **抓图验收**：`PrintWindow`-by-PID 抓**本实例**，min **1280×720** + 最大化，确认卡片 / 全文弹层在暗玻璃下不叠影、可读（rebuild 前先杀 `TimeArc.exe`）。
- **harness**：`harness_check.py` exit 0；`scan_qt_log` 干净。（pass 7 仅 Route C 新增 QML 文件时校验 rules/README；A/B 的同步义务源自 `rules/06:64`。）
- **构建经 `build.py`**；失误 → `record_error.py --level <L1|L2|L3> --track B`。

---

## 7. 与既有文档 / playbook 的关系

- backlog 行动项：`docs/implementation-backlog.md §F2`（本文是其展开）；依赖弧 `F1 ──> F2`。
- 姊妹篇：[`docs/f1-release-dynamic-link-qt-kickoff.md`](f1-release-dynamic-link-qt-kickoff.md)（F1-S2 产出本页消费的 `resources/licenses/`）。
- 规则 / 契约：`.harness/rules/06-licensing.md` **§4**（页面三要求）、`.harness/CHARTER.md` **I6**。
- 设置页范式：`docs/settings-functional-replication.md` / `docs/settings-render-pipeline-replication.md`；agent memory `timearc-settings-page`（暗玻璃控件坑）。
- known gaps：`.harness/state/open-issues.md`（UI 段「Third-party license page missing」）。
- 顶层路线：`README.md §Roadmap`（line 585 in-app page）+ §Third-Party Components（line 616-622）。

---

> 本文是计划，不是代码。每个 sub-session 仍须独立走 harness（preflight `--track B` → 最小纵切 → `build.py`/`scan_qt_log` → `harness_check`）。
