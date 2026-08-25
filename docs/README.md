# TimeArc 文档地图

这里保存实现规格、审计报告、发布清单和历史决策。新读者先看根目录
[README](../README.md)，开发者再按当前任务进入下面的文档。

> 文档仍保持平铺，避免破坏源码与历史工件中的既有链接。状态以代码、测试和
> [implementation-backlog.md](implementation-backlog.md) 为准；旧报告只代表生成当日。

## 当前入口

| 主题 | 首选文档 |
| --- | --- |
| 当前 backlog | [implementation-backlog.md](implementation-backlog.md) |
| 测试发布/视频 | [beta-tester-release-kit.md](beta-tester-release-kit.md) |
| Windows/macOS 差异 | [platform-parity-packaging-gap.md](platform-parity-packaging-gap.md) |
| Windows 测试审计 | [windows-test-release-audit-2026-08-20.md](windows-test-release-audit-2026-08-20.md) |
| 统计页本轮结果 | [stats-period-layout-report-2026-08-23.md](stats-period-layout-report-2026-08-23.md) |
| B 站归因修复 | [windows-bilibili-site-attribution-fix-2026-08-25.md](windows-bilibili-site-attribution-fix-2026-08-25.md) |
| 登录自启/游戏/时钟 | [windows-release-defaults-game-clock-2026-08-25.md](windows-release-defaults-game-clock-2026-08-25.md) |
| SQLite 迁移 | [jsonl-history-retirement-report.md](jsonl-history-retirement-report.md) |
| 采集服务契约 | [../src/service/README.md](../src/service/README.md) |
| Android/HarmonyOS | [../android/README.md](../android/README.md) |

## 产品与设计

- [life-timeline-product-direction.md](life-timeline-product-direction.md) — 私有生命时间线方向。
- [card-ai-development-spec.md](card-ai-development-spec.md) — 时间卡与 AI 文案边界。
- [DESIGN.md](../DESIGN.md) — 移动端设计系统。
- [PRODUCT.md](../PRODUCT.md) — 产品语气、用户和反例。

## 统计与回顾

- [stats-functional-replication.md](stats-functional-replication.md) — 统计功能规格。
- [stats-render-pipeline-replication.md](stats-render-pipeline-replication.md) — 统计视觉管线。
- [stats-backend-data-gaps.md](stats-backend-data-gaps.md) — 数据能力与缺口。
- [stats-backend-performance.md](stats-backend-performance.md) — 聚合性能约束。
- [memory-lake-implementation-plan.md](memory-lake-implementation-plan.md) — 记忆湖总计划。
- [memory-lake-backend-integration-plan.md](memory-lake-backend-integration-plan.md) — 真数据接入。

桌面测试发布暂时隐藏记忆湖入口；代码和历史数据保留。相关文档不是当前公开功能承诺。

## 采集、身份与图标

- [categorization-system.md](categorization-system.md) — 分类规则表（应用/站点识别 + 类别），含「如何新增一个应用或站点」。
- [categorization-redesign.md](categorization-redesign.md) — 该系统的设计与取舍。
- [mainland-site-tracking.md](mainland-site-tracking.md) — 国内站点拆分。
- [media-real-title-capture-status.md](media-real-title-capture-status.md) — 媒体标题状态。
- [site-icon-assets.md](site-icon-assets.md) — 图标来源登记。
- [windows-bilibili-site-attribution-fix-2026-08-25.md](windows-bilibili-site-attribution-fix-2026-08-25.md) — 浏览器媒体归因。

## 桌面 UI

- [settings-functional-replication.md](settings-functional-replication.md)
- [settings-render-pipeline-replication.md](settings-render-pipeline-replication.md)
- [settings-remaining-work.md](settings-remaining-work.md)
- [calendar-refactor-functional-replication.md](calendar-refactor-functional-replication.md)
- [calendar-refactor-render-pipeline-replication.md](calendar-refactor-render-pipeline-replication.md)

## 移动端

- [mobile/android-usage-time-collection-plan.md](mobile/android-usage-time-collection-plan.md)
- [mobile/android-usage-backend-implementation-report.md](mobile/android-usage-backend-implementation-report.md)

## 工程与发布

- [a1-sqlite-storage-migration-kickoff.md](a1-sqlite-storage-migration-kickoff.md)
- [b1-windows-service-scm-kickoff.md](b1-windows-service-scm-kickoff.md)
- [f2-in-app-licenses-page-kickoff.md](f2-in-app-licenses-page-kickoff.md)
- [future-coding-harness.md](future-coding-harness.md)
- [agent-harness-vs-superpowers.md](agent-harness-vs-superpowers.md)

## 文档维护规则

- 新增文档必须在本页或直接上游文档中可发现。
- 报告标题写明日期；过期结论在顶部标记，不悄悄改写历史。
- 可执行状态只放在 backlog/open issues，不在多个 README 复制。
- `superpowers/plans/` 与 `superpowers/specs/` 是合作工件，保留但不作为当前事实入口。
