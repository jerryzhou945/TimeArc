# TimeArc 文档索引

`docs/` 目前平铺：每篇 `*-functional-replication` = 功能复刻规格，
`*-render-pipeline-replication` = 渲染/视觉管线规格，`*-issues` / `*-gaps` /
`*-data-gaps` = 该页的"问题文档"（后端缺口 / 待决策 / 诚实天花板）。

本文件只做**导航索引**，不搬动文件——文件平铺、互链与源码注释里的 `docs/xxx.md`
路径保持不变（避免动到 ~80 处引用，含源码注释与合作方工件）。新增 doc 时在此补一行。

## 全局 / 工程

- [implementation-backlog.md](implementation-backlog.md) — 全局未完成项 backlog（被 `README` /
  `.harness/state/open-issues.md` 引用）。
- [a1-sqlite-storage-migration-kickoff.md](a1-sqlite-storage-migration-kickoff.md) — A1（keystone）
  SQLite 历史迁移的多 session 实施计划（backlog §A1 的展开）。**✅ S1–S5 已完成；`timearc_service.db` 为唯一历史存储。**
- [jsonl-history-retirement-report.md](jsonl-history-retirement-report.md) — 使用记录 JSON 文件退役报告：服务/UI/契约改动、验证、遗留文件策略与回滚说明。
- [b1-windows-service-scm-kickoff.md](b1-windows-service-scm-kickoff.md) — B1 Windows 服务化（SCM / 登录自启）
  实施计划（backlog §B1 的展开）：Session 0 隔离陷阱 + 产品路线决策门（**已选并实装 Route A，PR #37**）+ S0/S1/S2 与 Route B 范围卡。
- [agent-harness-vs-superpowers.md](agent-harness-vs-superpowers.md) — 本仓 `.harness` 与
  Superpowers 插件的对照学习：为何不引入插件、可借鉴项、给大范围工作的流程提醒。

## 产品方向

- [life-timeline-product-direction.md](life-timeline-product-direction.md) — 生命时间线产品方向。
- [card-ai-development-spec.md](card-ai-development-spec.md) — 卡片 / AI 开发规格。
- [future-coding-harness.md](future-coding-harness.md) — 未来编码 harness 设想。
- [desktop-mobile-next-plan.md](desktop-mobile-next-plan.md) — 桌面端剩余缺陷/修补清单 + 手机端制作流程与测试计划。
- [mobile/android-usage-time-collection-plan.md](mobile/android-usage-time-collection-plan.md) — 安卓软件使用时长获取方案：UsageStats 主方案、实时记录备用方案、优先级执行与测试计划。
- [mobile/android-usage-backend-implementation-report.md](mobile/android-usage-backend-implementation-report.md) — Android 使用时长后端采集 P0-P5 实施报告。

## 记忆湖（首页 / 回顾 / 备忘黑板）

- [memory-lake-implementation-plan.md](memory-lake-implementation-plan.md) — 总实现计划。
- [memory-lake-backend-integration-plan.md](memory-lake-backend-integration-plan.md) — 后端接入计划。
- [memory-lake-integration-issues.md](memory-lake-integration-issues.md) — 接入期 issue 记录。
- [memory-lake-home-art-implementation-spec.md](memory-lake-home-art-implementation-spec.md) — 首页美术规范。
- [memory-lake-home-render-pipeline-replication.md](memory-lake-home-render-pipeline-replication.md) — 首页渲染管线。
- [memory-lake-art-lighting-qml-cookbook.md](memory-lake-art-lighting-qml-cookbook.md) — 打光 / QML 技法字典。
- [memory-lake-fidelity-gaps.md](memory-lake-fidelity-gaps.md) — 诚实天花板 / 漏边超采样验证法。
- [memory-lake-memo-functional-replication.md](memory-lake-memo-functional-replication.md) — 备忘黑板功能复刻。
- [memory-lake-memo-render-pipeline-replication.md](memory-lake-memo-render-pipeline-replication.md) — 备忘黑板渲染管线。

## 日历页（v88 暗玻璃）

- [calendar-refactor-functional-replication.md](calendar-refactor-functional-replication.md)
- [calendar-refactor-render-pipeline-replication.md](calendar-refactor-render-pipeline-replication.md)

## 设置页（v88 暗玻璃 + 5 tab）

- [settings-functional-replication.md](settings-functional-replication.md)
- [settings-render-pipeline-replication.md](settings-render-pipeline-replication.md)
- [settings-implementation-issues.md](settings-implementation-issues.md) — 决策 A-* / 缺口 G-* / 三阶段。
- [settings-remaining-work.md](settings-remaining-work.md) — 未实装项审计 + 服务侧配置提案指针。

## 统计页（v88 暗玻璃 + 周/月/年）

- [stats-functional-replication.md](stats-functional-replication.md)
- [stats-render-pipeline-replication.md](stats-render-pipeline-replication.md)
- [stats-implementation-kickoff.md](stats-implementation-kickoff.md)
- [stats-backend-data-gaps.md](stats-backend-data-gaps.md) — 后端缺口 / 接入。
- [stats-backend-performance.md](stats-backend-performance.md) — 增量解析 / 记忆化 / 重算守卫。

## 适配（应用 / 网站 / 图标）

- [adapter-system.md](adapter-system.md) — 适配系统总览。
- [adding-website-support.md](adding-website-support.md) — 新增网站适配。
- [adding-app-support.md](adding-app-support.md) — 新增桌面应用适配。
- [adapter-support-implementation-report.md](adapter-support-implementation-report.md) — 实现报告。
- [mainland-site-tracking.md](mainland-site-tracking.md) — 国内站点拆分追踪。
- [media-real-title-capture-status.md](media-real-title-capture-status.md) — 媒体真实标题抓取现状。
- [site-icon-assets.md](site-icon-assets.md) — 站点图标资产来源登记。

## superpowers/（合作方 Superpowers 工件）

`superpowers/plans/` 与 `superpowers/specs/` 是合作方使用 Superpowers 插件时产出的
plans/specs 工件，不是插件本体，独立保留、不纳入本索引维护。

---

> 后续若确实要按主题分子目录，需一并更新约 80 处 `docs/xxx.md` 引用（含 ~21 处
> QML/C++/JS 源码注释、4 处 `superpowers/` 工件、文档互链、`open-issues.md`）。
> 本轮按"只加索引"处理，未做搬动。
