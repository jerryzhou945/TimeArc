# F1 · 发布构建动态链接 Qt 与 LGPL/GPL 合规姿态（Release Licensing Posture）· 实现启动（Kickoff / 多 session 拆分）

> **用途**：把 `docs/implementation-backlog.md` §F1（release 构建动态链接 Qt）从「散落待办」展开成
> **带依赖、可逐 session 落地**的执行计划。F1 与 §F2（应用内许可证页）是同一条「发布合规」弧，本文是
> 第一张（构建 / 打包 / 磁盘侧），见姊妹篇 [`f2-in-app-licenses-page-kickoff.md`](f2-in-app-licenses-page-kickoff.md)。
>
> **体例**参照 `docs/h5-service-config-channel-kickoff.md` / `docs/d1-export-backup-restore-kickoff.md` /
> `docs/b1-windows-service-scm-kickoff.md`（路线决策门结构）。
>
> **配套权威**：`.harness/CHARTER.md` **I6**（许可姿态，v0.4）、`.harness/rules/06-licensing.md`（§1 清单 / §4 页面要求 /
> §5 Qt 模块 / §6 SPDX）、`.harness/templates/change-proposal.md`、`.harness/state/frozen-files.json`。
>
> **维护**：完成一个 sub-session → 勾掉下表 + 移进 session log，并同步 `README.md §Roadmap`（line 583）/
> `.harness/state/open-issues.md`（Build/distribution 段）/ `docs/implementation-backlog.md §F1`。
>
> **重要前提（backlog 旧描述已过时）**：F1 **不是「把 Qt 从静态改成动态」**——Qt 在本机**已经是动态链接**。
> F1 的真实内容 = **证明并钉死动态姿态 + 补齐随二进制分发的许可证文本 + 把手工打包固化成脚本**。详见 §0。

---

## 0. 现状校正（这是 F1 的起点，backlog / open-issues 旧描述已过时）

### 0.1 Qt 早已动态链接（三条独立证据）

| 证据 | 出处 | 结论 |
|------|------|------|
| 部署支持文件标记 shared-libs build | `build/.qt/QtDeploySupport.cmake:36` `set(__QT_DEPLOY_IS_SHARED_LIBS_BUILD "ON")` | 配置的 Qt 是**共享库**安装 |
| 可执行文件导入 Qt DLL | `objdump -p build/TimeArc.exe` → `DLL Name: Qt6Core.dll / Qt6Gui.dll / Qt6Qml.dll / Qt6Quick.dll / Qt6Sql.dll / Qt6Widgets.dll` | **动态链接**铁证（导入表 = 运行期解析 DLL） |
| 已 windeployqt 打包并产出便携包 | `dist/TimeArc-portable/`（~36 个 `Qt6*.dll` + `libgcc_s_seh-1.dll`/`libstdc++-6.dll`/`libwinpthread-1.dll`）；`dist/TimeArc-portable/README.txt:31`（节选）「…Qt 6.11.1 (MinGW 64-bit) · Release · windeployqt 打包」 | 动态 DLL + MinGW 运行库**均以可替换文件形式分发**，relink 能力事实上已满足 |

> 注：Qt lib 目录里的 `libQt6Core.a` 是 MinGW **导入库**（成员对象名 `Qt6Core_dll_*.o` = DLL stub），**不是**静态归档——不要把它误判成静态构建。本机 Qt = `C:/Qt/6.11.1/mingw_64`（在线安装器标准 shared kit，`build/CMakeCache.txt` `Qt6_DIR`）。

**推论**：要把 Qt 改成静态需要另装一个 static Qt 构建，且会直接违反 CHARTER **I6**（「Qt **must** be dynamically linked」）。**绝不静态链接 Qt。** F1 ≠ relink，F1 = 证明 + 补合规件 + 固化打包。

### 0.2 真正的缺口（这才是 F1 要补的）

