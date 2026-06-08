# 中国大陆常用网站独立记录

## 已实现

TimeArc 现在会在 UI 聚合层把浏览器里的部分中国大陆常用网站提升为独立的 `site:*` 活动，而不是统一显示为 Chrome、Edge 或 Firefox。

第一版已内置这些站点：

- 哔哩哔哩：`site:bilibili`
- 抖音：`site:douyin`
- 小红书：`site:xiaohongshu`
- 微博：`site:weibo`
- 知乎：`site:zhihu`
- 淘宝：`site:taobao`
- 天猫：`site:tmall`
- 京东：`site:jd`
- 拼多多：`site:pinduoduo`
- 百度：`site:baidu`
- 爱奇艺：`site:iqiyi`
- 优酷：`site:youku`
- 腾讯视频：`site:tencent-video`
- 豆瓣：`site:douban`
- CSDN：`site:csdn`
- 支付宝：`site:alipay`
- 美团：`site:meituan`
- 大众点评：`site:dianping`

实现方式：

- 不修改后台 service。
- 不修改 `usage_records.jsonl` / `usage_current.json` 的 schema。
- UI 读取 usage journal 后，如果记录来自浏览器，并且窗口标题命中站点目录，就把该活动聚合为对应的 `site:*`。
- 未命中的网页仍归到浏览器应用，避免把浏览器使用记录切得过碎。

## UI 视觉字段

站点聚合结果会额外输出这些字段，供 QML 统一渲染：

- `siteDomain`：主域名，例如 `taobao.com`。
- `brandColor`：预设品牌背景色。
- `iconLabel`：无本地图标时的文字图标，例如“淘”“知”“红”“抖”。
- `iconSource`：可用本地图标资源。当前只有哔哩哔哩使用已有 SVG。

当前 UI 行为：

- 软件本身仍优先使用现有 `image://appicon/<path>` 获取真实系统图标。
- 网站有本地图标时使用本地图标。
- 网站没有本地图标时使用 `iconLabel` 文字 fallback。
- Memory Lake 封面、每日占比图、首页、统计页、记忆湖排行现在都能使用统一站点颜色。
- 首页、统计页、记忆湖排行和封面在站点没有本地图标时会显示文字 fallback。

## 未实现

这些能力尚未做：

- 不读取真实浏览器 URL。
- 不自动下载 favicon。
- 不从 Chrome/Edge/Firefox 历史库读取域名。
- 不提供用户自定义站点规则。
- 不拆分微信、网易云、WPS、剪映等原生客户端，它们继续走现有 app 识别逻辑。
- 不加入 YouTube、Google、GitHub、ChatGPT 等全球/开发者网站；v1 先以中国大陆常用网站为主。

## 已知限制

- v1 依赖浏览器窗口标题识别，准确率受标题格式影响。
- 如果网页标题不包含域名或站点中文名，可能无法识别。
- 如果普通网页标题里包含站点关键词，理论上可能误命中。
- 自动 favicon 获取需要未来接浏览器扩展或 URL 来源后再做，避免当前引入联网、授权和稳定性问题。

## 验证记录

- 已新增 `timearc_db_smoke` 覆盖：哔哩哔哩、淘宝、知乎、小红书命中正确 `site:*`，普通 Chrome 文档页不命中。
- `build\timearc_db_smoke.exe` 已直接运行通过，退出码为 0。
- `mingw32-make -C build timearc_db_smoke` 已成功重新构建测试目标。
- `ctest --test-dir build -R timearc_db_smoke --output-on-failure` 当前无法写入 `build/Testing/Temporary/LastTest.log`，普通权限和提升权限下都返回 `Permission denied`。
- `.harness/tools/preflight.py --track B` 超过 30 秒未返回，按本次任务约定跳过。
- `.harness/tools/build.py` 因无法写入 `.harness/journal/build-logs/*.log` 返回 `Permission denied`，按本次任务约定跳过。
- 主应用 `time-arc` 目标构建多次均因本地构建速度超过 10 分钟超时；期间已重新生成并编译相关 QML cache 文件、`daily_card_service.cpp` 和 `usage_stat_manager.cpp`，未见编译错误输出，但完整 `TimeArc.exe` 链接未在本次会话完成。

## v2：主流视频网站图标与媒体标题

当前已经把主流视频网站纳入 `site_catalog.h` 并获取首批本地图标。首批视频站点包括：Bilibili、小红书、爱奇艺、优酷、腾讯视频、芒果TV、抖音、快手、西瓜视频、AcFun、YouTube、Netflix、Twitch、斗鱼、虎牙。

图标资产规则：
- repo 内首批图标放在 `resources/icons/sites/`，并通过 `resources/CMakeLists.txt` 打进 Qt resources。
- `docs/site-icon-assets.md` 记录每个图标的来源 URL、文件名和获取方式。
- QML 只消费本地 `qrc:` 或缓存 `file:` 图标，不直接联网。
- 如果图标获取失败，UI 继续使用 `iconLabel + brandColor`，不能因为 favicon 失败影响统计聚合。

标题适配规则：
- foreground 的浏览器 `window_title` 和 media 的 `media_title/window_title` 共用同一个 `site_catalog.h` 匹配目录。
- 未命中的普通网页继续归到 Chrome、Edge、Firefox 等浏览器 app，不强行拆分。
- 后续如果接入浏览器扩展或真实 URL，再把 domain/favIconUrl 作为更高置信度来源；当前阶段仍只依赖标题和本地 catalog。

本轮验证：
- `build.py -- --target timearc_db_smoke` 通过。
- `build\timearc_db_smoke.exe` 在补齐 Qt/MinGW runtime PATH 后通过。
- `build.py -- --target time-arc` 通过，验证 QML 与资源打包链路。
