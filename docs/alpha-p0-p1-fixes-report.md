# Alpha P0/P1 功能修复报告（2026-06-13）

## 范围

本轮只处理桌面端 alpha 前的 P0/P1 功能修复，不触碰移动端与 AI 管线。

## 已完成

- 首页右侧「今日事项」checkbox 可直接勾选/取消完成，并写回 `CalendarManager.savedTodos`。
- 记忆湖排行榜应用身份优化：`r5apex_dx12` 显示为 Apex Legends，`nvcontainer` 显示为 NVIDIA Container，`svchost` 显示为 Service Host；同步补入 group key、分类关键词和前端底色兜底。
- 排行榜图标容器改为稳定 24px 居中视口，降低 Windows 原生图标透明边距导致的视觉偏移。
- B2 已完成：`write_json_string` 输出前校验 UTF-8，非法字节写为 `\ufffd`。
- H1 已完成桌面显示层：日历月/周/今日议程、右侧议程、创建弹层已选时间、记忆湖今日事项、时间河、便签截止时间均读取 `time_format`；内部存储和排序仍保留 24h `"HH:mm"`。

## 文档同步

- `docs/implementation-backlog.md` 已更新 B2/H1 状态，并新增 Alpha 桌面修复小清单；分类器长尾仍保留为后续渐进覆盖。
- `.harness/state/open-issues.md` 已移除 UTF-8 未校验问题，并补充分类器本轮覆盖范围。

## 提交记录

- `53acc61` Enable homepage todo completion
- `bddadd1` Improve desktop app identity display
- `74cc033` Add UTF-8 validation for JSON strings
- `c3317fb` Support desktop time format display
- `7dfad9c` Support time format in time river

## 验证

- 每个功能提交前均运行 `.harness/tools/harness_check.py`，结果为 clean。
- 未执行完整编译/打包；本轮按你的要求避免在编译链路上长时间停留，优先完成功能修复。