- **分发包零许可证文本**：`dist/TimeArc-portable/` 与 `dist/TimeArc-alpha-20260609/` 顶层只有 DLL / `README.txt` / `.cmd`，**没有任何** `LICENSE` / `NOTICE` / `COPYING`。GPL（本项目 GPL-3.0-or-later，`LICENSE` = 逐字 GPLv3）要求 LICENSE 随二进制分发；LGPL（Qt）要求随附 Qt 许可文本 + 版权 + relink 声明。**当前全缺。**
- **无随附第三方文本**：`thirdparty/sqlite3`、`thirdparty/parson` 只有源码 + `CMakeLists.txt`，**无独立 LICENSE 文件**；Qt 文本根本不在仓库（外部依赖）。Parson MIT 全文仅以注释存在于 `thirdparty/parson/parson.c:4-23`（版权行 :5 + 许可正文 :7-23；`parson.h` 亦带 `SPDX-License-Identifier: MIT` + 同段全文）；SQLite 仅 `thirdparty/sqlite3/sqlite3.h:4-9` 的 public-domain blessing（**公有领域、无许可正文**）。
- **无发布打包脚本**：`tools/` 只有 fork-sync / git-hooks 脚本；`dist/` 由**手工** `windeployqt` 产出，不可复现、易漏件。
- **MinGW 运行库无署名**：`libgcc_s_seh-1.dll` / `libstdc++-6.dll` / `libwinpthread-1.dll`（GCC Runtime Library Exception）随包分发，无对应声明。

### 0.3 可用素材 & 冻结边界（决定是否需要变更提案）

- **Qt 许可文本本机可取**：`C:/Qt/Licenses/`（`LICENSE`、`COPYING.txt`、`Copyright.txt`、`LICENSE.FDL`）——可直接 vendored 进 `resources/licenses/`。
- **冻结清单**（`.harness/CHARTER.md:63-76` + `state/frozen-files.json`）：顶层 `CMakeLists.txt`、`src/CMakeLists.txt`、`src/service/CMakeLists.txt` **均冻结**。
- **关键事实**：Qt 动态是 `find_package(Qt6 …)` + `target_link_libraries(Qt6::…)` 的**默认行为**（`CMakeLists.txt:18,53-61`），**无须改任何冻结文件**即已成立。`resources/CMakeLists.txt`、`tools/`、`rules/06`、`README`、`open-issues`、`dist/`、`docs/` **均非冻结**。
- **唯一会碰冻结文件的做法** = 把 windeployqt / `install()` 自动化塞进顶层 `CMakeLists.txt`（`qt_generate_deploy_app_script` / `install(TARGETS…RUNTIME_DEPENDENCIES)`）。这是**可选**，不是必须——见 §1.2 路线门。

### 0.4 待同步的过时文档

- `.harness/state/open-issues.md`（Build/distribution）：「Qt is not yet dynamically linked」——**与实测相反**，须改为「已动态；剩余 = 随包许可文本 + 应用内页」。
- `.harness/rules/06-licensing.md:10`：Qt 行「must be dynamic | Main README TO-DO item」——补注「动态已成立，剩余 = 文本分发 + F2 页」。
- `README.md:583-584,620`：Roadmap「Compile Qt as dynamically-linked…」+ Third-Party 表「dynamic (planned for release)」——改为「已动态，落地为可复现打包脚本 + 随包文本」。

---

## 1. 范围与落地顺序（依赖图）

```
S1 证明并钉死动态姿态 + 去过时文档（无冻结改动）
        └──> S2 vendored 第三方许可文本进 resources/licenses/（非冻结）   ←── F2 的 §S1 消费此产物
                    └──> S3 可复现发布打包脚本 tools/（非冻结 · windeployqt + 文本 + NOTICE/relink）
                                  ┊
                                  └┄> S4 （未来 · 门控）in-tree CMake 部署自动化 = 改冻结顶层 CMakeLists → 须提案，本轮不做
```

落地顺序铁律：**S1 → S2 → S3**，全程**无冻结改动、提案：否**（Route A）。S2 产出的 `resources/licenses/*.txt` 是 **F1 与 F2 的唯一共享产物**（见 §3「共享产物归属」），F1 负责**产出文本文件**，F2 负责**在 UI 渲染**——单一真相源，禁止两份拷贝。

### 1.2 三条打包路线（决策门 · 须维护者拍板）

**Route A — 仓外打包脚本（推荐 MVP · 零冻结改动 · 提案：否）**
新增 `tools/package-release.ps1`（非冻结目录），调用本机 `windeployqt.exe` + 复制 `LICENSE` + `resources/licenses/` + 写 `NOTICE.txt`（含 Qt LGPL relink 声明）。这正是 `dist/` 今天手工在做的事，只是固化、可复现。**本 kickoff 默认走 Route A。**

