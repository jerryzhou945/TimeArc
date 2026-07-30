# 20260730-1529 · Track A · macOS 显示菜单条目文案

## Motivation

`显示` 菜单的 ⌘1 / ⌘4 两行按 **路由键** 取名，而不是按侧栏 `navItems[i].title`：

- ⌘1 导航到 `memorylake`，却显示「记忆湖 / Memory Lake」——侧栏这一行叫「首页 / Home」。
- ⌘4 导航到 `recap`，却显示「月度记忆湖 / Monthly Recap」——侧栏这一行才叫「记忆湖 /
  Memory Lake」，`Monthly Recap` 是它的英文 `subtitle` 而非标题。

结果是「记忆湖」在菜单与侧栏里指向两个不同页面。根因见 f881cdc（2026-06-04，
Memory Lake 升为首页但没改路由键 `memorylake`，同时把「记忆湖」这个名字让给了新拆出的
`recap` 页）；`MacMenuBar.qml` 约两个月后在 f160acf 新建时照着键取名，继承了旧名。

## Change (text only — 行为不变)

- `qml/desktop/MacMenuBar.qml`：⌘1 `记忆湖` → `首页`；⌘4 `月度记忆湖` → `记忆湖`。
  `shortcut` 与 `onTriggered` 一律未动，两行仍去原来的页面。
- `qml/desktop/components/I18n.js`：`menuEn` / `menuJa` 增 `首页`，删 `月度记忆湖`，
  `记忆湖` 保留（现服务于 ⌘4）。取值与主表逐字一致，菜单与侧栏不会再分叉。
- `docs/macos-menu-bar-design.md` §2.4：表格改名，并加一段「行文案取 `navItems[i].title`,
  不取 `page` 键 / 英文 `subtitle`」，写明两个历史键，防止第三次漂移。

## Verification

- `preflight.py --track A` clean；三个文件均不在 CHARTER §3 冻结表内。
- `build.py` success（20260730-153129-build.log）。
- `qmllint MacMenuBar.qml` exit 0，只剩既有的 context-property unqualified 警告。
- 脚本比对 `en`/`ja` 主表与 `menuEn`/`menuJa`：首页/日历/统计/记忆湖 四项 en+ja 全等；
  zh 走 `menu()` 的 verbatim 分支，等同侧栏原文。
- 未启动 App 做菜单实拍：改动只是 `text:` 绑定换词，运行 UI 会连带拉起采集与写库。

## Follow-up (not done here)

⌘1–⌘4 仍跳过侧栏第 4 行「设置」与第 5 行「备忘」，⌘4 落在第 6 行，数字与侧栏位置不对齐。
属行为变更（Track B），本次未动。
