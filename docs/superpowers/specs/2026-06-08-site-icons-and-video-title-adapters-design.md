# Site Icons And Video Title Adapters Design

## Goal

让浏览器里的主流视频网站像本地应用一样被 TimeArc 识别、聚合和展示：小红书、爱奇艺、YouTube 等站点应有稳定的 `site:*` 身份、真实标题信号，以及可用的网站图标。

## Current State

`UsageStatManager` 已经能从浏览器 `window_title` 里把部分大陆站点归为 `site:*`。`site_catalog.h` 目前提供站点名、分类、域名、品牌色、文字 fallback 和少量本地图标，其中只有 Bilibili 有本地 SVG。媒体标题采集已经把 Windows audio 记录的 `window_title/media_title` 推进到 SQLite ranking，但 UI 侧还没有让 media title 走同一套站点目录。

## Architecture

这次不修改 service schema，也不让 QML 联网。Service 仍只负责写 foreground/audio 记录；UI 进程读 disk journal / SQLite 后，在 C++ 聚合层统一匹配站点。站点视觉输出由 catalog、图标资产和 favicon cache 组合产生，QML 只消费本地 `qrc:` 或 `file:` source。

## Icon Acquisition

第一阶段先获取主流视频网站图标资产，再实现消费逻辑。资产来源优先级：

1. 已有本地 SVG 或官方站点 favicon/apple-touch-icon。
2. 官方公开品牌资源页，必须在 `docs/site-icon-assets.md` 记录来源 URL 和文件名。
3. 自动 favicon cache，仅作为运行时补充；不能替代 repo 内首批主流视频网站图标。

首批视频站点：Bilibili、小红书、爱奇艺、优酷、腾讯视频、芒果TV、抖音、快手、西瓜视频、AcFun、YouTube、Netflix、Twitch、斗鱼、虎牙。扩展常用站点：GitHub、ChatGPT、Google、百度、知乎、微博、淘宝、京东。

## Data Flow

Foreground path: service writes browser `window_title` -> `UsageStatManager` parses JSONL/current -> browser title matches `site_catalog.h` -> aggregate output gets `groupKey`, `siteDomain`, `brandColor`, `iconLabel`, `iconSource`, `iconStatus`.

Media path: service writes audio `window_title`/SQLite `media_title` -> C++ helper checks title using the same catalog -> ranking rows can display site identity when the title contains a known video-site marker.

## Error Handling

If a local icon is missing, return `iconStatus: "label"` and keep `iconLabel + brandColor`. If favicon download fails, leave the cache empty and avoid blocking aggregation. If a title matches multiple sites, catalog order wins and tests lock the expected order for overlapping Chinese/English hints.

## Testing

Use `timearc_db_smoke` to cover catalog hits for all first-batch video sites, negative browser titles, and media-title matching. Build through `.harness/tools/build.py`; run `build\timearc_db_smoke.exe`; then run `harness_check.py`.