**Route B — in-tree CMake 部署自动化（门控 · 提案：是 · 本轮不做）**
在顶层 `CMakeLists.txt` 用 `qt_generate_deploy_app_script()` + `install()` 让 `cmake --install` 一步出可分发目录。优点：与构建同源；代价：**改冻结顶层 `CMakeLists.txt`** → 须先填 `.harness/templates/change-proposal.md`。仅当维护者要求「一键构建即出合规包」时再开（=本文 S4）。

**Route C — 不打包，仅证明 + 文档（不推荐）**
只做 S1 + S2，把打包留给手工。否决：CHARTER I6 + GPL 随包义务要求**真有合规包产出**，手工不可复现。

> 决策门产出：维护者在 A / B 间选一。A 与 B **不互斥**——可先 A（MVP），发版稳定后再提案升 B。

---

## 2. 多 session 拆分（逐张范围卡）

### S1 — 证明并钉死动态姿态 + 去过时文档（地基 · 无冻结改动 · Track B · 提案：否）

**目标**：把「Qt 已动态」从一次性观察变成**可复验的发布前断言**，并清掉自相矛盾的旧文档。
- 写一个发布前校验步骤（落进 S3 脚本或独立 `tools/verify-linkage.ps1`）：对**将分发的** `TimeArc.exe` 跑 `objdump -p`（或 `Dependencies`）断言 **存在** `Qt6*.dll` 导入、**不存在**静态 Qt 痕迹；断言 `build/.qt/QtDeploySupport.cmake` 的 `__QT_DEPLOY_IS_SHARED_LIBS_BUILD ON`。
- 同步去过时（§0.4）：`open-issues.md`、`rules/06:10`、`README:583-584,620`。
- 文件红线：🟢 `tools/`（新脚本）、`.harness/state/open-issues.md`、`.harness/rules/06-licensing.md`、`README.md`、`docs/implementation-backlog.md`。⛔ 任何冻结 `CMakeLists.txt`。
- 变更提案：**否**。验收：校验脚本在本机 exit 0；三处文档不再宣称「未动态」；`harness_check.py` exit 0。

### S2 — vendored 第三方许可文本进 `resources/licenses/`（共享产物 · 非冻结 · Track B · 提案：否）

**目标**：把每个第三方组件的**全文**许可证以**离线可读**的纯文本落进 `resources/licenses/`，作为 F1（随包）+ F2（应用内）的**单一真相源**。
- 落地清单（建议文件名）：
  - `resources/licenses/qt-lgpl-3.0.txt` + `resources/licenses/qt-gpl-3.0.txt`（取自 `C:/Qt/Licenses/`）；
  - `resources/licenses/parson-mit.txt`（逐字取 `thirdparty/parson/parson.c:5-23`：版权行 `Copyright (c) 2012 - 2023 Krzysztof Gabis`(:5) + MIT 正文(:7-23)；注意原文是「2012 - 2023」带空格短横）；
  - `resources/licenses/sqlite-public-domain.txt`（用 `thirdparty/sqlite3/sqlite3.h:4-9` blessing；**SQLite 公有领域、无许可正文**，以 blessing + 「公有领域，无许可文本」显式说明满足 `rules/06 §4(1)` 全文要求，记录为**有意偏离**）；
  - `resources/licenses/timearc-gpl-3.0.txt`（= 仓库根 `LICENSE`，本项目自身）；
  - `resources/licenses/mingw-runtime-exception.txt`（GCC Runtime Library Exception，针对随包 `libgcc`/`libstdc++`/`libwinpthread`）。
- 同时在 `thirdparty/parson/` 与 `thirdparty/sqlite3/` 各补一个独立 `LICENSE`/`NOTICE` 文件（便于工具发现；二者非冻结）。
- 注册：把上述 `.txt` 加进 `resources/CMakeLists.txt` 的 `TIME_ARC_RESOURCE_FILES`（**非冻结**），随 qrc 内嵌 → 离线可达（满足 `rules/06` §4(2)）。
- 文件红线：🟢 `resources/licenses/*`、`resources/CMakeLists.txt`、`thirdparty/{parson,sqlite3}/LICENSE`。⛔ 冻结 `CMakeLists.txt`（顶层把 `${TIME_ARC_RESOURCE_FILES}` 喂给 `qt_add_qml_module`，无须改它）。
- 变更提案：**否**。验收：rebuild 后 qrc 含全部文本；`settingsRepository.readTextFile()` 能离线读出（F2 依赖此）；与 `rules/06 §1` 清单逐项对齐。

