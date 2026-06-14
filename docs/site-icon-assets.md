# Site Icon Assets

TimeArc stores website icons as local Qt resources. The UI never fetches
icons from the network at runtime; new icons are refreshed manually from
official homepage metadata or official favicon endpoints, then recorded here.

| Site | File | Source URL | Acquisition Method | Notes |
|------|------|------------|--------------------|-------|
| Bilibili | `resources/icons/sites/bilibili.png` | `https://i0.hdslb.com/bfs/static/jinkela/long/images/512.png` | official 512px homepage metadata icon | Trademark belongs to the site owner. |
| Douyin | `resources/icons/sites/douyin.ico` | `https://www.douyin.com/favicon.ico` | official favicon download | Homepage metadata did not expose a larger icon during refresh, so this remains a favicon fallback. |
| Xiaohongshu | `resources/icons/sites/xiaohongshu.png` | `https://picasso-static.xiaohongshu.com/fe-platform/f43dc4a8baf03678996c62d8db6ebc01a82256ff.png` | official 180px apple-touch icon from homepage metadata | Replaces the previous favicon fallback. |
| Weibo | `resources/icons/sites/weibo.ico` | `https://weibo.com/favicon.ico` | official favicon download | No larger homepage metadata icon found during refresh. |
| Zhihu | `resources/icons/sites/zhihu.png` | `https://static.zhihu.com/heifetz/assets/apple-touch-icon-152.81060cab.png` | official 152px apple-touch icon from homepage metadata | Trademark belongs to the site owner. |
| Taobao | `resources/icons/sites/taobao.png` | `https://img.alicdn.com/tps/i3/T1OjaVFl4dXXa.JOZB-114-114.png` | official 114px icon from homepage metadata | Trademark belongs to the site owner. |
| Tmall | `resources/icons/sites/tmall.png` | `https://img.alicdn.com/tps/i3/T1OjaVFl4dXXa.JOZB-114-114.png` | official 114px icon from homepage metadata | Tmall currently shares Alibaba's official touch icon. |
| JD | `resources/icons/sites/jd.ico` | `https://www.jd.com/favicon.ico` | official favicon download | No larger homepage metadata icon found during refresh. |
| Pinduoduo | `resources/icons/sites/pinduoduo.png` | `https://www.pinduoduo.com/favicon.png` | official 48px favicon download | No larger homepage metadata icon found during refresh. |
| Baidu | `resources/icons/sites/baidu.png` | `https://psstatic.cdn.bcebos.com/video/wiseindex/aa6eef91f8b5b1a33b454c401_1660835115000.png` | official 1024px apple-touch icon from homepage metadata | Trademark belongs to the site owner. |
| iQIYI | `resources/icons/sites/iqiyi.png` | `https://www.iqiyi.com/logo.png` | official 256px PWA manifest icon | Replaces the previous favicon fallback. |
| Youku | `resources/icons/sites/youku.png` | `https://img.alicdn.com/imgextra/i2/O1CN01BeAcgL1ywY0G5nSn8_!!6000000006643-2-tps-195-195.png` | official 195px icon from homepage metadata | Replaces the previous low-resolution favicon. |
| Tencent Video | `resources/icons/sites/tencent-video.png` | `https://vfiles.gtimg.cn/wuji_dashboard/xy/starter/4ea79867.png` | official 192px icon from homepage metadata | Replaces the previous low-resolution favicon. |
| Mango TV | `resources/icons/sites/mango-tv.png` | `https://static.hitv.com/pc/icons/icon_512x512.1b7ca7.png` | official 512px icon from homepage metadata | Replaces the previous low-resolution favicon. |
| Kuaishou | `resources/icons/sites/kuaishou.ico` | `https://www.kuaishou.com/favicon.ico` | official favicon download | Trademark belongs to the site owner. |
| Xigua Video | `resources/icons/sites/xigua-video.ico` | `https://www.ixigua.com/favicon.ico` | official favicon download | Trademark belongs to the site owner. |
| AcFun | `resources/icons/sites/acfun.png` | `https://www.acfun.cn/sr/icon-512x512.png` | official 512px PWA manifest icon | Replaces the previous favicon fallback. |
| YouTube | `resources/icons/sites/youtube.png` | `https://www.youtube.com/s/desktop/43517217/img/favicon_144x144.png` | official 144px icon from homepage metadata | Replaces the previous low-resolution favicon. |
| Netflix | `resources/icons/sites/netflix.png` | `https://assets.nflxext.com/us/ffe/siteui/common/icons/nficon2016.png` | official 64px apple-touch icon from homepage metadata | Replaces the previous ICO fallback. |
| Twitch | `resources/icons/sites/twitch.ico` | `https://www.twitch.tv/favicon.ico` | official favicon download | Trademark belongs to the site owner. |
| Douyu | `resources/icons/sites/douyu.ico` | `https://www.douyu.com/favicon.ico` | official favicon download | Trademark belongs to the site owner. |
| Huya | `resources/icons/sites/huya.png` | `https://www.huya.com/favicon.ico` | official favicon download | Endpoint returned PNG bytes. Trademark belongs to the site owner. |
| Douban | `resources/icons/sites/douban.ico` | `https://www.douban.com/favicon.ico` | official favicon download | No larger homepage metadata icon found during refresh. |
| CSDN | n/a | n/a | not acquired | The homepage returned HTTP 521 during refresh, so this still uses text fallback. |
| Alipay | `resources/icons/sites/alipay.png` | `https://mdn.alipayobjects.com/rms/afts/file/A*7EyORZxdNDkAAAAAAAAAAAAAARQnAQ` | official 2600x1950 homepage shortcut image | Preserved as official high-resolution artwork even though it is not square. |
| Meituan | `resources/icons/sites/meituan.ico` | `https://s3plus.meituan.net/v1/mss_e2821d7f0cfe4ac1bf9202ecf9590e67/cdn-prod/file:1040877d/favicon-mt.ico` | official favicon download | No larger homepage metadata icon found during refresh. |
| Dianping | `resources/icons/sites/dianping.ico` | `https://www.dianping.com/favicon.ico` | official favicon download | No larger homepage metadata icon found during refresh. |
