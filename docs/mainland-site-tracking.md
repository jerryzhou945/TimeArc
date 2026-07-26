# 中国大陆常用网站独立记录

TimeArc 会在 UI 聚合层把浏览器里的部分常用网站提升为独立的
`site:*` 活动，而不是统一显示为 Chrome、Edge 或 Firefox。后端 service
和磁盘 schema 不需要变化：service 继续记录前台窗口和媒体会话，UI 读取时用本地
站点目录做识别。

## 已支持站点

首批大陆常用站点：

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
- 芒果 TV：`site:mango-tv`
- 快手：`site:kuaishou`
- 西瓜视频：`site:xigua-video`
- AcFun：`site:acfun`
- 豆瓣：`site:douban`
- CSDN：`site:csdn`
- 支付宝：`site:alipay`
- 美团：`site:meituan`
- 大众点评：`site:dianping`

另外，YouTube、Netflix、Twitch、斗鱼、虎牙也共用同一套站点目录和图标渲染逻辑。

## 识别方式

- 浏览器前台记录会读取 `window_title`，例如 `douyin.com/... - Google Chrome`
  会聚合为 `site:douyin`。
- 媒体记录会读取 `media_title/window_title`，例如 `...的抖音 - 抖音` 也会聚合为
  `site:douyin`。
- 小红书这类标题不总是暴露真实 URL 的网站，会通过中文站点名关键词匹配，例如
  `小红书 - 你的生活兴趣社区 - Google Chrome`。
- 未命中的普通网页仍归到原浏览器应用，避免把浏览器使用记录切得过碎。

## UI 视觉字段

站点聚合结果会输出统一字段供 QML 渲染：

- `siteDomain`：主域名，例如 `taobao.com`。
- `brandColor`：预设品牌背景色。
- `iconLabel`：没有本地图标时的文字 fallback。
- `iconSource`：可用的本地 Qt resource 图标。

当前 UI 行为：

- 原生软件优先使用 `image://appicon/<path>` 获取系统图标。
- 站点有本地图标时使用本地图标。
- 站点没有本地图标时使用 `iconLabel + brandColor`。
- 首页、统计页、设置页和记忆湖共享 `AppVisual.js`，避免不同页面出现不同图标。

## 图标资产规则

- repo 内站点图标放在 `resources/app/icons/sites/`，并通过
  `resources/CMakeLists.txt` 打进 Qt resources。
- `docs/site-icon-assets.md` 记录每个图标的来源 URL、文件名和获取方式。
- 本轮优先使用官方首页 metadata 里的 high-resolution `apple-touch-icon` 或等价
  PNG；如果官网只暴露 favicon，则保留 favicon，不伪造高像素资源。
- QML 只消费本地 `qrc:` / bundled resource，不在运行期直接联网下载图标。

## 已知限制

- 当前识别仍依赖窗口标题和媒体标题，不读取真实浏览器 URL。
- 如果页面标题不包含域名或站点中文名，可能无法识别。
- 如果普通网页标题包含站点关键词，理论上可能误命中。
- 自动 favicon 获取需要后续接入浏览器扩展或 URL 来源后再做，避免当前引入运行期联网、授权和稳定性问题。

## 验证记录

- `timearc_db_smoke` 覆盖了 Douyin/Xiaohongshu 的浏览器标题、Douyin 媒体标题、
  Zhihu/Youku 的高像素图标路径。
- 构建时需要补齐 Qt/MinGW/CMake/Ninja 到 `PATH`，当前机器有效前缀是
  `D:\TimeArc\QT\Tools\mingw1310_64\bin;D:\TimeArc\QT\6.11.0\mingw_64\bin;D:\TimeArc\QT\Tools\CMake_64\bin;D:\TimeArc\QT\Tools\Ninja;`。