### S3 — 可复现发布打包脚本（Route A · 非冻结 · Track B · 提案：否）

**目标**：用 `tools/package-release.ps1` 取代手工打包，产出**合规**便携包。
- 步骤：`cmake --build` Release → `windeployqt TimeArc.exe`（+ service exe）→ 复制 `LICENSE`、`resources/licenses/` 整目录、写 `NOTICE.txt`（聚合：本项目 GPL-3.0、Qt LGPL-3.0 + **relink/written-offer 声明**「Qt 以 LGPL-3.0 动态链接，用户可替换随包 Qt DLL」、SQLite public-domain、Parson MIT、MinGW runtime exception）→ 嵌入 S1 linkage 断言 → 打 zip。
- 文件红线：🟢 `tools/package-release.ps1`、（可选）`tools/verify-linkage.ps1`、`dist/`（产物，建议仍 gitignore，仅脚本入库）。⛔ 冻结 `CMakeLists.txt`。
- 变更提案：**否**（Route A 仓外）。验收：脚本一键产出含 DLL + `LICENSE` + `licenses/` + `NOTICE.txt` 的包；断面机（无 Qt 环境）解压即跑；`NOTICE.txt` 覆盖全部 §S2 组件。

### S4 — in-tree CMake 部署自动化（Route B · 未来 · 门控 · 提案：是 · 本轮不做）

仅当维护者在 §1.2 选 Route B 才开：在顶层 `CMakeLists.txt` 加 `qt_generate_deploy_app_script()` + `install()`。**改冻结文件** → 先填 `.harness/templates/change-proposal.md` 进 `journal/sessions/YYYYMMDD-HHMM-B-<slug>.md`，落地后 `harness_check.py --bootstrap` 重算冻结哈希。**本轮不做。**

---

## 3. 冻结文件与变更提案边界

**非冻结（可直接改）**：`tools/*`、`resources/licenses/*`、`resources/CMakeLists.txt`、`thirdparty/{parson,sqlite3}/LICENSE`、`.harness/rules/06-licensing.md`、`.harness/state/open-issues.md`、`README.md`、`docs/*`、`dist/`。

**冻结（改前须先填 `.harness/templates/change-proposal.md` 进 `journal/sessions/`，并在落地后重算 `state/frozen-files.json`）**：`CMakeLists.txt`（顶层）、`src/CMakeLists.txt`、`src/service/CMakeLists.txt`。

**关键事实**：Route A（S1–S3）**不触碰任何冻结文件 → 提案：否**。只有 Route B（S4）改顶层 `CMakeLists.txt` → 提案：是。`rules/06` / `README` / `open-issues` 不在冻结清单，可直接更新。

**共享产物归属（与 F2 的边界，杜绝 gap/overlap）**：唯一交叠物 = `resources/licenses/*.txt`。**F1-S2 产出文本文件并随包分发；F2 仅渲染**。F1 拥有「文本存在于磁盘 + 随二进制分发」；F2 拥有「文本在应用内可见」。组件**版本值**（Qt 6.11.1 / SQLite 3.51.3 / Parson 1.5.3）亦由 F1-S2 随文本拥有，F2 §0.4 表仅镜像——版本真相源唯一。任一方都须在文档里点名对方，不得各自再造一份文本。

---

## 4. 必须保留的不变量

1. **CHARTER I6**：Qt **动态**链接（绝不静态）+ 第三方文本**可从 UI 抵达**。F1 守前半（动态 + 随包文本），F2 守后半（UI 渲染）。
2. **GPL 随包义务**：本项目 GPL-3.0-or-later，`LICENSE` 必须随二进制分发。
3. **LGPL relink 能力**：Qt DLL + MinGW 运行库以可替换文件分发（已满足）；NOTICE 须载明 relink/written-offer 声明。
4. **I1 两进程一磁盘**：F1 只动构建 / 打包 / 文档，**不碰** UI↔service 磁盘契约（I2）、不引入 IPC。
5. **单一真相源**：`resources/licenses/` 是文本唯一来源，随包与应用内复用同一份。
6. **`rules/06` §4(3) 同步律**：日后 `thirdparty/CMakeLists.txt` 新增组件 → 必须同步新增 `resources/licenses/` 文本 + NOTICE 条目（F1）+ 页面条目（F2）。

