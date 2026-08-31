# 统计分类时钟区块修复（2026-08-30）

## 目标

恢复此前版本清晰、成块的分类时钟：每个区块颜色与右侧分类标签一致，并在选择某一分类时同时高亮该分类的全部区块。

## 范围与改动

- 半天固定划分为 72 个十分钟桶，以桶内有效时长最多的分类作为显示分类。
- 分类在单个桶内至少出现 60 秒才占据该桶；单个 `A-B-A` 中间桶并入 A。
- 连续同分类桶合并为整块，精确总时长、占比和原始记录保持不变。
- 区块起止时间采用十分钟几何边界，中央时长仍显示该分类在区块内的真实测量秒数。
- 左侧时钟直接复用右侧分类占比面板的颜色映射。
- 点击或悬停一个区块时，同分类的所有区块共同放大/高亮；中央详情仍指向当前区块。

主要文件：`qml/desktop/components/AppVisual.js`、`qml/desktop/memorylake/DailyUsageShare.qml`、`qml/desktop/pages/DesktopStatsPage.qml`、`qml/desktop/pages/StatsViewModel.js`、`tests/stats_view_model_test.js`、`tests/desktop_ux_static_test.py`。

## 验证

- `node tests/stats_view_model_test.js`
- `python tests/desktop_ux_static_test.py`
- `python .harness/tools/build.py --track C`
- `ctest --test-dir build --output-on-failure`
- 可见 Windows 运行、后台服务检查和 `scan_qt_log.py`
- `python .harness/tools/harness_check.py`

## 已知缺口

Windows 发布包仍未签名；日历页已有的文字绑定循环警告与本修复无关，继续保留在错误日志中。

## 回滚

回滚本修复对应的统计时钟提交即可；它只改变展示投影与颜色/交互，不改变数据库或精确统计口径。
