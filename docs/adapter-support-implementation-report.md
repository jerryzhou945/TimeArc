# Adapter 支持系统实施报告

日期：2026-06-08

分支：`feature/adapter-support-system`

## 已实现

- 新增 header-only adapter metadata model 和 activity registry。
- 新增网站 adapter registry，第一批支持 YouTube、Bilibili、Spotify Web、QQ Music Web。
- 新增桌面软件 adapter registry，第一批支持 Chrome、Edge、VSCode、Spotify、WeChat、QQ。
- 将 adapter resolve 接入 `UsageStatManager`，作为读取和聚合阶段的中间增强层。
- 保留 `groupKey`、`appId`、`appName`、`name`、`path`、`windowTitle` 等原始字段。
- 不修改数据库 schema，直接给 QML 输出追加 adapter 增强字段。
- 更新 QML helper 和主要使用排行界面，让 UI 优先使用 adapter displayName、icon、category、sourceType。
- 新增 contributor 文档，说明如何添加网站和桌面软件支持。

## 修改文件

- `README.md`
- `docs/adapter-system.md`
- `docs/adding-website-support.md`
- `docs/adding-app-support.md`
- `docs/adapter-support-implementation-report.md`
- `src/services/adapters/adapter_metadata.h`
- `src/services/adapters/activity_adapter_registry.h`
- `src/services/adapters/website_adapter_registry.h`
- `src/services/adapters/desktop_app_adapter_registry.h`
- `src/services/adapters/websites/*.h`
- `src/services/adapters/apps/*.h`
- `src/services/usage_stat_manager.cpp`
- `qml/desktop/components/AppVisual.js`
- `qml/desktop/memorylake/UsageRankList.qml`
- `qml/desktop/pages/DesktopHomePage.qml`
- `qml/desktop/pages/DesktopStatsPage.qml`
- `tests/db_smoke.cpp`
- harness 要求生成的 journal build/error/session 文件

## 数据流

```text
service 原始记录
  -> 解析为 UsageStatManager::UsageRecord
  -> 根据 app identifier、process name、浏览器标题 hint 解析 adapter
  -> 保留原有分组和展示字段
  -> 追加 adapter metadata 字段
  -> QML 优先使用 adapter 字段，缺失时回退到原字段
```

本次没有新增 schema migration。第一版 adapter foundation 选择读时派生 metadata，因为当前自动使用记录仍然以 JSONL/current 文件为主，adapter metadata 可以在读取和聚合时稳定生成。

## 数据库兼容

没有修改数据库表或字段。

旧数据仍兼容，因为：

- 原始字段没有删除。
- 旧的 `site_catalog` fallback 仍保留，用于旧网站分组逻辑。
- adapter 失败时会回退到原有 app/site 分类和展示逻辑。
- 未知网站和未知桌面软件会获得通用 metadata。

如果后续出现查询性能或历史一致性需求，再考虑持久化 normalized adapter metadata。

## 隐私

本次实现没有新增：

- 录屏
- 截图
- 网页正文捕获
- 输入框捕获
- 聊天内容读取
- 私密内容上传
- 默认 IP 识别

adapter map 不序列化完整 URL。

## 最终验证

- `build.py -- --target timearc_db_smoke`：通过
- `build/timearc_db_smoke.exe`：通过
- `ctest --test-dir build --output-on-failure`：通过，1/1
- `build.py -- --target time-arc`：通过
- `harness_check.py`：通过

项目没有独立 lint 或 typecheck 命令。当前以完整 Qt/C++ build 作为语法和类型验证路径。

## Commit 列表

- `877dfd6 feat: add adapter registry foundation`
- `2262cb2 feat: add initial website adapters`
- `d70bea3 feat: add initial desktop app adapters`
- `e7dcbbf feat: connect adapters to tracking data flow`
- `6786b20 feat: display adapter metadata in UI`
- `99ffc69 docs: add adapter documentation and implementation report`

## 已知限制

- service 还没有为每条浏览器 foreground 记录提供 URL/domain 字段，所以网站 adapter 当前在有 URL 时使用 URL，在只有窗口标题时使用 title hint。
- 高像素网站图标发现尚未自动化。已知网站应优先使用 repo-local 图标，未来可接浏览器侧 favicon metadata。
- adapter metadata 当前在读取/聚合时派生，没有持久化到 usage database。
- app registry 第一版刻意保持小范围、高频优先。

## TODO

- 增加浏览器扩展或浏览器集成，提供脱敏后的 domain 和 favicon metadata。
- 按 contributor 文档继续添加更多网站 adapter。
- 按 contributor 文档继续添加更多桌面软件 adapter。
- 只有在读时派生出现真实限制后，再考虑持久化 normalized metadata。
- 项目有 QML test harness 后补更深入的 UI 覆盖。

## 分支处理

实际分支处理：

1. 使用 no-fast-forward merge commit `675bec8` 将 `feature/adapter-support-system` 合并进 `dev`。
2. 已将 merge 结果推送到 `origin/dev`。
3. 已删除本地 feature branch：`feature/adapter-support-system`。
4. 已尝试删除远端 `feature/adapter-support-system`；远端 ref 不存在，所以没有可删除内容。

说明：本地 `dev` 被主工作区占用，而且主工作区已有无关未提交修改。为了不碰这些修改，本次在隔离 adapter worktree 上从 detached `origin/dev` 执行 merge，然后用 `HEAD:dev` 推送。
