# Track B Session — 统计周期布局压缩

## Goal

重构桌面统计页的周、月、年布局，移除重复排行和日视图冗余区块，并为应用时钟增加可锁定的扇区交互。

## Scope

- 预计修改：`qml/desktop/pages/DesktopStatsPage.qml`、统计页静态测试、`README.md`、统计布局实现报告、UI backlog 状态。
- 不修改：服务采集、数据库契约、统计聚合口径、移动端页面、任何 frozen file。
- 适用规则：`.harness/rules/04-ui-conventions.md`、`.harness/rules/08-git-workflow.md`。

## Service side

后台服务继续输出同样的前台应用与媒体会话数据；本次不增加采样来源、不改变会话身份、落盘结构或聚合范围。

## UI side

桌面 QML 继续消费现有 `vmTrendBars`、`vmCategories`、`vmLibraryRows` 和 `vmClockSegments`，只调整周/月/年信息拓扑、移除重复 Top/24H 展示，并在现有 Canvas 命中逻辑上增加点击锁定状态。

## Progress checklist

- [x] 建立分支并验证修改前基线。
- [x] 以失败测试锁定新布局和交互。
- [x] 实现 QML 与文档更新。
- [x] 完成构建、测试和运行日志检查。

## Completion report

- Completed: 周/月/年改为左侧总览与分类、右侧趋势图，并用统计专用 900px 阈值确保常见桌面宽度保持双列；周期摘要压缩为横向 132px；日页移除 24H/排行；时钟新增点击锁定；说明与 backlog 已同步。
- Incomplete: None.
- Verification: 文件锁解除后 harness 构建成功；CTest 6/6；统计、桌面 UX、i18n 与资源静态测试通过；应用启动响应正常；最新 Qt 日志扫描无警告。
- Next: 由维护者在真实统计数据下检查周/月/年密度与时钟点击手感。
- Risks: 小于 900px 的窄内容区回落单列；真实数据下的最终密度仍需维护者目视确认。
