# UI 应用展示与统计页修复报告

## 目标

修复本轮用户反馈的 5 类桌面 UI 回归：常见应用名称不够大众化、记忆湖卡片提示遮挡、白天模式侧栏图标颜色错误、记忆湖/统计图标兜底丢失、统计月视图布局溢出。

## 范围

- 应用身份：新增剪映专业版 adapter，并将 WeChat 显示为“微信”。
- 记忆湖首页：卡片区左上滚轮提示改为短暂显示，锁定态提示保留。
- 侧栏主题：白天模式始终使用黑色资源，夜间模式使用白色资源。
- 图标兜底：系统无法解析 exe 图标时让 QML 回退到首字图标。
- 统计月视图：活跃热力图改为 GitHub 风格周列小格，月度排行和洞察卡增高避免裁切。

## 主要改动文件

- `src/services/adapters/apps/jianying_adapter.h`
- `src/services/adapters/apps/wechat_adapter.h`
- `src/services/adapters/desktop_app_adapter_registry.h`
- `src/services/usage_stat_manager.cpp`
- `src/services/app_icon_image_provider.{h,cpp}`
- `qml/desktop/DesktopAppShell.qml`
- `qml/desktop/memorylake/CardCarousel.qml`
- `qml/desktop/pages/DesktopStatsPage.qml`
- `tests/db_smoke.cpp`

## 验证

- Baseline build: `.local-python\Python312\python.exe .harness/tools/build.py`
- RED: `build\timearc_db_smoke.exe` failed on old WeChat/JianyingPro naming.
- GREEN: `build\timearc_db_smoke.exe` passed after adapter fix.
- Full build passed after each UI/C++ phase.
- `harness_check.py` passed before each commit.
- Final runtime sanity: launched `build\TimeArc.exe`, closed it, then `scan_qt_log.py` reported no Qt log for the clean run.

## 已提交修复

- `5c8e939` Fix common app display names
- `bbae8d1` Fix Memory Lake card tip fadeout
- `d8b4b81` Fix day mode sidebar icons
- `f023587` Fix missing app icon fallback
- `f369f1f` Fix statistics month layout
- Final commit: `Fix runtime UI verification warnings`

## 已知后续

移动端记忆湖等价页仍未实现；更长尾的应用分类覆盖仍按 `open-issues.md` 的 A4 渐进处理。

## 回滚

若需要回滚本轮 UI 修复，优先 revert PR merge commit；若按单提交回滚，则按上方 5 个修复提交逐个 revert。
