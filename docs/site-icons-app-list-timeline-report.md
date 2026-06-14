# Site Icons, App List, And TimeRiver Completion Report

Date: 2026-06-14
Branch: `codex/site-icons-app-list-timeline`
Track: B Feature

## 完成内容

- 抖音/小红书未在 TimeArc UI 中独立展示的问题：确认 SQLite 已记录浏览器前台标题和媒体标题，修复点放在 UI 读层站点目录与 smoke 覆盖，不改 service 写库 schema。
- 站点图标：新增/替换 Zhihu、Taobao、Tmall、Baidu、Youku、Tencent Video、Mango TV、YouTube 的官方 high-resolution PNG 资源，并接入 C++ catalog、QML fallback 和 Qt resources。
- 抖音/小红书图标：官网元数据当前只暴露 favicon 级资源，本轮继续使用官方 favicon，不伪造高清来源。
- 设置页应用管理：`allApps()` 输出聚合 `seconds`、大众化 `displayName/category` 和 `settingsVisible`；QML 默认按高频展示主流应用/站点，收起 `pid:*`、`.dll`、Windows helper、QQ 截图、NVIDIA helper 等低信号项；搜索仍可查全量记录。
- 首页卡片背面 TimeRiver：密集时间段改为单个摘要标签，例如 `03:36-05:39 · 6次`，节点仍保留，文字不再堆叠。
- 记忆湖图标：新增 `recap_white.svg`，夜间和深色全幅页导航统一使用白色图标。

## 验证

- `timearc_db_smoke` 覆盖 Douyin/Xiaohongshu 浏览器标题、Douyin 媒体标题、Zhihu/Youku 新图标路径。
- 静态红绿检查覆盖设置页 `seconds/settingsVisible`、TimeRiver 密集簇摘要 helper、记忆湖白色图标资源与导航接线。
- 每个小功能提交前均运行 `python .harness/tools/harness_check.py`。
- 关键构建均通过 `python .harness/tools/build.py`，并补齐 D 盘 Qt/CMake/Ninja PATH。

## 已知边界

- 运行期不联网抓图标；图标刷新仍是 repo 内人工更新并记录来源。
- 站点识别仍依赖窗口标题/媒体标题，不读取浏览器真实 URL。
- 设置页低信号项只是默认收起，搜索仍可找回和调整显隐，不删除历史。

## 回滚点

- `550e29d Support high resolution site icons`
- `077d6d0 Support cleaner settings app list`
- `1727c5b Support readable TimeRiver labels`
- `d2c926e Add white memory lake icon`
