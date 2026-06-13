#ifndef TIMEARC_SITE_CATALOG_H
#define TIMEARC_SITE_CATALOG_H

#include <QString>
#include <QStringList>
#include <QVector>

namespace TimeArcSiteCatalog {

struct SiteDefinition {
  QString siteId;
  QString displayName;
  QString category;
  QString domain;
  QString brandColor;
  QString iconLabel;
  QString iconSource;
  QStringList titleHints;
};

inline const QVector<SiteDefinition>& sites() {
  static const QVector<SiteDefinition> entries = {
      {QStringLiteral("site:bilibili"), QStringLiteral("\u54D4\u54E9\u54D4\u54E9"),
       QStringLiteral("\u89C6\u9891"), QStringLiteral("bilibili.com"),
       QStringLiteral("#FABECF"), QStringLiteral("B"),
       QStringLiteral("qrc:/qt/qml/time_arc/resources/icons/sites/bilibili.png"),
       {QStringLiteral("bilibili"), QStringLiteral("b23.tv"),
        QStringLiteral("\u54D4\u54E9\u54D4\u54E9"), QStringLiteral("bilibili.com")}},
      {QStringLiteral("site:douyin"), QStringLiteral("\u6296\u97F3"),
       QStringLiteral("\u77ED\u89C6\u9891"), QStringLiteral("douyin.com"),
       QStringLiteral("#E8E2F1"), QStringLiteral("\u6296"),
       QStringLiteral("qrc:/qt/qml/time_arc/resources/icons/sites/douyin.ico"),
       {QStringLiteral("douyin"), QStringLiteral("\u6296\u97F3"),
        QStringLiteral("douyin.com")}},
      {QStringLiteral("site:xiaohongshu"), QStringLiteral("\u5C0F\u7EA2\u4E66"),
       QStringLiteral("\u793E\u4EA4"), QStringLiteral("xiaohongshu.com"),
       QStringLiteral("#F5D7DE"), QStringLiteral("\u7EA2"),
       QStringLiteral("qrc:/qt/qml/time_arc/resources/icons/sites/xiaohongshu.ico"),
       {QStringLiteral("xiaohongshu"), QStringLiteral("\u5C0F\u7EA2\u4E66"),
        QStringLiteral("xiaohongshu.com")}},
      {QStringLiteral("site:weibo"), QStringLiteral("\u5FAE\u535A"),
       QStringLiteral("\u793E\u4EA4"), QStringLiteral("weibo.com"),
       QStringLiteral("#E6162D"), QStringLiteral("\u5FAE"), QString(),
       {QStringLiteral("weibo"), QStringLiteral("\u5FAE\u535A"),
        QStringLiteral("weibo.com")}},
      {QStringLiteral("site:zhihu"), QStringLiteral("\u77E5\u4E4E"),
       QStringLiteral("\u77E5\u8BC6"), QStringLiteral("zhihu.com"),
       QStringLiteral("#1772F6"), QStringLiteral("\u77E5"), QString(),
       {QStringLiteral("zhihu"), QStringLiteral("\u77E5\u4E4E"),
        QStringLiteral("zhihu.com")}},
      {QStringLiteral("site:taobao"), QStringLiteral("\u6DD8\u5B9D"),
       QStringLiteral("\u8D2D\u7269"), QStringLiteral("taobao.com"),
       QStringLiteral("#FF5000"), QStringLiteral("\u6DD8"), QString(),
       {QStringLiteral("taobao"), QStringLiteral("\u6DD8\u5B9D"),
        QStringLiteral("taobao.com")}},
      {QStringLiteral("site:tmall"), QStringLiteral("\u5929\u732B"),
       QStringLiteral("\u8D2D\u7269"), QStringLiteral("tmall.com"),
       QStringLiteral("#DD2727"), QStringLiteral("\u732B"), QString(),
       {QStringLiteral("tmall"), QStringLiteral("\u5929\u732B"),
        QStringLiteral("tmall.com")}},
      {QStringLiteral("site:jd"), QStringLiteral("\u4EAC\u4E1C"),
       QStringLiteral("\u8D2D\u7269"), QStringLiteral("jd.com"),
       QStringLiteral("#E2231A"), QStringLiteral("\u4EAC"), QString(),
       {QStringLiteral("jd.com"), QStringLiteral("\u4EAC\u4E1C"),
        QStringLiteral("jingdong")}},
      {QStringLiteral("site:pinduoduo"), QStringLiteral("\u62FC\u591A\u591A"),
       QStringLiteral("\u8D2D\u7269"), QStringLiteral("pinduoduo.com"),
       QStringLiteral("#E02E24"), QStringLiteral("\u62FC"), QString(),
       {QStringLiteral("pinduoduo"), QStringLiteral("\u62FC\u591A\u591A"),
        QStringLiteral("yangkeduo")}},
      {QStringLiteral("site:baidu"), QStringLiteral("\u767E\u5EA6"),
       QStringLiteral("\u641C\u7D22"), QStringLiteral("baidu.com"),
       QStringLiteral("#2932E1"), QStringLiteral("\u767E"), QString(),
       {QStringLiteral("baidu"), QStringLiteral("\u767E\u5EA6"),
        QStringLiteral("baidu.com")}},
      {QStringLiteral("site:iqiyi"), QStringLiteral("\u7231\u5947\u827A"),
       QStringLiteral("\u89C6\u9891"), QStringLiteral("iqiyi.com"),
       QStringLiteral("#D8F0D6"), QStringLiteral("\u7231"),
       QStringLiteral("qrc:/qt/qml/time_arc/resources/icons/sites/iqiyi.ico"),
       {QStringLiteral("iqiyi"), QStringLiteral("\u7231\u5947\u827A"),
        QStringLiteral("iqiyi.com")}},
      {QStringLiteral("site:youku"), QStringLiteral("\u4F18\u9177"),
       QStringLiteral("\u89C6\u9891"), QStringLiteral("youku.com"),
       QStringLiteral("#D5ECF6"), QStringLiteral("\u4F18"),
       QStringLiteral("qrc:/qt/qml/time_arc/resources/icons/sites/youku.ico"),
       {QStringLiteral("youku"), QStringLiteral("\u4F18\u9177"),
        QStringLiteral("youku.com")}},
      {QStringLiteral("site:tencent-video"),
       QStringLiteral("\u817E\u8BAF\u89C6\u9891"),
       QStringLiteral("\u89C6\u9891"), QStringLiteral("v.qq.com"),
       QStringLiteral("#F5E4BE"), QStringLiteral("\u817E"),
       QStringLiteral("qrc:/qt/qml/time_arc/resources/icons/sites/tencent-video.ico"),
       {QStringLiteral("\u817E\u8BAF\u89C6\u9891"), QStringLiteral("v.qq.com"),
        QStringLiteral("qqlive")}},
      {QStringLiteral("site:mango-tv"), QStringLiteral("\u8292\u679CTV"),
       QStringLiteral("\u89C6\u9891"), QStringLiteral("mgtv.com"),
       QStringLiteral("#F4DDC7"), QStringLiteral("\u8292"),
       QStringLiteral("qrc:/qt/qml/time_arc/resources/icons/sites/mango-tv.ico"),
       {QStringLiteral("mgtv"), QStringLiteral("mgtv.com"),
        QStringLiteral("\u8292\u679CTV"), QStringLiteral("\u8292\u679Ctv")}},
      {QStringLiteral("site:kuaishou"), QStringLiteral("\u5FEB\u624B"),
       QStringLiteral("\u77ED\u89C6\u9891"), QStringLiteral("kuaishou.com"),
       QStringLiteral("#F4D9C8"), QStringLiteral("\u5FEB"),
       QStringLiteral("qrc:/qt/qml/time_arc/resources/icons/sites/kuaishou.ico"),
       {QStringLiteral("kuaishou"), QStringLiteral("\u5FEB\u624B"),
        QStringLiteral("kuaishou.com")}},
      {QStringLiteral("site:xigua-video"),
       QStringLiteral("\u897F\u74DC\u89C6\u9891"),
       QStringLiteral("\u89C6\u9891"), QStringLiteral("ixigua.com"),
       QStringLiteral("#F3D5D2"), QStringLiteral("\u74DC"),
       QStringLiteral("qrc:/qt/qml/time_arc/resources/icons/sites/xigua-video.ico"),
       {QStringLiteral("ixigua"), QStringLiteral("\u897F\u74DC\u89C6\u9891"),
        QStringLiteral("ixigua.com")}},
      {QStringLiteral("site:acfun"), QStringLiteral("AcFun"),
       QStringLiteral("\u89C6\u9891"), QStringLiteral("acfun.cn"),
       QStringLiteral("#F5D7DD"), QStringLiteral("A"),
       QStringLiteral("qrc:/qt/qml/time_arc/resources/icons/sites/acfun.ico"),
       {QStringLiteral("acfun"), QStringLiteral("acfun.cn"),
        QStringLiteral("a\u7AD9"), QStringLiteral("A\u7AD9")}},
      {QStringLiteral("site:youtube"), QStringLiteral("YouTube"),
       QStringLiteral("\u89C6\u9891"), QStringLiteral("youtube.com"),
       QStringLiteral("#F2D4D4"), QStringLiteral("Y"),
       QStringLiteral("qrc:/qt/qml/time_arc/resources/icons/sites/youtube.ico"),
       {QStringLiteral("youtube"), QStringLiteral("youtu.be"),
        QStringLiteral("youtube.com")}},
      {QStringLiteral("site:netflix"), QStringLiteral("Netflix"),
       QStringLiteral("\u89C6\u9891"), QStringLiteral("netflix.com"),
       QStringLiteral("#EFD3D5"), QStringLiteral("N"),
       QStringLiteral("qrc:/qt/qml/time_arc/resources/icons/sites/netflix.ico"),
       {QStringLiteral("netflix"), QStringLiteral("netflix.com")}},
      {QStringLiteral("site:twitch"), QStringLiteral("Twitch"),
       QStringLiteral("\u89C6\u9891"), QStringLiteral("twitch.tv"),
       QStringLiteral("#E6DCF7"), QStringLiteral("T"),
       QStringLiteral("qrc:/qt/qml/time_arc/resources/icons/sites/twitch.ico"),
       {QStringLiteral("twitch"), QStringLiteral("twitch.tv")}},
      {QStringLiteral("site:douyu"), QStringLiteral("\u6597\u9C7C"),
       QStringLiteral("\u76F4\u64AD"), QStringLiteral("douyu.com"),
       QStringLiteral("#F4DEC7"), QStringLiteral("\u6597"),
       QStringLiteral("qrc:/qt/qml/time_arc/resources/icons/sites/douyu.ico"),
       {QStringLiteral("douyu"), QStringLiteral("\u6597\u9C7C"),
        QStringLiteral("douyu.com")}},
      {QStringLiteral("site:huya"), QStringLiteral("\u864E\u7259"),
       QStringLiteral("\u76F4\u64AD"), QStringLiteral("huya.com"),
       QStringLiteral("#F3E0C4"), QStringLiteral("\u864E"),
       QStringLiteral("qrc:/qt/qml/time_arc/resources/icons/sites/huya.png"),
       {QStringLiteral("huya"), QStringLiteral("\u864E\u7259"),
        QStringLiteral("huya.com")}},
      {QStringLiteral("site:douban"), QStringLiteral("\u8C46\u74E3"),
       QStringLiteral("\u77E5\u8BC6"), QStringLiteral("douban.com"),
       QStringLiteral("#007722"), QStringLiteral("\u8C46"), QString(),
       {QStringLiteral("douban"), QStringLiteral("\u8C46\u74E3"),
        QStringLiteral("douban.com")}},
      {QStringLiteral("site:csdn"), QStringLiteral("CSDN"),
       QStringLiteral("\u5F00\u53D1"), QStringLiteral("csdn.net"),
       QStringLiteral("#C92027"), QStringLiteral("C"), QString(),
       {QStringLiteral("csdn"), QStringLiteral("csdn.net")}},
      {QStringLiteral("site:alipay"), QStringLiteral("\u652F\u4ED8\u5B9D"),
       QStringLiteral("\u652F\u4ED8"), QStringLiteral("alipay.com"),
       QStringLiteral("#1677FF"), QStringLiteral("\u652F"), QString(),
       {QStringLiteral("alipay"), QStringLiteral("\u652F\u4ED8\u5B9D"),
        QStringLiteral("alipay.com")}},
      {QStringLiteral("site:meituan"), QStringLiteral("\u7F8E\u56E2"),
       QStringLiteral("\u751F\u6D3B"), QStringLiteral("meituan.com"),
       QStringLiteral("#FFD100"), QStringLiteral("\u56E2"), QString(),
       {QStringLiteral("meituan"), QStringLiteral("\u7F8E\u56E2"),
        QStringLiteral("meituan.com")}},
      {QStringLiteral("site:dianping"), QStringLiteral("\u5927\u4F17\u70B9\u8BC4"),
       QStringLiteral("\u751F\u6D3B"), QStringLiteral("dianping.com"),
       QStringLiteral("#FF7A00"), QStringLiteral("\u70B9"), QString(),
       {QStringLiteral("dianping"), QStringLiteral("\u5927\u4F17\u70B9\u8BC4"),
        QStringLiteral("dianping.com")}},
  };
  return entries;
}

inline const SiteDefinition* findBySiteId(const QString& siteId) {
  const QString normalized = siteId.trimmed().toLower();
  if (normalized.isEmpty()) return nullptr;

  for (const SiteDefinition& site : sites()) {
    if (site.siteId == normalized) return &site;
  }
  return nullptr;
}

inline const SiteDefinition* matchByWindowTitle(const QString& windowTitle) {
  const QString title = windowTitle.trimmed();
  if (title.isEmpty()) return nullptr;

  const QString lowerTitle = title.toLower();
  for (const SiteDefinition& site : sites()) {
    for (const QString& hint : site.titleHints) {
      if (!hint.trimmed().isEmpty() && lowerTitle.contains(hint.toLower())) {
        return &site;
      }
    }
  }
  return nullptr;
}

}  // namespace TimeArcSiteCatalog

#endif
