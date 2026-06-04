# 20260604-2153 · Track B · 备忘黑板覆盖层 入口+黑板底（Slice 0+1）

**Goal (one sentence).** Make the 「备忘」 nav an *action* that opens a modal
blackboard overlay over home (not a route), and build the blackboard backdrop
(near-black gradient + corner glows + dot lattice + 3-layer skeleton).

源规范：`docs/memory-lake-memo-functional-replication.md` §2.1/C0、
`docs/memory-lake-memo-render-pipeline-replication.md` §1.1/§4.1/§4.2/M-B1。

## Two-sided design (Track B)

- **Service side:** 无 / N/A by design. 备忘内容是 **UI 本地状态**（功能文 §0 / G4 硬边界）。
  服务不 emit、不 consume、不读备忘；不加 IPC/socket/共享内存。本切片不触碰服务-UI 磁盘契约。
- **UI side:** Shell 把 nav「备忘」从 `page:"notes"` 路由改成 `action:"memo"` →
  `memoOverlay.open = true`（不动 selectedIndex/pageLoader）。新增 `MemoOverlay.qml`
  （壳 + 黑板底 + 三层分离骨架）与 `MemoDotTexture.qml`（点阵）。翻面守卫读
  `pageLoader.item.locked`（记忆湖页已暴露）。持久化（MemoStore）属后续切片，将走
  **C++ manager**（rules/04 §4：QML 禁 localStorage）。

## Files touched

- `qml/desktop/memorylake/MemoryLakeStyle.qml` — 加黑板令牌（memoBoard*/memoScrim/
  memoDot*/memoGlow*Opacity/memoBackdropBlurMax）。
- `qml/desktop/memorylake/MemoDotTexture.qml` — 新增，GridTexture 的点阵变体。
- `qml/desktop/memorylake/MemoOverlay.qml` — 新增，模态黑板覆盖层壳 + 黑板底 + ink/object host。
- `qml/desktop/DesktopAppShell.qml` — nav action 化、memoLocked 守卫、挂 MemoOverlay、移除 notes 路由。
- `qml/desktop/pages/DesktopChatPage.qml` — 删除（用户决定：移除路由 + 丢弃旧本地笔记）。
- `qml/CMakeLists.txt` — 去 DesktopChatPage，加 MemoOverlay + MemoDotTexture。

**Frozen files:** 无（qml/CMakeLists.txt 非冻结；top-level/src CMake 不碰）。

**保留不动（越界则扩面）:** `src/services/settings_repository.cpp` 的 DesktopChatPageData
方法 + `tests/db_smoke.cpp` —— 现成为孤儿但无害、删之会破 db_smoke，故留待专门清理。

## Rule files to update

- `rules/04-ui-conventions.md` §8（新增）：记录备忘=模态覆盖层动作（非路由）、桌面专属、
  内容为 UI 私有态走 C++ manager（禁 localStorage）、组件落 memorylake/、令牌取 MemoryLakeStyle。
- Commit 前在 `state/open-issues.md` 增一条「备忘黑板覆盖层（进行中，分切片）」。

## Manual smoke path

启动 App → 点左导航「备忘」→ 黑板覆盖层 .26s 淡入盖住首页（首页快照重模糊 + 近黑底 +
左上 aqua / 右下 violet 角辉 + 白点阵）→ 按 Esc 淡出退回原首页（selectedIndex 不变）。
记忆卡翻面时「备忘」入口置灰、hover 提示「当前卡牌翻面时不可打开备忘录」、点击无反应。

## §7-B bugs addressed this slice

- 入口=动作而非路由（修 v88 的 notes→独立页错误接线）。
- 黑板恒暗、点阵画在底层（G10：修 v88 `.active` 光色黑板永不生效的分裂）。

## Deferred (per user)

全部 §7-A 产品缺口（撤销/调色/页重命名/番茄持久化…）本轮不做；只做 v88 已实现项 + §7-B 修正。