---

## 5. 风险登记

- **静态 Qt 回潜**：若换 kit / 改链接方式导致静态 Qt 进入分发 → 违反 I6。缓解：S1 的 `objdump` 断言纳入发布前必跑。
- **文本漂移**：`resources/licenses/` 与 `rules/06 §1` / `README` Third-Party 表 / 真实 `thirdparty/` 版本（SQLite 3.51.3、Parson 1.5.3）不一致。缓解：S2 逐项对齐 + §4(3) 同步律。
- **windeployqt 过度打包**：当前 `dist/` 含 `Qt6Network.dll`、`Quick3D*`、全套 `QuickControls2*` 等未必用到的 DLL；过度分发增大体积、扩大需署名的 Qt 模块集。缓解：S3 可加 `--no-translations` / 按 `rules/06 §5` 实际模块裁剪（可选）。
- **MinGW 运行库署名缺失**：`libgcc`/`libstdc++`/`libwinpthread`（GCC Runtime Library Exception）随包但今天无声明。缓解：S2 补 `mingw-runtime-exception.txt` + S3 NOTICE 收录。
- **Qt 版本/edition 不明**：`dist/TimeArc-portable/README.txt` 写「Qt 6.11.1」，`dist/TimeArc-alpha-20260609/README.txt` **完全未注明** Qt 版本；二者均未注明 open-source(LGPL) vs commercial。缓解：S1 在文档钉死「以 open-source LGPL-3.0 构建」。
- **品牌图标 / 游戏截图 IP（越界提醒）**：`resources/icons/sites/*.ico`（YouTube/Netflix/Bilibili…）、`resources/memorylake/*.png`（Elden/P3R/Exit8…）是**第三方商标 / 版权美术**，仓内无署名——这是**独立的 IP 议题，不属 F1/F2 代码许可范畴**。须维护者单独决策（署名 / 替换 / 移除），勿在 F1/F2 里悄悄混入。

---

## 6. 验收口径（贯穿各 session）

- **发布前 linkage 断言**：对**将分发的** `TimeArc.exe` 跑 `objdump -p`（或 `Dependencies`）→ 有 `Qt6*.dll` 导入、无静态 Qt；`build/.qt` 确认 shared-libs。
- **合规包内容**：产出包含 `LICENSE` + `licenses/`（全部 §S2 文本）+ `NOTICE.txt`（覆盖全组件 + relink 声明）+ Qt/MinGW DLL；**断面机解压即跑**。
- **离线可达**：`resources/licenses/` 内嵌 qrc，`settingsRepository.readTextFile()` 无网络可读（为 F2 兜底）。
- **harness**：`harness_check.py` exit 0；如本轮触发 Route B（改冻结文件），提案已签核且 `state/frozen-files.json` 已重算。
- **构建经 `build.py`**（非裸 `cmake`）；rebuild 前先杀 `TimeArc.exe`（exe 锁）。
- 任何 build/runtime/QML/agent 失误 → `record_error.py --level <L1|L2|L3> --track B`。

---

## 7. 与既有文档 / playbook 的关系

- backlog 行动项：`docs/implementation-backlog.md §F1`（本文是其展开）；依赖弧 `F1 ──> F2`。
- 姊妹篇：[`docs/f2-in-app-licenses-page-kickoff.md`](f2-in-app-licenses-page-kickoff.md)（应用内页；消费 F1-S2 的 `resources/licenses/`）。
- known gaps：`.harness/state/open-issues.md`（Build/distribution 段，S1 须去过时）。
- 规则 / 契约：`.harness/rules/06-licensing.md`（§1 清单 / §4 页面 / §5 Qt 模块 / §6 SPDX）、`.harness/CHARTER.md` **I6**。
- 顶层路线：`README.md §Roadmap`（line 583 dynamic Qt、line 585 in-app page）+ §Third-Party Components（line 616-622）。
- 变更提案模板（仅 Route B 需要）：`.harness/templates/change-proposal.md`。

---

> 本文是计划，不是代码。每个 sub-session 仍须独立走 harness（preflight `--track B` → 最小纵切 → `build.py`/`scan_qt_log` → `harness_check`）。
